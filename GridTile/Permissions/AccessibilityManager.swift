import AppKit
import ApplicationServices
import Combine

/// Wraps macOS's Accessibility trust APIs (§21). GridTile needs Accessibility
/// permission to read the focused window of other applications and to move /
/// resize them via `AXUIElement`.
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    /// Published so SwiftUI permission UI can react live without polling from
    /// the view layer itself.
    @Published private(set) var isTrusted: Bool

    private var pollTimer: Timer?

    private init() {
        isTrusted = AXIsProcessTrusted()
    }

    /// Re-checks trust status. Called on app foregrounding and from the
    /// permissions screen; also runs on a low-frequency timer only while the
    /// permissions screen itself is visible (see `startObservingWhileVisible`)
    /// so idle CPU stays at zero the rest of the time (§27).
    @discardableResult
    func refresh() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted {
            isTrusted = trusted
        }
        return trusted
    }

    /// Prompts the user with the system's own "GridTile would like to control
    /// this computer" dialog, which includes a direct link into System
    /// Settings. Only call this in response to explicit user action (e.g. a
    /// "Grant Access" button), not silently at launch.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        refresh()
    }

    /// Opens System Settings directly to the Accessibility pane as a fallback
    /// for users who dismissed the system prompt.
    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Starts a short-lived, low-frequency poll used only while the onboarding /
    /// permissions view is on screen, since there is no push notification for
    /// accessibility-trust changes. Stops itself automatically.
    func startObservingWhileVisible() {
        stopObserving()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopObserving() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
