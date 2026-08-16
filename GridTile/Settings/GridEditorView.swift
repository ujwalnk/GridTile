import SwiftUI

/// Editor for grid geometry (rows/columns/weights) and per-cell key
/// assignments (§18, §19). Uses a visual grid rather than a flat list so large
/// grids stay comprehensible, and wraps it in a horizontal scroll view so wide
/// grids never force the whole settings window to grow unusably (§18).
struct GridEditorView: View {
    @Binding var layout: GridLayoutModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                Stepper(value: rowsBinding, in: 1...12) {
                    Text("Rows: \(layout.rows)")
                }
                Stepper(value: columnsBinding, in: 1...16) {
                    Text("Columns: \(layout.columns)")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Row Weights").font(.subheadline).bold()
                HStack(spacing: 6) {
                    ForEach(layout.rowWeights.indices, id: \.self) { i in
                        WeightField(value: rowWeightBinding(i))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Column Weights").font(.subheadline).bold()
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 6) {
                        ForEach(layout.columnWeights.indices, id: \.self) { i in
                            WeightField(value: columnWeightBinding(i))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Cell Assignments").font(.subheadline).bold()
                    if !layout.duplicateShortcuts.isEmpty {
                        Label("Duplicate shortcuts assigned", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                ScrollView([.horizontal, .vertical]) {
                    cellGrid
                }
                .frame(minHeight: 160, maxHeight: 280)
            }
        }
    }

    private var cellGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<layout.rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<layout.columns, id: \.self) { column in
                        if let cellIndex = layout.cells.firstIndex(where: { $0.row == row && $0.column == column }) {
                            let isDuplicate = layout.duplicateShortcuts.contains(layout.cells[cellIndex].shortcut)
                            ShortcutRecorderView(
                                shortcut: cellShortcutBinding(cellIndex),
                                conflictMessage: isDuplicate ? "Duplicate" : nil
                            )
                        }
                    }
                }
            }
        }
        .padding(4)
    }

    // MARK: - Bindings

    private var rowsBinding: Binding<Int> {
        Binding(
            get: { layout.rows },
            set: { newValue in layout.resize(rows: newValue, columns: layout.columns) }
        )
    }

    private var columnsBinding: Binding<Int> {
        Binding(
            get: { layout.columns },
            set: { newValue in layout.resize(rows: layout.rows, columns: newValue) }
        )
    }

    private func rowWeightBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { layout.rowWeights.indices.contains(index) ? layout.rowWeights[index] : 1.0 },
            set: { newValue in
                guard layout.rowWeights.indices.contains(index) else { return }
                layout.rowWeights[index] = max(0.1, newValue)
            }
        )
    }

    private func columnWeightBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { layout.columnWeights.indices.contains(index) ? layout.columnWeights[index] : 1.0 },
            set: { newValue in
                guard layout.columnWeights.indices.contains(index) else { return }
                layout.columnWeights[index] = max(0.1, newValue)
            }
        )
    }

    private func cellShortcutBinding(_ cellIndex: Int) -> Binding<KeyboardShortcut> {
        Binding(
            get: { layout.cells.indices.contains(cellIndex) ? layout.cells[cellIndex].shortcut : KeyboardShortcut(keyCode: 0, modifierFlags: []) },
            set: { newValue in
                guard layout.cells.indices.contains(cellIndex) else { return }
                layout.cells[cellIndex].shortcut = newValue
            }
        )
    }
}

/// A compact numeric field for a single weight value; rejects zero/negative
/// input at the model layer (`GridEditorView`'s bindings clamp to `>= 0.1`),
/// satisfying §6's "prevent invalid weights" requirement without a modal error.
private struct WeightField: View {
    @Binding var value: Double

    var body: some View {
        TextField("", value: $value, format: .number.precision(.fractionLength(0...2)))
            .textFieldStyle(.roundedBorder)
            .frame(width: 44)
            .multilineTextAlignment(.center)
    }
}
