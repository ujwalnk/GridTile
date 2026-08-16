import Foundation
import os.log

/// Loads and saves `AppConfiguration` as human-readable JSON under
/// `~/Library/Application Support/GridTile/configuration.json` (§20).
///
/// Writes are atomic (write to a temp file, then replace) so a crash or power
/// loss mid-save can never leave a half-written, corrupt configuration file.
final class ConfigurationStore {
    static let shared = ConfigurationStore()

    private let log = Logger(subsystem: "com.gridtile.app", category: "ConfigurationStore")
    private let fileManager = FileManager.default

    private lazy var supportDirectory: URL = {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("GridTile", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var fileURL: URL {
        supportDirectory.appendingPathComponent("configuration.json")
    }

    /// Loads the saved configuration, migrating older versions forward, or
    /// falling back to defaults (and preserving the corrupt file alongside a
    /// `.bak` copy for inspection) if the file is missing or unreadable.
    func load() -> AppConfiguration {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            log.info("No configuration file found; using defaults.")
            let defaultConfig = AppConfiguration.defaultConfiguration
            save(defaultConfig)
            return defaultConfig
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let raw = try decoder.decode(VersionProbe.self, from: data)
            let migrated = try migrate(data: data, fromVersion: raw.version)
            return migrated
        } catch {
            log.error("Failed to load configuration: \(error.localizedDescription, privacy: .public). Falling back to defaults.")
            backupCorruptFile()
            let defaultConfig = AppConfiguration.defaultConfiguration
            save(defaultConfig)
            return defaultConfig
        }
    }

    /// Saves atomically. Safe to call frequently (e.g. after every settings edit).
    @discardableResult
    func save(_ configuration: AppConfiguration) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            let tempURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: tempURL, options: .atomic)
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
            return true
        } catch {
            log.error("Failed to save configuration: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func backupCorruptFile() {
        let backupURL = fileURL.appendingPathExtension("bak")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.copyItem(at: fileURL, to: backupURL)
    }

    /// Very small migration chain. Add a case per historical version as the
    /// schema evolves; each step should decode with the *old* shape and produce
    /// the current `AppConfiguration`.
    private func migrate(data: Data, fromVersion version: Int) throws -> AppConfiguration {
        switch version {
        case AppConfiguration.currentVersion:
            return try JSONDecoder().decode(AppConfiguration.self, from: data)
        default:
            // Unknown/future version, or version 0 with no migration defined yet.
            // Attempt a best-effort direct decode; if that fails, the caller's
            // catch block will fall back to defaults.
            return try JSONDecoder().decode(AppConfiguration.self, from: data)
        }
    }

    private struct VersionProbe: Codable {
        var version: Int
    }
}
