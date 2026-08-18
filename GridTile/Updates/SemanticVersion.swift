import Foundation

/// A minimal semantic version: `major.minor.patch[-prerelease]`. Deliberately
/// tolerant of version strings with fewer than three components (`"1.2"` →
/// patch `0`) since that's the kind of thing a hand-edited `version.txt` on
/// GitHub is likely to contain (§11).
struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    /// Present only if the version string had a `-something` suffix, e.g.
    /// `"1.3.0-beta.1"` → `"beta.1"`. Compared lexically after numeric
    /// components, and — per standard semver rules — any prerelease sorts
    /// *before* the same version without one (`1.3.0-beta` < `1.3.0`).
    let prerelease: String?

    /// Parses a version string, tolerating leading "v", surrounding
    /// whitespace, and 1-3 numeric components. Returns `nil` for anything
    /// that isn't recognizably a version (§8: "handle malformed version
    /// strings").
    init?(parsing raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }

        let mainAndPrerelease = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numericPart = String(mainAndPrerelease[0])
        let prereleasePart = mainAndPrerelease.count > 1 ? String(mainAndPrerelease[1]) : nil

        let components = numericPart.split(separator: ".").map(String.init)
        guard components.count >= 1, components.count <= 3 else { return nil }
        let ints = components.map { Int($0) }
        guard ints.allSatisfy({ $0 != nil }) else { return nil }

        major = ints[0] ?? 0
        minor = ints.count > 1 ? (ints[1] ?? 0) : 0
        patch = ints.count > 2 ? (ints[2] ?? 0) : 0
        prerelease = (prereleasePart?.isEmpty == false) ? prereleasePart : nil
    }

    var description: String {
        let base = "\(major).\(minor).\(patch)"
        guard let prerelease else { return base }
        return "\(base)-\(prerelease)"
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        // No prerelease outranks any prerelease of the same x.y.z.
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (nil, .some): return false
        case (.some, nil): return true
        case let (.some(l), .some(r)): return l < r
        }
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch && lhs.prerelease == rhs.prerelease
    }
}
