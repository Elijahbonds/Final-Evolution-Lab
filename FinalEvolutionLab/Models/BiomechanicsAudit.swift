import Foundation

struct BiomechanicsAudit: Codable, Sendable {
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
        let screenComposite = scan.movementScreening?
            .screenResults
            .map(\.percent)
            .reduce(0.0, +) ?? 0
        let screenCount = scan.movementScreening?.screenResults.count ?? 0
        let avgScreenPercent = screenCount > 0 ? (screenComposite / Double(screenCount)) : min(1.0, prq / 100.0)
        let dysfunctionPenalty = (scan.movementScreening?.dysfunctions.count ?? 0) > 0
            ? min(0.25, Double(scan.movementScreening?.dysfunctions.count ?? 0) * 0.06)
            : 0

        let ankleBase = (prq * 0.55 + flight * 30 + avgScreenPercent * 30) * (1.0 - dysfunctionPenalty)
        let kneeBase = (prq * 0.6 + vertical * 0.35 + avgScreenPercent * 28) * (1.0 - dysfunctionPenalty * 0.9)
        let hipBase = (prq * 0.5 + vertical * 0.55 + avgScreenPercent * 25) * (1.0 - dysfunctionPenalty * 0.85)
        let ankleScore: Double = min(100, ankleBase)
        let kneeScore: Double = min(100, kneeBase)
        let hipScore: Double = min(100, hipBase)

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

        let gradeInput = (prq * 0.7) + (avgScreenPercent * 100 * 0.3) - dysfunctionPenalty * 25
        let grade: BiomechanicsGrade
        switch gradeInput {
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

struct JointScore: Codable, Sendable {
    let value: Double
    let status: JointStatus
}

enum JointStatus: String, Codable, Sendable {
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

enum JointType: String, Codable, Sendable, CaseIterable {
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

struct LeakageZone: Codable, Sendable, Identifiable {
    var id: String { "\(joint.rawValue)_\(severity)" }
    let joint: JointType
    let severity: Double
    let description: String
}

enum BiomechanicsGrade: String, Codable, Sendable {
    case elite = "ELITE"
    case primed = "PRIMED"
    case developing = "DEVELOPING"
    case foundation = "FOUNDATION"
}
