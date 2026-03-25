import Foundation

/// Watches `Documents/FEL/` for Unreal `session_results.json` (and related exports), merges into Vault + PRQ history.
/// **Recovery scan:** `performLaunchRecoveryScan()` runs from `FinalEvolutionLabUnrealApp.init` before first frame so orphaned
/// `session_results.json` (crash / force-quit before Swift import) merges into Vault + PRQ history by stable session `id`.
@MainActor
final class FELUnrealSessionImporter {
    static let shared = FELUnrealSessionImporter()

    private var notificationToken: NSObjectProtocol?
    private var dirSource: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private weak var labViewModel: LabViewModel?
    private var debounceWorkItem: DispatchWorkItem?

    private init() {}

    deinit {
        if let t = notificationToken {
            NotificationCenter.default.removeObserver(t)
        }
        dirSource?.cancel()
        dirSource = nil
        debounceWorkItem?.cancel()
    }

    /// Gold Master — primary launch entry: recovery scan of `Documents/FEL/` before UI; idempotent vs Vault (`GameSessionResult.id`).
    func performLaunchRecoveryScan() {
        _ = scanOrphanedSessionExports(triggerHapticOnMerge: true)
    }

    /// Legacy alias — same as `performLaunchRecoveryScan()`.
    func performColdStartRecovery() {
        performLaunchRecoveryScan()
    }

    /// Call when Lab opens (after cold start may have already persisted to disk).
    func start(labViewModel: LabViewModel) {
        self.labViewModel = labViewModel
        refreshLabViewModelFromSavedVault()

        if notificationToken == nil {
            notificationToken = NotificationCenter.default.addObserver(
                forName: .felUnrealSessionResultsReady,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let sessionPath = note.userInfo?["sessionResultsPath"] as? String
                guard let sessionPath else { return }
                let fileURL = URL(fileURLWithPath: sessionPath)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    FELHaptics.sessionRewardImpact()
                    _ = self.importSessionFile(at: fileURL, triggerHapticOnNewMerge: false)
                    self.refreshLabViewModelFromSavedVault()
                }
            }
        }

        startDirectoryWatchIfPossible()
        _ = scanOrphanedSessionExports(triggerHapticOnMerge: false)
    }

    private func refreshLabViewModelFromSavedVault() {
        guard let vm = labViewModel else { return }
        vm.gameResults = SaveSystem.loadGameResults()
        vm.prqHistoryEntries = SaveSystem.loadPRQHistory()
        vm.profile = SaveSystem.loadProfile()
        let prq = Int(vm.profile.metrics.prqScore.rounded())
        PRQScoreManager.shared.simulateUnityScore(prq)
    }

    private static func felDocumentsFELDirectory() throws -> URL {
        try FELDocumentsFolder.urlCreatingIfNeeded()
    }

    /// Enumerates JSON exports in `Documents/FEL` (excluding readiness / progression / flags) and merges into Vault.
    @discardableResult
    private func scanOrphanedSessionExports(triggerHapticOnMerge: Bool) -> Bool {
        guard let fel = try? Self.felDocumentsFELDirectory() else { return false }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: fel,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let candidates = urls.filter { u in
            let n = u.lastPathComponent.lowercased()
            if n == "readiness_snapshot.json" || n == "progression_session.json" { return false }
            if n.hasSuffix(".flag") { return false }
            if !n.hasSuffix(".json") { return false }
            return n.hasPrefix("session_results") || n == "last_session_result.json"
        }
        .sorted { a, b in Self.recoveryFileSortPriority(a) < Self.recoveryFileSortPriority(b) }

        var mergedAny = false
        for url in candidates {
            if importSessionFile(at: url, triggerHapticOnNewMerge: false) {
                mergedAny = true
            }
        }
        if mergedAny, triggerHapticOnMerge {
            FELHaptics.sessionRewardImpact()
        }
        return mergedAny
    }

    /// Prefer canonical `session_results.json` before `last_session_result.json` / rotated names.
    private static func recoveryFileSortPriority(_ url: URL) -> Int {
        let n = url.lastPathComponent.lowercased()
        if n == "session_results.json" { return 0 }
        if n.hasPrefix("session_results") { return 1 }
        if n == "last_session_result.json" { return 2 }
        return 3
    }

    private func startDirectoryWatchIfPossible() {
        guard dirSource == nil else { return }
        do {
            let fel = try Self.felDocumentsFELDirectory()
            let path = fel.path
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { return }
            dirFD = fd
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .extend], queue: .main)
            src.setEventHandler { [weak self] in
                self?.scheduleDebouncedImport()
            }
            src.setCancelHandler { [weak self] in
                if let s = self, s.dirFD >= 0 {
                    close(s.dirFD)
                    s.dirFD = -1
                }
            }
            src.resume()
            dirSource = src
        } catch {}
    }

    private func scheduleDebouncedImport() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                _ = self.scanOrphanedSessionExports(triggerHapticOnMerge: true)
                self.refreshLabViewModelFromSavedVault()
            }
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    /// Returns `true` if a new session row was merged into the Vault.
    @discardableResult
    private func importSessionFile(at fileURL: URL, triggerHapticOnNewMerge: Bool) -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }

        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let decoder = JSONDecoder()
        // Unreal `FELSessionExport` writes `date` as seconds since 2001-01-01 UTC (Swift `Date` JSON convention).
        decoder.dateDecodingStrategy = .deferredToDate

        let result: GameSessionResult
        do {
            result = try decoder.decode(GameSessionResult.self, from: data)
        } catch {
            return false
        }

        let merged = mergeSessionIntoPersistedVault(result)
        if merged {
            if triggerHapticOnNewMerge {
                FELHaptics.sessionRewardImpact()
            }
            PRQNativeBridge.postMetrics([
                "unrealSessionImported": true,
                "shardsEarned": result.shardsEarned,
                "mentalSharpness": result.mentalSharpness as Any,
                "neuroPerformance": result.neuroPerformance as Any
            ])
        }
        return merged
    }

    @discardableResult
    private func mergeSessionIntoPersistedVault(_ result: GameSessionResult) -> Bool {
        var gameResults = SaveSystem.loadGameResults()
        if gameResults.contains(where: { $0.id == result.id }) {
            return false
        }

        gameResults.append(result)
        SaveSystem.saveGameResults(gameResults)

        var profile = SaveSystem.loadProfile()
        profile.evolutionShards += result.shardsEarned
        if let ap = result.academyProgress {
            for id in ap.completedModuleIds where !profile.completedAcademyModuleIds.contains(id) {
                profile.completedAcademyModuleIds.append(id)
            }
            let bonus = max(0, ap.evolutionShardsEarned)
            if bonus > 0 {
                profile.evolutionShards += bonus
            }
        }
        SaveSystem.saveProfile(profile)

        let hist = PRQHistoryEntry(
            source: "unreal_session",
            prqBonus: result.prqBonus,
            mentalSharpness: result.mentalSharpness,
            neuroPerformance: result.neuroPerformance,
            gameModeId: result.gameModeId
        )
        var prqList = SaveSystem.loadPRQHistory()
        prqList.append(hist)
        SaveSystem.savePRQHistory(prqList)

        refreshLabViewModelFromSavedVault()
        return true
    }
}
