import AppKit
import Combine
import SwiftUI

/// The single source of truth for GridTile's runtime state. Owns the
/// configuration, keeps global shortcuts in sync with it, and orchestrates the
/// full "activate → overlay → select → tile → restore" flow described in §10.
///
/// `ObservableObject` so SwiftUI settings views can bind directly to it.
final class AppState: ObservableObject {
    @Published private(set) var configuration: AppConfiguration
    @Published var lastError: GridTileError?

    private let store = ConfigurationStore.shared
    private var registeredHotKeyIDs: [UUID: UInt32] = [:]
    private let overlayController = GridOverlayController()

    /// The window/app GridTile is currently mid-operation on, if any. Captured
    /// before GridTile takes focus and consulted only through this reference
    /// afterward — never by re-querying "the focused window" mid-flow (§10, §23).
    private var pendingFocusedWindow: FocusedWindowInfo?

    init() {
        configuration = store.load()
        registerAllShortcuts()
    }

    // MARK: - Configuration mutation (used by Settings UI)

    func updateLayouts(_ layouts: [GridLayoutModel]) {
        configuration.layouts = layouts
        persistAndReregister()
    }

    func updateLayout(_ layout: GridLayoutModel) {
        guard let index = configuration.layouts.firstIndex(where: { $0.id == layout.id }) else { return }
        configuration.layouts[index] = layout
        persistAndReregister()
    }

    func addLayout() -> GridLayoutModel {
        let index = configuration.layouts.count + 1
        var layout = DefaultLayoutFactory.makeDefaultLayout()
        layout.id = UUID()
        layout.name = "Layout \(index)"
        layout.activationShortcut = nextAvailableDefaultActivationShortcut()
        configuration.layouts.append(layout)
        persistAndReregister()
        return layout
    }

    /// `⌃⌥<N>`-style defaults are derived from a layout's position, but a
    /// layout can be removed and a new one added later, or an existing
    /// layout's shortcut can be hand-edited — either can leave the "next"
    /// positional default already claimed by another layout. Walking forward
    /// until an unclaimed one is found keeps every new layout's shortcut
    /// independently usable from the moment it's created, rather than
    /// handing out one that immediately conflicts (§9).
    private func nextAvailableDefaultActivationShortcut() -> KeyboardShortcut {
        let used = Set(configuration.layouts.map(\.activationShortcut))
        var index = configuration.layouts.count + 1
        var candidate = KeyboardShortcut.defaultActivationShortcut(index: index)
        while used.contains(candidate) {
            index += 1
            candidate = KeyboardShortcut.defaultActivationShortcut(index: index)
        }
        return candidate
    }

    func removeLayout(id: UUID) {
        configuration.layouts.removeAll { $0.id == id }
        persistAndReregister()
    }

    /// Validates a proposed activation shortcut against every *other* layout.
    /// Returns a conflict description, or `nil` if it's free to use (§9).
    func activationShortcutConflict(_ shortcut: KeyboardShortcut, excludingLayout id: UUID) -> String? {
        if let match = configuration.layouts.first(where: { $0.id != id && $0.activationShortcut == shortcut }) {
            return "already used by \"\(match.name)\""
        }
        return nil
    }

    /// Lets Settings UI surface a user-facing error (e.g. a rejected,
    /// already-in-use activation shortcut) through the same alert path as
    /// every other `GridTileError` (see `AppDelegate`), without exposing a
    /// general-purpose public setter for `lastError`.
    func reportError(_ error: GridTileError) {
        lastError = error
    }

    private func persistAndReregister() {
        store.save(configuration)
        registerAllShortcuts()
    }

    // MARK: - Global shortcut lifecycle

    private func registerAllShortcuts() {
        for id in registeredHotKeyIDs.values {
            GlobalShortcutManager.shared.unregister(id)
        }
        registeredHotKeyIDs.removeAll()

        for layout in configuration.layouts {
            let layoutID = layout.id
            let hotKeyID = GlobalShortcutManager.shared.register(shortcut: layout.activationShortcut) { [weak self] in
                self?.activate(layoutID: layoutID)
            }
            if let hotKeyID {
                registeredHotKeyIDs[layoutID] = hotKeyID
            } else {
                lastError = .shortcutConflict(layout.activationShortcut.displayString)
            }
        }
    }

    // MARK: - Activation flow (§10)

    func activate(layoutID: UUID) {
        guard let layout = configuration.layouts.first(where: { $0.id == layoutID }) else { return }
        guard !overlayController.isVisible else { return } // Ignore re-entrant activation.

        guard AccessibilityManager.shared.refresh() else {
            lastError = .accessibilityPermissionMissing
            return
        }

        // Step 1: remember the focused window BEFORE GridTile touches focus.
        guard let focused = FocusedWindowInfo.captureCurrentlyFocused() else {
            lastError = .noFocusedWindow
            return
        }
        pendingFocusedWindow = focused

        // Step 2: determine the target screen from the layout's display mode,
        // using the state of the world *before* activation changes it.
        let targetScreen: NSScreen
        switch layout.displayMode {
        case .followMouse:
            targetScreen = ScreenManager.screenUnderMouse()
        case .followFocusedWindow:
            if let frame = WindowManager.currentFrame(of: focused) {
                targetScreen = ScreenManager.screen(containing: frame)
            } else {
                targetScreen = ScreenManager.screenUnderMouse()
            }
        }

        overlayController.onComplete = { [weak self] globalRect in
            self?.completeTiling(rect: globalRect)
        }
        overlayController.onCancel = { [weak self] in
            self?.cancelTiling()
        }

        // Steps 3-6: activate GridTile and show the overlay.
        overlayController.show(layout: layout, on: targetScreen)
    }

    private func completeTiling(rect: CGRect) {
        defer { pendingFocusedWindow = nil }
        guard let focused = pendingFocusedWindow else { return }

        do {
            try WindowManager.apply(frame: rect, to: focused)
        } catch let error as GridTileError {
            lastError = error
        } catch {
            lastError = .windowMoveFailed(error.localizedDescription)
        }
        focused.restoreFocus()
    }

    private func cancelTiling() {
        defer { pendingFocusedWindow = nil }
        pendingFocusedWindow?.restoreFocus()
    }
}
