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

        // Proxy joint angles (replace with DeepMotion skeletal degrees when wired).
        let rawAnkle = 22 + (prq - 65) * 0.12 + (flight - 0.5) * 8
        let rawKnee = 37 + (vertical - 26) * 0.35
        let rawHip = 172 - max(0, vertical - 24) * 0.55

        var ka = FELKalmanFilter1D()
        var kk = FELKalmanFilter1D()
        var kh = FELKalmanFilter1D()
        let ankleDeg = ka.update(measurement: rawAnkle)
        let kneeDeg = kk.update(measurement: rawKnee)
        let hipDeg = kh.update(measurement: rawHip)

        let ankleSt = FELJointAngleThresholds.statusAnkleDorsiflexion(measurement: ankleDeg)
        let kneeSt = FELJointAngleThresholds.statusKneeFlexion(measurement: kneeDeg)
        let hipSt = FELJointAngleThresholds.statusHipExtension(measurement: hipDeg)

        let ankleScore = min(100, max(0, 100 - abs(ankleDeg - 23) * 4))
        let kneeScore = min(100, max(0, 100 - abs(kneeDeg - 37) * 3))
        let hipScore = min(100, max(0, 100 - abs(hipDeg - 172) * 2))

        var leakageZones: [LeakageZone] = []
        if ankleSt != JointStatus.optimal {
            leakageZones.append(LeakageZone(joint: .ankle, severity: ankleSt == JointStatus.moderate ? 0.35 : 0.65, description: "Ankle dorsiflexion outside optimal window — check stiffness / load"))
        }
        if kneeSt != JointStatus.optimal {
            leakageZones.append(LeakageZone(joint: .knee, severity: kneeSt == JointStatus.moderate ? 0.3 : 0.6, description: "Knee flexion at takeoff outside optimal band"))
        }
        if hipSt != JointStatus.optimal {
            leakageZones.append(LeakageZone(joint: .hip, severity: hipSt == JointStatus.moderate ? 0.32 : 0.62, description: "Hip extension angle suggests power leakage vs PRIMED"))
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
            ankleDorsiflexion: JointScore(value: ankleScore, status: ankleSt, flexionDegrees: ankleDeg),
            kneeTracking: JointScore(value: kneeScore, status: kneeSt, flexionDegrees: kneeDeg),
            hipExtension: JointScore(value: hipScore, status: hipSt, flexionDegrees: hipDeg),
            kineticLeakageZones: leakageZones,
            overallGrade: grade,
            auditDate: scan.date
        )
    }

    static let empty = BiomechanicsAudit(
        ankleDorsiflexion: JointScore(value: 0, status: .deficit, flexionDegrees: nil),
        kneeTracking: JointScore(value: 0, status: .deficit, flexionDegrees: nil),
        hipExtension: JointScore(value: 0, status: .deficit, flexionDegrees: nil),
        kineticLeakageZones: [],
        overallGrade: .foundation,
        auditDate: Date()
    )
}

nonisolated struct JointScore: Codable, Sendable {
    let value: Double
    let status: JointStatus
    /// Flexion / extension angle (degrees) when pose pipeline (e.g. DeepMotion) or scan proxy provides it.
    var flexionDegrees: Double?

    init(value: Double, status: JointStatus, flexionDegrees: Double? = nil) {
        self.value = value
        self.status = status
        self.flexionDegrees = flexionDegrees
    }
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
