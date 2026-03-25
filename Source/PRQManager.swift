import Foundation
import Observation

// MARK: - Neuro-Mechanic readiness export (Swift → Unreal `readiness_snapshot.json`)

nonisolated let felReadinessExportDidUpdateNotification = Notification.Name("FelReadinessExportDidUpdate")
/// FEL_NON_SHIPPING: posted after each `sync` when twin scales are recomputed (DA smoke overlay).
nonisolated let felReadinessTwinScalesUpdatedNotification = Notification.Name("FelReadinessTwinScalesUpdated")

// MARK: - Cloud Cortex (Google AI Studio / Gemini)

/// One row of PRQ history used for Bonds Apex / dunk-lane Cloud Cortex prompts.
nonisolated struct BondsApexJumpRow: Sendable {
    let dateISO8601: String
    let prqBonus: Double
    let neuroPerformance: Double?
    let gameModeId: String
}

/// Snapshot of athlete metrics + recent dunk-lane jumps for `fetchAICoachInsight`.
nonisolated struct PerformanceSnapshot: Sendable {
    let prqScore: Double
    let readinessScore: Double
    let efficiencyScore: Double
    let verticalPotential: Double
    let neuralDrive: Double
    let fatigueState: String
    let allTimePeakZCmS: Double?
    let bondsApexJumps: [BondsApexJumpRow]
    /// `false` = SFMA multi-segmental rotation screen fail — prescribe Mod 4 + 90/90 seated rotation.
    let sfmaMultiSegmentalRotationPassed: Bool?
}

extension PerformanceSnapshot {
    @MainActor
    static func make(from viewModel: LabViewModel) -> PerformanceSnapshot {
        let m = viewModel.effectiveMetrics
        let coach = FELCoachPerformanceSnapshot.decodedPayload()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let rows: [BondsApexJumpRow] = viewModel.prqHistoryEntries
            .filter { row in
                guard let gid = row.gameModeId?.lowercased() else { return false }
                return gid.contains("dunk") || gid.contains("basketball_dunk")
            }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { row in
                BondsApexJumpRow(
                    dateISO8601: iso.string(from: row.date),
                    prqBonus: row.prqBonus,
                    neuroPerformance: row.neuroPerformance,
                    gameModeId: row.gameModeId ?? ""
                )
            }

        return PerformanceSnapshot(
            prqScore: m.prqScore,
            readinessScore: m.readinessScore,
            efficiencyScore: m.efficiencyScore,
            verticalPotential: m.verticalPotential,
            neuralDrive: m.neuralDrive,
            fatigueState: coach?.fatigueState ?? "Unknown",
            allTimePeakZCmS: coach?.allTimePeakZ,
            bondsApexJumps: Array(rows),
            sfmaMultiSegmentalRotationPassed: viewModel.profile.systemScan?.sfmaMultiSegmentalRotationPassed
        )
    }
}

/// Pulls PRQ, scan vertical estimate, and biomechanics audit into a single payload for Arena + Unreal `FELReadinessIO::TryLoadSnapshot`.
@Observable
@MainActor
final class PRQManager {
    static let shared = PRQManager()

    /// Persisted arena handoff for `readiness_snapshot.json` → Unreal `active_mode` (`FELReadinessIO.cpp`).
    static let lastExportedArenaModeKey = "felLastExportedArenaMode"

    /// Set in `ArenaView.performLuminanceCheck()` — when `false`, Unreal readiness JSON is not written (forensic scan needs adequate light).
    static let neuroMechanicLightingOptimalKey = "felNeuroMechanicLightingOptimal"

    /// First scan → Unreal twin-birth cinematic (`playTwinBirthCinematicOnce` in readiness JSON).
    static let pendingTwinBirthCinematicKey = "felPendingTwinBirthCinematic"
    /// First Lab tab visit → welcome toast on `AFELVaultHologramTerminalActor` + shard grant (consumed on export).
    static let pendingLabWelcomeToastKey = "felPendingLabWelcomeToast"

