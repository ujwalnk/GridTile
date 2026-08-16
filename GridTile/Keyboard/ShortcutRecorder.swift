import AppKit
import Carbon.HIToolbox

/// A focusable, otherwise-invisible `NSView` that, while recording, intercepts
/// the very next key combination as raw `keyDown` and reports it back —
/// deliberately bypassing normal text-field/`NSResponder` key-equivalent
/// handling so keys like Tab, Space, and Return can be captured instead of
/// triggering focus-change or button-press behavior (§8).
final class ShortcutRecorderNSView: NSView {
    var onCapture: ((KeyboardShortcut) -> Void)?
    var onCancel: (() -> Void)?

    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    func beginRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    func endRecording() {
        isRecording = false
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == UInt16(kVK_Escape), event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            endRecording()
            onCancel?()
            return
        }

        let shortcut = KeyboardShortcut(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
        endRecording()
        onCapture?(shortcut)
    }

    // Prevent the system beep / lost-focus behavior for keys like Tab that
    // AppKit would otherwise treat as a focus-navigation key equivalent.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
