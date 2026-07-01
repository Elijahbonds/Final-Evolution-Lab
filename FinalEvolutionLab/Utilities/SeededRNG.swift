import Foundation

/// Deterministic RNG for replayable gameplay (dunk judges, AI sim, etc.).
nonisolated struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform double in [`low`, `high`], inclusive-ish on lower bound.
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        let u = Double(next() % 1_000_000) / 999_999.0
        return range.lowerBound + span * u
    }
}

nonisolated enum GameplaySeed {
    static func uint64(from uuid: UUID) -> UInt64 {
        let u = uuid.uuid
        return UInt64(u.0) << 56
            | UInt64(u.1) << 48
            | UInt64(u.2) << 40
            | UInt64(u.3) << 32
            | UInt64(u.4) << 24
            | UInt64(u.5) << 16
            | UInt64(u.6) << 8
            | UInt64(u.7)
    }

    /// Named AI dunk profile for deterministic solo opponent scores (GAME-28).
    static func aiDunkProfileSeed(matchSeed: UInt64, round: Int) -> UInt64 {
        matchSeed &+ 0xD06E15A10001 &+ UInt64(UInt32(bitPattern: Int32(round)))
    }
}
