import Foundation

/// All user-facing failure conditions listed in §24. Every case carries enough
/// context to produce a friendly, actionable message — GridTile should never
/// need to fall back to a generic "something went wrong" string.
enum GridTileError: LocalizedError {
    case noFocusedApplication
    case noFocusedWindow
    case accessibilityPermissionMissing
    case targetWindowDisappeared
    case shortcutConflict(String)
    case invalidKeyAssignment(String)
    case duplicateShortcut(String)
    case invalidWeight(String)
    case invalidConfiguration(String)
    case monitorDisappeared
    case windowMoveFailed(String)

    var errorDescription: String? {
        switch self {
        case .noFocusedApplication:
            return "There's no focused application to tile. Click a window and try again."
        case .noFocusedWindow:
            return "The focused application doesn't have a window GridTile can move."
        case .accessibilityPermissionMissing:
            return "GridTile needs Accessibility permission to move and resize windows. Grant it in System Settings › Privacy & Security › Accessibility."
        case .targetWindowDisappeared:
            return "The window you were tiling was closed before GridTile could finish."
        case .shortcutConflict(let detail):
            return "That shortcut is already in use (\(detail)). Choose a different one."
        case .invalidKeyAssignment(let detail):
            return "That key can't be assigned: \(detail)."
        case .duplicateShortcut(let detail):
            return "\(detail) is assigned to more than one cell in this layout."
        case .invalidWeight(let detail):
            return "Row and column weights must be greater than zero (\(detail))."
        case .invalidConfiguration(let detail):
            return "GridTile's saved configuration couldn't be read (\(detail)). Defaults were loaded instead."
        case .monitorDisappeared:
            return "The target display was disconnected during tiling."
        case .windowMoveFailed(let detail):
            return "GridTile couldn't move that window (\(detail))."
        }
    }
}
