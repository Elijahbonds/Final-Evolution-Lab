import AVFoundation
import Foundation

/// Sprint 1 (nexus/audio-vfx) — audio architecture on top of ``FELSoundscapeEngine``.
///
/// Layers:
///  1. **Low-latency SFX bus** (``FELSFXBus``): a dedicated `AVAudioEngine` with
///     preloaded, procedurally-synthesized PCM buffers played through
///     `AVAudioPlayerNode`s — no disk hit and no `AVAudioPlayer` start latency
///     on the trigger path. All SFX are synthesized (rim hit, swish whoosh,
///     buzzer, crowd stab, judge sting) so nothing depends on missing bundled
///     assets, matching the engine's procedural soundscape approach.
///  2. **Spatial crowd/announcer mix**: stereo placement + intensity ducking on
///     top of the existing crowd reaction generators (crowd wide, announcer
///     center, SFX slightly forward).
///  3. **Per-event triggers**: subscribes to ``FELGameplayEventBus``
///     notifications and routes each gameplay beat to soundscape reactions +
///     bus one-shots from a single table (`route(_:)`).
///
/// `FELSoundscapeEngine` remains the owner of ambient/reaction/music synthesis;
/// this director never reaches into its render blocks.
@MainActor
final class FELAudioDirector {
    static let shared = FELAudioDirector()

    private let sfxBus = FELSFXBus()
    private var observers: [NSObjectProtocol] = []
    private(set) var isActive = false

    private init() {}

    // MARK: - Lifecycle

    /// Starts the soundscape for the mode, preloads the SFX bus, and begins
    /// routing gameplay events. Safe to call repeatedly.
    func start(for mode: GameModeId) {
        FELSoundscapeEngine.shared.start(for: mode)
        sfxBus.prepare()
        subscribeIfNeeded()
        isActive = true
    }

    func stop() {
        isActive = false
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        sfxBus.stop()
        FELSoundscapeEngine.shared.stop()
    }

    // MARK: - Spatial mix

    /// Positions the crowd bed wide, announcer stings center, SFX slightly
    /// left/right of center. Pan in [-1, 1], matching source position on court.
    func setListenerFocus(courtX: Float) {
        let clamped = max(-1.0, min(1.0, courtX))
        sfxBus.setPan(clamped * 0.4, forGroup: .gameplay)
        sfxBus.setPan(0.0, forGroup: .announcer)
        sfxBus.setPan(clamped * 0.15, forGroup: .crowd)
    }

    /// Ducks crowd + music while an announcer sting plays.
    func duckForAnnouncer(_ ducked: Bool) {
        sfxBus.setVolume(ducked ? 0.45 : 1.0, forGroup: .crowd)
        FELSoundscapeEngine.shared.isPlayingMusic = !ducked
    }

    // MARK: - Event routing

    private func subscribeIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .felGameplayScored, .felGameplayBuzzIn, .felGameplayPenalty,
            .felGameplayKarateBlock, .felGameplayWaveCompleted, .felGameplayOpponentScored,
        ]
        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { note in
                MainActor.assumeIsolated {
                    FELAudioDirector.shared.route(note.name)
                }
            }
            observers.append(observer)
        }
    }

    private func route(_ event: Notification.Name) {
        guard isActive else { return }
        switch event {
        case .felGameplayScored:
            sfxBus.play(.swish)
            FELSoundscapeEngine.shared.triggerCheer(intensity: 0.85)
        case .felGameplayBuzzIn:
            sfxBus.play(.buzzer)
        case .felGameplayPenalty:
            sfxBus.play(.rimHit)
            FELSoundscapeEngine.shared.triggerGasp(intensity: 0.9)
        case .felGameplayKarateBlock:
            sfxBus.play(.rimHit)
            FELSoundscapeEngine.shared.triggerApplause(intensity: 0.4)
        case .felGameplayWaveCompleted:
            sfxBus.play(.crowdStab)
            FELSoundscapeEngine.shared.triggerApplause(intensity: 1.0)
        case .felGameplayOpponentScored:
            sfxBus.play(.crowdStab)
            FELSoundscapeEngine.shared.triggerGasp(intensity: 0.5)
        default:
            break
        }
    }

    /// Judge-reveal moment (dunk contest): announcer duck + sting, crowd swell.
    func playJudgeReveal(score: Int) {
        guard isActive else { return }
        duckForAnnouncer(true)
        sfxBus.play(.judgeSting)
        FELSoundscapeEngine.shared.triggerCheer(intensity: score >= 40 ? 1.0 : 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            FELAudioDirector.shared.duckForAnnouncer(false)
        }
    }
}

// MARK: - Low-latency SFX bus

