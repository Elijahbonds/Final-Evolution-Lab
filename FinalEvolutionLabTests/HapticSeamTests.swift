import Foundation
import Testing
@testable import FinalEvolutionLab

/// Dev-harness seam: gameplay haptic cues are capturable as an ordered event
/// stream (for the session timeline) without a physical Taptic Engine.
@MainActor
struct HapticSeamTests {

    private func record(_ body: () -> Void) -> [HapticEvent] {
        let sink = RecordingHapticSink()
        FELHaptics.setSink(sink)
        defer { FELHaptics.resetSink() }
        body()
        return sink.events
    }

    @Test func dunkApexMapsCriticalToDistinctCue() {
        let events = record {
            FELHaptics.dunkApex(isCritical: false)
            FELHaptics.dunkApex(isCritical: true)
        }
        #expect(events == [.dunkApex, .dunkApexCritical])
    }

    @Test func sessionEndBranchesWinLossDraw() {
        #expect(record { FELHaptics.sessionEnd(won: true) } == [.sessionWin])
        #expect(record { FELHaptics.sessionEnd(won: false) } == [.sessionLoss])
        #expect(record { FELHaptics.sessionEnd(won: false, isDraw: true) } == [.sessionDraw])
    }

    @Test func cueStreamPreservesOrder() {
        let events = record {
            FELHaptics.modeSelect()
            FELHaptics.dunkChargeRelease()
            FELHaptics.actionSuccess(isCritical: true)
            FELHaptics.actionFail()
        }
        #expect(events == [.modeSelect, .dunkChargeRelease, .actionSuccessCritical, .actionFail])
    }

    @Test func eventsRoundTripThroughJSON() throws {
        let stream: [HapticEvent] = [.dunkApex, .sessionWin, .modeSelect]
        let data = try JSONEncoder().encode(stream)
        #expect(try JSONDecoder().decode([HapticEvent].self, from: data) == stream)
    }
}
