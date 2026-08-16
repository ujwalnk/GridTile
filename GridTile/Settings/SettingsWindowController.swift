import AppKit
import SwiftUI

/// Owns the single Settings window. Created once and reused — repeated
/// "Settings…" clicks just re-show the same window rather than creating new
/// ones.
final class SettingsWindowController: NSWindowController {
    private let appState: AppState
    private let selectedTab = CurrentValueSubjectBox(SettingsTab.layouts)

    init(appState: AppState) {
        self.appState = appState

        let rootView = SettingsRootView(appState: appState, selectedTab: selectedTab)
        let hosting = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hosting)
        window.title = "GridTile Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 560))
        window.minSize = NSSize(width: 640, height: 480)
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func showPermissionsOnboarding() {
        selectedTab.value = .permissions
        show()
    }
}

/// Tiny `ObservableObject` box so a plain `@State`-free reference type can be
/// shared between the window controller (which decides *when* to switch tabs,
/// e.g. for onboarding) and the SwiftUI view (which owns the tab UI).
final class CurrentValueSubjectBox: ObservableObject {
    @Published var value: SettingsTab
    init(_ value: SettingsTab) { self.value = value }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case layouts = "Layouts"
    case permissions = "Permissions"
    var id: String { rawValue }
}