    private(set) var lastExport: FelReadinessSnapshotExport?
    private(set) var lastJSONString: String?
    private(set) var lastExportURL: URL?

    /// Google AI Studio (Gemini) — latest Neuro-Mechanic prescription line for Lab **Cloud Cortex** card.
    private(set) var cloudCortexPrescription: String?
    private(set) var cloudCortexLastUpdated: Date?
    private(set) var cloudCortexIsLoading: Bool = false
    private(set) var cloudCortexError: String?

#if FEL_NON_SHIPPING
    /// Last `avatarHeightScale` / `avatarWeightScale` from the readiness payload (computed every `sync`; matches JSON when write succeeds).
    private(set) var lastReadinessTwinScales: (height: Double, weight: Double)?
#endif

    private let userDefaultsKey = "fel_readiness_snapshot_json_cache"

    /// Weak link so `felUnrealSessionResultsReady` can call `sync(from:)` with full biomechanics audit after Vault merge.
    private weak var sessionBridgeLab: LabViewModel?
    private var felUnrealSessionResultsToken: NSObjectProtocol?

    private init() {
        registerFelUnrealSessionResultsObserver()
    }

    /// Call once from `LabViewModel` so session-result notifications refresh readiness + heat-map data with the live audit.
    func attachSessionBridge(_ vm: LabViewModel) {
        sessionBridgeLab = vm
    }

