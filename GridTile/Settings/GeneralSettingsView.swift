import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showingGuide = false

    var body: some View {
        Form {
            Section {
                AccessibilityStatusCard()
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
            } header: {
                Text("Permissions")
            }

            Section {
                Picker("Grid Display", selection: defaultDisplayModeBinding) {
                    ForEach(GridDisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text("Used as the starting display mode for newly created layouts. Each layout can still override it individually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Default Grid Display")
            }

            Section {
                Toggle("Show startup guide on launch", isOn: showGuideOnLaunchBinding)
                Button("Show Startup Guide Now") {
                    showingGuide = true
                }
            } header: {
                Text("Startup Guide")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingGuide) {
            StartupGuideView(appState: appState, isPresentedStandalone: true) {
                showingGuide = false
            }
            .frame(width: 520, height: 480)
        }
    }

    private var defaultDisplayModeBinding: Binding<GridDisplayMode> {
        Binding(
            get: { appState.configuration.settings.defaultDisplayMode },
            set: { newValue in
                appState.updateGlobalSettings { $0.defaultDisplayMode = newValue }
            }
        )
    }

    private var showGuideOnLaunchBinding: Binding<Bool> {
        Binding(
            get: { appState.configuration.settings.showStartupGuideOnLaunch },
            set: { newValue in
                appState.updateGlobalSettings { $0.showStartupGuideOnLaunch = newValue }
            }
        )
    }
}
