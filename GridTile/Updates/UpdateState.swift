import Foundation

/// Cached result of the last update check (§9, §18). Persisted as part of
/// `AppConfiguration` so GridTile doesn't need to hit the network on every
/// launch — only once the 24-hour interval has actually elapsed.
struct UpdateState: Codable, Equatable {
    /// When GridTile last attempted a check (successful or not) — this is
    /// what the 24-hour gate is measured against, so a string of network
    /// failures doesn't turn into a retry loop.
    var lastCheckDate: Date?
    /// The most recent version string successfully read from the remote
    /// endpoint, kept even if a later check fails, so the UI still has
    /// something useful to show.
    var latestKnownVersionString: String?
    /// True only when `latestKnownVersionString` parses to something newer
    /// than the installed version.
    var updateAvailable: Bool
    /// Set when the most recent check attempt failed, purely for the "Unable
    /// to check for updates" UI string — never surfaced as an alert (§8).
    var lastCheckFailed: Bool

    static let empty = UpdateState(lastCheckDate: nil, latestKnownVersionString: nil, updateAvailable: false, lastCheckFailed: false)

    /// Backward-compatible: a configuration file saved before update
    /// checking existed simply has no `updateState` key at all, which
    /// `AppConfiguration`'s decoder maps to `.empty`.
    init(lastCheckDate: Date?, latestKnownVersionString: String?, updateAvailable: Bool, lastCheckFailed: Bool) {
        self.lastCheckDate = lastCheckDate
        self.latestKnownVersionString = latestKnownVersionString
        self.updateAvailable = updateAvailable
        self.lastCheckFailed = lastCheckFailed
    }

    var isStale: Bool {
        guard let lastCheckDate else { return true }
        return Date().timeIntervalSince(lastCheckDate) > UpdateChecker.checkInterval
    }
}