    private func registerFelUnrealSessionResultsObserver() {
        felUnrealSessionResultsToken = NotificationCenter.default.addObserver(
            forName: .felUnrealSessionResultsReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Defer so `FELUnrealSessionImporter` can merge `session_results.json` into the Vault first.
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                self.refreshReadinessExportAfterUnrealSessionArtifact()
            }
        }
    }

    /// Re-writes `readiness_snapshot.json` from disk profile (no live `LabViewModel`) — cold-path fallback.
    func refreshReadinessFromSavedProfile() {
        let profile = SaveSystem.loadProfile()
        sync(profile: profile, audit: nil, metrics: profile.metrics)
    }

    private func refreshReadinessExportAfterUnrealSessionArtifact() {
        if let vm = sessionBridgeLab {
            sync(from: vm)
        } else {
            refreshReadinessFromSavedProfile()
        }
    }

    /// Sync from live profile + effective metrics (call after scan, profile load, or Arena appear).
    func sync(from viewModel: LabViewModel) {
        sync(
            profile: viewModel.profile,
            audit: viewModel.biomechanicsAudit,
            metrics: viewModel.effectiveMetrics
        )
    }

    /// Pushes `allTimePeakZ` + `displayName` to the Sovereign global leaderboard (Supabase or webhook when configured in Info.plist).
    func syncTopPerformance() async -> Int? {
        let profile = sessionBridgeLab?.profile ?? SaveSystem.loadProfile()
        let coach = FELCoachPerformanceSnapshot.decodedPayload()
        let peak = coach?.allTimePeakZ ?? 0
        return await FELSovereignLeaderboardSync.push(
            displayName: profile.displayName,
            allTimePeakZ: peak,
            athleteId: profile.id
        )
    }

    /// Sovereign Launch: pulls `user_balances` from Supabase and merges shard balance, Cloud Cortex credits, and optional gear paths into the active profile.
    func syncWallet() async {
        let profile = sessionBridgeLab?.profile ?? SaveSystem.loadProfile()
        guard let state = await FELSupabaseWalletSync.shared.authState() else { return }
        guard let snap = await FELSovereignShardEconomy.syncWallet(userId: state.userId, accessToken: state.accessToken) else { return }
        var merged = profile
        merged.supabaseUserId = state.userId.uuidString.lowercased()
        merged.evolutionShards = snap.shardBalance
        merged.credits = snap.cloudCortexCredits
        for (k, v) in snap.equippedGearTexturePaths where !v.isEmpty {
            merged.equippedGearTexturePaths[k] = v
        }
        SaveSystem.saveProfile(merged)
        sessionBridgeLab?.profile = merged
        NotificationCenter.default.post(name: .felWalletBalanceDidUpdate, object: nil)
    }

    /// Cloud Cortex: sends the last 10 Bonds Apex–lane jumps + `FatigueState` / Peak Z to Gemini; stores a one-line Neuro-Mechanic prescription.
    func fetchAICoachInsight(metrics: PerformanceSnapshot) async {
        cloudCortexIsLoading = true
        cloudCortexError = nil
        defer { cloudCortexIsLoading = false }

        guard GeminiService.shared.isConfigured else {
            cloudCortexError = GeminiError.missingAPIKey.localizedDescription
            return
        }
        guard let apiKey = GeminiService.shared.apiKey, !apiKey.isEmpty else {
            cloudCortexError = GeminiError.missingAPIKey.localizedDescription
            return
        }

        let snapshot = metrics
        do {
            // Prompt build + REST run entirely off MainActor — 3D HUD / Lab scroll never blocks on Gemini RTT.
            let raw = try await Task.detached(priority: .userInitiated) {
                let prompt = Self.buildCloudCortexPrompt(metrics: snapshot)
                return try await GeminiService.generateContentREST(prompt: prompt, apiKey: apiKey)
            }.value
            let line = Self.extractNeuroMechanicPrescription(from: raw)
            cloudCortexPrescription = line
            cloudCortexLastUpdated = Date()
        } catch {
            cloudCortexError = error.localizedDescription
        }
    }

    func sync(profile: UserProfile, audit: BiomechanicsAudit?, metrics: PerformanceMetrics) {
        let export = Self.buildExport(profile: profile, audit: audit, metrics: metrics)
#if FEL_NON_SHIPPING
        lastReadinessTwinScales = (export.avatarHeightScale, export.avatarWeightScale)
        NotificationCenter.default.post(name: felReadinessTwinScalesUpdatedNotification, object: nil)
#endif
        writeExport(export)
    }

    private static func buildExport(profile: UserProfile, audit: BiomechanicsAudit?, metrics: PerformanceMetrics) -> FelReadinessSnapshotExport {
        let scan = profile.systemScan
        let baseLeakage = Self.kineticLeakageMultiplier(audit: audit)
        let sovereignLeak = FELGearBoostCalculator.sovereignKineticLeakageScale(profile: profile)
        let leakage = max(0.45, min(1.0, baseLeakage * sovereignLeak))
        let hang = Self.hangTimeScale(scan: scan, prq: metrics.prqScore)
        let heats = Self.kineticJointHeats(audit: audit)
        let gear = FELGearBoostCalculator.aggregatedMultipliers(profile: profile)
        let neuroScale = FELGearBoostCalculator.neuroFlowIntensityScale(activeCard: profile.activeCreatorCard)
        let traitLine = FELGearBoostCalculator.stoodTraitLine(for: profile.activeCreatorCard)
        let stoodPhysics = FELGearBoostCalculator.stoodCardPhysics(from: profile.activeCreatorCard)
        let stoodTier = FELGearBoostCalculator.stoodCardTierString(for: profile.activeCreatorCard)
        let signatureTraitId = FELGearBoostCalculator.signatureTraitId(for: profile.activeCreatorCard)
        let rawMode = UserDefaults.standard.string(forKey: Self.lastExportedArenaModeKey)
            ?? GameModeId.basketballHeadToHead.rawValue
        let activeMode = Self.normalizeActiveModeForUnreal(rawMode)
        let avatar = profile.effectiveAvatarConfig

        return FelReadinessSnapshotExport(
            efficiencyScore: metrics.efficiencyScore,
            prqScore: metrics.prqScore,
            readinessScore: metrics.readinessScore,
            verticalPotential: metrics.verticalPotential,
            neuralDrive: metrics.neuralDrive,
            popForce: metrics.popForce,
            currentOutfit: metrics.currentOutfit,
            verticalEstimateInches: scan?.verticalEstimateInches ?? Double(metrics.verticalPotential) * 0.28,
            hangTimeScale: hang,
            kineticLeakageMultiplier: leakage,
            movementGrade: scan?.movementGrade,
            flightTimeSeconds: scan?.flightTimeSeconds,
            isPrimed: audit?.isPrimed,
            ankleKineticHeat: heats.ankle,
            kneeKineticHeat: heats.knee,
            hipKineticHeat: heats.hip,
            academyPlyosMasteryBonus: profile.completedAcademyModuleIds.contains("mod9") ? 0.02 : nil,
            videoNominalFrameRateHz: scan?.videoNominalFrameRateHz,
            jerseyTexturePath: profile.equippedGearTexturePaths["jersey"],
            shoeTexturePath: profile.equippedGearTexturePaths["shoes"],
            gearMotionWarpMultiplier: gear.motionWarp,
            gearJumpVelocityMultiplier: gear.jumpVelocity,
            stoodCreatorCardId: profile.activeCreatorCard?.cardId,
            neuroFlowIntensityScale: neuroScale,
            stoodCreatorCardTraitLine: traitLine.isEmpty ? nil : traitLine,
            stoodCardJumpScale: stoodPhysics.jump,
            stoodCardNeuralDriveAlpha: stoodPhysics.neuralAlpha,
            stoodCardTier: stoodTier,
            signatureTraitId: signatureTraitId,
            activeMode: activeMode,
            creatorCardTextures: nil,
            neuroMechanicLogoTexture: nil,
            bondsBounceLogoTexture: nil,
            avatarHeightScale: avatar.heightScale,
            avatarWeightScale: avatar.weightScale,
            sfmaMultiSegmentalRotationPassed: scan?.sfmaMultiSegmentalRotationPassed
        )
    }

    /// Multi-athlete / coach handoff: clears local `readiness_snapshot.json` cache, reapplies the profile, re-syncs twin scales (FEL_NON_SHIPPING HUD), and requests an Unreal `setUnrealReady` pulse via `felUnrealReadinessHandshakeRequested`.
    func switchAthleteProfile(newProfile: UserProfile) {
        clearLocalReadinessSnapshotArtifacts()
        if let vm = sessionBridgeLab {
            vm.profile = newProfile
            if let scan = newProfile.systemScan {
                vm.biomechanicsAudit = BiomechanicsAudit.fromScanResult(scan)
            } else {
                vm.biomechanicsAudit = nil
            }
            SaveSystem.saveProfile(newProfile)
            sync(from: vm)
        } else {
            SaveSystem.saveProfile(newProfile)
            let audit = newProfile.systemScan.map { BiomechanicsAudit.fromScanResult($0) }
            sync(profile: newProfile, audit: audit, metrics: newProfile.metrics)
        }
        NotificationCenter.default.post(
            name: .felUnrealReadinessHandshakeRequested,
            object: nil,
            userInfo: ["athleteId": newProfile.id, "athleteDisplayName": newProfile.displayName]
        )
    }

    /// Season / scout export: PRQ history rows + biometric scales from last readiness export + coach performance snapshot (Peak Z proxy, fatigue) — CSV for recruiters (`ScoutsPortalView`).
    func exportSeasonStatsCSV() -> String {
        let profile = sessionBridgeLab?.profile ?? SaveSystem.loadProfile()
        let history = sessionBridgeLab?.prqHistoryEntries ?? SaveSystem.loadPRQHistory()
        let coach = FELCoachPerformanceSnapshot.decodedPayload()
        let scales = lastExport
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var lines: [String] = []
        lines.append("# Final Evolution — Performance Report (1.0.0)")
        lines.append("# Generated: \(iso.string(from: Date()))")
        lines.append("section,metric,value")
        lines.append("profile,id,\(Self.csvEscape(profile.id))")
        lines.append("profile,displayName,\(Self.csvEscape(profile.displayName))")
        lines.append("profile,athleteTag,\(Self.csvEscape(profile.athleteTag))")
        lines.append("profile,prqScore,\(String(format: "%.4f", profile.metrics.prqScore))")
        lines.append("profile,verticalPotential,\(String(format: "%.4f", profile.metrics.verticalPotential))")
        if let s = scales {
            lines.append("biometric,avatarHeightScale,\(String(format: "%.6f", s.avatarHeightScale))")
            lines.append("biometric,avatarWeightScale,\(String(format: "%.6f", s.avatarWeightScale))")
        } else {
            lines.append("biometric,avatarHeightScale,")
            lines.append("biometric,avatarWeightScale,")
        }
        lines.append("performanceHistory,peakZ_cm_s_max,\(coach?.allTimePeakZ.map { String(format: "%.4f", $0) } ?? "")")
        lines.append("performanceHistory,fatigueState,\(Self.csvEscape(coach?.fatigueState ?? "Unknown"))")
        lines.append("performanceHistory,jumpHeight_proxy_note,PeakZ_velocity_cm_s_from_Unreal_save_coach_JSON")
        lines.append("gear,gearId,\(Self.csvEscape(coach?.gearId ?? ""))")

        lines.append("prq_history_id,date_iso,source,prqBonus,mentalSharpness,neuroPerformance,gameModeId")
        for row in history.sorted(by: { $0.date < $1.date }) {
            let d = iso.string(from: row.date)
            lines.append([
                Self.csvEscape(row.id),
                Self.csvEscape(d),
                Self.csvEscape(row.source),
                String(format: "%.6f", row.prqBonus),
                row.mentalSharpness.map { String(format: "%.6f", $0) } ?? "",
                row.neuroPerformance.map { String(format: "%.6f", $0) } ?? "",
                Self.csvEscape(row.gameModeId ?? "")
            ].joined(separator: ","))
        }

        let bonuses = history.map(\.prqBonus)
        let avgBonus = bonuses.isEmpty ? 0.0 : bonuses.reduce(0, +) / Double(bonuses.count)
        lines.append("aggregate,prq_history_count,\(history.count)")
        lines.append("aggregate,avg_prqBonus,\(String(format: "%.6f", avgBonus))")
        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            let doubled = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return s
    }

    private func clearLocalReadinessSnapshotArtifacts() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        lastExport = nil
        lastJSONString = nil
        lastExportURL = nil
