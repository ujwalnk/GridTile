import SwiftUI

/// Renders the grid described by `layout` inside `bounds` (the screen's
/// usable frame, in *local* window coordinates — i.e. starting at .zero,
/// since the overlay window itself is already positioned at the screen's
/// origin). Highlights `firstSelection`, if any (§16).
struct GridOverlayView: View {
    let layout: GridLayoutModel
    let firstSelection: GridCell?
    let localBounds: CGRect

    var body: some View {
        let appearance = layout.appearance
        let cells = GridCalculator.computeCells(
            rows: layout.rows,
            columns: layout.columns,
            rowWeights: layout.rowWeights,
            columnWeights: layout.columnWeights,
            in: localBounds
        )

        ZStack(alignment: .topLeading) {
            ForEach(cells, id: \.hashID) { computed in
                if let cell = layout.cell(row: computed.row, column: computed.column) {
                    cellView(cell: cell, rect: computed.rect, appearance: appearance)
                }
            }
        }
        .frame(width: localBounds.width, height: localBounds.height)
        .background(Color.clear)
    }

    @ViewBuilder
    private func cellView(cell: GridCell, rect: CGRect, appearance: GridAppearance) -> some View {
        let isSelected = cell.id == firstSelection?.id
        let padding = CGFloat(appearance.cellPadding)
        let inset = rect.insetBy(dx: padding / 2, dy: padding / 2)

        RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
            .fill(Color(appearance.fillColor.nsColor).opacity(
                isSelected ? appearance.selectionFillOpacity : appearance.fillOpacity
            ))
            .overlay(
                RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? Color(appearance.selectionBorderColor.nsColor) : Color(appearance.borderColor.nsColor),
                        lineWidth: appearance.borderWidth
                    )
                    .opacity(isSelected ? 1.0 : appearance.borderOpacity)
            )
            .overlay(
                Text(cell.shortcut.displayString)
                    .font(Font(appearance.font))
                    .foregroundColor(Color(appearance.textColor.nsColor).opacity(appearance.textOpacity))
            )
            .frame(width: max(0, inset.width), height: max(0, inset.height))
            .position(x: inset.midX, y: inset.midY)
    }
}

private extension GridCalculator.ComputedCell {
    /// Stable identity for `ForEach` without requiring the geometry struct
    /// itself to be `Identifiable`.
    var hashID: String { "\(row)-\(column)" }
}
