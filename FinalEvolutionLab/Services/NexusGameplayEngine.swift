import Foundation

/// Live HUD snapshot from `fel.hud.poll` (Agent 2 HUD relay).
struct NexusHUDSnapshot: Equatable {
    var modeId: String = ""
    var playerScore: Double = 0
    var opponentScore: Double = 0
    var combo: Int = 0
    var sessionState: String = "idle"
    var throwCatchPhase: NexusGameplayEngine.ThrowCatchPhase = .catchPhase
    var powerMultiplier: Double = 1.0
    var throwsTriggered: UInt64 = 0
    var elapsedSeconds: Double = 0
    var frameSequence: UInt64 = 0
    var karateWave: Int = 0
    var karatePlayerHP: Double = 0
    var karateOpponentsAlive: Int = 0
    var karateWaveState: String = "combat"
    var karatePlayerCount: Int = 1
    var karateActivePlayer: Int = 0
    var karatePlayerHPs: [Double] = []
    var karateTargetWave: Int = 10
    var karatePerkAvailable: Bool = false
    var karateExfilAvailable: Bool = false
    var karateVictory: Bool = false
    var matchComplete: Bool = false
    var outcomeSportStreak: Int = 0
    var outcomeSportModeId: String = ""
    var outcomeSportPlayerMetric: Int = 0
    var outcomeSportOpponentMetric: Int = 0
    var outcomeSportSecondaryMetric: Int = 0
    var outcomeSportPlayerSets: Int = 0
    var outcomeSportOpponentSets: Int = 0
    var outcomeSportHolesPlayed: Int = 0
    var outcomeSportCoursePar: Int = 0
    var outcomeSportInning: Int = 0
    var outcomeSportHotStreak: Bool = false
    var outcomeSportLastAction: String = ""
    var outcomeSportWinTarget: Int = 0
    var outcomeSportPenaltyRound: Int = 0
    var brainPlayerCorrect: Int = 0
    var brainOpponentCorrect: Int = 0
    var cognitiveScore: Double = 0
    var cognitiveStreak: Int = 0
    var cognitiveWinTarget: Int = 0
    var cognitivePhase: Int = 0
    var sceneBuzzWins: Int = 0
    var scenePlayerHasBuzz: Bool = false
    var carnivalWinTarget: Int = 15
    var carnivalRoundsToWin: Int = 5
    var carnivalRoundsWon: Int = 0
    var carnivalActivePad: String = ""
    var carnivalPhase: Int = 0

    var sessionStateLabel: String {
        sessionState.uppercased()
    }

    /// Mode-specific secondary line for outcome-sport HUD (inning, sets, par, rally, etc.).
    var outcomeSportStatusLine: String {
        let modeKey = outcomeSportModeId.isEmpty ? modeId : outcomeSportModeId
        switch modeKey {
        case "baseball":
            let inning = outcomeSportInning > 0 ? outcomeSportInning : 1
            return "INN \(inning) · RUNS \(outcomeSportPlayerMetric)-\(outcomeSportOpponentMetric)"
        case "football":
            return "TD \(outcomeSportPlayerMetric)-\(outcomeSportOpponentMetric) · \(Int(playerScore))-\(Int(opponentScore)) PTS"
        case "soccer":
            let target = outcomeSportWinTarget > 0 ? outcomeSportWinTarget : 5
            let round = outcomeSportPenaltyRound > 0 ? outcomeSportPenaltyRound : max(1, outcomeSportPlayerMetric + outcomeSportOpponentMetric)
            return "PENALTY R\(round) · GOALS \(outcomeSportPlayerMetric)-\(outcomeSportOpponentMetric) (first to \(target))"
        case "golf":
            let par = outcomeSportCoursePar > 0 ? outcomeSportCoursePar : 36
            let currentHole = min(outcomeSportHolesPlayed + 1, 9)
            return "HOLE \(currentHole)/9 · \(outcomeSportPlayerMetric)/\(par) STROKES"
        case "tennis":
            return "SETS \(outcomeSportPlayerSets)-\(outcomeSportOpponentSets) · G \(outcomeSportPlayerMetric)-\(outcomeSportOpponentMetric)"
        case "volleyball":
            return "RALLY \(outcomeSportPlayerMetric)-\(outcomeSportOpponentMetric) (25 win by 2)"
        case "basketball_3v3":
            if outcomeSportHotStreak {
                return "HOT STREAK · \(outcomeSportPlayerMetric)-\(outcomeSportOpponentMetric)"
            }
            if outcomeSportLastAction == "three_pointer" {
                return "3PT · PTS \(outcomeSportPlayerMetric)-\(outcomeSportOpponentMetric)"
            }
            return "PTS \(outcomeSportPlayerMetric)-\(outcomeSportOpponentMetric)"
        case "karate_h2h":
            return "HP \(Int(playerScore)) vs \(Int(opponentScore))"
        default:
            if !outcomeSportLastAction.isEmpty {
                return FELPremiumCopy.humanizeOutcomeSportAction(outcomeSportLastAction).uppercased()
            }
            return ""
        }
    }
}

/// Swift façade over the headless NEXUS `nexus_gameplay` C++ module (fel.* protocol).
@MainActor
@Observable
final class NexusGameplayEngine {
    enum ThrowCatchPhase: Int {
        case catchPhase = 0
        case load = 1
        case throwPhase = 2
        case recover = 3

        var label: String {
            switch self {
            case .catchPhase: return "CATCH"
            case .load: return "LOAD"
            case .throwPhase: return "THROW"
            case .recover: return "RECOVER"
            }
        }
    }

    private(set) var isLinked: Bool = false
    private(set) var bridgeLinked: Bool = NexusGameplayBridge.isLinked
    private(set) var physicsReady: Bool = false
    private(set) var sessionActive: Bool = false
    private(set) var hud = NexusHUDSnapshot()
    private(set) var arenaModeId: String = ""
    private(set) var venueToken: String = ""
    private(set) var lastCommandError: String?

    /// Player-facing command error — raw fel.* strings stay in ``lastCommandError`` for logs.
    var userFacingCommandError: String? {
        guard let lastCommandError else { return nil }
        return FELPremiumCopy.humanizeCommandError(lastCommandError)
    }
    private(set) var lastEndSessionStatus: String?
    private(set) var lastFinalScoresJSON: String?
    private(set) var lastFlushDelivered: Int = 0
    private(set) var lastDunkTimingGrade: String = ""
    private(set) var dunkChargePower: Double = 0
    private(set) var lastDunkScoringResult: DunkScoringResult?
    private var lastEngineDunkDetailsCount: Int = 0
    private(set) var lastKarateActionLabel: String = ""
    private(set) var lastKarateDamage: Double = 0
    private(set) var lastSportPulsePoints: Int = 0
    private(set) var lastPickupActionPoints: Int = 0
    private(set) var lastCarnivalDiceValue: Int = 0
    private(set) var lastCarnivalPadPoints: Int = 0
    private(set) var lastCarnivalPadGrade: String = ""
    private(set) var lastBoardActionPoints: Int = 0
    private(set) var lastBoardActionGrade: String = ""
    private(set) var lastGenerativeIntent: String = ""
    private(set) var lastGenerativeSummary: String = ""

    // Pending customizer parameters to merge during generation
    private var pendingHudCustomizer: [String: Any]?
    private var pendingVoxelCustomizer: [String: Any]?

    /// Back-compat accessors for existing HUD bindings.
    var throwCatchPhase: ThrowCatchPhase { hud.throwCatchPhase }
    var powerMultiplier: Double { hud.powerMultiplier }
    var throwsTriggered: UInt64 { hud.throwsTriggered }

