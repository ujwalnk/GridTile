import Foundation

/// Checks GridTile's published `version.txt` for a newer release, at most
/// once every 24 hours (§8, §9, §14).
///
/// There is no continuously-running poll loop: `checkIfNeeded` is called once
/// at launch (from `AppState`), decides synchronously whether enough time has
/// passed, and if so fires a single asynchronous `URLSession` request off the
/// main thread. If GridTile stays running past the next 24-hour boundary, a
/// single deferred `Timer` (scheduled for exactly the remaining interval, not
/// a repeating poll) fires one more check — see `scheduleNextCheck`.
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// Published version manifest — a single line containing the latest
    /// version string, e.g. "1.3.0".
    static let versionManifestURL = URL(string: "https://raw.githubusercontent.com/ujwalnk/GridTile/refs/heads/main/version.txt")!
    /// Known from the same GitHub project the manifest is hosted in — not
    /// invented (§12).
    static let repositoryURL = URL(string: "https://github.com/ujwalnk/GridTile")!

    static let checkInterval: TimeInterval = 24 * 60 * 60

    private var deferredTimer: Timer?

    private init() {}

    /// Called once on launch. Uses the cached `UpdateState` if it's still
    /// fresh; otherwise performs one network request. Either way, schedules
    /// the *next* check for whenever the 24-hour window will next elapse,
    /// so a long-running instance of GridTile still checks again later
    /// without needing to poll.
    func checkIfNeeded(currentState: UpdateState, completion: @escaping (UpdateState) -> Void) {
        if currentState.isStale {
            performCheck(completion: completion)
        } else {
            completion(currentState) // Cached result is still fresh — no network I/O.
        }
        scheduleNextCheck(after: currentState)
    }

    /// Performs exactly one asynchronous, non-blocking network request.
    private func performCheck(completion: @escaping (UpdateState) -> Void) {
        var request = URLRequest(url: Self.versionManifestURL)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let now = Date()
            guard error == nil,
                  let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let data, let raw = String(data: data, encoding: .utf8),
                  let remote = SemanticVersion(parsing: raw) else {
                // Network unavailable, endpoint missing, or malformed content —
                // fail quietly and keep whatever we knew before (§8, §39).
                DispatchQueue.main.async {
                    completion(UpdateState(
                        lastCheckDate: now,
                        latestKnownVersionString: nil,
                        updateAvailable: false,
                        lastCheckFailed: true
                    ))
                }
                return
            }

            let isNewer = remote > VersionManager.installedVersion
            DispatchQueue.main.async {
                completion(UpdateState(
                    lastCheckDate: now,
                    latestKnownVersionString: remote.description,
                    updateAvailable: isNewer,
                    lastCheckFailed: false
                ))
            }
        }
        task.resume()
    }

    /// Schedules a single one-shot timer for whenever the *next* 24-hour
    /// boundary will be, rather than a repeating poll. Cancels any
    /// previously-scheduled one first.
    private func scheduleNextCheck(after state: UpdateState) {
        deferredTimer?.invalidate()
        let elapsed = state.lastCheckDate.map { Date().timeIntervalSince($0) } ?? Self.checkInterval
        let remaining = max(60, Self.checkInterval - elapsed)
        deferredTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.onNextCheckDue?()
        }
    }

    /// `AppState` sets this to re-run `checkIfNeeded` with the latest
    /// persisted state once the deferred timer fires.
    var onNextCheckDue: (() -> Void)?

    func invalidate() {
        deferredTimer?.invalidate()
        deferredTimer = nil
    }
}
