import Foundation

// MARK: - Live session recorder
//
// Accumulates the seam streams during a real or replayed session into a
// HarnessSessionLog. Point the app's haptic sink at `hapticSink` and forward
// motion/pose/game events via the record* methods; call `finish()` for the
// timeline. Timestamps are relative to `start()` so recordings normalize to
// their own clock.

@MainActor
final class HarnessSessionRecorder {
    private var metadata: HarnessSessionMetadata
    private var motion: [MotionSample] = []
    private var poses: [PoseFrame] = []
    private var events: [HarnessGameEvent] = []
    private var startWallClock: TimeInterval = 0

    /// Attach as the FELHaptics sink to capture cues onto the timeline.
    let hapticSink = TimestampedHapticSink()

    init(metadata: HarnessSessionMetadata) {
        self.metadata = metadata
    }

    /// Begins a recording; `now` lets callers inject a clock in tests.
    func start(now: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        startWallClock = now
        motion.removeAll(); poses.removeAll(); events.removeAll()
        hapticSink.reset(startWallClock: now)
        FELHaptics.setSink(hapticSink)
    }

    func recordMotion(_ sample: MotionSample) { motion.append(relative(sample)) }
    func recordPose(_ frame: PoseFrame) { poses.append(relative(frame)) }

    func recordEvent(_ type: String, playerId: String? = nil, points: Int? = nil,
                     payload: [String: String]? = nil,
                     at now: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        events.append(HarnessGameEvent(timestamp: now - startWallClock, type: type,
                                       playerId: playerId, points: points, payload: payload))
    }

    /// Stops recording, detaches the haptic sink, returns the timeline.
    func finish() -> HarnessSessionLog {
        FELHaptics.resetSink()
        return HarnessSessionLog(
            metadata: metadata,
            motion: motion.sorted { $0.timestamp < $1.timestamp },
            poses: poses.sorted { $0.timestamp < $1.timestamp },
            haptics: hapticSink.cues.sorted { $0.timestamp < $1.timestamp },
            events: events.sorted { $0.timestamp < $1.timestamp }
        )
    }

    private func relative(_ s: MotionSample) -> MotionSample {
        var out = s; out.timestamp -= motionEpoch(s.timestamp); return out
    }
    private func relative(_ f: PoseFrame) -> PoseFrame {
        var out = f; out.timestamp -= poseEpoch(f.timestamp); return out
    }

    // Motion/pose samples already carry monotonic device timestamps; anchor the
    // first one seen to 0 so the recording normalizes to its own clock.
    private var motionEpochValue: TimeInterval?
    private func motionEpoch(_ t: TimeInterval) -> TimeInterval {
        if let e = motionEpochValue { return e }
        motionEpochValue = t; return t
    }
    private var poseEpochValue: TimeInterval?
    private func poseEpoch(_ t: TimeInterval) -> TimeInterval {
        if let e = poseEpochValue { return e }
        poseEpochValue = t; return t
    }
}

/// Haptic sink that timestamps each cue relative to recording start.
@MainActor
final class TimestampedHapticSink: HapticSink {
    private(set) var cues: [HarnessHapticCue] = []
    private var startWallClock: TimeInterval = 0

    func reset(startWallClock: TimeInterval) {
        self.startWallClock = startWallClock
        cues.removeAll()
    }

    func emit(_ event: HapticEvent) {
        cues.append(HarnessHapticCue(timestamp: Date().timeIntervalSinceReferenceDate - startWallClock,
                                     event: event))
    }
}
