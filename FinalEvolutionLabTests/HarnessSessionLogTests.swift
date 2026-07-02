import Foundation
import Testing
@testable import FinalEvolutionLab

/// Dev-harness: the session log is the record/cut/inject/export surface. These
/// pin the editing operations that make clips into reproducible fixtures.
@MainActor
struct HarnessSessionLogTests {

    private func sampleLog(seed: UInt64 = 42) -> HarnessSessionLog {
        HarnessSessionLog(
            metadata: HarnessSessionMetadata(modeId: "basketball_dunk_3d", seed: seed,
                                             judgeOffsets: [-4, -3, -4]),
            motion: [.resting(at: 0.0), .freefall(at: 1.0), .impact(at: 1.5), .resting(at: 2.0)],
            poses: [.neutralStance(at: 0.5), .neutralStance(at: 1.8)],
            haptics: [HarnessHapticCue(timestamp: 1.5, event: .dunkApexCritical),
                      HarnessHapticCue(timestamp: 2.0, event: .sessionWin)],
            events: [HarnessGameEvent(timestamp: 1.5, type: "dunk_result", playerId: "p1", points: 48),
                     HarnessGameEvent(timestamp: 2.0, type: "match_end")]
        )
    }

    @Test func spanReflectsAllStreams() {
        let log = sampleLog()
        #expect(log.startTime == 0.0)
        #expect(log.endTime == 2.0)
        #expect(log.duration == 2.0)
    }

    @Test func trimKeepsOnlyWindowedItemsAndMetadata() {
        // Highlight just the dunk apex → landing (1.4–1.7s).
        let clip = sampleLog().trimmed(from: 1.4, to: 1.7)
        #expect(clip.motion == [.impact(at: 1.5)])
        #expect(clip.haptics.map(\.event) == [.dunkApexCritical])
        #expect(clip.events.map(\.type) == ["dunk_result"])
        // Seed/offsets survive the cut so the clip still reproduces.
        #expect(clip.metadata.seed == 42)
        #expect(clip.metadata.judgeOffsets == [-4, -3, -4])
    }

    @Test func timeShiftNormalizesClipToZero() {
        let clip = sampleLog().trimmed(from: 1.4, to: 2.0).timeShiftedToZero()
        #expect(clip.startTime == 0.0)
        // dunk_result was at 1.5, shifted by -1.5.
        #expect(clip.events.first?.timestamp == 0.0)
    }

    @Test func spliceStitchesTwoClipsSequentially() {
        let a = sampleLog().trimmed(from: 1.4, to: 2.0).timeShiftedToZero() // 0.6s
        let b = sampleLog(seed: 99).trimmed(from: 0.0, to: 1.0).timeShiftedToZero()
        let reel = a.spliced(with: b, gap: 0.5)
        // b's first event starts after a ends + gap; timeline stays ordered.
        #expect(reel.startTime == 0.0)
        #expect(reel.duration >= a.duration + b.duration)
        let ts = reel.events.map(\.timestamp)
        #expect(ts == ts.sorted())
        // Reel keeps the first clip's seed (one seed per reel).
        #expect(reel.metadata.seed == 42)
    }

    @Test func injectOverridesSeedAndOffsetsOnly() {
        let original = sampleLog()
        let variant = original.injecting(seed: 7, judgeOffsets: [0, 0, 0])
        #expect(variant.metadata.seed == 7)
        #expect(variant.metadata.judgeOffsets == [0, 0, 0])
        // Recorded inputs are untouched — same inputs, new conditions.
        #expect(variant.motion == original.motion)
        #expect(variant.events == original.events)
    }

    @Test func logRoundTripsThroughJSONFixture() throws {
        let log = sampleLog()
        let data = try log.encoded()
        #expect(try HarnessSessionLog.decoded(from: data) == log)
    }

    @Test func recorderBuildsTimelineFromSeams() {
        let rec = HarnessSessionRecorder(
            metadata: HarnessSessionMetadata(modeId: "basketball_dunk_3d", seed: 1))
        rec.start(now: 100.0)
        rec.recordMotion(.freefall(at: 50.0))   // arbitrary device epoch
        rec.recordMotion(.impact(at: 50.5))
        rec.recordEvent("dunk_result", playerId: "p1", points: 40, at: 101.2)
        let log = rec.finish()
        // Motion normalized to first-sample epoch; event relative to start.
        #expect(log.motion.first?.timestamp == 0.0)
        #expect(abs((log.motion.last?.timestamp ?? -1) - 0.5) < 1e-9)
        #expect(abs((log.events.first?.timestamp ?? -1) - 1.2) < 1e-9)
        #expect(log.events.first?.points == 40)
    }
}
