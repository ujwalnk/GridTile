import SwiftUI

struct LayoutListView: View {
    let layouts: [GridLayoutModel]
    @Binding var selectedLayoutID: UUID?
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedLayoutID) {
                ForEach(layouts) { layout in
                    HStack {
                        Text(layout.name)
                        Spacer()
                        Text(layout.activationShortcut.displayString)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .tag(layout.id as UUID?)
                    .contextMenu {
                        Button("Delete", role: .destructive) { onRemove(layout.id) }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button(action: onAdd) {
                    Label("Add Layout", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                Spacer()
                if let id = selectedLayoutID {
                    Button(role: .destructive, action: { onRemove(id) }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(layouts.count <= 1)
                    .help(layouts.count <= 1 ? "GridTile needs at least one layout" : "Delete layout")
                }
            }
            .padding(8)
        }
    }
}
