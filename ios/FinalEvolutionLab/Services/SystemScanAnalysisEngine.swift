import AVFoundation
import Foundation

enum SystemScanAnalysisEngine {
    static func analyze(videoURL: URL?, sport: String?, goal: String?) async -> SystemScanResult {
        let stress = await captureStressTest(from: videoURL)
        let movement = deriveMovementSample(stress: stress, sport: sport, goal: goal)
        let screens = buildScreens(movement: movement, stress: stress)
        let dysfunctions = inferDysfunctions(screens: screens, movement: movement, stress: stress)
        let prescription = buildPrescription(
            screens: screens,
            dysfunctions: dysfunctions,
            movement: movement,
            stress: stress
        )

        let composite = compositeScore(screens: screens, movement: movement, stress: stress)
        let prq = PRQ.clamp(composite)
        let vertical = estimateVertical(prq: prq, movement: movement, stress: stress)
        let flight = estimateFlightTime(verticalInches: vertical)
        let movementGrade = gradeLabel(forPRQ: prq)
        let notes = composeNotes(
            dysfunctions: dysfunctions,
            prescription: prescription,
            stress: stress,
            sport: sport
        )
        let avatarConfig = AvatarSkinConfig.fromScan(
            prq: prq,
            vertical: vertical,
            flight: flight,
            sport: sport
        )

        let report = MovementScreeningReport(
            stressTest: stress,
            movementCapture: movement,
            screenResults: screens,
            dysfunctions: dysfunctions,
            prescription: prescription,
            confidence: screeningConfidence(stress: stress, screens: screens)
        )

        return SystemScanResult(
            id: UUID().uuidString,
            date: Date(),
            prqScore: prq,
            verticalEstimateInches: vertical,
            flightTimeSeconds: flight,
            movementGrade: movementGrade,
            notes: notes,
            recommendedTrack: prescription.trainingTrack.rawValue,
            avatarConfig: avatarConfig,
            movementScreening: report
        )
    }

    private static func captureStressTest(from videoURL: URL?) async -> StressTestCapture {
        guard let videoURL else {
            return StressTestCapture(
                clipDurationSeconds: 9.0,
                frameRate: 30,
                estimatedRepCount: 4,
                burstRatePerMinute: 26.6,
                fatigueIndex: 0.45,
                asymmetryIndex: 0.32,
                landingStability: 0.55,
                effortIndex: 0.62
            )
        }

        let asset = AVURLAsset(url: videoURL)
        let duration = max(2.0, (try? await asset.load(.duration).seconds) ?? 9.0)
        let tracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
        let primaryTrack = tracks.first
        let frameRate = max(24.0, min(120.0, Double(primaryTrack?.nominalFrameRate ?? 30)))
        let estimatedReps = max(1, Int(duration / 2.0))
        let burstRate = min(120.0, (Double(estimatedReps) / duration) * 60.0)
        let fatigue = max(0.15, min(0.95, (duration / 22.0) + (burstRate / 140.0)))
        let asymmetry = max(0.05, min(0.9, abs(0.5 - (burstRate / 120.0)) * 0.8))
        let landingStability = max(0.2, min(0.95, 1.0 - fatigue * 0.45 - asymmetry * 0.35))
        let effort = max(0.25, min(1.0, (burstRate / 90.0) * 0.7 + (duration / 18.0) * 0.3))

        return StressTestCapture(
            clipDurationSeconds: duration,
            frameRate: frameRate,
            estimatedRepCount: estimatedReps,
            burstRatePerMinute: burstRate,
            fatigueIndex: fatigue,
            asymmetryIndex: asymmetry,
            landingStability: landingStability,
            effortIndex: effort
        )
    }

