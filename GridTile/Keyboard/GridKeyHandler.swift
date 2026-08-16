import Foundation
import Carbon.HIToolbox
import AppKit

/// The result of feeding one key event into `GridKeyHandler` (§15, §17).
enum GridKeyOutcome: Equatable {
    /// The key matched a cell and this was the *first* selection.
    case firstCellSelected(GridCell)
    /// The key matched a cell and this completes the selection — the caller
    /// should compute the spanning rect and tile the window.
    case selectionComplete(first: GridCell, second: GridCell)
    /// Escape was pressed — cancel and restore focus without moving anything.
    case cancelled
    /// The key didn't match anything relevant; ignore it (and, importantly,
    /// swallow it so it doesn't leak through to whatever's behind the overlay).
    case ignored
}

/// Pure state machine driving the "press cell A, press cell B" interaction.
/// Kept free of AppKit window/view concerns so it's trivially unit-testable
/// and so the overlay controller stays a thin adapter around it.
final class GridKeyHandler {
    private(set) var firstSelection: GridCell?
    let layout: GridLayoutModel

    init(layout: GridLayoutModel) {
        self.layout = layout
    }

    /// Feeds a raw key event into the state machine. Escape always cancels
    /// (§17) — even if a layout author has bound Escape to a cell, since
    /// predictable cancellation is more important than an edge-case binding.
    func handle(event: NSEvent) -> GridKeyOutcome {
        if event.keyCode == UInt16(kVK_Escape) {
            return .cancelled
        }

        let pressed = KeyboardShortcut(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
        guard let cell = layout.cells.first(where: { $0.shortcut == pressed }) else {
            return .ignored
        }

        if let first = firstSelection {
            firstSelection = nil
            return .selectionComplete(first: first, second: cell)
        } else {
            firstSelection = cell
            return .firstCellSelected(cell)
        }
    }

    func reset() {
        firstSelection = nil
    }
}
