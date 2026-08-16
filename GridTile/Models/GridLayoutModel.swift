import Foundation

/// A complete, independent grid layout: geometry (rows/columns/weights), the
/// keyboard shortcut assigned to every cell, its own appearance, and its own
/// global activation shortcut. See §5 of the spec — every layout is fully
/// self-contained.
struct GridLayoutModel: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var rows: Int
    var columns: Int
    var rowWeights: [Double]
    var columnWeights: [Double]
    /// Sparse-friendly storage: one shortcut per (row, column). Always kept in
    /// sync with `rows`/`columns` by `resize(rows:columns:)`.
    var cells: [GridCell]
    var appearance: GridAppearance
    var activationShortcut: KeyboardShortcut
    var displayMode: GridDisplayMode

    init(
        id: UUID = UUID(),
        name: String,
        rows: Int,
        columns: Int,
        rowWeights: [Double],
        columnWeights: [Double],
        cells: [GridCell],
        appearance: GridAppearance = .defaultAppearance,
        activationShortcut: KeyboardShortcut,
        displayMode: GridDisplayMode = .followMouse
    ) {
        self.id = id
        self.name = name
        self.rows = rows
        self.columns = columns
        self.rowWeights = rowWeights
        self.columnWeights = columnWeights
        self.cells = cells
        self.appearance = appearance
        self.activationShortcut = activationShortcut
        self.displayMode = displayMode
    }

    func cell(row: Int, column: Int) -> GridCell? {
        cells.first { $0.row == row && $0.column == column }
    }

    /// All shortcuts currently assigned more than once. Used to surface
    /// duplicate-assignment warnings in the editor (§7).
    var duplicateShortcuts: Set<KeyboardShortcut> {
        var counts: [KeyboardShortcut: Int] = [:]
        for cell in cells { counts[cell.shortcut, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    /// Resizes the grid to `newRows` x `newColumns`, preserving existing weight
    /// values and cell shortcut assignments wherever the (row, column) position
    /// still exists, and generating sensible defaults for any new cells/weights.
    /// See §19 — shrinking must not scramble the surviving cells, growing must
    /// not disturb the original NxN block.
    mutating func resize(rows newRows: Int, columns newColumns: Int) {
        let newRows = max(1, newRows)
        let newColumns = max(1, newColumns)

        // Weights: truncate or extend with 1.0 defaults.
        rowWeights = Self.resizedWeights(rowWeights, to: newRows)
        columnWeights = Self.resizedWeights(columnWeights, to: newColumns)

        // Cells: keep any (row, column) still in range; drop the rest.
        var kept = cells.filter { $0.row < newRows && $0.column < newColumns }
        let keptPositions = Set(kept.map { "\($0.row)-\($0.column)" })
        let usedShortcuts = Set(kept.map { $0.shortcut })

        var generator = DefaultKeyAssignment.generator(excluding: usedShortcuts)
        for r in 0..<newRows {
            for c in 0..<newColumns {
                let key = "\(r)-\(c)"
                if !keptPositions.contains(key) {
                    let shortcut = generator.next() ?? KeyboardShortcut(keyCode: 0, modifierFlags: [])
                    kept.append(GridCell(row: r, column: c, shortcut: shortcut))
                }
            }
        }
        cells = kept
        rows = newRows
        columns = newColumns
    }

    private static func resizedWeights(_ weights: [Double], to count: Int) -> [Double] {
        if weights.count == count { return weights }
        if weights.count > count { return Array(weights.prefix(count)) }
        return weights + Array(repeating: 1.0, count: count - weights.count)
    }
}

/// Produces the spec's default 8x5 layout (§28), generated data rather than
/// runtime-hardcoded cell objects.
enum DefaultLayoutFactory {
    static func makeDefaultLayout() -> GridLayoutModel {
        let columnWeights: [Double] = [1, 2, 3, 3, 3, 3, 2, 1]
        let rowWeights: [Double] = [1, 2, 3, 2, 1]

        let rowsOfKeys: [[Character]] = [
            Array("12347890"),
            Array("qweruiop"),
            Array("QWERUIOP"),
            Array("asdfjkl;"),
            Array("zxcvnm,."),
        ]

        var cells: [GridCell] = []
        for (r, rowChars) in rowsOfKeys.enumerated() {
            for (c, char) in rowChars.enumerated() {
                guard let shortcut = KeyboardShortcut.fromDefaultCharacter(char) else { continue }
                cells.append(GridCell(row: r, column: c, shortcut: shortcut))
            }
        }

        return GridLayoutModel(
            name: "Grid 1",
            rows: rowsOfKeys.count,
            columns: 8,
            rowWeights: rowWeights,
            columnWeights: columnWeights,
            cells: cells,
            appearance: .defaultAppearance,
            activationShortcut: KeyboardShortcut.defaultActivationShortcut(index: 1),
            displayMode: .followMouse
        )
    }
}