    private static func deriveMovementSample(stress: StressTestCapture, sport: String?, goal: String?) -> MovementCaptureSample {
        let sportBias = sportBiasMultiplier(sport: sport)
        let goalBias = goalBiasMultiplier(goal: goal)

        let ankle = normalized(
            base: 0.55 + (stress.landingStability * 0.35) - (stress.asymmetryIndex * 0.2),
            scale: sportBias.ankle
        )
        let knee = normalized(
            base: 0.58 + (stress.landingStability * 0.3) - (stress.fatigueIndex * 0.2),
            scale: sportBias.knee
        )
        let hip = normalized(
            base: 0.6 + (stress.effortIndex * 0.25) - (stress.fatigueIndex * 0.15),
            scale: goalBias.hip
        )
        let trunk = normalized(
            base: 0.56 + (stress.effortIndex * 0.2) - (stress.asymmetryIndex * 0.2),
            scale: goalBias.trunk
        )
        let decel = normalized(
            base: 0.52 + (stress.landingStability * 0.3) - (stress.fatigueIndex * 0.25),
            scale: sportBias.deceleration
        )
        let mobility = normalized(
            base: 0.5 + (stress.frameRate / 120.0) * 0.15 + (stress.clipDurationSeconds / 20.0) * 0.1 - stress.fatigueIndex * 0.1,
            scale: goalBias.mobility
        )

        return MovementCaptureSample(
            ankleControl: ankle,
            kneeControl: knee,
            hipControl: hip,
            trunkControl: trunk,
            decelerationControl: decel,
            mobilityBandwidth: mobility
        )
    }

    private static func buildScreens(movement: MovementCaptureSample, stress: StressTestCapture) -> [MovementScreenResult] {
        let fmsItems: [MovementScreenItem] = [
            threePointItem("fms_deep_squat", "Deep Squat", 0.45 * movement.mobilityBandwidth + 0.55 * movement.hipControl),
            threePointItem("fms_hurdle_step", "Hurdle Step", 0.55 * movement.kneeControl + 0.45 * movement.ankleControl),
            threePointItem("fms_inline_lunge", "Inline Lunge", 0.45 * movement.trunkControl + 0.55 * movement.hipControl),
            threePointItem("fms_shoulder_mobility", "Shoulder Mobility", 0.65 * movement.mobilityBandwidth + 0.35 * movement.trunkControl),
            threePointItem("fms_aslr", "Active Straight Leg Raise", 0.6 * movement.mobilityBandwidth + 0.4 * movement.hipControl),
            threePointItem("fms_trunk_stability", "Trunk Stability Push-Up", 0.75 * movement.trunkControl + 0.25 * movement.decelerationControl),
            threePointItem("fms_rotary_stability", "Rotary Stability", 0.5 * movement.trunkControl + 0.5 * (1.0 - stress.asymmetryIndex))
        ]

        let sfmaItems: [MovementScreenItem] = [
            threePointItem("sfma_ms_flex", "Multi-Segment Flexion", 0.7 * movement.mobilityBandwidth + 0.3 * movement.hipControl),
            threePointItem("sfma_ms_ext", "Multi-Segment Extension", 0.6 * movement.mobilityBandwidth + 0.4 * movement.trunkControl),
            threePointItem("sfma_rot", "Multi-Segment Rotation", 0.55 * movement.trunkControl + 0.45 * movement.mobilityBandwidth),
            threePointItem("sfma_single_leg", "Single Leg Stance", 0.6 * movement.ankleControl + 0.4 * movement.decelerationControl),
            threePointItem("sfma_overhead_squat", "Overhead Squat Pattern", 0.5 * movement.hipControl + 0.5 * movement.trunkControl)
        ]

        let fcsItems: [MovementScreenItem] = [
            threePointItem("fcs_tripod", "Foot Tripod Control", 0.75 * movement.ankleControl + 0.25 * movement.decelerationControl),
            threePointItem("fcs_bracing", "Core Bracing", 0.8 * movement.trunkControl + 0.2 * (1.0 - stress.fatigueIndex)),
            threePointItem("fcs_hip_hinge", "Hip Hinge Pattern", 0.7 * movement.hipControl + 0.3 * movement.mobilityBandwidth),
            threePointItem("fcs_decel", "Deceleration Capacity", 0.7 * movement.decelerationControl + 0.3 * movement.kneeControl)
        ]

        let frcItems: [MovementScreenItem] = [
            threePointItem("frc_ankle_car", "Ankle CARs", 0.75 * movement.mobilityBandwidth + 0.25 * movement.ankleControl),
            threePointItem("frc_hip_car", "Hip CARs", 0.7 * movement.mobilityBandwidth + 0.3 * movement.hipControl),
            threePointItem("frc_tspine_car", "T-Spine CARs", 0.8 * movement.mobilityBandwidth + 0.2 * movement.trunkControl),
            threePointItem("frc_control", "End-Range Control", 0.55 * movement.trunkControl + 0.45 * movement.hipControl)
        ]

        return [
            screenResult(kind: .fms, items: fmsItems),
            screenResult(kind: .sfma, items: sfmaItems),
            screenResult(kind: .fcs, items: fcsItems),
            screenResult(kind: .frc, items: frcItems)
        ]
    }

