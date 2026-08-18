import AppKit
import SwiftUI

/// Thin AppKit adapter that owns exactly one `GridOverlayWindow` for the
/// lifetime of a single activation. Created fresh on activation and torn down
/// immediately after (§27); nothing here runs, polls, or holds resources while
/// GridTile is idle.
final class GridOverlayController {
    private var window: GridOverlayWindow?
    private var hostingView: NSHostingView<GridOverlayView>?
    private var keyMonitor: Any?
    private var keyHandler: GridKeyHandler?
    private var localBounds: CGRect = .zero

    /// Called with the final spanning rect, in the *screen's* AppKit global
    /// coordinates, once two cells have been selected.
    var onComplete: ((CGRect) -> Void)?
    /// Called when the user presses Escape (§17).
    var onCancel: (() -> Void)?

    var isVisible: Bool { window != nil }

    func show(layout: GridLayoutModel, on screen: NSScreen) {
        hide() // Defensive: never stack two overlays.

        let usableFrame = ScreenManager.usableFrame(for: screen)
        localBounds = CGRect(origin: .zero, size: usableFrame.size)

        let handler = GridKeyHandler(layout: layout)
        keyHandler = handler

        let rootView = GridOverlayView(layout: layout, firstSelection: nil, localBounds: localBounds)
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = localBounds
        hostingView = hosting

        let overlayWindow = GridOverlayWindow(screenFrame: usableFrame)
        overlayWindow.contentView = hosting
        window = overlayWindow

        overlayWindow.orderFrontRegardless()
        overlayWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, let handler = self.keyHandler, self.window != nil else { return event }
            let outcome = handler.handle(event: event)
            self.process(outcome: outcome, layout: layout)
            // Always swallow key events while the overlay is up so they never
            // reach whatever application is underneath.
            return nil
        }
    }

    private func process(outcome: GridKeyOutcome, layout: GridLayoutModel) {
        switch outcome {
        case .ignored:
            return

        case .firstCellSelected(let cell):
            updateHighlight(layout: layout, selection: cell)

        case .cancelled:
            let callback = onCancel
            hide()
            callback?()

        case .selectionComplete(let first, let second):
            let cells = GridCalculator.computeCells(
                rows: layout.rows, columns: layout.columns,
                rowWeights: layout.rowWeights, columnWeights: layout.columnWeights,
                in: localBounds
            )
            guard let firstRect = cells.first(where: { $0.row == first.row && $0.column == first.column })?.rect,
                  let secondRect = cells.first(where: { $0.row == second.row && $0.column == second.column })?.rect,
                  let screenFrame = window?.frame else {
                hide()
                return
            }

            let rawSpan = GridCalculator.spanningRect(firstRect, secondRect)
            // The tiled window's edges get the same padding/2 inset each
            // individual cell gets in the overlay (see `GridOverlayView`),
            // not just the overlay's own rendering — so `cellPadding`
            // actually controls the gap between the tiled window and its
            // neighbors (adjacent windows, the screen edge, etc.), not only
            // how the grid overlay looks while selecting. Guard the same way
            // `GridOverlayView` does: if padding is large enough to overrun a
            // very thin span, clamp to a centered zero-size rect rather than
            // letting the inset flip the rectangle inside-out.
            let padding = CGFloat(layout.appearance.cellPadding)
            let insetSpan = rawSpan.insetBy(dx: padding / 2, dy: padding / 2)
            let localSpan = CGRect(
                x: insetSpan.width >= 0 ? insetSpan.minX : rawSpan.midX,
                y: insetSpan.height >= 0 ? insetSpan.minY : rawSpan.midY,
                width: max(0, insetSpan.width),
                height: max(0, insetSpan.height)
            )
            // `localSpan` is in GridCalculator's top-left-origin, y-down space
            // (see its doc comment). AppKit screen frames are bottom-left-
            // origin, y-up, so the y axis must be flipped — using the
            // window's own height, since `localBounds`/`screenFrame` share it
            // — before adding the screen's global origin.
            let globalSpan = CGRect(
                x: screenFrame.origin.x + localSpan.origin.x,
                y: screenFrame.origin.y + (localBounds.height - localSpan.origin.y - localSpan.height),
                width: localSpan.width,
                height: localSpan.height
            )

            let callback = onComplete
            hide()
            callback?(globalSpan)
        }
    }

    private func updateHighlight(layout: GridLayoutModel, selection: GridCell) {
        guard let hostingView else { return }
        hostingView.rootView = GridOverlayView(layout: layout, firstSelection: selection, localBounds: localBounds)
    }

    func hide() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        hostingView = nil
        keyHandler = nil
    }
}
