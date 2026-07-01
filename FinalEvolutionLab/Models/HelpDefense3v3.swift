import Foundation

nonisolated enum RotationScheme: String, Sendable, CaseIterable {
    case packLine = "Pack Line"
    case helpAndRecover = "Help and Recover"
    case switching = "Switching"
    case matchup = "Matchup Zone"

    var description: String {
        switch self {
        case .packLine: return "Deny dribble penetration; defenders deny passing lanes"
        case .helpAndRecover: return "Sag into lane, recover to shooter on kick-out"
        case .switching: return "Switch all screens; maintain matchups by athleticism"
        case .matchup: return "Zone principles with man-to-man assignments"
        }
    }
}

// CGRect equivalent for pure Swift (no UIKit import)
nonisolated struct CoverageZone: Sendable, Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    func contains(pointX: Double, pointY: Double) -> Bool {
        pointX >= x && pointX <= (x + width) &&
        pointY >= y && pointY <= (y + height)
    }

    static let fullCourt = CoverageZone(x: 0, y: 0, width: 94, height: 50)
    static let paint = CoverageZone(x: 0, y: 17, width: 19, height: 16)
    static let threePointLine = CoverageZone(x: 0, y: 0, width: 47, height: 50)
}

nonisolated struct Defender: Sendable, Identifiable {
    let id: UUID
    let playerId: String
    var coverageZone: CoverageZone
    var coverageScore: Double  // 0-100

    init(playerId: String, coverageZone: CoverageZone, coverageScore: Double = 75.0) {
        self.id = UUID()
        self.playerId = playerId
        self.coverageZone = coverageZone
        self.coverageScore = max(0, min(100, coverageScore))
    }
}

nonisolated struct DefensiveSet: Sendable {
    let scheme: RotationScheme
    let defenders: [Defender]  // Must be exactly 3 for 3v3

    init(scheme: RotationScheme, defenders: [Defender]) {
        self.scheme = scheme
        self.defenders = defenders
    }

    var averageCoverageScore: Double {
        guard !defenders.isEmpty else { return 0 }
        return defenders.reduce(0) { $0 + $1.coverageScore } / Double(defenders.count)
    }

    var weakestDefender: Defender? {
        defenders.min { $0.coverageScore < $1.coverageScore }
    }
}

nonisolated struct Player3v3Position: Sendable {
    let id: String
    let position: SIMD3<Double>
    let isOffense: Bool
    let assignedDefenderId: String?
}

nonisolated enum ShadingDirection: String, Sendable {
    case baseline
    case middle
}

nonisolated struct HelpDefense3v3: Sendable {

    struct CloseoutResult: Sendable {
        let helperId: String
        let recoverToOffenseId: String
    }

    static func xCloseout(
        players: [Player3v3Position],
        ballHandlerId: String,
        defenderIds: [String]
    ) -> CloseoutResult? {
        guard let ballHandler = players.first(where: { $0.id == ballHandlerId && $0.isOffense }) else { return nil }

        let defense = players.filter { !$0.isOffense && defenderIds.contains($0.id) }
        let assignedToBall = defense.first { $0.assignedDefenderId == ballHandlerId }
        guard let beaten = assignedToBall else { return nil }

        let offBall = defense.filter { $0.id != beaten.id }
        guard !offBall.isEmpty else { return nil }

        let ballPos = ballHandler.position
        var nearestId: String?
        var nearestDistSq: Double = .greatestFiniteMagnitude
        for d in offBall {
            let dx = ballPos.x - d.position.x
            let dz = ballPos.z - d.position.z
            let distSq = dx * dx + dz * dz
            if distSq < nearestDistSq {
                nearestDistSq = distSq
                nearestId = d.id
            }
        }
        guard let helperId = nearestId else { return nil }

        let openOffense = players.filter { $0.isOffense && $0.id != ballHandlerId }
        var recoverToId: String = ""
        var minDist: Double = .greatestFiniteMagnitude
        for o in openOffense {
            let dx = beaten.position.x - o.position.x
            let dz = beaten.position.z - o.position.z
            let d = dx * dx + dz * dz
            if d < minDist {
                minDist = d
                recoverToId = o.id
            }
        }

        return CloseoutResult(helperId: helperId, recoverToOffenseId: recoverToId)
    }

    static func shadingDirection(
        ballPosXZ: SIMD2<Double>,
        hoopPosXZ: SIMD2<Double>,
        preference: ShadingDirection
    ) -> ShadingDirection {
        preference
    }

    static func switchTarget(
        players: [Player3v3Position],
        screenerId: String,
        ballHandlerId: String,
        myDefenderId: String
    ) -> String? {
        guard players.contains(where: { $0.id == screenerId && $0.isOffense }) else { return nil }
        return screenerId
    }
}