/// One-shot identifiers for the synthesized SFX palette.
enum FELSFXCue: CaseIterable {
    case swish       // dunk made: filtered noise whoosh, falling pitch
    case rimHit      // metallic thunk: damped 220 Hz + partials
    case buzzer      // quiz/shot-clock buzzer: hard square burst
    case crowdStab   // short crowd swell stab
    case judgeSting  // rising two-note announcer sting
}

/// Preloaded PCM one-shots on dedicated player nodes, grouped for spatial mix.
@MainActor
final class FELSFXBus {
    enum Group { case gameplay, crowd, announcer }

    private let engine = AVAudioEngine()
    private var players: [FELSFXCue: AVAudioPlayerNode] = [:]
    private var buffers: [FELSFXCue: AVAudioPCMBuffer] = [:]
    private var groupMixers: [Group: AVAudioMixerNode] = [:]
    private var prepared = false

    private static let sampleRate = 44_100.0

    func prepare() {
        guard !prepared else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!

        for group in [Group.gameplay, .crowd, .announcer] {
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            engine.connect(mixer, to: engine.mainMixerNode, format: format)
            groupMixers[group] = mixer
        }

        for cue in FELSFXCue.allCases {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: groupMixers[Self.group(for: cue)]!, format: format)
            players[cue] = node
            buffers[cue] = Self.synthesize(cue, format: format)
        }

        do {
            try engine.start()
            for node in players.values { node.play() }
            prepared = true
        } catch {
            print("FELSFXBus failed to start: \(error)")
        }
    }

    func stop() {
        guard prepared else { return }
        engine.stop()
        prepared = false
    }

    /// Real-time trigger: schedules a preloaded buffer; no allocation, no I/O.
    func play(_ cue: FELSFXCue) {
        guard prepared, let node = players[cue], let buffer = buffers[cue] else { return }
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    func setPan(_ pan: Float, forGroup group: Group) {
        groupMixers[group]?.pan = pan
    }

    func setVolume(_ volume: Float, forGroup group: Group) {
        groupMixers[group]?.outputVolume = volume
    }

    private static func group(for cue: FELSFXCue) -> Group {
        switch cue {
        case .swish, .rimHit, .buzzer: return .gameplay
        case .crowdStab: return .crowd
        case .judgeSting: return .announcer
        }
    }

    // MARK: Synthesis

    private static func synthesize(_ cue: FELSFXCue, format: AVAudioFormat) -> AVAudioPCMBuffer {
        switch cue {
        case .swish:
            return render(duration: 0.35, format: format) { t, progress in
                var noise = Float.random(in: -1...1)
                noise *= 0.5 + 0.5 * sin(Float(t) * 2.0 * .pi * (900.0 - 700.0 * progress))
                return noise * (1.0 - progress) * (1.0 - progress) * 0.6
            }
        case .rimHit:
            return render(duration: 0.28, format: format) { t, progress in
                let fundamental = sin(Float(t) * 2.0 * .pi * 220.0)
                let partial = 0.5 * sin(Float(t) * 2.0 * .pi * 570.0)
                let clank = 0.25 * sin(Float(t) * 2.0 * .pi * 1310.0)
                return (fundamental + partial + clank) * exp(-9.0 * progress) * 0.5
            }
        case .buzzer:
            return render(duration: 0.5, format: format) { t, progress in
                let phase = Float(t) * 2.0 * .pi * 233.0
                let square: Float = sin(phase) > 0 ? 1.0 : -1.0
                let edge: Float = progress > 0.92 ? Float(1.0 - (progress - 0.92) / 0.08) : 1.0
                return square * 0.28 * edge
            }
        case .crowdStab:
            var filterState: Float = 0
            return render(duration: 0.6, format: format) { _, progress in
                let white = Float.random(in: -1...1)
                filterState = 0.08 * white + 0.92 * filterState
                let swell = progress < 0.25 ? progress / 0.25 : (1.0 - progress) / 0.75
                return filterState * swell * 1.4
            }
        case .judgeSting:
            return render(duration: 0.7, format: format) { t, progress in
                let note: Float = progress < 0.5 ? 523.25 : 783.99 // C5 -> G5
                let vibrato = 1.0 + 0.004 * sin(Float(t) * 2.0 * .pi * 6.0)
                let envelope = progress < 0.5
                    ? min(1.0, progress / 0.06) * (1.0 - progress * 0.4)
                    : min(1.0, (progress - 0.5) / 0.06) * (1.0 - (progress - 0.5) * 1.6)
                return sin(Float(t) * 2.0 * .pi * note * vibrato) * envelope * 0.3
            }
        }
    }

    /// Renders `sample(timeSeconds, progress01)` into a mono PCM buffer.
    private static func render(duration: Double,
                               format: AVAudioFormat,
                               sample: (Double, Float) -> Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let progress = Float(frame) / Float(frameCount)
            channel[frame] = sample(t, progress)
        }
        return buffer
    }
}
