import AppKit

/// The three background treatments available for the grid overlay's backdrop
/// (the uniform layer that sits behind every tile and covers the full usable
/// screen area). See `GridAppearance` for the associated settings and
/// `GridBackgroundView` for the rendering.
enum BackgroundStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case transparent
    case solidColor
    case macOSMaterial

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transparent: return "Transparent"
        case .solidColor: return "Solid Color"
        case .macOSMaterial: return "macOS Material"
        }
    }
}

/// A curated subset of `NSVisualEffectView.Material` well suited to a
/// full-screen, borderless overlay. Not every system material makes sense
/// here (some are meant for small chrome elements like title bars), so this
/// intentionally doesn't expose the entire `NSVisualEffectView.Material` enum.
enum BackgroundMaterial: String, Codable, CaseIterable, Identifiable, Hashable {
    case hudWindow
    case fullScreenUI
    case underWindowBackground
    case sidebar
    case menu
    case popover

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hudWindow: return "HUD"
        case .fullScreenUI: return "Full Screen"
        case .underWindowBackground: return "Under Window"
        case .sidebar: return "Sidebar"
        case .menu: return "Menu"
        case .popover: return "Popover"
        }
    }

    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .hudWindow: return .hudWindow
        case .fullScreenUI: return .fullScreenUI
        case .underWindowBackground: return .underWindowBackground
        case .sidebar: return .sidebar
        case .menu: return .menu
        case .popover: return .popover
        }
    }
}
