import Foundation

/// Global (non-per-layout) application settings.
struct GlobalSettings: Codable, Equatable {
    /// Kept for forward compatibility; monitor selection currently lives per-layout
    /// (`GridLayoutModel.displayMode`) since §11 allows either approach and
    /// per-layout is strictly more flexible. This global value is used only as the
    /// default applied to newly created layouts.
    var defaultDisplayMode: GridDisplayMode

    static var defaultSettings: GlobalSettings {
        GlobalSettings(defaultDisplayMode: .followMouse)
    }
}

/// The complete, versioned, on-disk configuration format (§20). `version` allows
/// `ConfigurationStore` to migrate older files forward without breaking existing
/// users' saved layouts.
struct AppConfiguration: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var settings: GlobalSettings
    var layouts: [GridLayoutModel]

    static var defaultConfiguration: AppConfiguration {
        AppConfiguration(
            version: currentVersion,
            settings: .defaultSettings,
            layouts: [DefaultLayoutFactory.makeDefaultLayout()]
        )
    }
}
