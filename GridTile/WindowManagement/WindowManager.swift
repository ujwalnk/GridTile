import AppKit
import ApplicationServices

/// Moves and resizes windows belonging to *other* applications using the
/// Accessibility (`AXUIElement`) API — the only supported way to reposition
/// another process's window on modern macOS (§23).
enum WindowManager {
    /// Applies `targetFrame` (in AppKit/Cocoa global screen coordinates —
    /// bottom-left origin, points) to `window`.
    ///
    /// The Accessibility API expects **top-left-origin, main-display-relative**
    /// coordinates (matching `CGWindowListCopyWindowInfo` / Core Graphics
    /// global space), so this is the one place that conversion happens (§12).
    static func apply(frame targetFrame: CGRect, to window: FocusedWindowInfo) throws {
        guard AccessibilityManager.shared.refresh() else {
            throw GridTileError.accessibilityPermissionMissing
        }
        guard window.stillExists else {
            throw GridTileError.targetWindowDisappeared
        }

        let axFrame = Self.axFrame(fromCocoaFrame: targetFrame)

        // Position is applied before size so that, for apps which validate a
        // requested size against the window's *current* on-screen position
        // (rejecting/clamping sizes that would put the window off-screen at
        // its old location), the size request is evaluated against the
        // frame's *new* origin rather than a stale one.
        var size = CGSize(width: axFrame.width, height: axFrame.height)
        var origin = CGPoint(x: axFrame.origin.x, y: axFrame.origin.y)

        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let positionValue = AXValueCreate(.cgPoint, &origin) else {
            throw GridTileError.windowMoveFailed("could not construct AX values")
        }

        let positionResult = AXUIElementSetAttributeValue(window.axWindow, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(window.axWindow, kAXSizeAttribute as CFString, sizeValue)

        guard positionResult == .success, sizeResult == .success else {
            throw GridTileError.windowMoveFailed("the application declined the new frame")
        }

        // Some apps clamp size in a way that shifts position as a side
        // effect, so the resulting position can drift from what was
        // requested even though both calls above reported success. Correct
        // that — but only when it actually happened: re-issuing the position
        // write unconditionally, immediately after the size write, races
        // with apps that apply a programmatic resize asynchronously (e.g. on
        // their next layout/display pass rather than synchronously inside
        // the AX call). For those apps, an unconditional follow-up position
        // write can be processed by the app *before* its own pending resize
        // has been committed internally; the app then re-derives the frame
        // from its still-stale size when handling the move, silently
        // discarding the resize. That race is what produced GridTile's
        // intermittent "moved but not resized" bug. Reading the actual
        // resulting frame back and only correcting position when it's
        // actually wrong avoids sending that redundant, racy AX call in the
        // common case.
        if let resultingFrame = currentFrame(of: window) {
            let resultingAXFrame = Self.axFrame(fromCocoaFrame: resultingFrame)
            if abs(resultingAXFrame.origin.x - origin.x) > 0.5 || abs(resultingAXFrame.origin.y - origin.y) > 0.5 {
                AXUIElementSetAttributeValue(window.axWindow, kAXPositionAttribute as CFString, positionValue)
            }
        }
    }

    /// Converts an AppKit-space (bottom-left origin) global rectangle to
    /// Accessibility/Core Graphics space (top-left origin, relative to the
    /// primary display).
    static func axFrame(fromCocoaFrame cocoaFrame: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return cocoaFrame }
        let primaryHeight = primary.frame.height
        let axY = primaryHeight - cocoaFrame.origin.y - cocoaFrame.height
        return CGRect(x: cocoaFrame.origin.x, y: axY, width: cocoaFrame.width, height: cocoaFrame.height)
    }

    /// Converts the other direction — used when reading an existing window's
    /// AX frame back into AppKit space (e.g. to decide which screen currently
    /// contains it).
    static func cocoaFrame(fromAXFrame axFrame: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return axFrame }
        let primaryHeight = primary.frame.height
        let cocoaY = primaryHeight - axFrame.origin.y - axFrame.height
        return CGRect(x: axFrame.origin.x, y: cocoaY, width: axFrame.width, height: axFrame.height)
    }

    /// Reads a window's current on-screen frame, in AppKit/Cocoa coordinates.
    static func currentFrame(of window: FocusedWindowInfo) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window.axWindow, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window.axWindow, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef, let sizeValue = sizeRef else {
            return nil
        }
        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return cocoaFrame(fromAXFrame: CGRect(origin: origin, size: size))
    }
}
