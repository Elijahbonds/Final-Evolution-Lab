import Foundation

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
