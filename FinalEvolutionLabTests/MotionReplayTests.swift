import Foundation
import Testing
@testable import FinalEvolutionLab

/// Dev-harness seam: jump detection must be fully deterministic from a motion
/// trace — no hardware, no timing dependence (`realtime: false` delivers the
/// whole trace synchronously).
@MainActor
struct MotionReplayTests {

    private func detectJumps(flightTime: TimeInterval) -> [Double] {
        let service = HealthKitService()
        let trace = ReplayMotionProvider.syntheticJumpTrace(flightTime: flightTime)
        service.setMotionProvider(ReplayMotionProvider(samples: trace, realtime: false))
        var jumps: [Double] = []
        service.startJumpTracking { jumps.append($0) }
        service.stopJumpTracking()
        return jumps
    }

    @Test func syntheticHalfSecondFlightYieldsTwelveInches() {
        let jumps = detectJumps(flightTime: 0.5)
        #expect(jumps.count == 1)
        // h = g·t²/8 = 9.81 · 0.25 / 8 = 0.3066 m = 12.07 in
        #expect(abs((jumps.first ?? 0) - 12.07) < 0.15)
    }

    @Test func sameTraceIsDeterministicAcrossRuns() {
        let first = detectJumps(flightTime: 0.42)
        let second = detectJumps(flightTime: 0.42)
        #expect(first == second)
        #expect(first.count == 1)
    }

    @Test func tooShortFlightIsRejectedAsNoise() {
        // Flight < 0.15s guard: a bump or step must not register as a jump.
        let jumps = detectJumps(flightTime: 0.1)
        #expect(jumps.isEmpty)
    }

    @Test func traceRoundTripsThroughJSON() throws {
        let trace = ReplayMotionProvider.syntheticJumpTrace(flightTime: 0.5)
        let data = try JSONEncoder().encode(trace)
        let decoded = try JSONDecoder().decode([MotionSample].self, from: data)
        #expect(decoded == trace)
    }
}
