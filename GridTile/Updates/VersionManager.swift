import Foundation

/// The one place GridTile's own version is read from. Every other file that
/// needs to display or compare the installed version goes through this
/// (§7) — nothing hard-codes a version string elsewhere.
///
/// The value ultimately comes from the Xcode project's `MARKETING_VERSION`
/// build setting, which is injected into `Info.plist` as
/// `CFBundleShortVersionString` at build time.
enum VersionManager {
    /// e.g. "1.0.0". Falls back to "0.0.0" only in the pathological case of
    /// a missing bundle entry (should not happen in a normal build).
    static var installedVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var installedVersion: SemanticVersion {
        SemanticVersion(parsing: installedVersionString) ?? SemanticVersion(parsing: "0.0.0")!
    }

    static var displayString: String {
        "Version \(installedVersionString)"
    }
}