#if FEL_NON_SHIPPING
        lastReadinessTwinScales = nil
        NotificationCenter.default.post(name: felReadinessTwinScalesUpdatedNotification, object: nil)
#endif
        if let url = try? Self.ensureFELDocumentsURL().appendingPathComponent("readiness_snapshot.json") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func writeExport(_ export: FelReadinessSnapshotExport) {
        if let optimal = UserDefaults.standard.object(forKey: Self.neuroMechanicLightingOptimalKey) as? Bool, optimal == false {
            #if DEBUG
            print("[FEL] Skipping readiness_snapshot.json — lighting below forensic threshold (Arena System Scan needs brighter ambient light).")
            #endif
            return
        }

        var merged = export
        let d = UserDefaults.standard
        if d.bool(forKey: Self.pendingTwinBirthCinematicKey) {
            merged.playTwinBirthCinematicOnce = true
            d.set(false, forKey: Self.pendingTwinBirthCinematicKey)
        }
        if let toast = d.string(forKey: Self.pendingLabWelcomeToastKey), !toast.isEmpty {
            merged.labWelcomeToast = toast
            d.removeObject(forKey: Self.pendingLabWelcomeToastKey)
        }

        lastExport = merged
        guard let data = try? JSONEncoder.felPretty.encode(merged),
              let json = String(data: data, encoding: .utf8) else { return }

        lastJSONString = json
        UserDefaults.standard.set(json, forKey: userDefaultsKey)

        if let url = try? Self.ensureFELDocumentsURL().appendingPathComponent("readiness_snapshot.json") {
            try? json.write(to: url, atomically: true, encoding: .utf8)
            try? FELBiometricFileProtection.applyCompleteProtection(to: url)
            lastExportURL = url
        }

        NotificationCenter.default.post(name: felReadinessExportDidUpdateNotification, object: nil, userInfo: ["json": json])
    }

    /// Joint status from scan audit: MODERATE / LEAKING reduce effective verticality vs PRIMED (`optimal`).
    /// Collapses legacy / marketing labels to canonical `GameModeId.rawValue` for `FELArenaModeFromSwiftId` (Unreal).
    private static func normalizeActiveModeForUnreal(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "dunk_contest", "dunkcontest", "hang_time", "hangtime":
            return GameModeId.basketballDunkContest.rawValue
        case "basketball-h2h", "h2h", "head_to_head", "headtohead":
            return GameModeId.basketballHeadToHead.rawValue
        case "market_browse", "sovereign_shop", "shop":
            return "market_browse"
        default:
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func kineticLeakageMultiplier(audit: BiomechanicsAudit?) -> Double {
        guard let a = audit else { return 1.0 }
        var m = 1.0
        for joint in [a.ankleDorsiflexion, a.kneeTracking, a.hipExtension] {
            switch joint.status {
            case .optimal: break
            case .moderate: m *= 0.94
            case .deficit: m *= 0.88
            }
        }
        return max(0.55, min(1.0, m))
    }

    private static func hangTimeScale(scan: SystemScanResult?, prq: Double) -> Double {
        let flight = scan?.flightTimeSeconds ?? 0.48
        let base = 0.78 + prq / 400.0 + flight * 0.14
        return min(1.15, max(0.75, base))
    }

    /// 0 = PRIMED (cool), 1 = LEAKING (hot) — matches Athlete Hub heat bars.
    private static func kineticJointHeats(audit: BiomechanicsAudit?) -> (ankle: Double, knee: Double, hip: Double) {
        guard let a = audit else { return (0.2, 0.2, 0.2) }
        func heat(_ status: JointStatus) -> Double {
            switch status {
            case .optimal: return 0.12
            case .moderate: return 0.48
            case .deficit: return 0.88
            }
        }
        return (heat(a.ankleDorsiflexion.status), heat(a.kneeTracking.status), heat(a.hipExtension.status))
    }

    private static func ensureFELDocumentsURL() throws -> URL {
        try FELDocumentsFolder.urlCreatingIfNeeded()
    }

    private nonisolated static func loadGeminiSystemInstructions() -> String {
        if let url = Bundle.main.url(forResource: "GEMINI_SYSTEM_INSTRUCTIONS", withExtension: "txt", subdirectory: "Config") {
            return (try? String(contentsOf: url)) ?? ""
        }
        if let url = Bundle.main.url(forResource: "GEMINI_SYSTEM_INSTRUCTIONS", withExtension: "txt") {
            return (try? String(contentsOf: url)) ?? ""
        }
        return ""
    }

    private nonisolated static func buildCloudCortexPrompt(metrics: PerformanceSnapshot) -> String {
        let systemBlock = loadGeminiSystemInstructions()
        let peakZ = metrics.allTimePeakZCmS.map { String(format: "%.2f", $0) } ?? "n/a"
        let jumpLines: String
        if metrics.bondsApexJumps.isEmpty {
            jumpLines = "(No dunk-lane PRQ history rows yet — still prescribe from fatigue + Peak Z.)"
        } else {
            jumpLines = metrics.bondsApexJumps.enumerated().map { i, j in
                let n = j.neuroPerformance.map { String(format: "%.4f", $0) } ?? "—"
                return "\(i + 1). \(j.dateISO8601) | prqBonus=\(String(format: "%.4f", j.prqBonus)) neuro=\(n) mode=\(j.gameModeId)"
            }.joined(separator: "\n")
        }
        let academyModuleIndex = """
        Vertical Velocity Academy (10-module forensic curriculum): mod1 Bio-Electric Freeway; mod2 Internal GPS (SFMA/FMS); mod3 The Piston (IAP — diaphragm & pelvic floor); mod4 Movement Snacks; mod5 Anatomy of the Sling (Spiral Line overlay); mod6 Clearing the Path (NMS — Isometric Split Stance Wall Push); mod7 Loaded Spring; mod8 Rhythmic Penultimate (Push 1,2); mod9 Elastic Engine (progressed/regressed → deep-tier plyos); mod10 Flight Blueprint (Continuous Hops 45–60s = extensive/regressed elasticity depth).
        Forensic alias: "Module 2: The Ankle Piston" = ankle dorsiflexion + elastic recoil mechanics (ankle stiffness / Jump Code block) — prescribe alongside mod3 Piston (IAP) when bracing or Peak Z loss suggests ankle limitation; use mod8 Push 1,2 context for penultimate timing.
        """
        let rulesReminder = """
        \(academyModuleIndex)
        Hard rules: If Peak Z drops >5% over the last 3 dunk-lane sessions vs prior trend, prescribe 48h CNS recovery. If Peak Z is stable but PRQ is low, prescribe Neuro-Priming drills. Use FatigueState with Peak Z to infer CNS burnout risk.
        """
        let sfmaRotationBlock: String
        if metrics.sfmaMultiSegmentalRotationPassed == false {
            sfmaRotationBlock = """
        SFMA MULTI-SEGMENTAL ROTATION SCREEN: FAILED (forensic flag).
        Vertical Velocity Academy (10-module launch): you MUST explicitly prescribe Module 6 — NMS Correctives (Clearing the Path), and the Isometric Split Stance Wall Push as the primary neuromuscular corrective before high-intensity plyometrics or dunk-lane volume. Reference Spiral Line / rotation-chain context from Module 5 when explaining why.
        """
        } else {
            sfmaRotationBlock = """
        SFMA multi-segmental rotation: not flagged as failed (or not yet screened) — tie prescriptions to modules mod1–mod10 only when metrics support (Peak Z, PRQ, fatigue).
        """
        }
        return """
        === SYSTEM INSTRUCTIONS (Neuro-Mechanic / CONFIG) ===
        \(systemBlock.isEmpty ? "(Embedded CONFIG/GEMINI_SYSTEM_INSTRUCTIONS not bundled — follow rules below.)" : systemBlock)

        \(rulesReminder)

        \(sfmaRotationBlock)

        === CURRENT ATHLETE METRICS ===
        - PRQ: \(String(format: "%.2f", metrics.prqScore))
        - Readiness: \(String(format: "%.2f", metrics.readinessScore))
        - Efficiency: \(String(format: "%.2f", metrics.efficiencyScore))
        - Vertical potential: \(String(format: "%.2f", metrics.verticalPotential))
        - Neural drive: \(String(format: "%.2f", metrics.neuralDrive))
        - FatigueState (from Unreal coach JSON): \(metrics.fatigueState)
        - All-time Peak Z proxy (cm/s): \(peakZ)

        Last up to 10 Bonds Apex / dunk-lane jumps (PRQ history):
        \(jumpLines)

        Output exactly ONE line: Neuro-Mechanic Prescription — strictly fewer than 200 characters (UI cap). No markdown, no quotes, no bullets.
        """
    }

    private nonisolated static func extractNeuroMechanicPrescription(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? trimmed
        let noBold = firstLine.replacingOccurrences(of: "**", with: "")
        return String(noBold.prefix(199))
    }
}