    private var session: NexusGameplayHandle?
    private let proMotionTicker = FELProMotionTicker()
    private var activeModeId: String = ""
    private var lastHudPollTime: CFAbsoluteTime = 0
    private let hudPollMinInterval: CFAbsoluteTime = 1.0 / Double(FELViewportRefreshPolicy.gameplayTickHz)

    /// Boots a lightweight session so fel.generate.* / fel.creative.* commands can run outside active play.
    func bootstrapForCreativeCommands(readiness: Double = 72) {
        guard session == nil else { return }
        start(modeId: "basketball_dunk", readiness: readiness, userId: "creative_author")
        if session != nil, physicsReady {
            sessionActive = true
            isLinked = true
        }
    }

    struct ArenaPromptPreview: Equatable {
        var intent: String
        var stepCount: Int
    }

    struct DescribeArenaResult: Equatable {
        var success: Bool
        var intent: String
        var jobCount: Int
        var summary: String
        var errorMessage: String?
    }

    struct GeneratedGameSpec {
        var specId: String
        var modeId: String
        var displayName: String
        var venueToken: String
        var difficultyTier: String
        var previewLabel: String
        var adapterTier: String
        var generatorTier: String
        var geminiAttempted: Bool
        var geminiFallbackReason: String?
        var fallbackUsed: Bool
        var aiProvider: String
        var exportPathHint: String
        var rawPayload: [String: Any]

        // Customizer properties
        var hudPrimaryColor: String?
        var hudAccentColor: String?
        var hudBadgeLabel: String?
        var voxelMaterial: String?
        var voxelPaintRadius: Double?
        var voxelGridScale: Double?
        var voxelDensity: Double?

        /// Human-readable adapter badge for generator UI.
        var adapterDisplayLabel: String {
            if aiProvider == "ai_studio" || generatorTier == "ai_studio_assisted" {
                return "Powered by AI Studio"
            }
            switch generatorTier {
            case "template_ai_studio_partial":
                return "Templates + AI hints"
            case "gemini_assisted":
                return "Powered by AI Studio"
            case "template_gemini_partial":
                return "Templates + AI hints"
            default:
                if geminiAttempted, geminiFallbackReason != nil {
                    return "Built-in templates (AI unavailable)"
                }
                return "Built-in templates"
            }
        }

        var displayPreviewLabel: String {
            FELPremiumCopy.humanizePreviewLabel(previewLabel)
        }

        var displayGeneratorTier: String {
            FELPremiumCopy.generatorTierLabel(generatorTier)
        }

        var registryMode: GameMode? {
            GameModeRegistry.playableMode(forRegistryId: modeId)
        }

        static func from(payload: [String: Any]) -> GeneratedGameSpec? {
            let spec = payload["game_spec"] as? [String: Any] ?? payload
            guard let modeId = spec["mode_id"] as? String else { return nil }
            let rules = spec["rules"] as? [String: Any] ?? [:]
            let hud = spec["hud_theme"] as? [String: Any] ?? [:]
            let metadata = spec["metadata"] as? [String: Any] ?? [:]
            let adapter = metadata["adapter"] as? String ?? "template_mvp"
            let aiProvider = metadata["ai_provider"] as? String ?? metadata["ai_backend"] as? String ?? "template_mvp"
            let generatorTier = metadata["generator_tier"] as? String ?? adapter
            let geminiAttempted = (metadata["gemini_attempted"] as? Bool ?? false)
                || (metadata["ai_studio_attempted"] as? Bool ?? false)
            let fallbackUsed = metadata["fallback_used"] as? Bool ?? false
            let geminiFallbackReason = metadata["gemini_fallback_reason"] as? String
                ?? metadata["ai_studio_fallback_reason"] as? String
            let adapterLabel = aiProvider == "ai_studio" ? "Powered by AI Studio" : "Template-only"

            let customHud = spec["hud_customizer"] as? [String: Any]
            let customVoxel = spec["voxel_customizer"] as? [String: Any]

            return GeneratedGameSpec(
                specId: spec["spec_id"] as? String ?? "game_unknown",
                modeId: modeId,
                displayName: spec["display_name"] as? String ?? modeId,
                venueToken: spec["venue_token"] as? String ?? "",
                difficultyTier: rules["difficulty_tier"] as? String ?? "normal",
                previewLabel: FELPremiumCopy.humanizePreviewLabel(
                    hud["preview_label"] as? String ?? "PREVIEW · GENERATED GAME SPEC"
                ),
                adapterTier: adapterLabel,
                generatorTier: generatorTier,
                geminiAttempted: geminiAttempted,
                geminiFallbackReason: geminiFallbackReason,
                fallbackUsed: fallbackUsed,
                aiProvider: aiProvider,
                exportPathHint: spec["export_path_hint"] as? String ?? "NexusStudio/sandbox/generated_games/\(modeId).json",
                rawPayload: spec,
                hudPrimaryColor: customHud?["primary_color"] as? String,
                hudAccentColor: customHud?["accent_color"] as? String,
                hudBadgeLabel: customHud?["badge_label"] as? String,
                voxelMaterial: customVoxel?["voxel_material"] as? String,
                voxelPaintRadius: customVoxel?["paint_radius"] as? Double,
                voxelGridScale: customVoxel?["grid_scale"] as? Double,
                voxelDensity: customVoxel?["density"] as? Double
            )
        }
    }

    struct GenerateGameResult {
        var success: Bool
        var spec: GeneratedGameSpec?
        var summary: String
        var sessionStarted: Bool
        var errorMessage: String?
    }

    private(set) var lastGeneratedGameSpec: GeneratedGameSpec?

    func parseArenaPrompt(_ text: String) async -> ArenaPromptPreview? {
        let response = sendCommand([
            "command": "fel.generate.parse_prompt",
            "id": "ios_parse_prompt",
            "params": ["text": text],
        ])
        guard response?.status == "ok", let payload = response?.payload else { return nil }
        let intent = payload["intent"] as? String ?? "unknown"
        let steps = payload["steps"] as? [[String: Any]] ?? []
        return ArenaPromptPreview(intent: intent, stepCount: steps.count)
    }

    func parseGamePrompt(_ text: String) async -> GeneratedGameSpec? {
        let response = sendCommand([
            "command": "fel.generate.parse_game",
            "id": "ios_parse_game",
            "params": ["text": text],
        ])
        guard response?.status == "ok", let payload = response?.payload else { return nil }
        return GeneratedGameSpec.from(payload: payload)
    }

    @discardableResult
    func generateGame(
        _ text: String,
        includeArena: Bool = false,
        startSession: Bool = true,
        forceTemplate: Bool = false,
        aiStudio: NexusAIStudioConfigService? = nil,
        hudThemeCustomizer: [String: Any]? = nil,
        voxelArenaDesigner: [String: Any]? = nil
    ) async -> GenerateGameResult {
        pendingHudCustomizer = hudThemeCustomizer
        pendingVoxelCustomizer = voxelArenaDesigner

        if session == nil {
            bootstrapForCreativeCommands()
        }

        let studio = aiStudio ?? NexusAIStudioConfigService.shared
        let effectiveForceTemplate = forceTemplate || studio.shouldForceTemplate
        var params: [String: Any] = [
            "text": text,
            "include_arena": includeArena,
            "start_session": startSession,
            "force_template": effectiveForceTemplate,
            "user_id": "ios_generator",
        ]
        if !effectiveForceTemplate {
            for (key, value) in studio.gameplayCommandParams(forceTemplate: false) where key != "force_template" {
                params[key] = value
            }
        }

        let response = sendCommand([
            "command": "fel.generate.game",
            "id": "ios_generate_game",
            "params": params,
        ])

        return mapGenerateGameResponse(response, failureMessage: "fel.generate.game failed")
    }

