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

        // GridTile's own activation (`NSApp.activate(ignoringOtherApps:)`,
        // called when the overlay is shown — see `GridOverlayController`)
        // takes key/main status away from `window`'s application *before*
        // the user makes any cell selection at all. How long that
        // application has had to finish reacting to losing key/main status
        // by the time we get here is exactly "how long the overlay stayed
        // up," i.e. how long the user took to pick two cells — not anything
        // about the AX calls below. Several apps apply a programmatic AX
        // frame change asynchronously relative to their own focus-resignation
        // handling (on a later layout/display pass rather than synchronously
        // inside the AX call), so a frame change applied while that handling
        // is still in flight can be partially dropped or clamped — reported
        // as `.success` regardless. That's why this was reproducible as
        // "fast selection → broken, slow selection → fine": less elapsed
        // settle time makes the race more likely to be lost, not the
        // keystrokes themselves.
        //
        // Fix: verify the window's *actual* resulting AX frame against what
        // was requested, and only if it doesn't match, retry — bounded, and
        // only for the attribute(s) that are actually still wrong. This is
        // deliberately not a blind pre-emptive delay: compliant apps (the
        // common case) resolve on the first attempt and pay no extra cost;
        // only a genuine mismatch pays the (small, bounded) retry cost.
        let maxAttempts = 4
        let retryDelay: TimeInterval = 0.100
        let tolerance: CGFloat = 1.0

        var lastPositionResult: AXError = .success
        var lastSizeResult: AXError = .success

        for attempt in 1...maxAttempts {
            lastPositionResult = AXUIElementSetAttributeValue(window.axWindow, kAXPositionAttribute as CFString, positionValue)
            lastSizeResult = AXUIElementSetAttributeValue(window.axWindow, kAXSizeAttribute as CFString, sizeValue)

            guard let resultingFrame = currentFrame(of: window) else {
                throw GridTileError.targetWindowDisappeared
            }
            let resultingAXFrame = Self.axFrame(fromCocoaFrame: resultingFrame)

            let positionMatches = abs(resultingAXFrame.origin.x - origin.x) <= tolerance
                && abs(resultingAXFrame.origin.y - origin.y) <= tolerance
            let sizeMatches = abs(resultingAXFrame.width - size.width) <= tolerance
                && abs(resultingAXFrame.height - size.height) <= tolerance

            if positionMatches && sizeMatches {
                return
            }

            if attempt < maxAttempts {
                Thread.sleep(forTimeInterval: retryDelay)
            }
        }

        guard lastPositionResult == .success, lastSizeResult == .success else {
            throw GridTileError.windowMoveFailed("the application declined the new frame")
        }
        // The AX calls themselves reported success every time, but the
        // window's actual frame still doesn't match the request after the
        // full retry budget — the application is silently clamping or
        // ignoring part of the requested frame rather than rejecting it
        // outright.
        throw GridTileError.windowMoveFailed("the application did not apply the full requested frame")
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
