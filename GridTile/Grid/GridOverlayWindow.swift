import AppKit
import SwiftUI

/// A borderless, transparent window that sits above every other window on one
/// screen and can become key so it receives the cell-selection key presses
/// (§13). One instance is created per activation and destroyed immediately
/// after (§27 — never kept around idle).
final class GridOverlayWindow: NSWindow {
    init(screenFrame: CGRect) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isMovable = false
    }

    /// Borderless windows can't become key by default; GridTile explicitly
    /// needs to, since key-window status is what routes keyboard events to it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