    private static func inferDysfunctions(
        screens: [MovementScreenResult],
        movement: MovementCaptureSample,
        stress: StressTestCapture
    ) -> [MovementDysfunction] {
        var issues: [MovementDysfunction] = []
        let fmsPercent = screens.first(where: { $0.kind == .fms })?.percent ?? 0
        let sfmaPercent = screens.first(where: { $0.kind == .sfma })?.percent ?? 0
        let fcsPercent = screens.first(where: { $0.kind == .fcs })?.percent ?? 0
        let frcPercent = screens.first(where: { $0.kind == .frc })?.percent ?? 0

        if movement.ankleControl < 0.58 || frcPercent < 0.62 {
            issues.append(
                MovementDysfunction(
                    id: "dys_ankle_mobility",
                    title: "Ankle Mobility Restriction",
                    severity: severity(for: 1.0 - movement.ankleControl),
                    confidence: min(0.95, 0.6 + (1.0 - movement.ankleControl) * 0.3),
                    sourceScreens: [.fms, .frc],
                    clinicalSummary: "Limited dorsiflexion and end-range ankle control are reducing landing efficiency.",
                    correctiveFocus: ["FRC ankle CARs", "Foot tripod loading", "Slow eccentrics for deceleration"]
                )
            )
        }

        if stress.asymmetryIndex > 0.38 || sfmaPercent < 0.6 {
            issues.append(
                MovementDysfunction(
                    id: "dys_lateral_asymmetry",
                    title: "Lateral Asymmetry",
                    severity: severity(for: stress.asymmetryIndex),
                    confidence: min(0.92, 0.55 + stress.asymmetryIndex * 0.5),
                    sourceScreens: [.sfma, .fcs],
                    clinicalSummary: "Single-leg control differs side-to-side and likely impacts force transfer consistency.",
                    correctiveFocus: ["Single-leg stance progressions", "Split stance rotations", "Unilateral landing drills"]
                )
            )
        }

        if movement.trunkControl < 0.6 || fmsPercent < 0.58 {
            issues.append(
                MovementDysfunction(
                    id: "dys_trunk_stability",
                    title: "Trunk Stability Deficit",
                    severity: severity(for: 1.0 - movement.trunkControl),
                    confidence: min(0.9, 0.58 + (1.0 - movement.trunkControl) * 0.35),
                    sourceScreens: [.fms, .fcs],
                    clinicalSummary: "Core stiffness under load is inconsistent, increasing leakage through hip-knee-ankle chain.",
                    correctiveFocus: ["Anti-rotation core work", "Bracing patterns", "Tempo hinge + trunk lock"]
                )
            )
        }

        if stress.fatigueIndex > 0.62 {
            issues.append(
                MovementDysfunction(
                    id: "dys_capacity_fatigue",
                    title: "Capacity/Fatigue Drop-Off",
                    severity: severity(for: stress.fatigueIndex),
                    confidence: min(0.9, 0.5 + stress.fatigueIndex * 0.4),
                    sourceScreens: [.fcs, .sfma],
                    clinicalSummary: "Output and landing quality degrade under stress-test volume.",
                    correctiveFocus: ["Submax volume progression", "Aerobic recovery blocks", "Decel skill under fatigue"]
                )
            )
        }

        return issues
    }

