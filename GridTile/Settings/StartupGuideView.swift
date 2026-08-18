import SwiftUI
import AppKit

/// A deliberately short onboarding screen — three things, no page-by-page
/// wizard, dismissible in a glance (§4). Shown automatically once on first
/// launch (see `AppDelegate`), and reachable afterward from General settings.
struct StartupGuideView: View {
    @ObservedObject var appState: AppState
    var isPresentedStandalone: Bool = false
    var onFinished: () -> Void

    @State private var showAgainNextTime = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to GridTile")
                    .font(.title2).bold()
                Text("Three things to know before you start.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            step(number: 1, title: "Allow Accessibility Access") {
                AccessibilityStatusCard(compact: true)
            }

            step(number: 2, title: "Choose a Layout") {
                Text("A layout defines a grid and the keyboard shortcut assigned to every cell. GridTile starts with one ready-made layout — you can add more anytime in Settings › Layouts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            step(number: 3, title: "Use GridTile") {
                usageDiagram
            }

            Spacer(minLength: 0)

            HStack {
                Toggle("Show startup guide on launch", isOn: $showAgainNextTime)
                    .toggleStyle(.checkbox)
                Spacer()
                Button(isPresentedStandalone ? "Close" : "Get Started") {
                    finish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .onAppear {
            showAgainNextTime = appState.configuration.settings.showStartupGuideOnLaunch
        }
    }

    private func finish() {
        appState.updateGlobalSettings {
            $0.showStartupGuideOnLaunch = showAgainNextTime
            $0.hasCompletedStartupGuide = true
        }
        onFinished()
    }

    @ViewBuilder
    private func step<Content: View>(number: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                content()
            }
        }
    }

    private var usageDiagram: some View {
        HStack(spacing: 10) {
            diagramChip("Press layout\nshortcut")
            arrow
            diagramChip("Choose first\ncell")
            arrow
            diagramChip("Choose second\ncell")
            arrow
            diagramChip("Window is\ntiled")
        }
        .font(.caption)
    }

    private func diagramChip(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(minWidth: 76)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .foregroundStyle(.secondary)
    }
}
