import AppKit
import SwiftUI

/// Presents `StartupGuideView` in its own small window for the automatic
/// first-launch appearance (§4) — kept separate from `SettingsWindowController`
/// so the guide can show up immediately without the full settings UI opening
/// behind it.
final class StartupGuideWindowController: NSWindowController {
    init(appState: AppState) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to GridTile"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        let view = StartupGuideView(appState: appState, isPresentedStandalone: false) { [weak self] in
            self?.close()
        }
        window.contentViewController = NSHostingController(rootView: view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    override func close() {
        window?.close()
    }
}
