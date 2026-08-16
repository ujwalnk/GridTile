import SwiftUI
import AppKit

/// A button-like control that shows the current shortcut and, when clicked,
/// switches into "recording" mode and captures the next key combination
/// (§8). No text entry is ever required from the user.
struct ShortcutRecorderView: View {
    @Binding var shortcut: KeyboardShortcut
    var conflictMessage: String? = nil
    var onRecorded: ((KeyboardShortcut) -> Void)? = nil

    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ShortcutRecorderRepresentable(
                isRecording: $isRecording,
                onCapture: { newShortcut in
                    shortcut = newShortcut
                    onRecorded?(newShortcut)
                },
                displayText: isRecording ? "Press a key…" : shortcut.displayString
            )
            .frame(width: 140, height: 24)

            if let conflictMessage {
                Text(conflictMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct ShortcutRecorderRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (KeyboardShortcut) -> Void
    var displayText: String

    func makeNSView(context: Context) -> RecorderButtonView {
        let view = RecorderButtonView()
        view.onClick = {
            isRecording = true
            view.beginRecording()
        }
        view.recorder.onCapture = { shortcut in
            isRecording = false
            onCapture(shortcut)
        }
        view.recorder.onCancel = {
            isRecording = false
        }
        return view
    }

    func updateNSView(_ nsView: RecorderButtonView, context: Context) {
        nsView.label.stringValue = displayText
        nsView.setHighlighted(isRecording)
    }
}

/// Combines a clickable, styled background with the key-capturing
/// `ShortcutRecorderNSView` layered invisibly on top, so the whole control
/// looks like a normal macOS control while still owning first-responder
/// status during recording.
final class RecorderButtonView: NSView {
    let label = NSTextField(labelWithString: "")
    let recorder = ShortcutRecorderNSView()
    var onClick: (() -> Void)?
    private let background = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        background.wantsLayer = true
        background.layer?.cornerRadius = 5
        background.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor.separatorColor.cgColor
        addSubview(background)

        label.alignment = .center
        label.font = .systemFont(ofSize: 12, weight: .medium)
        addSubview(label)

        addSubview(recorder)

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        background.frame = bounds
        label.frame = bounds.insetBy(dx: 6, dy: 2)
        recorder.frame = bounds
    }

    func beginRecording() {
        recorder.beginRecording()
    }

    func setHighlighted(_ highlighted: Bool) {
        background.layer?.borderColor = (highlighted ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        background.layer?.borderWidth = highlighted ? 2 : 1
    }

    @objc private func handleClick() {
        onClick?()
    }
}
