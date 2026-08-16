import Foundation

/// A single addressable cell in a grid layout: its row/column position and the
/// keyboard shortcut that selects it.
struct GridCell: Codable, Hashable, Equatable, Identifiable {
    var row: Int
    var column: Int
    var shortcut: KeyboardShortcut

    var id: String { "\(row)-\(column)" }
}

/// Which monitor the overlay should appear on when a layout is activated.
/// See §11 of the spec.
enum GridDisplayMode: String, Codable, CaseIterable, Identifiable {
    case followMouse
    case followFocusedWindow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .followMouse: return "Follow Mouse"
        case .followFocusedWindow: return "Follow Focused Window"
        }
    }
}
