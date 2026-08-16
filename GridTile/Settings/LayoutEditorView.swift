import SwiftUI

struct LayoutEditorView: View {
    @Binding var layout: GridLayoutModel
    @ObservedObject var appState: AppState
    @State private var gridSectionExpanded = true
    @State private var appearanceSectionExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                nameAndShortcutSection
                Divider()
                displayModeSection
                Divider()
                DisclosureGroup("Grid Geometry & Cell Assignments", isExpanded: $gridSectionExpanded) {
                    GridEditorView(layout: $layout)
                        .padding(.top, 8)
                }
                Divider()
                DisclosureGroup("Appearance", isExpanded: $appearanceSectionExpanded) {
                    AppearanceEditorView(appearance: $layout.appearance)
                        .padding(.top, 8)
                }
            }
            .padding(20)
        }
    }

    private var nameAndShortcutSection: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name").font(.subheadline).bold()
                TextField("Layout name", text: $layout.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Activation Shortcut").font(.subheadline).bold()
                ShortcutRecorderView(
                    shortcut: $layout.activationShortcut,
                    conflictMessage: appState.activationShortcutConflict(layout.activationShortcut, excludingLayout: layout.id)
                )
            }
        }
    }

    private var displayModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grid Display").font(.subheadline).bold()
            Picker("", selection: $layout.displayMode) {
                ForEach(GridDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }
}
