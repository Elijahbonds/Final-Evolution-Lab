import Foundation

nonisolated struct BiomechanicsAudit: Codable, Sendable {
    var ankleDorsiflexion: JointScore
    var kneeTracking: JointScore
    var hipExtension: JointScore
    var kineticLeakageZones: [LeakageZone]
    var overallGrade: BiomechanicsGrade
    var auditDate: Date

    var leakagePercentage: Double {
        guard !kineticLeakageZones.isEmpty else { return 0 }
        let total = kineticLeakageZones.reduce(0.0) { $0 + $1.severity }
        return min(100, total / Double(kineticLeakageZones.count) * 100)
    }

    var isPrimed: Bool {
        overallGrade == .elite || overallGrade == .primed
    }

    static func fromScanResult(_ scan: SystemScanResult) -> BiomechanicsAudit {
        let prq = scan.prqScore
        let vertical = scan.verticalEstimateInches
        let flight = scan.flightTimeSeconds

        let ankleScore: Double = min(100, prq * 0.8 + flight * 40)
        let kneeScore: Double = min(100, prq * 0.9 + vertical * 0.5)
        let hipScore: Double = min(100, prq * 0.7 + vertical * 0.8)

        var leakageZones: [LeakageZone] = []
        if ankleScore < 60 {
            leakageZones.append(LeakageZone(joint: .ankle, severity: (60 - ankleScore) / 60, description: "Ankle stiffness deficit — reduced ground contact efficiency"))
        }
        if kneeScore < 65 {
            leakageZones.append(LeakageZone(joint: .knee, severity: (65 - kneeScore) / 65, description: "Knee valgus detected during load phase"))
        }
        if hipScore < 55 {
            leakageZones.append(LeakageZone(joint: .hip, severity: (55 - hipScore) / 55, description: "Hip extension power below optimal threshold"))
        }
        if flight < 0.5 {
            leakageZones.append(LeakageZone(joint: .ankle, severity: 0.4, description: "Short flight time — reactive strength needs development"))
        }

        let grade: BiomechanicsGrade
        switch prq {
        case 80...: grade = .elite
        case 65..<80: grade = .primed
        case 50..<65: grade = .developing
        default: grade = .foundation
        }

        return BiomechanicsAudit(
            ankleDorsiflexion: JointScore(value: ankleScore, status: ankleScore >= 70 ? .optimal : (ankleScore >= 50 ? .moderate : .deficit)),
            kneeTracking: JointScore(value: kneeScore, status: kneeScore >= 70 ? .optimal : (kneeScore >= 50 ? .moderate : .deficit)),
            hipExtension: JointScore(value: hipScore, status: hipScore >= 70 ? .optimal : (hipScore >= 50 ? .moderate : .deficit)),
            kineticLeakageZones: leakageZones,
            overallGrade: grade,
            auditDate: scan.date
        )
    }

    static let empty = BiomechanicsAudit(
        ankleDorsiflexion: JointScore(value: 0, status: .deficit),
        kneeTracking: JointScore(value: 0, status: .deficit),
        hipExtension: JointScore(value: 0, status: .deficit),
        kineticLeakageZones: [],
        overallGrade: .foundation,
        auditDate: Date()
    )
}

nonisolated struct JointScore: Codable, Sendable {
    let value: Double
    let status: JointStatus
}

nonisolated enum JointStatus: String, Codable, Sendable {
    case optimal
    case moderate
    case deficit

    var label: String {
        switch self {
        case .optimal: "PRIMED"
        case .moderate: "MODERATE"
        case .deficit: "LEAKING"
        }
    }
}

nonisolated enum JointType: String, Codable, Sendable, CaseIterable {
    case ankle
    case knee
    case hip

    var displayName: String {
        switch self {
        case .ankle: "Ankle"
        case .knee: "Knee"
        case .hip: "Hip"
        }
    }

    var systemImage: String {
        switch self {
        case .ankle: "figure.walk"
        case .knee: "figure.run"
        case .hip: "figure.flexibility"
        }
    }
}

nonisolated struct LeakageZone: Codable, Sendable, Identifiable {
    var id: String { "\(joint.rawValue)_\(severity)" }
    let joint: JointType
    let severity: Double
    let description: String
}

nonisolated enum BiomechanicsGrade: String, Codable, Sendable {
    case elite = "ELITE"
    case primed = "PRIMED"
    case developing = "DEVELOPING"
    case foundation = "FOUNDATION"
}

nonisolated struct MovementEfficiencyScore: Sendable {
    let kneeTracking: Double      // 0-100
    let hipAlignment: Double      // 0-100
    let coreEngagement: Double    // 0-100
    let shoulderPosition: Double  // 0-100
    let ankleStability: Double    // 0-100
    let headPosition: Double      // 0-100

    init(kneeTracking: Double, hipAlignment: Double, coreEngagement: Double,
         shoulderPosition: Double, ankleStability: Double, headPosition: Double) {
        self.kneeTracking = max(0, min(100, kneeTracking))
        self.hipAlignment = max(0, min(100, hipAlignment))
        self.coreEngagement = max(0, min(100, coreEngagement))
        self.shoulderPosition = max(0, min(100, shoulderPosition))
        self.ankleStability = max(0, min(100, ankleStability))
        self.headPosition = max(0, min(100, headPosition))
    }

    var overallEfficiency: Double {
        (kneeTracking + hipAlignment + coreEngagement + shoulderPosition + ankleStability + headPosition) / 6.0
    }

    static let perfect = MovementEfficiencyScore(
        kneeTracking: 100, hipAlignment: 100, coreEngagement: 100,
        shoulderPosition: 100, ankleStability: 100, headPosition: 100
    )
}
