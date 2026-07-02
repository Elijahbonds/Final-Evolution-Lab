import Foundation

/// NEXUS app-layer economy rules — shards and ranked PRQ are **server-authoritative**.
///
/// - **IAP (Intra-Abdominal Pressure):** breath metrics from ``ThreadSafeFitnessData`` / NEXUS fitness
///   commands are fail-closed: invalid or non-finite samples are rejected and never mutate gameplay power.
/// - **Shards / PRQ:** local gameplay may show *candidates* in HUD; only ``GameSessionTrustLevel/serverVerified``
///   receipts (``POST /api/games/session`` 2xx via ``SessionReceiptUploadService``) may mutate ranked balance.
enum NexusEconomyAuthority {
    /// NEXUS P0/P1 modes where C++ is score authority and economy grants require server receipt.
    static func usesServerAuthoritativeEconomy(modeId: GameModeId) -> Bool {
        switch modeId {
        case .basketballDunkContestIRL, .basketballDunkContest3D, .karateEndless:
            return true
        default:
            return false
        }
    }

    /// Whether local finalize may apply shard/PRQ deltas before a verified receipt arrives.
    static func allowsLocalEconomyGrant(modeId: GameModeId, trustLevel: GameSessionTrustLevel) -> Bool {
        if usesServerAuthoritativeEconomy(modeId: modeId) {
            return trustLevel == .serverVerified
        }
        return trustLevel == .serverVerified
            || (trustLevel == .localPractice && _isDebugBuild)
    }

    /// Fail-closed IAP breath gate — both engagement and confidence must be finite and in [0, 1].
    static func acceptsIAPSample(engagement: Double, confidence: Double) -> Bool {
        guard engagement.isFinite, confidence.isFinite else { return false }
        return (0...1).contains(engagement) && (0...1).contains(confidence)
    }

    private static var _isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
