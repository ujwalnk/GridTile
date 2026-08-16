import AppKit
import ApplicationServices

/// A snapshot of "the window the user was in before invoking GridTile",
/// captured *before* GridTile activates itself (§10 step 1). Holding the
/// `AXUIElement` directly (rather than re-querying "the focused window" later)
/// is what guarantees GridTile always resizes the window the user meant, even
/// if focus has visibly moved to GridTile's own overlay in the meantime (§23).
struct FocusedWindowInfo {
    let axWindow: AXUIElement
    let axApplication: AXUIElement
    let runningApplication: NSRunningApplication
    let pid: pid_t

    /// Captures the frontmost application's focused window. Returns `nil`
    /// (rather than throwing) when there is no focused app/window at all —
    /// callers translate that into the appropriate `GridTileError`.
    static func captureCurrentlyFocused() -> FocusedWindowInfo? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var focusedWindowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            axApp, kAXFocusedWindowAttribute as CFString, &focusedWindowRef
        )
        guard result == .success, let focusedWindowRef, CFGetTypeID(focusedWindowRef) == AXUIElementGetTypeID() else {
            return nil
        }
        // Safe: type-checked above.
        let axWindow = focusedWindowRef as! AXUIElement

        return FocusedWindowInfo(
            axWindow: axWindow,
            axApplication: axApp,
            runningApplication: frontApp,
            pid: pid
        )
    }

    /// True if the underlying window still exists (hasn't been closed since
    /// capture). Cheap check used before attempting to move/resize it.
    var stillExists: Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &value)
        return result == .success
    }

    /// Restores focus to the original application and, best-effort, its window.
    func restoreFocus() {
        runningApplication.activate(options: [])
        AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
    }
}