    @discardableResult
    func refineGame(
        _ text: String,
        startSession: Bool = true,
        forceTemplate: Bool = false,
        aiStudio: NexusAIStudioConfigService? = nil,
        hudThemeCustomizer: [String: Any]? = nil,
        voxelArenaDesigner: [String: Any]? = nil
    ) async -> GenerateGameResult {
        pendingHudCustomizer = hudThemeCustomizer
        pendingVoxelCustomizer = voxelArenaDesigner

        if session == nil {
            bootstrapForCreativeCommands()
        }

        let studio = aiStudio ?? NexusAIStudioConfigService.shared
        let effectiveForceTemplate = forceTemplate || studio.shouldForceTemplate
        var params: [String: Any] = [
            "text": text,
            "start_session": startSession,
            "force_template": effectiveForceTemplate,
            "user_id": "ios_generator",
        ]
        if !effectiveForceTemplate {
            for (key, value) in studio.gameplayCommandParams(forceTemplate: false) where key != "force_template" {
                params[key] = value
            }
        }
        if let last = lastGeneratedGameSpec {
            params["spec"] = last.rawPayload
        }

        let response = sendCommand([
            "command": "fel.generate.refine_game",
            "id": "ios_refine_game",
            "params": params,
        ])

        return mapGenerateGameResponse(response, failureMessage: "fel.generate.refine_game failed")
    }

    @discardableResult
    func exportGeneratedSpecToSandbox(_ spec: GeneratedGameSpec) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: spec.rawPayload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else { return nil }

        let relative = spec.exportPathHint.hasPrefix("NexusStudio/")
            ? String(spec.exportPathHint.dropFirst("NexusStudio/".count))
            : "generated_games/\(spec.specId).json"

