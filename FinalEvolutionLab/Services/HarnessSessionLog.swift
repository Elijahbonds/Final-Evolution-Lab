import Foundation

// MARK: - Harness session log
//
// One timeline that unifies every input the app reacts to — device motion,
// camera pose, haptic cues, and gameplay/score events — plus the deterministic
// metadata (seed, judge_offsets) needed to reproduce a session. This is the
// "record / trim / splice / inject / export" surface, applied to the EVENT LOG
// rather than video: logs are tiny, diffable, reproducible test fixtures, and a
// video reel is a later render-out step from an edited log.
//
// The JSON shape mirrors the backend replay contract ({metadata, events}) so a
// Swift-recorded session and a server-exported replay are the same kind of file.

/// Deterministic seeding metadata — matches the backend replay `metadata` block.
nonisolated struct HarnessSessionMetadata: Sendable, Codable, Equatable {
    var modeId: String
    var seed: UInt64
    var judgeOffsets: [Int]
    var players: [String]

    enum CodingKeys: String, CodingKey {
        case modeId = "mode_id"
        case seed
        case judgeOffsets = "judge_offsets"
        case players
    }

    init(modeId: String, seed: UInt64, judgeOffsets: [Int] = [], players: [String] = ["local"]) {
        self.modeId = modeId
        self.seed = seed
        self.judgeOffsets = judgeOffsets
        self.players = players
    }
}

/// A gameplay/score event on the timeline (parallels a backend match event).
nonisolated struct HarnessGameEvent: Sendable, Codable, Equatable {
    var timestamp: TimeInterval
    var type: String            // e.g. "score_event", "dunk_result", "match_end"
    var playerId: String?
    var points: Int?
    var payload: [String: String]?

    enum CodingKeys: String, CodingKey {
        case timestamp, type
        case playerId = "player_id"
        case points, payload
    }

    init(timestamp: TimeInterval, type: String, playerId: String? = nil,
         points: Int? = nil, payload: [String: String]? = nil) {
        self.timestamp = timestamp
        self.type = type
        self.playerId = playerId
        self.points = points
        self.payload = payload
    }
}

/// A haptic cue stamped onto the timeline.
nonisolated struct HarnessHapticCue: Sendable, Codable, Equatable {
    var timestamp: TimeInterval
    var event: HapticEvent
}

/// The full recorded session — every seam's stream on one clock.
nonisolated struct HarnessSessionLog: Sendable, Codable, Equatable {
    var metadata: HarnessSessionMetadata
    var motion: [MotionSample]
    var poses: [PoseFrame]
    var haptics: [HarnessHapticCue]
    var events: [HarnessGameEvent]

    init(metadata: HarnessSessionMetadata,
         motion: [MotionSample] = [],
         poses: [PoseFrame] = [],
         haptics: [HarnessHapticCue] = [],
         events: [HarnessGameEvent] = []) {
        self.metadata = metadata
        self.motion = motion
        self.poses = poses
        self.haptics = haptics
        self.events = events
    }

    // MARK: Span

    /// Earliest timestamp across all streams (0 if empty).
    var startTime: TimeInterval {
        [motion.first?.timestamp, poses.first?.timestamp,
         haptics.first?.timestamp, events.first?.timestamp]
            .compactMap { $0 }.min() ?? 0
    }

    /// Latest timestamp across all streams (0 if empty).
    var endTime: TimeInterval {
        [motion.last?.timestamp, poses.last?.timestamp,
         haptics.last?.timestamp, events.last?.timestamp]
            .compactMap { $0 }.max() ?? 0
    }

    var duration: TimeInterval { max(0, endTime - startTime) }

    // MARK: Trim (cut a highlight window)

    /// Keeps only samples/frames/events within `[from, to]` (inclusive),
    /// preserving absolute timestamps. Metadata (seed/offsets) is retained so
    /// the trimmed clip still reproduces deterministically.
    func trimmed(from: TimeInterval, to: TimeInterval) -> HarnessSessionLog {
        precondition(to >= from, "trim window end must be >= start")
        func within<T>(_ items: [T], _ ts: (T) -> TimeInterval) -> [T] {
            items.filter { ts($0) >= from && ts($0) <= to }
        }
        return HarnessSessionLog(
            metadata: metadata,
            motion: within(motion, \.timestamp),
            poses: within(poses, \.timestamp),
            haptics: within(haptics, \.timestamp),
            events: within(events, \.timestamp)
        )
    }

    /// Shifts every timestamp so the earliest sample sits at `newStart`
    /// (default 0). Use after trimming to normalize a clip to its own clock.
    func timeShiftedToZero(newStart: TimeInterval = 0) -> HarnessSessionLog {
        let offset = newStart - startTime
        guard offset != 0 else { return self }
        return offsetBy(offset)
    }

    private func offsetBy(_ dt: TimeInterval) -> HarnessSessionLog {
        var copy = self
        copy.motion = motion.map { var s = $0; s.timestamp += dt; return s }
        copy.poses = poses.map { var p = $0; p.timestamp += dt; return p }
        copy.haptics = haptics.map { HarnessHapticCue(timestamp: $0.timestamp + dt, event: $0.event) }
        copy.events = events.map { var e = $0; e.timestamp += dt; return e }
        return copy
    }

    // MARK: Splice (stitch clips into a reel)

    /// Appends `other` after this log, offsetting `other`'s timeline to start
    /// `gap` seconds after this log ends. `self`'s metadata wins (a reel needs
    /// one seed). Sorted by timestamp within each stream.
    func spliced(with other: HarnessSessionLog, gap: TimeInterval = 0) -> HarnessSessionLog {
        let shift = (endTime + gap) - other.startTime
        let b = other.offsetBy(shift)
        return HarnessSessionLog(
            metadata: metadata,
            motion: (motion + b.motion).sorted { $0.timestamp < $1.timestamp },
            poses: (poses + b.poses).sorted { $0.timestamp < $1.timestamp },
            haptics: (haptics + b.haptics).sorted { $0.timestamp < $1.timestamp },
            events: (events + b.events).sorted { $0.timestamp < $1.timestamp }
        )
    }

    // MARK: Inject (override seed / judge offsets for a test vector)

    /// Returns a copy with a new seed and/or judge offsets — the same recorded
    /// inputs replayed under different deterministic conditions.
    func injecting(seed: UInt64? = nil, judgeOffsets: [Int]? = nil) -> HarnessSessionLog {
        var copy = self
        if let seed { copy.metadata.seed = seed }
        if let judgeOffsets { copy.metadata.judgeOffsets = judgeOffsets }
        return copy
    }

    // MARK: Providers (replay the recorded inputs back through the seams)

    @MainActor
    func makeMotionProvider(realtime: Bool = true) -> ReplayMotionProvider {
        ReplayMotionProvider(samples: motion, realtime: realtime)
    }

    @MainActor
    func makePoseProvider(realtime: Bool = true) -> PoseTraceProvider {
        PoseTraceProvider(frames: poses, realtime: realtime)
    }

    // MARK: Persistence (fixtures / demo reels on disk)

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> HarnessSessionLog {
        try JSONDecoder().decode(HarnessSessionLog.self, from: data)
    }

    func write(to url: URL) throws { try encoded().write(to: url) }

    static func read(from url: URL) throws -> HarnessSessionLog {
        try decoded(from: Data(contentsOf: url))
    }
}
