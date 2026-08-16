import SwiftUI

struct PermissionsView: View {
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: accessibility.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(accessibility.isTrusted ? .green : .orange)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(accessibility.isTrusted ? "Accessibility access granted" : "Accessibility access needed")
                        .font(.headline)
                    Text(accessibility.isTrusted
                         ? "GridTile can move and resize windows."
                         : "GridTile can't move or resize windows until this is granted.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("""
            GridTile uses macOS's Accessibility APIs to find the window you're \
            currently using and move or resize it into the grid cells you select. \
            It never reads window content, keystrokes typed elsewhere, or any data \
            besides window position and size.
            """)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 480, alignment: .leading)

            HStack {
                Button("Grant Access…") {
                    accessibility.requestPermission()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(accessibility.isTrusted)

                Button("Open System Settings") {
                    accessibility.openSystemSettings()
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { accessibility.startObservingWhileVisible() }
        .onDisappear { accessibility.stopObserving() }
    }
}
