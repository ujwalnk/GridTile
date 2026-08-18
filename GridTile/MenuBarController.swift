import AppKit
import Combine

/// Owns GridTile's `NSStatusItem` and menu (§4). GridTile has no Dock
/// presence (`LSUIElement` in Info.plist) — this menu is the app's primary
/// surface alongside the Settings window.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private var cancellable: AnyCancellable?
    private var openSettings: () -> Void

    init(appState: AppState, openSettings: @escaping () -> Void) {
        self.appState = appState
        self.openSettings = openSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            if let image = NSImage(named: "icon-bw") {

                image.isTemplate = false
                image.size = NSSize(width: 18, height: 18)

                button.image = image
            } 
        }


        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()

        cancellable = appState.$configuration.sink { [weak self] _ in
            self?.rebuildMenu()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let title = NSMenuItem(title: "GridTile", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        for layout in appState.configuration.layouts {
            let item = NSMenuItem(title: layout.name, action: #selector(activateLayout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = layout.id
            item.toolTip = "Activate \(layout.name) (\(layout.activationShortcut.displayString))"

            // Show the configured shortcut as a right-aligned hint via an
            // attributed title, since NSMenuItem's own keyEquivalent field
            // can't represent arbitrary key codes like our custom shortcuts.
            let attributed = NSMutableAttributedString(string: layout.name)
            let hint = NSAttributedString(
                string: "  " + layout.activationShortcut.displayString,
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
            attributed.append(hint)
            item.attributedTitle = attributed

            menu.addItem(item)
        }

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit GridTile", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func activateLayout(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        appState.activate(layoutID: id)
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
