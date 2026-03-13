import Foundation

struct UnityExportManifest: Codable, Sendable {
    let version: String
    let exportDate: String
    let athlete: AthleteData
    let performanceMetrics: MetricsData
    let arcadePhysics: ArcadePhysicsData
    let gameModes: [GameModeExport]
    let comboSystem: ComboSystemExport
    let timeScaleConfig: TimeScaleExport
    let ddaConfig: DDAExport
    let animationManifest: AnimationManifest

    struct AthleteData: Codable, Sendable {
        let id: String
        let displayName: String
        let athleteTag: String
        let sport: String
        let totalWorkouts: Int
        let streakDays: Int
        let evolutionShards: Int
        let premiumCredits: Int
        let creatorCredits: Int
    }

    struct MetricsData: Codable, Sendable {
        let prqScore: Double
        let neuralDrive: Double
        let efficiencyScore: Double
        let readinessScore: Double
        let verticalPotential: Double
        let prqTier: String
        let neuralBurstActive: Bool
        let auraLevel: String
    }

    struct ArcadePhysicsData: Codable, Sendable {
        let hangTimeMultiplier: Double
        let explosiveFirstStep: Double
        let comboDecayRate: Double
        let maxComboMultiplier: Double
        let successChanceBase: Double
        let criticalHitChance: Double
        let neuralBurstMultiplier: Double
        let impactIntensity: Double
        let perfectGuardWindow: Double
        let specialMeterGainRate: Double
        let perimeterDefense: Double
        let contestBonus: Double
    }

    struct GameModeExport: Codable, Sendable {
        let id: String
        let name: String
        let sport: String
        let environment: String
        let inputScheme: String
        let physicsConfig: PhysicsConfigExport
        let movementConfig: MovementConfigExport
    }

    struct PhysicsConfigExport: Codable, Sendable {
        let jumpHeight: Double
        let moveSpeed: Double
        let impactIntensity: Double
        let floorShakeAmplitude: Double
        let particleTrailDensity: Double
    }

    struct MovementConfigExport: Codable, Sendable {
        let topSpeed: Double
        let acceleration: Double
        let deceleration: Double
        let airControl: Double
        let baseJump: Double
        let chargedJump: Double
    }

    struct ComboSystemExport: Codable, Sendable {
        let maxChainLength: Int
        let chainWindowSeconds: Double
        let styleLandingWindowSeconds: Double
        let qteApexWindowSeconds: Double
        let qteGrades: [QTEGradeExport]
        let dunkTricks: [TrickExport]
        let combatTricks: [TrickExport]
    }

    struct QTEGradeExport: Codable, Sendable {
        let grade: String
        let multiplier: Double
        let triggersSlowMo: Bool
    }

    struct TrickExport: Codable, Sendable {
        let id: String
        let name: String
        let direction: String
        let modifier: String
        let basePoints: Int
        let riskFactor: Double
        let animationKey: String
    }

    struct TimeScaleExport: Codable, Sendable {
        let normalScale: Double
        let slowMoScale: Double
        let finisherScale: Double
        let perfectGuardScale: Double
        let apexScale: Double
        let blendInDuration: Double
        let blendOutDuration: Double
        let slowMoDuration: Double
        let finisherDuration: Double
        let stateMachineBlendDuration: Double
    }

    struct DDAExport: Codable, Sendable {
        let difficultyTier: String
        let aiAggressionFloor: Double
        let aiAggressionCeiling: Double
        let aiPatternComplexity: Int
        let aiFeintChance: Double
        let counterWindowShrink: Double
    }

    struct AnimationManifest: Codable, Sendable {
        let dunkAnimations: [AnimationEntry]
        let combatAnimations: [AnimationEntry]
        let generalAnimations: [AnimationEntry]
    }

    struct AnimationEntry: Codable, Sendable {
        let key: String
        let name: String
        let category: String
        let blendDuration: Double
    }
}

