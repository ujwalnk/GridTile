import Foundation
import Carbon.HIToolbox
import AppKit

/// A single, fully-specified keyboard shortcut: one virtual key code plus a set of
/// modifier flags. `A` and `⇧A` are different instances of this type because
/// `keyCode` is the same but `modifiers` differs — this is what §7 of the spec requires.
struct KeyboardShortcut: Codable, Hashable, Equatable, Identifiable {
    /// Virtual key code (macOS `CGKeyCode` / Carbon `kVK_*` constant).
    var keyCode: UInt16

    /// Raw value of `NSEvent.ModifierFlags`, restricted to the four "device independent"
    /// modifiers we care about (command, option, control, shift). Stored as a raw UInt
    /// so the type stays trivially `Codable` without a custom encoder.
    var modifierFlagsRaw: UInt

    var id: String { "\(keyCode)-\(modifierFlagsRaw)" }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw)
    }

    init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        // Keep only the modifiers that matter for a shortcut; strip caps-lock, fn, etc.
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        self.modifierFlagsRaw = modifierFlags.intersection(relevant).rawValue
    }

    static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifierFlagsRaw == rhs.modifierFlagsRaw
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifierFlagsRaw)
    }

    /// Carbon modifier mask, used when registering a global hotkey via
    /// `RegisterEventHotKey` (see `GlobalShortcutManager`).
    var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        let flags = modifierFlags
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }

    /// Builds the shortcut for a plain default-configuration character, adding
    /// ⇧ automatically for uppercase letters so `q` and `Q` become distinct
    /// shortcuts, matching the spec's default key map (§28).
    static func fromDefaultCharacter(_ char: Character) -> KeyboardShortcut? {
        let lower = Character(char.lowercased())
        guard let code = KeyCodeMap.keyCodeByLowercaseCharacter[lower] else { return nil }
        let isUpper = char.isUppercase
        return KeyboardShortcut(keyCode: code, modifierFlags: isUpper ? [.shift] : [])
    }

    /// Default activation shortcut for the Nth layout, e.g. ⌃⌥1, ⌃⌥2, ...
    static func defaultActivationShortcut(index: Int) -> KeyboardShortcut {
        let digitCodes: [UInt16] = [
            UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3), UInt16(kVK_ANSI_4),
            UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_6), UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_8),
            UInt16(kVK_ANSI_9), UInt16(kVK_ANSI_0),
        ]
        let code = digitCodes[(index - 1) % digitCodes.count]
        return KeyboardShortcut(keyCode: code, modifierFlags: [.control, .option])
    }

    /// Human readable representation, e.g. "⌃⌥⇧A", "⌘Space", "Tab".
    var displayString: String {
        var s = ""
        let flags = modifierFlags
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += KeyCodeMap.displayName(for: keyCode)
        return s
    }
}

/// Maps macOS virtual key codes to/from human-readable names.
///
/// Key codes are physical-position codes (they come from the ANSI US layout
/// constants in `Carbon.HIToolbox`), not layout-aware characters. This matches
/// how most keyboard-driven macOS utilities behave and keeps shortcut recording
/// simple and reliable regardless of modifier state. This is documented as a
/// known limitation for non-US keyboard layouts in the README.
enum KeyCodeMap {
    static let nameByKeyCode: [UInt16: String] = {
        var m: [UInt16: String] = [
            UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
            UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
            UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
            UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
            UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
            UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
            UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
            UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
            UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",
            UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2",
            UInt16(kVK_ANSI_3): "3", UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5",
            UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8",
            UInt16(kVK_ANSI_9): "9",
            UInt16(kVK_Tab): "Tab", UInt16(kVK_Space): "Space", UInt16(kVK_Return): "Return",
            UInt16(kVK_Escape): "Escape", UInt16(kVK_Delete): "Delete",
            UInt16(kVK_ForwardDelete): "Forward Delete",
            UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓",
            UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
            UInt16(kVK_ANSI_Semicolon): ";", UInt16(kVK_ANSI_Comma): ",",
            UInt16(kVK_ANSI_Period): ".", UInt16(kVK_ANSI_Slash): "/",
            UInt16(kVK_ANSI_Quote): "'", UInt16(kVK_ANSI_Backslash): "\\",
            UInt16(kVK_ANSI_Minus): "-", UInt16(kVK_ANSI_Equal): "=",
            UInt16(kVK_ANSI_LeftBracket): "[", UInt16(kVK_ANSI_RightBracket): "]",
            UInt16(kVK_ANSI_Grave): "`",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
            UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
            UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
        ]
        return m
    }()

    static func displayName(for keyCode: UInt16) -> String {
        nameByKeyCode[keyCode] ?? "Key(\(keyCode))"
    }

    /// Keys that should never be assignable as *activation* shortcuts without at
    /// least one modifier (bare letters etc. would break normal typing everywhere).
    static let functionKeyCodes: Set<UInt16> = [
        UInt16(kVK_F1), UInt16(kVK_F2), UInt16(kVK_F3), UInt16(kVK_F4), UInt16(kVK_F5),
        UInt16(kVK_F6), UInt16(kVK_F7), UInt16(kVK_F8), UInt16(kVK_F9), UInt16(kVK_F10),
        UInt16(kVK_F11), UInt16(kVK_F12),
    ]

    /// Reverse lookup used only for building the generated default configuration
    /// (§28) from plain characters like `"q"` or `"Q"`.
    static let keyCodeByLowercaseCharacter: [Character: UInt16] = {
        var m: [Character: UInt16] = [:]
        for (code, name) in nameByKeyCode where name.count == 1 {
            m[Character(name.lowercased())] = code
        }
        m["1"] = UInt16(kVK_ANSI_1); m["2"] = UInt16(kVK_ANSI_2); m["3"] = UInt16(kVK_ANSI_3)
        m["4"] = UInt16(kVK_ANSI_4); m["7"] = UInt16(kVK_ANSI_7); m["8"] = UInt16(kVK_ANSI_8)
        m["9"] = UInt16(kVK_ANSI_9); m["0"] = UInt16(kVK_ANSI_0)
        m[";"] = UInt16(kVK_ANSI_Semicolon); m[","] = UInt16(kVK_ANSI_Comma)
        m["."] = UInt16(kVK_ANSI_Period)
        return m
    }()
}
