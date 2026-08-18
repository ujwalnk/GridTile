import SwiftUI
import AppKit

/// GridTile's About screen (§12, §41). The version shown here is read
/// through `VersionManager` — the same single source of truth the update
/// checker compares against — never duplicated as a literal string.
struct AboutView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            VStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text("GridTile")
                    .font(.title).bold()
                Text(VersionManager.displayString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("Developed with Love by Ujwal N K.")
                Text("Licensed under GNU GPLv3.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {
                NSWorkspace.shared.open(UpdateChecker.repositoryURL)
            } label: {
                Label("View on GitHub", systemImage: "arrow.up.forward.square")
            }

            Divider()
                .frame(maxWidth: 320)

            updateSection
                .frame(maxWidth: 360)

            Spacer(minLength: 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var updateSection: some View {
        let state = appState.configuration.updateState

        VStack(spacing: 10) {
            HStack {
                Text("Installed Version").foregroundStyle(.secondary)
                Spacer()
                Text(VersionManager.installedVersionString)
            }
            .font(.callout)

            HStack {
                Text("Latest Version").foregroundStyle(.secondary)
                Spacer()
                Text(state.latestKnownVersionString ?? "—")
            }
            .font(.callout)

            statusLine(for: state)

            HStack {
                Button("Check for Updates") {
                    appState.checkForUpdatesNow()
                }
                if state.updateAvailable {
                    Button("Open Release Page") {
                        NSWorkspace.shared.open(UpdateChecker.repositoryURL)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ViewBuilder
    private func statusLine(for state: UpdateState) -> some View {
        Group {
            if state.updateAvailable {
                Label("A new version is available.", systemImage: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
            } else if state.lastCheckFailed {
                Label("Unable to check for updates.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            } else if state.lastCheckDate != nil {
                Label("GridTile is up to date.", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                Label("Update status not yet checked.", systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }
}