        do {
            try NexusStudioWorkspaceService.shared.saveToSandbox(relativePath: relative, content: json)
            return relative
        } catch {
            lastCommandError = error.localizedDescription
            return nil
        }
    }

    private func mapGenerateGameResponse(_ response: NexusCommandResponse?, failureMessage: String) -> GenerateGameResult {
        guard let response else {
            return GenerateGameResult(
                success: false,
                spec: nil,
                summary: "",
                sessionStarted: false,
                errorMessage: "Bridge unavailable"
            )
        }

        if response.status != "ok" {
            lastCommandError = response.error
            return GenerateGameResult(
                success: false,
                spec: nil,
                summary: "",
                sessionStarted: false,
                errorMessage: response.error ?? failureMessage
            )
        }

        var payload = response.payload ?? [:]

        // Merge pending customizers if present
        if var specDict = payload["game_spec"] as? [String: Any] ?? (payload.keys.contains("mode_id") ? payload : nil) {
            if let hud = pendingHudCustomizer {
                specDict["hud_customizer"] = hud
                // Also merge into hud_theme if needed
                var hudTheme = specDict["hud_theme"] as? [String: Any] ?? [:]
                if let primary = hud["primary_color"] as? String {
                    hudTheme["primary_color"] = primary
                }
                if let accent = hud["accent_color"] as? String {
                    hudTheme["accent_color"] = accent
                }
                if let label = hud["badge_label"] as? String {
                    hudTheme["preview_label"] = label
                }
                specDict["hud_theme"] = hudTheme
            }
            if let voxel = pendingVoxelCustomizer {
                specDict["voxel_customizer"] = voxel
            }
            payload["game_spec"] = specDict
        }

        // Clear pending customizers
        pendingHudCustomizer = nil
        pendingVoxelCustomizer = nil

        let spec = GeneratedGameSpec.from(payload: payload)
        lastGeneratedGameSpec = spec
        lastGenerativeSummary = payload["agent_summary"] as? String ?? "Game spec generated"
        lastCommandError = nil

        if spec?.modeId.isEmpty == false {
            arenaModeId = spec?.modeId ?? arenaModeId
            venueToken = spec?.venueToken ?? venueToken
        }

        let sessionStarted = payload["session_started"] as? Bool ?? false
        if sessionStarted {
            sessionActive = true
            isLinked = session != nil && physicsReady
            if let modeId = spec?.modeId, !modeId.isEmpty {
                activeModeId = modeId
            }
            refreshHUDPoll()
            FELHUDRelayClient.shared.startIfConfigured()
            proMotionTicker.start { [weak self] deltaSeconds in
                guard let self, self.session != nil, self.sessionActive, self.physicsReady else { return }
                NexusGameplayBridge.tick(self.session, deltaSeconds: deltaSeconds)
                self.refreshHUDPollIfDue()
            }
        }

        return GenerateGameResult(
            success: true,
            spec: spec,
            summary: lastGenerativeSummary,
            sessionStarted: sessionStarted,
            errorMessage: nil
        )
    }

    @discardableResult
    func describeArena(_ text: String) async -> DescribeArenaResult {
        let response = sendCommand([
            "command": "fel.generate.from_text",
            "id": "ios_describe_arena",
            "params": ["text": text],
        ])

        guard let response else {
            return DescribeArenaResult(
                success: false,
                intent: "",
                jobCount: 0,
                summary: "",
                errorMessage: "Bridge unavailable"
            )
        }

        if response.status != "ok" {
            lastCommandError = response.error
            return DescribeArenaResult(
                success: false,
                intent: "",
                jobCount: 0,
                summary: "",
                errorMessage: response.error ?? "fel.generate.from_text failed"
            )
        }

        let payload = response.payload ?? [:]
        let intent = payload["intent"] as? String ?? "unknown"
        let summary = payload["agent_summary"] as? String ?? "Arena plan applied"
        let jobs = payload["jobs"] as? [[String: Any]] ?? []
        lastGenerativeIntent = intent
        lastGenerativeSummary = summary
        lastCommandError = nil

        return DescribeArenaResult(
            success: true,
            intent: intent,
            jobCount: jobs.count,
            summary: summary,
            errorMessage: nil
        )
    }

    /// Boots the C++ gameplay session, syncs readiness, and starts an arena session for ``modeId``.
    func start(modeId: String, readiness: Double, userId: String = "ios_player", coopPlayerCount: Int = 1) {
        stop()
        bridgeLinked = NexusGameplayBridge.isLinked
        guard bridgeLinked else {
            isLinked = false
            lastCommandError = "NEXUS gameplay bridge is not linked"
            return
        }

        guard let created = NexusGameplayBridge.createSession() else {
            isLinked = false
            lastCommandError = "NEXUS gameplay session create failed"
            return
        }
        session = created
        activeModeId = modeId
        lastFinalScoresJSON = nil
        physicsReady = NexusGameplayBridge.physicsReady(session)
        guard physicsReady else {
            lastCommandError = "NEXUS physics world failed to initialize"
            sessionActive = false
            isLinked = false
            NexusGameplayBridge.destroySession(session)
            session = nil
            physicsReady = false
            activeModeId = ""
            return
        }

        NexusGameplayBridge.syncReadiness(session, readiness: Float(readiness))

        let startPayload: [String: Any] = [
            "command": "fel.arena.start_session",
            "id": "ios_start_session",
            "params": [
                "mode_id": modeId,
                "user_id": userId,
            ],
        ]
        let startResponse = sendCommand(startPayload)
        if startResponse?.status == "ok" {
            sessionActive = true
            isLinked = true
            lastCommandError = nil
            broadcastMapLoaded(modeId: modeId)
            if modeId == GameModeId.karateEndless.rawValue {
                _ = karateConfigureCoop(playerCount: coopPlayerCount)
            }
        } else {
            lastCommandError = startResponse?.error ?? "fel.arena.start_session failed"
            sessionActive = false
            isLinked = false
            NexusGameplayBridge.destroySession(session)
            session = nil
            physicsReady = false
            activeModeId = ""
            return
        }

        refreshHUDPoll()

        FELHUDRelayClient.shared.startIfConfigured()

        proMotionTicker.start { [weak self] deltaSeconds in
            guard let self, self.session != nil, self.sessionActive, self.physicsReady else { return }
            NexusGameplayBridge.tick(self.session, deltaSeconds: deltaSeconds)
            self.refreshHUDPollIfDue()
        }
    }

    private func broadcastMapLoaded(modeId: String) {
        let mapToken = venueToken.isEmpty ? modeId : venueToken
        let response = sendCommand([
            "command": "fel.bridge.broadcast_map_loaded",
            "id": "ios_map_loaded",
            "params": [
                "map": mapToken,
                "mode_id": modeId,
            ],
        ])
        if response?.status != "ok" {
            lastCommandError = response?.error ?? "fel.bridge.broadcast_map_loaded failed"
        }
    }

    /// Pushes Swift gameplay scores into the C++ arena session for modes without NEXUS score authority.
    func syncScores(player: Int, opponent: Int) {
        guard session != nil, sessionActive else { return }
        let payload: [String: Any] = [
            "command": "fel.arena.update_score",
            "id": "ios_update_score",
            "params": [
                "player_score": player,
                "opponent_score": opponent,
            ],
        ]
        _ = sendCommand(payload)
    }

    @discardableResult
    func dunkChargeBegin() -> Bool {
        let response = sendCommand([
            "command": "fel.dunk.charge_begin",
            "id": "ios_dunk_charge_begin",
            "params": [:] as [String: Any],
        ])
        let ok = response?.status == "ok"
        if !ok {
            lastCommandError = response?.error ?? "fel.dunk.charge_begin failed"
        }
        refreshHUDPoll()
        return ok
    }

    @discardableResult
    func dunkChargeRelease(power: Float) -> Bool {
        let clamped = max(0, min(1, power))
        dunkChargePower = Double(clamped)
        let response = sendCommand([
            "command": "fel.dunk.charge_release",
            "id": "ios_dunk_charge_release",
            "params": ["power": clamped],
        ])
        let ok = response?.status == "ok"
        if !ok {
            lastCommandError = response?.error ?? "fel.dunk.charge_release failed"
        }
        refreshHUDPoll()
        return ok
    }

    @discardableResult
    func dunkApexTap() -> Bool {
        let response = sendCommand([
            "command": "fel.dunk.apex_tap",
            "id": "ios_dunk_apex_tap",
            "params": [:] as [String: Any],
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            if let grade = payload["timing_grade"] as? String {
                lastDunkTimingGrade = grade
            }
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.dunk.apex_tap failed"
        }
        refreshHUDPoll()
        return ok
    }

    /// Venice pickup H2H — Shoot / Drive / Crossover via `fel.pickup.action`.
    @discardableResult
    func pickupAction(action: String, success: Bool, timing: Float) -> Bool {
        let response = sendCommand([
            "command": "fel.pickup.action",
            "id": "ios_pickup_action",
            "params": [
                "action": action.lowercased(),
                "success": success,
                "timing": max(0, min(1, timing)),
            ],
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            applyPickupPayload(payload)
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.pickup.action failed"
        } else {
            lastCommandError = nil
        }
        refreshHUDPoll()
        return ok
    }

    /// Court Carnival pad minigame — `fel.carnival.trigger_pad`.
    @discardableResult
    func carnivalTriggerPad(pad: String, timing: Float) -> Bool {
        let response = sendCommand([
            "command": "fel.carnival.trigger_pad",
            "id": "ios_carnival_pad",
            "params": [
                "pad": pad,
                "timing": max(0, min(1, timing)),
            ],
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            applyCarnivalPayload(payload)
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.carnival.trigger_pad failed"
        } else {
            lastCommandError = nil
        }
        refreshHUDPoll()
        return ok
    }

    /// Court Carnival board dice — returns rolled value when linked.
    @discardableResult
    func carnivalRollDice() -> Int? {
        let response = sendCommand([
            "command": "fel.carnival.roll_dice",
            "id": "ios_carnival_dice",
            "params": [:] as [String: Any],
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            applyCarnivalPayload(payload)
            if let dice = payload["dice"] as? [String: Any] {
                lastCarnivalDiceValue = intValue(dice["value"])
            }
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.carnival.roll_dice failed"
            return nil
        }
        lastCommandError = nil
        refreshHUDPoll()
        return lastCarnivalDiceValue > 0 ? lastCarnivalDiceValue : nil
    }

    /// Unified arena input — C++ routes dunk/karate actions to mode runtime handlers.
    @discardableResult
    func arenaModeInput(action: String) -> Bool {
        let response = sendCommand([
            "command": "fel.arena.mode_input",
            "id": "ios_mode_input",
            "params": ["action": action],
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            applyKarateActionPayload(payload, fallbackAction: action)
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.arena.mode_input failed"
        }
        refreshHUDPoll()
        return ok
    }

    @discardableResult
    func karateAction(_ action: String, playerIndex: Int? = nil) -> Bool {
        var params: [String: Any] = ["action": action]
        if let playerIndex {
            params["player_index"] = playerIndex
        }
        let response = sendCommand([
            "command": "fel.karate.action",
            "id": "ios_karate_action",
            "params": params,
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            applyKarateActionPayload(payload, fallbackAction: action)
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.karate.action failed"
        }
        refreshHUDPoll()
        return ok
    }

    @discardableResult
    func karateConfigureCoop(playerCount: Int) -> Bool {
        let response = sendCommand([
            "command": "fel.karate.wave",
            "id": "ios_karate_coop",
            "params": ["player_count": min(4, max(1, playerCount))],
        ])
        let ok = response?.status == "ok"
        if !ok {
            lastCommandError = response?.error ?? "fel.karate.wave configure failed"
        }
        refreshHUDPoll()
        return ok
    }

    @discardableResult
    func karateClaimPerk(_ perk: String) -> Bool {
        let response = sendCommand([
            "command": "fel.karate.wave",
            "id": "ios_karate_perk",
            "params": ["perk": perk],
        ])
        let ok = response?.status == "ok"
        if !ok {
            lastCommandError = response?.error ?? "fel.karate.wave perk failed"
        }
        refreshHUDPoll()
        return ok
    }

    @discardableResult
    func karateExfil() -> Bool {
        let response = sendCommand([
            "command": "fel.karate.wave",
            "id": "ios_karate_exfil",
            "params": ["exfil": true],
        ])
        let ok = response?.status == "ok"
        if !ok {
            lastCommandError = response?.error ?? "fel.karate.wave exfil failed"
        }
        refreshHUDPoll()
        return ok
    }

    private func applyKarateActionPayload(_ payload: [String: Any], fallbackAction: String) {
        if let combat = payload["combat"] as? [String: Any] {
            lastKarateActionLabel = combat["action"] as? String ?? fallbackAction
            lastKarateDamage = doubleValue(combat["damage"])
        }
    }

    private func applyPickupPayload(_ payload: [String: Any]) {
        if let pickup = payload["pickup"] as? [String: Any] {
            hud.playerScore = doubleValue(pickup["player_score"], default: hud.playerScore)
            hud.opponentScore = doubleValue(pickup["opponent_score"], default: hud.opponentScore)
            if pickup["match_complete"] as? Bool == true {
                hud.matchComplete = true
            }
        } else {
            hud.playerScore = doubleValue(payload["player_score"], default: hud.playerScore)
            hud.opponentScore = doubleValue(payload["opponent_score"], default: hud.opponentScore)
        }
        if let action = payload["action"] as? [String: Any] {
            let bonus = intValue(action["bonus_points"])
            let feedback = intValue(action["catch_feedback"])
            lastPickupActionPoints = bonus + (feedback >= 2 ? feedback : max(1, bonus))
        }
    }

    private func applyCarnivalPayload(_ payload: [String: Any]) {
        let carnival = payload["carnival"] as? [String: Any] ?? payload
        applyCarnivalState(carnival)

        if let padTrigger = payload["pad_trigger"] as? [String: Any] {
            lastCarnivalPadPoints = intValue(padTrigger["points"])
            lastCarnivalPadGrade = padTrigger["grade"] as? String ?? ""
        }
        if let dice = payload["dice"] as? [String: Any] {
            lastCarnivalDiceValue = intValue(dice["value"])
            lastCarnivalPadPoints = intValue(dice["bonus_points"])
            lastCarnivalPadGrade = lastCarnivalPadPoints > 0 ? "dice" : ""
        }
    }

    private func applyCarnivalState(_ carnival: [String: Any]) {
        hud.playerScore = doubleValue(carnival["player_score"], default: hud.playerScore)
        hud.opponentScore = doubleValue(carnival["opponent_score"], default: hud.opponentScore)
        hud.carnivalWinTarget = intValue(carnival["win_target"])
        if hud.carnivalWinTarget <= 0 { hud.carnivalWinTarget = 15 }
        hud.carnivalRoundsToWin = intValue(carnival["rounds_to_win"])
        if hud.carnivalRoundsToWin <= 0 { hud.carnivalRoundsToWin = 5 }
        hud.carnivalRoundsWon = intValue(carnival["rounds_won"])
        hud.carnivalActivePad = carnival["active_pad"] as? String ?? hud.carnivalActivePad
        hud.carnivalPhase = intValue(carnival["phase"])
        if carnival["match_complete"] as? Bool == true {
            hud.matchComplete = true
        }
    }

    /// Maps on-screen action labels to fel.karate.action params.
    static func nexusKarateActionName(for uiAction: String) -> String? {
        switch uiAction.lowercased() {
        case "punch": return "light_strike"
        case "kick": return "heavy_strike"
        case "block": return "block"
        case "dodge": return "dodge"
        case "counter": return "counter"
        default: return nil
        }
    }

    /// Mode-specific params for `fel.sport.pulse` from UI action labels and charge timing.
    static func sportPulseParams(
        modeId: GameModeId,
        uiAction: String,
        success: Bool,
        timing: Float = 0.85
    ) -> [String: Any] {
        switch modeId {
        case .basketball3v3:
            switch uiAction.lowercased() {
            case "shoot": return ["shot_type": "three_pointer"]
            case "drive": return ["shot_type": "layup"]
            default: return ["shot_type": "two_pointer"]
            }
        case .karate:
            if let action = nexusKarateActionName(for: uiAction) {
                return ["action": action]
            }
            return [:]
        case .volleyball:
            if uiAction.lowercased() == "spike", success {
                return ["rally_type": "ace_serve"]
            }
            return [:]
        case .baseball:
            if uiAction.lowercased() == "bunt" {
                return success ? [:] : ["play_type": "strikeout"]
            }
            if !success {
                return ["play_type": "strikeout"]
            }
            if uiAction.lowercased() == "swing", timing >= 0.92 {
                return ["play_type": "home_run"]
            }
            return [:]
        case .football:
            switch uiAction.lowercased() {
            case "turnover":
                return ["play_type": "turnover"]
            case "field goal":
                return ["play_type": success ? "field_goal" : "turnover"]
            case "catch", "break away":
                return ["play_type": success ? "touchdown" : "turnover"]
            default:
                return ["play_type": success ? "field_goal" : "turnover"]
            }
        case .soccer:
            return ["shot_type": "penalty"]
        case .golf:
            return ["club": "putt"]
        case .tennis:
            switch uiAction.lowercased() {
            case "serve": return ["shot_type": "ace"]
            case "volley": return ["shot_type": "volley"]
            default: return ["shot_type": "baseline"]
            }
        default:
            return [:]
        }
    }

    @discardableResult
    func sportPulse(success: Bool, timing: Float, extraParams: [String: Any] = [:]) -> Bool {
        var params: [String: Any] = [
            "success": success,
            "timing": max(0, min(1, timing)),
        ]
        for (key, value) in extraParams {
            params[key] = value
        }
        let response = sendCommand([
            "command": "fel.sport.pulse",
            "id": "ios_sport_pulse",
            "params": params,
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            applyOutcomeSportPayload(payload)
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.sport.pulse failed"
        } else {
            lastCommandError = nil
        }
        refreshHUDPoll()
        return ok
    }

    @discardableResult
    func brainAnswer(correct: Bool, responseTime: Float = 4.0, category: String = "SportsIQ") -> Bool {
        let response = sendCommand([
            "command": "fel.brain.answer",
            "id": "ios_brain_answer",
            "params": [
                "correct": correct,
                "response_time": max(0, min(15, responseTime)),
                "category": category,
            ],
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            if let nested = payload["brain_brawl"] as? [String: Any] {
                applyBrainBrawlPayload(nested)
            } else {
                applyBrainBrawlPayload(payload)
            }
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.brain.answer failed"
        } else {
            lastCommandError = nil
        }
        refreshHUDPoll()
        return ok
    }

    /// Maps rhythm-tap UI labels to board/academy fel.* commands (`GymnasticsMode`, `SkateboardingMode`, etc.).
    static func boardAcademyCommand(
        modeId: GameModeId,
        uiAction: String,
        timing: Float,
        success: Bool,
        comboMultiplier: Int
    ) -> (command: String, params: [String: Any])? {
        let t = max(0, min(1, timing))
        let combo = min(8, max(1, comboMultiplier))
        switch modeId {
        case .gymnastics:
            if success {
                let difficulty: Float
                switch uiAction.lowercased() {
                case "vault": difficulty = 0.9
                case "tumble": difficulty = 0.75
                default: difficulty = 0.8
                }
                return ("fel.gymnastics.tap", ["timing": t, "difficulty": difficulty])
            }
            return ("fel.gymnastics.deduct", ["value": 0.6])
        case .skateboarding:
            if success {
                let difficulty: Float
                switch uiAction.lowercased() {
                case "grind": difficulty = 0.85
                case "kickflip": difficulty = 0.9
                default: difficulty = 0.7
                }
                return ("fel.skate.trick", ["difficulty": difficulty, "combo_multiplier": combo])
            }
            return ("fel.skate.bail", [:])
        case .snowboarding:
            if success {
                switch uiAction.lowercased() {
                case "jump":
                    return ("fel.snow.jump", ["air_difficulty": 0.85, "combo_multiplier": combo])
                case "butter":
                    return ("fel.snow.butter", ["style": 0.8])
                default:
                    return ("fel.snow.carve", ["timing": t, "line_difficulty": 0.78])
                }
            }
            return ("fel.snow.wipeout", [:])
        case .surfing:
            if success {
                switch uiAction.lowercased() {
                case "aerial", "snap":
                    return ("fel.surf.aerial", ["air_difficulty": 0.85, "combo_multiplier": combo])
                default:
                    return ("fel.surf.carve", ["timing": t, "wave_difficulty": 0.78])
                }
            }
            return ("fel.surf.wipeout", [:])
        default:
            return nil
        }
    }

    @discardableResult
    func boardAcademyAction(
        modeId: GameModeId,
        uiAction: String,
        timing: Float,
        success: Bool,
        comboMultiplier: Int
    ) -> Bool {
        guard let routed = Self.boardAcademyCommand(
            modeId: modeId,
            uiAction: uiAction,
            timing: timing,
            success: success,
            comboMultiplier: comboMultiplier
        ) else {
            lastCommandError = "unsupported board/academy mode"
            return false
        }
        let response = sendCommand([
            "command": routed.command,
            "id": "ios_board_academy",
            "params": routed.params,
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            applyBoardAcademyPayload(payload, modeId: modeId)
        }
        if !ok {
            lastCommandError = response?.error ?? "\(routed.command) failed"
        } else {
            lastCommandError = nil
        }
        refreshHUDPoll()
        return ok
    }

    private func applyBoardAcademyPayload(_ payload: [String: Any], modeId: GameModeId) {
        lastBoardActionPoints = 0
        lastBoardActionGrade = ""
        if let tap = payload["tap"] as? [String: Any] {
            lastBoardActionGrade = tap["grade"] as? String ?? ""
            lastBoardActionPoints = intValue(tap["element_score"])
        }
        if let trick = payload["trick"] as? [String: Any] {
            lastBoardActionPoints = intValue(trick["points"])
        }
        if let carve = payload["carve"] as? [String: Any] {
            lastBoardActionGrade = carve["grade"] as? String ?? ""
            lastBoardActionPoints = intValue(carve["points"])
        }
        if let jump = payload["jump"] as? [String: Any] {
            lastBoardActionPoints = intValue(jump["points"])
        }
        if let aerial = payload["aerial"] as? [String: Any] {
            lastBoardActionPoints = intValue(aerial["points"])
        }
        if let butter = payload["butter"] as? [String: Any] {
            lastBoardActionPoints = intValue(butter["points"])
        }
        if modeId == .gymnastics, let gym = payload["gymnastics"] as? [String: Any] {
            hud.playerScore = doubleValue(gym["judge_score"])
            if gym["routine_complete"] as? Bool == true {
                hud.matchComplete = true
            }
        } else if modeId == .skateboarding {
            let skate = payload["skateboarding"] as? [String: Any]
            hud.playerScore = doubleValue(payload["trick_score"] ?? skate?["trick_score"])
            if payload["run_complete"] as? Bool == true || skate?["run_complete"] as? Bool == true {
                hud.matchComplete = true
            }
        } else if modeId == .snowboarding {
            let snow = payload["snowboarding"] as? [String: Any]
            hud.playerScore = doubleValue(payload["line_score"] ?? snow?["line_score"])
            if payload["run_complete"] as? Bool == true || snow?["run_complete"] as? Bool == true {
                hud.matchComplete = true
            }
        } else if modeId == .surfing {
            let surf = payload["surfing"] as? [String: Any]
            hud.playerScore = doubleValue(payload["wave_score"] ?? surf?["wave_score"])
            if payload["run_complete"] as? Bool == true || surf?["run_complete"] as? Bool == true {
                hud.matchComplete = true
            }
        }
    }

    @discardableResult
    func sceneBuzzIn(timing: Float) -> Bool {
        let response = sendCommand([
            "command": "fel.scene.buzz_in",
            "id": "ios_scene_buzz",
            "params": [
                "timing": max(0, min(1, timing)),
            ],
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            if let nested = payload["who_scene_it"] as? [String: Any] {
                applyWhoSceneItPayload(nested)
            } else {
                applyWhoSceneItPayload(payload)
            }
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.scene.buzz_in failed"
        } else {
            lastCommandError = nil
        }
        refreshHUDPoll()
        return ok
    }

    @discardableResult
    func sceneAnswer(correct: Bool, responseTime: Float = 4.0, category: String = "ClassicFilm") -> Bool {
        let response = sendCommand([
            "command": "fel.scene.answer",
            "id": "ios_scene_answer",
            "params": [
                "correct": correct,
                "response_time": max(0, min(15, responseTime)),
                "category": category,
            ],
        ])
        let ok = response?.status == "ok"
        if let payload = response?.payload {
            if let nested = payload["who_scene_it"] as? [String: Any] {
                applyWhoSceneItPayload(nested)
            } else {
                applyWhoSceneItPayload(payload)
            }
        }
        if !ok {
            lastCommandError = response?.error ?? "fel.scene.answer failed"
        } else {
            lastCommandError = nil
        }
        refreshHUDPoll()
        return ok
    }

    private func applyOutcomeSportPayload(_ payload: [String: Any]) {
        if let pulse = payload["pulse"] as? [String: Any] {
            lastSportPulsePoints = intValue(pulse["points"])
        }
        if let sport = payload["outcome_sport"] as? [String: Any] {
            applyOutcomeSportState(sport)
        } else {
            applyOutcomeSportState(payload)
        }
    }

    private func applyBrainBrawlPayload(_ payload: [String: Any]) {
        applyCognitiveModePayload(payload, prefix: "brain")
    }

    private func applyWhoSceneItPayload(_ payload: [String: Any]) {
        applyCognitiveModePayload(payload, prefix: "scene")
        hud.sceneBuzzWins = intValue(payload["buzz_wins"])
        if let hasBuzz = payload["player_has_buzz"] as? Bool {
            hud.scenePlayerHasBuzz = hasBuzz
        }
    }

    private func applyCognitiveModePayload(_ payload: [String: Any], prefix: String) {
        if prefix == "brain" {
            hud.brainPlayerCorrect = intValue(payload["player_correct"])
            hud.brainOpponentCorrect = intValue(payload["opponent_correct"])
        }
        hud.cognitiveScore = doubleValue(payload["cognitive_score"])
        hud.cognitiveStreak = intValue(payload["current_streak"])
        hud.cognitivePhase = intValue(payload["phase"])
        if let winTarget = payload["questions_to_win"] as? Int {
            hud.cognitiveWinTarget = winTarget
        } else if let winTarget = payload["win_target"] as? Int {
            hud.cognitiveWinTarget = winTarget
        }
        if let complete = payload["match_complete"] as? Bool {
            hud.matchComplete = complete
        }
    }

    private func applyOutcomeSportState(_ state: [String: Any]) {
        hud.outcomeSportModeId = state["mode_id"] as? String ?? hud.outcomeSportModeId
        hud.outcomeSportStreak = intValue(state["streak"])
        hud.outcomeSportPlayerMetric = intValue(state["player_metric"])
        hud.outcomeSportOpponentMetric = intValue(state["opponent_metric"])
        hud.outcomeSportSecondaryMetric = intValue(state["secondary_metric"])
        hud.outcomeSportPlayerSets = intValue(state["player_sets"])
        hud.outcomeSportOpponentSets = intValue(state["opponent_sets"])
        hud.outcomeSportHolesPlayed = intValue(state["holes_played"])
        hud.outcomeSportCoursePar = intValue(state["course_par"])
        hud.outcomeSportInning = intValue(state["inning"])
        hud.outcomeSportHotStreak = state["hot_streak"] as? Bool ?? false
        hud.outcomeSportLastAction = state["last_action"] as? String ?? ""
        hud.outcomeSportWinTarget = intValue(state["win_target"])
        hud.outcomeSportPenaltyRound = intValue(state["penalty_round"])
        hud.playerScore = doubleValue(state["player_score"], default: hud.playerScore)
        hud.opponentScore = doubleValue(state["opponent_score"], default: hud.opponentScore)
        if let complete = state["match_complete"] as? Bool {
            hud.matchComplete = complete
        }
    }

    func stop(playerScore: Int = 0, opponentScore: Int = 0, skipScoreSync: Bool = false) {
        proMotionTicker.stop()
        lastHudPollTime = 0

        if session != nil {
            if !skipScoreSync {
                syncScores(player: playerScore, opponent: opponentScore)
            }

            if let endRaw = NexusGameplayBridge.endArena(
                session,
                playerScore: Float(playerScore),
                opponentScore: Float(opponentScore)
            ) {
                lastEndSessionStatus = NexusCommandResponse.parse(endRaw)?.status
            }

            lastFinalScoresJSON = NexusGameplayBridge.finalScoresJSON(session)

            if let flushRaw = NexusGameplayBridge.flushReceipts(session) {
                if let response = NexusCommandResponse.parse(flushRaw),
                   response.status == "ok",
                   let payload = response.payload {
                    lastFlushDelivered = payload["delivered"] as? Int
                        ?? (payload["delivered"] as? NSNumber)?.intValue
                        ?? 0
                }
            }

            Task {
                await SessionReceiptUploadService.uploadPendingReceipts()
            }
        }

        NexusGameplayBridge.destroySession(session)
        session = nil
        sessionActive = false
        physicsReady = false
        activeModeId = ""
        hud = NexusHUDSnapshot()
        lastKarateActionLabel = ""
        lastKarateDamage = 0
        lastDunkScoringResult = nil
        lastEngineDunkDetailsCount = 0
        bridgeLinked = NexusGameplayBridge.isLinked
        isLinked = false
        FELHUDRelayClient.shared.stop()
    }

    private func refreshHUDPollIfDue(force: Bool = false) {
        let now = CFAbsoluteTimeGetCurrent()
        guard force || now - lastHudPollTime >= hudPollMinInterval else { return }
        lastHudPollTime = now
        refreshHUDPoll()
    }

    private func refreshHUDPoll() {
        guard let json = NexusGameplayBridge.hudPollJSON(session),
              let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outerPayload = root["payload"] as? [String: Any],
              let framePayload = outerPayload["payload"] as? [String: Any]
        else {
            return
        }

        FELHUDRelayClient.shared.sendFrameIfConfigured(json: json)

        var snapshot = NexusHUDSnapshot()

        if let seq = outerPayload["seq"] as? UInt64 {
            snapshot.frameSequence = seq
        } else if let seq = outerPayload["seq"] as? NSNumber {
            snapshot.frameSequence = seq.uint64Value
        }

        if let modeId = framePayload["mode_id"] as? String, !modeId.isEmpty {
            snapshot.modeId = modeId
            arenaModeId = modeId
        } else if !activeModeId.isEmpty {
            snapshot.modeId = activeModeId
            arenaModeId = activeModeId
        }

        snapshot.playerScore = doubleValue(framePayload["score"])
        snapshot.opponentScore = doubleValue(framePayload["opponent_score"])
        snapshot.combo = intValue(framePayload["combo"])
        snapshot.sessionState = framePayload["session_state"] as? String ?? "idle"
        snapshot.elapsedSeconds = doubleValue(framePayload["elapsed_seconds"])
        sessionActive = snapshot.sessionState == "active"
        isLinked = session != nil && physicsReady && sessionActive

        if let throwCatch = framePayload["throw_catch"] as? [String: Any] {
            if let phaseRaw = throwCatch["phase"] as? Int,
               let phase = ThrowCatchPhase(rawValue: phaseRaw) {
                snapshot.throwCatchPhase = phase
            }
            snapshot.powerMultiplier = doubleValue(throwCatch["power_multiplier"], default: 1.0)
            snapshot.throwsTriggered = uint64Value(throwCatch["throws_triggered"])
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let karate = modeState["karate"] as? [String: Any] {
            snapshot.karateWave = intValue(karate["wave"])
            snapshot.karatePlayerHP = doubleValue(karate["player_hp"])
            snapshot.karateOpponentsAlive = intValue(karate["opponents_alive"])
            snapshot.karateWaveState = karate["wave_state"] as? String ?? "combat"
            snapshot.karatePlayerCount = intValue(karate["player_count"])
            snapshot.karateActivePlayer = intValue(karate["active_player"])
            snapshot.karateTargetWave = intValue(karate["target_wave"])
            snapshot.karatePerkAvailable = karate["perk_available"] as? Bool ?? false
            snapshot.karateExfilAvailable = karate["exfil_available"] as? Bool ?? false
            snapshot.karateVictory = karate["victory"] as? Bool ?? false
            if let players = karate["players"] as? [[String: Any]] {
                snapshot.karatePlayerHPs = players.map { doubleValue($0["hp"]) }
            }
            if snapshot.playerScore == 0 {
                snapshot.playerScore = doubleValue(karate["score"])
            }
            snapshot.combo = intValue(karate["combo_chain"])
            if karate["session_over"] as? Bool == true || snapshot.karateVictory {
                snapshot.matchComplete = true
            }
        }

        if snapshot.outcomeSportModeId.isEmpty, !snapshot.modeId.isEmpty {
            snapshot.outcomeSportModeId = snapshot.modeId
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let sport = modeState["outcome_sport"] as? [String: Any] {
            snapshot.outcomeSportModeId = sport["mode_id"] as? String ?? snapshot.modeId
            snapshot.outcomeSportStreak = intValue(sport["streak"])
            snapshot.outcomeSportPlayerMetric = intValue(sport["player_metric"])
            snapshot.outcomeSportOpponentMetric = intValue(sport["opponent_metric"])
            snapshot.outcomeSportSecondaryMetric = intValue(sport["secondary_metric"])
            snapshot.outcomeSportPlayerSets = intValue(sport["player_sets"])
            snapshot.outcomeSportOpponentSets = intValue(sport["opponent_sets"])
            snapshot.outcomeSportHolesPlayed = intValue(sport["holes_played"])
            snapshot.outcomeSportCoursePar = intValue(sport["course_par"])
            snapshot.outcomeSportInning = intValue(sport["inning"])
            snapshot.outcomeSportHotStreak = sport["hot_streak"] as? Bool ?? false
            snapshot.outcomeSportLastAction = sport["last_action"] as? String ?? ""
            snapshot.outcomeSportWinTarget = intValue(sport["win_target"])
            snapshot.outcomeSportPenaltyRound = intValue(sport["penalty_round"])
            snapshot.playerScore = doubleValue(sport["player_score"], default: snapshot.playerScore)
            snapshot.opponentScore = doubleValue(sport["opponent_score"], default: snapshot.opponentScore)
            if let complete = sport["match_complete"] as? Bool {
                snapshot.matchComplete = complete
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let brain = modeState["brain_brawl"] as? [String: Any] {
            snapshot.brainPlayerCorrect = intValue(brain["player_correct"])
            snapshot.brainOpponentCorrect = intValue(brain["opponent_correct"])
            snapshot.cognitiveScore = doubleValue(brain["cognitive_score"])
            snapshot.cognitiveStreak = intValue(brain["current_streak"])
            snapshot.cognitivePhase = intValue(brain["phase"])
            snapshot.cognitiveWinTarget = intValue(brain["questions_to_win"])
            if let complete = brain["match_complete"] as? Bool {
                snapshot.matchComplete = complete
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let scene = modeState["who_scene_it"] as? [String: Any] {
            snapshot.brainPlayerCorrect = intValue(scene["correct_count"])
            snapshot.brainOpponentCorrect = intValue(scene["opponent_correct"])
            snapshot.cognitiveScore = doubleValue(scene["cognitive_score"])
            snapshot.cognitiveStreak = intValue(scene["current_streak"])
            snapshot.cognitivePhase = intValue(scene["phase"])
            snapshot.cognitiveWinTarget = intValue(scene["win_target"])
            snapshot.sceneBuzzWins = intValue(scene["buzz_wins"])
            snapshot.scenePlayerHasBuzz = scene["player_has_buzz"] as? Bool ?? false
            if let complete = scene["match_complete"] as? Bool {
                snapshot.matchComplete = complete
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let gym = modeState["gymnastics"] as? [String: Any] {
            snapshot.playerScore = doubleValue(gym["judge_score"])
            if gym["routine_complete"] as? Bool == true {
                snapshot.matchComplete = true
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let skate = modeState["skateboarding"] as? [String: Any] {
            snapshot.playerScore = doubleValue(skate["trick_score"])
            snapshot.combo = intValue(skate["combo_multiplier"])
            if skate["run_complete"] as? Bool == true {
                snapshot.matchComplete = true
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let snow = modeState["snowboarding"] as? [String: Any] {
            snapshot.playerScore = doubleValue(snow["line_score"])
            snapshot.combo = intValue(snow["combo_multiplier"])
            if snow["run_complete"] as? Bool == true {
                snapshot.matchComplete = true
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let surf = modeState["surfing"] as? [String: Any] {
            snapshot.playerScore = doubleValue(surf["wave_score"])
            snapshot.combo = intValue(surf["combo_multiplier"])
            if surf["run_complete"] as? Bool == true {
                snapshot.matchComplete = true
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let pickup = modeState["pickup"] as? [String: Any] {
            snapshot.playerScore = doubleValue(pickup["player_score"], default: snapshot.playerScore)
            snapshot.opponentScore = doubleValue(pickup["opponent_score"], default: snapshot.opponentScore)
            if pickup["match_complete"] as? Bool == true {
                snapshot.matchComplete = true
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let dunk = modeState["dunk"] as? [String: Any] {
            snapshot.playerScore = doubleValue(dunk["player_score"], default: snapshot.playerScore)
            snapshot.opponentScore = doubleValue(dunk["opponent_score"], default: snapshot.opponentScore)
            if dunk["match_complete"] as? Bool == true {
                snapshot.matchComplete = true
            }
            if let details = dunk["dunk_details"] as? [[String: Any]], details.count > lastEngineDunkDetailsCount {
                let latest = details[details.count - 1]
                let charge = doubleValue(dunk["charge_power"], default: dunkChargePower)
                let signatureId = dunk["signature_animation_id"] as? String
                let bonus = signatureId?.isEmpty == false ? 2.0 : nil
                let engineInput = WDAScoringEngine.adaptEngine3D(
                    dunkEvent: latest,
                    chargePower: charge,
                    signatureAnimationId: signatureId,
                    signatureDifficultyBonus: bonus
                )
                lastDunkScoringResult = WDAScoringEngine.shared.scoreEngine3DDunk(input: engineInput)
                lastEngineDunkDetailsCount = details.count
                if let grade = latest["timing_grade"] as? String {
                    lastDunkTimingGrade = grade
                }
            }
        }

        if let modeState = framePayload["mode_state"] as? [String: Any],
           let carnival = modeState["carnival"] as? [String: Any] {
            snapshot.playerScore = doubleValue(carnival["player_score"], default: snapshot.playerScore)
            snapshot.opponentScore = doubleValue(carnival["opponent_score"], default: snapshot.opponentScore)
            snapshot.carnivalWinTarget = intValue(carnival["win_target"])
            if snapshot.carnivalWinTarget <= 0 { snapshot.carnivalWinTarget = 15 }
            snapshot.carnivalRoundsToWin = intValue(carnival["rounds_to_win"])
            if snapshot.carnivalRoundsToWin <= 0 { snapshot.carnivalRoundsToWin = 5 }
            snapshot.carnivalRoundsWon = intValue(carnival["rounds_won"])
            snapshot.carnivalActivePad = carnival["active_pad"] as? String ?? ""
            snapshot.carnivalPhase = intValue(carnival["phase"])
            if carnival["match_complete"] as? Bool == true {
                snapshot.matchComplete = true
            }
        }

        hud = snapshot
    }

    @discardableResult
    private func sendCommand(_ payload: [String: Any]) -> NexusCommandResponse? {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let raw = NexusGameplayBridge.handleCommand(session, commandJson: json)
        else {
            return nil
        }
        return NexusCommandResponse.parse(raw)
    }

    private func doubleValue(_ value: Any?, default defaultValue: Double = 0) -> Double {
        if let number = value as? Double { return number }
        if let number = value as? NSNumber { return number.doubleValue }
        if let number = value as? Int { return Double(number) }
        return defaultValue
    }

    private func intValue(_ value: Any?) -> Int {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        return 0
    }

    private func uint64Value(_ value: Any?) -> UInt64 {
        if let number = value as? UInt64 { return number }
        if let number = value as? NSNumber { return number.uint64Value }
        if let number = value as? Int { return UInt64(number) }
        return 0
    }
}

private struct NexusCommandResponse {
    let status: String
    let error: String?
    let payload: [String: Any]?

    static func parse(_ json: String) -> NexusCommandResponse? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = root["status"] as? String
        else {
            return nil
        }
        let error = root["error"] as? String
        let payload = root["payload"] as? [String: Any]
        return NexusCommandResponse(status: status, error: error, payload: payload)
    }
}

enum NexusGameplayBridge {
    static var isLinked: Bool {
        nexus_gameplay_bridge_is_linked()
    }

    static func createSession() -> NexusGameplayHandle? {
        nexus_gameplay_session_create()
    }

    static func destroySession(_ session: NexusGameplayHandle?) {
        nexus_gameplay_session_destroy(session)
    }

    static func physicsReady(_ session: NexusGameplayHandle?) -> Bool {
        nexus_gameplay_session_physics_ready(session)
    }

    static func tick(_ session: NexusGameplayHandle?, deltaSeconds: Double) {
        nexus_gameplay_session_tick(session, deltaSeconds)
    }

    static func syncReadiness(_ session: NexusGameplayHandle?, readiness: Float) {
        nexus_gameplay_session_sync_readiness(session, readiness)
    }

    static func hudPollJSON(_ session: NexusGameplayHandle?) -> String? {
        guard let cString = nexus_gameplay_session_hud_poll_json(session) else {
            return nil
        }
        defer { nexus_gameplay_session_free_string(cString) }
        return String(cString: cString)
    }

    static func endArena(_ session: NexusGameplayHandle?, playerScore: Float, opponentScore: Float) -> String? {
        guard let cString = nexus_gameplay_session_end_arena(session, playerScore, opponentScore) else {
            return nil
        }
        defer { nexus_gameplay_session_free_string(cString) }
        return String(cString: cString)
    }

    static func flushReceipts(_ session: NexusGameplayHandle?) -> String? {
        guard let cString = nexus_gameplay_session_flush_receipts(session) else {
            return nil
        }
        defer { nexus_gameplay_session_free_string(cString) }
        return String(cString: cString)
    }

    static func finalScoresJSON(_ session: NexusGameplayHandle?) -> String? {
        guard let cString = nexus_gameplay_session_final_scores_json(session) else {
            return nil
        }
        defer { nexus_gameplay_session_free_string(cString) }
        return String(cString: cString)
    }

    static func sessionStateJSON(_ session: NexusGameplayHandle?) -> String? {
        guard let cString = nexus_gameplay_session_state_json(session) else {
            return nil
        }
        defer { nexus_gameplay_session_free_string(cString) }
        return String(cString: cString)
    }

    static func handleCommand(_ session: NexusGameplayHandle?, commandJson: String) -> String? {
        guard let cString = nexus_gameplay_session_handle_command(session, commandJson) else {
            return nil
        }
        defer { nexus_gameplay_session_free_string(cString) }
        return String(cString: cString)
    }
}
