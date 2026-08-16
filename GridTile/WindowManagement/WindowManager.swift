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

        // Setting size before position (then re-setting position) reduces
        // cases where a window that refuses a given size ends up with a
        // correct size but a stale, no-longer-matching position — a known
        // quirk of some AXUIElement implementations.
        var size = CGSize(width: axFrame.width, height: axFrame.height)
        var origin = CGPoint(x: axFrame.origin.x, y: axFrame.origin.y)

        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let positionValue = AXValueCreate(.cgPoint, &origin) else {
            throw GridTileError.windowMoveFailed("could not construct AX values")
        }

        let positionResult = AXUIElementSetAttributeValue(window.axWindow, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(window.axWindow, kAXSizeAttribute as CFString, sizeValue)
        // Re-apply position once more: some apps clamp size in a way that
        // shifts position as a side effect.
        AXUIElementSetAttributeValue(window.axWindow, kAXPositionAttribute as CFString, positionValue)

        guard positionResult == .success, sizeResult == .success else {
            throw GridTileError.windowMoveFailed("the application declined the new frame")
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
