import Foundation
import CoreGraphics

/// Pure, side-effect-free geometry. Kept independent of AppKit/SwiftUI so it's
/// trivially testable and reusable by both the overlay renderer and the final
/// window-frame calculation, guaranteeing they never disagree (§6, §15).
enum GridCalculator {
    /// One computed cell: its position in the grid and its rectangle within
    /// the *content* area (i.e. already inset from the outer bounds — padding
    /// between cells is handled by the caller/renderer per §14, not baked in
    /// here, so the same geometry can back both the visual grid and the final
    /// window rect without padding artifacts on the tiled window).
    struct ComputedCell {
        let row: Int
        let column: Int
        let rect: CGRect
    }

    /// Distributes `bounds` into a `rows` x `columns` grid according to the
    /// given weights. Weights are normalized internally, so callers don't need
    /// to pre-sum them (mirrors the Lua reference's `sum()` helper, generalized
    /// to arbitrary weight arrays per §6).
    ///
    /// **Coordinate convention:** the returned rects use a **top-left-origin,
    /// y-increasing-downward** space matching `bounds` directly (row 0 is at
    /// the smallest y) — the natural "reading order" space, and also what
    /// SwiftUI's layout system (and `NSHostingView`, which flips itself to
    /// match) expects. `GridOverlayView` can therefore use these rects as-is.
    /// The one place that *isn't* this convention is final AppKit window
    /// placement, which needs bottom-left-origin screen coordinates — that
    /// conversion happens in `GridOverlayController`, the single place that
    /// bridges SwiftUI-space selection back to AppKit-space window frames.
    static func computeCells(
        rows: Int,
        columns: Int,
        rowWeights: [Double],
        columnWeights: [Double],
        in bounds: CGRect
    ) -> [ComputedCell] {
        guard rows > 0, columns > 0,
              rowWeights.count == rows, columnWeights.count == columns,
              rowWeights.allSatisfy({ $0 > 0 }), columnWeights.allSatisfy({ $0 > 0 }) else {
            return []
        }

        let columnEdges = cumulativeEdges(weights: columnWeights, totalLength: bounds.width, origin: bounds.minX)
        let rowEdges = cumulativeEdges(weights: rowWeights, totalLength: bounds.height, origin: bounds.minY)

        var cells: [ComputedCell] = []
        for r in 0..<rows {
            let y = rowEdges[r]
            let height = rowEdges[r + 1] - rowEdges[r]

            for c in 0..<columns {
                let x = columnEdges[c]
                let width = columnEdges[c + 1] - columnEdges[c]
                cells.append(ComputedCell(row: r, column: c, rect: CGRect(x: x, y: y, width: width, height: height)))
            }
        }
        return cells
    }

    /// Returns `weights.count + 1` cumulative edge positions, e.g. weights
    /// `[1, 2, 1]` over length 400 → `[origin, origin+100, origin+300, origin+400]`.
    private static func cumulativeEdges(weights: [Double], totalLength: CGFloat, origin: CGFloat) -> [CGFloat] {
        let sum = weights.reduce(0, +)
        var edges: [CGFloat] = [origin]
        var running: Double = 0
        for w in weights {
            running += w
            edges.append(origin + CGFloat(running / sum) * totalLength)
        }
        return edges
    }

    /// The bounding rectangle spanning two selected cells, independent of
    /// selection order (§15) — mirrors the Lua reference's `getRect`.
    static func spanningRect(_ a: CGRect, _ b: CGRect) -> CGRect {
        let minX = min(a.minX, b.minX)
        let minY = min(a.minY, b.minY)
        let maxX = max(a.maxX, b.maxX)
        let maxY = max(a.maxY, b.maxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