    private static func buildPrescription(
        screens: [MovementScreenResult],
        dysfunctions: [MovementDysfunction],
        movement: MovementCaptureSample,
        stress: StressTestCapture
    ) -> WorkoutPrescription {
        let severeCount = dysfunctions.filter { $0.severity == .severe }.count
        let moderateCount = dysfunctions.filter { $0.severity == .moderate }.count
        let avgPercent = screens.map(\.percent).reduce(0, +) / Double(max(1, screens.count))

        if severeCount > 0 || avgPercent < 0.58 {
            return WorkoutPrescription(
                trainingTrack: .foundations,
                equipmentFocus: .movementEducation,
                rationale: "Movement screen risk is elevated. Prioritize control, mobility restoration, and movement literacy.",
                priorityBlocks: ["FRC mobility", "FMS corrective patterns", "Tripod + decel control"]
            )
        }

        if moderateCount >= 2 || stress.fatigueIndex > 0.58 {
            return WorkoutPrescription(
                trainingTrack: .flight,
                equipmentFocus: .movementEducation,
                rationale: "Movement quality is workable but constrained under stress. Build resilience before max-intent loading.",
                priorityBlocks: ["SFMA pattern corrections", "Unilateral force transfer", "Progressive plyometric tolerance"]
            )
        }

        if movement.decelerationControl > 0.7 && movement.hipControl > 0.72 && stress.effortIndex > 0.7 {
            return WorkoutPrescription(
                trainingTrack: .elite,
                equipmentFocus: .bodyweight,
                rationale: "Screen quality and stress resilience support high-intent training progression.",
                priorityBlocks: ["Reactive plyometrics", "Max intent jump exposures", "High-speed force expression"]
            )
        }

        return WorkoutPrescription(
            trainingTrack: .flight,
            equipmentFocus: .bodyweight,
            rationale: "Intermediate profile with stable base. Progress power while maintaining screen quality.",
            priorityBlocks: ["Plyometric progression", "Hip/trunk power transfer", "Landing consistency"]
        )
    }

    private static func composeNotes(
        dysfunctions: [MovementDysfunction],
        prescription: WorkoutPrescription,
        stress: StressTestCapture,
        sport: String?
    ) -> [String] {
        var notes: [String] = []
        notes.append(
            String(
                format: "Stress test: %.1fs clip, %.0f fps, %d reps, fatigue %.0f%%.",
                stress.clipDurationSeconds,
                stress.frameRate,
                stress.estimatedRepCount,
                stress.fatigueIndex * 100
            )
        )
        if dysfunctions.isEmpty {
            notes.append("Movement screens passed with low dysfunction risk across FMS/SFMA/FCS/FRC.")
        } else {
            for issue in dysfunctions.prefix(3) {
                notes.append("\(issue.title): \(issue.clinicalSummary)")
            }
        }
        notes.append("Prescription: \(prescription.trainingTrack.rawValue) + \(prescription.equipmentFocus.rawValue).")
        if let sport, !sport.isEmpty {
            notes.append("\(sport)-specific progression cues applied to this path.")
        }
        return notes
    }

    private static func compositeScore(
        screens: [MovementScreenResult],
        movement: MovementCaptureSample,
        stress: StressTestCapture
    ) -> Double {
        let screenComposite = screens.map(\.percent).reduce(0, +) / Double(max(1, screens.count))
        let movementComposite =
            movement.ankleControl * 0.16 +
            movement.kneeControl * 0.16 +
            movement.hipControl * 0.2 +
            movement.trunkControl * 0.2 +
            movement.decelerationControl * 0.14 +
            movement.mobilityBandwidth * 0.14
        let stressResilience = max(0.0, min(1.0, (1.0 - stress.fatigueIndex) * 0.65 + stress.effortIndex * 0.35))

        let weighted = screenComposite * 0.42 + movementComposite * 0.4 + stressResilience * 0.18
        return weighted * 100
    }