struct UnityExportBuilder {
    static func build(profile: UserProfile, metrics: PerformanceMetrics, arcade: ArcadePhysics, audit: BiomechanicsAudit?) -> UnityExportManifest {
        let formatter = ISO8601DateFormatter()

        let athlete = UnityExportManifest.AthleteData(
            id: profile.id,
            displayName: profile.displayName,
            athleteTag: profile.athleteTag,
            sport: profile.sport ?? "Unknown",
            totalWorkouts: profile.totalWorkouts,
            streakDays: profile.streakDays,
            evolutionShards: profile.evolutionShards,
            premiumCredits: profile.premiumCredits,
            creatorCredits: profile.creatorCredits
        )

        let prqTier = PRQTier.fromPRQ(metrics.prqScore)
        let metricsData = UnityExportManifest.MetricsData(
            prqScore: metrics.prqScore,
            neuralDrive: metrics.neuralDrive,
            efficiencyScore: metrics.efficiencyScore,
            readinessScore: metrics.readinessScore,
            verticalPotential: metrics.verticalPotential,
            prqTier: prqTier.rawValue,
            neuralBurstActive: arcade.neuralBurstActive,
            auraLevel: arcade.auraLevel.rawValue
        )

        let arcadeData = UnityExportManifest.ArcadePhysicsData(
            hangTimeMultiplier: arcade.hangTimeMultiplier,
            explosiveFirstStep: arcade.explosiveFirstStep,
            comboDecayRate: arcade.comboDecayRate,
            maxComboMultiplier: arcade.maxComboMultiplier,
            successChanceBase: arcade.successChanceBase,
            criticalHitChance: arcade.criticalHitChance,
            neuralBurstMultiplier: arcade.neuralBurstMultiplier,
            impactIntensity: arcade.impactIntensity,
            perfectGuardWindow: arcade.perfectGuardWindow,
            specialMeterGainRate: arcade.specialMeterGainRate,
            perimeterDefense: arcade.perimeterDefense,
            contestBonus: arcade.contestBonus
        )

        let gameModes = GameModeId.allCases.map { modeId -> UnityExportManifest.GameModeExport in
            let mode = GameModeRegistry.mode(for: modeId)
            let physics = GamePhysicsConfig.forMode(modeId, prq: metrics.prqScore, audit: audit)
            let movement = PS2MovementConfig.forMode(modeId)
            return UnityExportManifest.GameModeExport(
                id: modeId.rawValue,
                name: mode.name,
                sport: mode.sport.rawValue,
                environment: mode.environmentName,
                inputScheme: modeId.inputScheme.rawValue,
                physicsConfig: UnityExportManifest.PhysicsConfigExport(
                    jumpHeight: Double(physics.jumpHeight),
                    moveSpeed: Double(physics.moveSpeed),
                    impactIntensity: Double(physics.impactIntensity),
                    floorShakeAmplitude: Double(physics.floorShakeAmplitude),
                    particleTrailDensity: Double(physics.particleTrailDensity)
                ),
                movementConfig: UnityExportManifest.MovementConfigExport(
                    topSpeed: Double(movement.topSpeed),
                    acceleration: Double(movement.acceleration),
                    deceleration: Double(movement.deceleration),
                    airControl: Double(movement.airControl),
                    baseJump: Double(movement.baseJump),
                    chargedJump: Double(movement.chargedJump)
                )
            )
        }

        let qteGrades: [UnityExportManifest.QTEGradeExport] = [
            .init(grade: QTEGrade.perfect.rawValue, multiplier: QTEGrade.perfect.multiplier, triggersSlowMo: QTEGrade.perfect.triggersSlowMo),
            .init(grade: QTEGrade.great.rawValue, multiplier: QTEGrade.great.multiplier, triggersSlowMo: QTEGrade.great.triggersSlowMo),
            .init(grade: QTEGrade.good.rawValue, multiplier: QTEGrade.good.multiplier, triggersSlowMo: QTEGrade.good.triggersSlowMo),
            .init(grade: QTEGrade.ok.rawValue, multiplier: QTEGrade.ok.multiplier, triggersSlowMo: QTEGrade.ok.triggersSlowMo),
            .init(grade: QTEGrade.miss.rawValue, multiplier: QTEGrade.miss.multiplier, triggersSlowMo: QTEGrade.miss.triggersSlowMo),
        ]

        let dunkTricks = DirectionalTrick.dunkTricks.map {
            UnityExportManifest.TrickExport(id: $0.id, name: $0.name, direction: $0.direction.rawValue, modifier: $0.modifier.label, basePoints: $0.basePoints, riskFactor: $0.riskFactor, animationKey: $0.animationKey)
        }

        let combatTricks = DirectionalTrick.combatTricks.map {
            UnityExportManifest.TrickExport(id: $0.id, name: $0.name, direction: $0.direction.rawValue, modifier: $0.modifier.label, basePoints: $0.basePoints, riskFactor: $0.riskFactor, animationKey: $0.animationKey)
        }

        let comboSystem = UnityExportManifest.ComboSystemExport(
            maxChainLength: GoldenEraComboEngine.maxChainLength,
            chainWindowSeconds: GoldenEraComboEngine.chainWindowSeconds,
            styleLandingWindowSeconds: GoldenEraComboEngine.styleLandingWindowSeconds,
            qteApexWindowSeconds: QTEApexWindow.windowDuration,
            qteGrades: qteGrades,
            dunkTricks: dunkTricks,
            combatTricks: combatTricks
        )

        let timeScale = UnityExportManifest.TimeScaleExport(
            normalScale: TimeScaleManager.normalScale,
            slowMoScale: TimeScaleManager.slowMoScale,
            finisherScale: TimeScaleManager.finisherScale,
            perfectGuardScale: TimeScaleManager.perfectGuardScale,
            apexScale: TimeScaleManager.apexScale,
            blendInDuration: TimeScaleManager.blendInDuration,
            blendOutDuration: TimeScaleManager.blendOutDuration,
            slowMoDuration: TimeScaleManager.slowMoDuration,
            finisherDuration: TimeScaleManager.finisherDuration,
            stateMachineBlendDuration: MatrixStateMachine.blendDuration
        )

        let dda = PRQDrivenDDA(playerPRQ: metrics.prqScore, neuralDrive: metrics.neuralDrive, mode: .basketballDunkContest)
        let ddaExport = UnityExportManifest.DDAExport(
            difficultyTier: dda.difficultyTier.rawValue,
            aiAggressionFloor: dda.aiAggressionFloor,
            aiAggressionCeiling: dda.aiAggressionCeiling,
            aiPatternComplexity: dda.difficultyTier.aiPatternComplexity,
            aiFeintChance: dda.difficultyTier.aiFeintChance,
            counterWindowShrink: dda.difficultyTier.counterWindowShrink
        )

        let dunkAnims = DirectionalTrick.dunkTricks.map {
            UnityExportManifest.AnimationEntry(key: $0.animationKey, name: $0.name, category: "dunk", blendDuration: MatrixStateMachine.blendDuration)
        }
        let combatAnims = DirectionalTrick.combatTricks.map {
            UnityExportManifest.AnimationEntry(key: $0.animationKey, name: $0.name, category: "combat", blendDuration: MatrixStateMachine.blendDuration)
        }
        let generalAnims: [UnityExportManifest.AnimationEntry] = [
            .init(key: "idle_breathe", name: "Breathing Idle", category: "general", blendDuration: 0.2),
            .init(key: "sprint", name: "Sprint", category: "general", blendDuration: 0.15),
            .init(key: "gather", name: "Gather", category: "general", blendDuration: 0.2),
            .init(key: "land", name: "Landing", category: "general", blendDuration: 0.2),
            .init(key: "celebrate", name: "Victory Celebration", category: "general", blendDuration: 0.25),
            .init(key: "block", name: "Block Stance", category: "general", blendDuration: 0.15),
            .init(key: "perfect_guard", name: "Perfect Guard", category: "general", blendDuration: 0.1),
            .init(key: "vanish", name: "Vanish Counter", category: "general", blendDuration: 0.1),
        ]

        return UnityExportManifest(
            version: "2.0.0",
            exportDate: formatter.string(from: Date()),
            athlete: athlete,
            performanceMetrics: metricsData,
            arcadePhysics: arcadeData,
            gameModes: gameModes,
            comboSystem: comboSystem,
            timeScaleConfig: timeScale,
            ddaConfig: ddaExport,
            animationManifest: UnityExportManifest.AnimationManifest(
                dunkAnimations: dunkAnims,
                combatAnimations: combatAnims,
                generalAnimations: generalAnims
            )
        )
    }

    static func exportJSON(profile: UserProfile, metrics: PerformanceMetrics, arcade: ArcadePhysics, audit: BiomechanicsAudit?) -> String? {
        let manifest = build(profile: profile, metrics: metrics, arcade: arcade, audit: audit)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(manifest) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
