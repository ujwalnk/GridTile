import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var menuBarController: MenuBarController!
    private var settingsWindowController: SettingsWindowController!
    private var errorCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, no app-switcher entry — GridTile lives entirely in the
        // menu bar (§4). This is also set via LSUIElement in Info.plist; both
        // are kept in sync intentionally since the plist value is what actually
        // governs Dock visibility, while this call ensures correct behavior
        // even if the app is ever launched in a context that ignores it.
        NSApp.setActivationPolicy(.accessory)

        let state = AppState()
        appState = state

        let settingsController = SettingsWindowController(appState: state)
        settingsWindowController = settingsController

        menuBarController = MenuBarController(appState: state) { [weak settingsController] in
            settingsController?.show()
        }

        errorCancellable = state.$lastError
            .compactMap { $0 }
            .sink { error in
                Self.presentError(error)
            }

        if !AccessibilityManager.shared.isTrusted {
            // First-launch (or still-not-granted) onboarding: explain why
            // GridTile needs Accessibility access before the user hits it as
            // a confusing failure mid-tile (§21).
            settingsController.showPermissionsOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static func presentError(_ error: GridTileError) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "GridTile"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