    private static func estimateVertical(prq: Double, movement: MovementCaptureSample, stress: StressTestCapture) -> Double {
        let powerFactor = (movement.hipControl + movement.decelerationControl) / 2.0
        let stressPenalty = stress.fatigueIndex * 3.0
        return max(16, min(44, 14 + (prq * 0.25) + (powerFactor * 9.0) - stressPenalty))
    }

    private static func estimateFlightTime(verticalInches: Double) -> Double {
        // Approximation around hang-time perception for demo/simulation.
        max(0.32, min(1.1, 0.26 + verticalInches * 0.0145))
    }

    private static func gradeLabel(forPRQ prq: Double) -> String {
        switch prq {
        case 85...: return "ELITE POTENTIAL"
        case 70..<85: return "FLIGHT READY"
        case 55..<70: return "DEVELOPING BASE"
        default: return "FOUNDATION PHASE"
        }
    }

    private static func screeningConfidence(stress: StressTestCapture, screens: [MovementScreenResult]) -> Double {
        let screenSpread = screens.map(\.percent).max() ?? 0 - (screens.map(\.percent).min() ?? 0)
        let sourceQuality = min(1.0, max(0.4, (stress.frameRate / 60.0) * 0.7 + (stress.clipDurationSeconds / 16.0) * 0.3))
        return min(0.95, max(0.45, sourceQuality - screenSpread * 0.15))
    }

    private static func threePointItem(_ id: String, _ title: String, _ normalizedInput: Double) -> MovementScreenItem {
        let clamped = max(0, min(1, normalizedInput))
        let score = (clamped * 3.0).rounded(toPlaces: 1)
        return MovementScreenItem(
            id: id,
            title: title,
            score: score,
            maxScore: 3.0,
            notes: score < 2.0 ? "Restricted pattern quality" : "Pattern within expected tolerance"
        )
    }

    private static func screenResult(kind: MovementScreenKind, items: [MovementScreenItem]) -> MovementScreenResult {
        let total = items.reduce(0.0) { $0 + $1.score }
        let max = items.reduce(0.0) { $0 + $1.maxScore }
        let percent = max > 0 ? total / max : 0
        let risk: MovementRiskBand
        switch percent {
        case 0.72...: risk = .low
        case 0.55..<0.72: risk = .moderate
        default: risk = .high
        }
        return MovementScreenResult(
            id: "screen_\(kind.rawValue.lowercased())",
            kind: kind,
            totalScore: total.rounded(toPlaces: 1),
            maxScore: max,
            riskBand: risk,
            items: items
        )
    }

    private static func severity(for normalizedRisk: Double) -> MovementDysfunctionSeverity {
        switch normalizedRisk {
        case 0.62...: return .severe
        case 0.38..<0.62: return .moderate
        default: return .mild
        }
    }

    private static func normalized(base: Double, scale: Double) -> Double {
        max(0.0, min(1.0, base * scale))
    }

    private static func sportBiasMultiplier(sport: String?) -> (ankle: Double, knee: Double, deceleration: Double) {
        switch (sport ?? "").lowercased() {
        case "basketball", "volleyball":
            return (1.0, 1.0, 1.0)
        case "football":
            return (0.95, 1.05, 1.08)
        case "soccer":
            return (1.05, 1.0, 1.03)
        case "gymnastics":
            return (1.12, 1.04, 0.95)
        default:
            return (1.0, 1.0, 1.0)
        }
    }

    private static func goalBiasMultiplier(goal: String?) -> (hip: Double, trunk: Double, mobility: Double) {
        switch (goal ?? "").lowercased() {
        case "jump higher":
            return (1.08, 1.0, 0.98)
        case "build power":
            return (1.06, 1.04, 0.96)
        case "get faster":
            return (1.0, 1.05, 1.0)
        default:
            return (1.0, 1.0, 1.0)
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
