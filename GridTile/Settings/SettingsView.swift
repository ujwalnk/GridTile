import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var selectedTab: CurrentValueSubjectBox

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab.value) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 8)

            Divider()

            switch selectedTab.value {
            case .layouts:
                LayoutsTabView(appState: appState)
            case .permissions:
                PermissionsView()
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

/// Master-detail layout: the layout list on the left, the selected layout's
/// full editor on the right (§18).
struct LayoutsTabView: View {
    @ObservedObject var appState: AppState
    @State private var selectedLayoutID: UUID?

    var body: some View {
        HSplitView {
            LayoutListView(
                layouts: appState.configuration.layouts,
                selectedLayoutID: $selectedLayoutID,
                onAdd: {
                    let created = appState.addLayout()
                    selectedLayoutID = created.id
                },
                onRemove: { id in
                    appState.removeLayout(id: id)
                    if selectedLayoutID == id { selectedLayoutID = appState.configuration.layouts.first?.id }
                }
            )
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 260)

            if let id = selectedLayoutID,
               let index = appState.configuration.layouts.firstIndex(where: { $0.id == id }) {
                LayoutEditorView(
                    layout: Binding(
                        get: { appState.configuration.layouts[index] },
                        set: { appState.updateLayout($0) }
                    ),
                    appState: appState
                )
                .frame(minWidth: 420)
            } else {
                VStack {
                    Spacer()
                    Text("Select a layout, or add a new one.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(minWidth: 420, maxWidth: .infinity)
            }
        }
        .onAppear {
            if selectedLayoutID == nil {
                selectedLayoutID = appState.configuration.layouts.first?.id
            }
        }
    }
}