// MARK: - JSON shape (keys match `FELReadinessIO::ParseSnapshotJsonString` — `active_mode` is explicit).
// Security: metrics-only payload — no API keys, tokens, or DeepMotion credentials (those stay in process env / CI secrets).

nonisolated struct FelReadinessSnapshotExport: Codable, Sendable {
    var efficiencyScore: Double
    var prqScore: Double
    var readinessScore: Double
    var verticalPotential: Double
    var neuralDrive: Double
    var popForce: Double
    var currentOutfit: String
    var verticalEstimateInches: Double
    var hangTimeScale: Double
    var kineticLeakageMultiplier: Double
    /// System Scan — optional keys for backward-compatible decode; Unreal reads via `FELReadinessIO`.
    var movementGrade: String?
    var flightTimeSeconds: Double?
    var isPrimed: Bool?
    var ankleKineticHeat: Double?
    var kneeKineticHeat: Double?
    var hipKineticHeat: Double?
    /// Academy `mod9` (Plyos) complete — Unreal applies +2% jump neuro in Dunk Contest (`AcademyPlyosMasteryBonus`).
    var academyPlyosMasteryBonus: Double?
    /// System Scan video probe (async `loadTracks` / `nominalFrameRate`) — present when library clip was analyzed.
    var videoNominalFrameRateHz: Double?
    var playTwinBirthCinematicOnce: Bool?
    var labWelcomeToast: String?
    var jerseyTexturePath: String?
    var shoeTexturePath: String?
    /// MyTeam gear — matches `FELReadinessIO` (`gearMotionWarpMultiplier` / `gearJumpVelocityMultiplier`).
    var gearMotionWarpMultiplier: Double?
    var gearJumpVelocityMultiplier: Double?
    var stoodCreatorCardId: String?
    var neuroFlowIntensityScale: Double?
    var stoodCreatorCardTraitLine: String?
    var stoodCardJumpScale: Double?
    var stoodCardNeuralDriveAlpha: Double?
    var stoodCardTier: String?
    /// Creator Card signature — Unreal `EFELSignatureTrait` (`signature_trait_id`).
    var signatureTraitId: String?
    /// Unreal `ActiveArenaMode` — JSON key **`active_mode`** (not `activeArenaMode`).
    var activeMode: String
    /// Up to 3 card art paths for Vault hologram terminal (optional).
    var creatorCardTextures: [String]?
    var neuroMechanicLogoTexture: String?
    var bondsBounceLogoTexture: String?
    /// Swift `AvatarSkinConfig` — Unreal `AFELBasketballCharacter` mesh relative scale (digital twin rig).
    var avatarHeightScale: Double
    var avatarWeightScale: Double
    /// SFMA rotation screen — Unreal `UFELBiometricOverlays` congestion (JSON key **`sfmaMultiSegmentalRotationPassed`**; Unreal also accepts `sfma_multi_segmental_rotation_passed`).
    var sfmaMultiSegmentalRotationPassed: Bool?

    enum CodingKeys: String, CodingKey {
        case efficiencyScore
        case prqScore
        case readinessScore
        case verticalPotential
        case neuralDrive
        case popForce
        case currentOutfit
        case verticalEstimateInches
        case hangTimeScale
        case kineticLeakageMultiplier
        case movementGrade
        case flightTimeSeconds
        case isPrimed
        case ankleKineticHeat
        case kneeKineticHeat
        case hipKineticHeat
        case academyPlyosMasteryBonus
        case videoNominalFrameRateHz
        case playTwinBirthCinematicOnce
        case labWelcomeToast
        case jerseyTexturePath
        case shoeTexturePath
        case gearMotionWarpMultiplier
        case gearJumpVelocityMultiplier
        case stoodCreatorCardId
        case neuroFlowIntensityScale
        case stoodCreatorCardTraitLine
        case stoodCardJumpScale
        case stoodCardNeuralDriveAlpha
        case stoodCardTier
        case signatureTraitId = "signature_trait_id"
        case activeMode = "active_mode"
        case creatorCardTextures
        case neuroMechanicLogoTexture
        case bondsBounceLogoTexture
        case avatarHeightScale
        case avatarWeightScale
        case sfmaMultiSegmentalRotationPassed
    }
}

private extension JSONEncoder {
    static var felPretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }
}
