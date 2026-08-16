import Foundation
import Carbon.HIToolbox

/// Produces a stream of plausible, not-yet-used keyboard shortcuts to assign to
/// newly created cells when a grid grows (§19). Walks the alphabet, then digits,
/// then falls back to shifted letters, skipping anything already assigned.
enum DefaultKeyAssignment {
    static func generator(excluding used: Set<KeyboardShortcut>) -> AnyIterator<KeyboardShortcut> {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        let digits = "1234567890"
        var candidates: [KeyboardShortcut] = []

        for ch in letters {
            if let s = KeyboardShortcut.fromDefaultCharacter(ch) { candidates.append(s) }
        }
        for ch in digits {
            if let s = KeyboardShortcut.fromDefaultCharacter(ch) { candidates.append(s) }
        }
        for ch in letters.uppercased() {
            if let s = KeyboardShortcut.fromDefaultCharacter(ch) { candidates.append(s) }
        }

        var index = 0
        return AnyIterator {
            while index < candidates.count {
                let candidate = candidates[index]
                index += 1
                if !used.contains(candidate) {
                    return candidate
                }
            }
            // Exhausted plain candidates — fall back to Control-modified letters,
            // which is exceedingly unlikely to collide.
            let fallbackIndex = index - candidates.count
            let letterCode = UInt16(kVK_ANSI_A) + UInt16(fallbackIndex % 26)
            index += 1
            return KeyboardShortcut(keyCode: letterCode, modifierFlags: [.control, .command])
        }
    }
}
