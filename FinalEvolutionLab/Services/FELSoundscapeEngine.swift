import AVFoundation
import SwiftUI

enum VenueType: String, Sendable {
    case outdoorVenice = "Venice Beach"
    case indoorDojo = "Zen Dojo"
    case packedStadium = "Packed Stadium"
}

private enum OscillatorType {
    case sine, square, sawtooth, triangle
}

private final class SynthVoice {
    var oscillatorType: OscillatorType
    var phase: Float = 0.0
    var frequency: Float = 0.0
    
    // Envelope parameters (in seconds)
    var attack: Double
    var decay: Double
    var sustain: Double
    var release: Double
    
    // Envelope state
    enum EnvelopeState {
        case idle, attack, decay, sustain, release
    }
    var envelopeState: EnvelopeState = .idle
    var envelopeValue: Float = 0.0
    var timeInState: Double = 0.0
    var sampleRate: Double = 44100.0
    
    init(oscillatorType: OscillatorType, attack: Double, decay: Double, sustain: Double, release: Double) {
        self.oscillatorType = oscillatorType
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
    }
    
    func trigger(frequency: Float) {
        self.frequency = frequency
        self.phase = 0.0
        self.envelopeState = .attack
        self.timeInState = 0.0
        self.envelopeValue = 0.0
    }
    
    func releaseNote() {
        if envelopeState != .idle && envelopeState != .release {
            envelopeState = .release
            timeInState = 0.0
        }
    }
    
    func nextSample() -> Float {
        guard envelopeState != .idle else { return 0.0 }
        
        let dt = 1.0 / sampleRate
        timeInState += dt
        
        switch envelopeState {
        case .idle:
            envelopeValue = 0.0
        case .attack:
            if attack > 0 {
                envelopeValue = Float(timeInState / attack)
                if timeInState >= attack {
                    envelopeState = .decay
                    timeInState = 0.0
                    envelopeValue = 1.0
                }
            } else {
                envelopeState = .decay
                timeInState = 0.0
                envelopeValue = 1.0
            }
        case .decay:
            if decay > 0 {
                envelopeValue = Float(1.0 - (1.0 - sustain) * (timeInState / decay))
                if timeInState >= decay {
                    envelopeState = .sustain
                    timeInState = 0.0
                    envelopeValue = Float(sustain)
                }
            } else {
                envelopeState = .sustain
                timeInState = 0.0
                envelopeValue = Float(sustain)
            }
        case .sustain:
            envelopeValue = Float(sustain)
        case .release:
            if release > 0 {
                envelopeValue = Float(sustain * (1.0 - timeInState / release))
                if timeInState >= release {
                    envelopeState = .idle
                    timeInState = 0.0
                    envelopeValue = 0.0
                }
            } else {
                envelopeState = .idle
                timeInState = 0.0
                envelopeValue = 0.0
            }
        }
        
        let twopi = Float.pi * 2.0
        phase += twopi * frequency / Float(sampleRate)
        if phase >= twopi {
            phase -= twopi
        }
        
        var oscVal: Float = 0.0
        switch oscillatorType {
        case .sine:
            oscVal = sin(phase)
        case .square:
            oscVal = phase < Float.pi ? 1.0 : -1.0
        case .sawtooth:
            oscVal = (phase / Float.pi) - 1.0
        case .triangle:
            oscVal = abs((phase / Float.pi) - 1.0) * 2.0 - 1.0
        }
        
        return oscVal * envelopeValue
    }
}

final class FELSoundscapeEngine: @unchecked Sendable {
    static let shared = FELSoundscapeEngine()
    
    // Audio Engine
    private var audioEngine: AVAudioEngine?
    private var reverbNode: AVAudioUnitReverb?
    private var mixerNode: AVAudioMixerNode?
    
    // Source nodes
    private var ambientNode: AVAudioSourceNode?
    private var reactionNode: AVAudioSourceNode?
    private var synthMusicNode: AVAudioSourceNode?
    
    // State variables
    private let stateQueue = DispatchQueue(label: "com.finalevolution.soundscape.state", qos: .userInteractive)
    private var _isRunning = false
    
    // Lock-free pointers for real-time safe parameter updates
    private let cheerIntensityPtr = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private let applauseIntensityPtr = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private let gaspIntensityPtr = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private let comboPtr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    private let timeRemainingPtr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    private let venueTypeRawPtr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    private let isPlayingMusicPtr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    private let isSlowMoPtr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    
    var isRunning: Bool {
        get { stateQueue.sync { _isRunning } }
        set { stateQueue.sync { _isRunning = newValue } }
    }
    
    var cheerIntensity: Float {
        get { cheerIntensityPtr.pointee }
        set { cheerIntensityPtr.pointee = newValue }
    }
    
    var applauseIntensity: Float {
        get { applauseIntensityPtr.pointee }
        set { applauseIntensityPtr.pointee = newValue }
    }
    
    var gaspIntensity: Float {
        get { gaspIntensityPtr.pointee }
        set { gaspIntensityPtr.pointee = newValue }
    }
    
    var combo: Int {
        get { comboPtr.pointee }
        set { comboPtr.pointee = newValue }
    }
    
    var timeRemaining: Int {
        get { timeRemainingPtr.pointee }
        set { timeRemainingPtr.pointee = newValue }
    }
    
    var isSlowMo: Bool {
        get { isSlowMoPtr.pointee != 0 }
        set { isSlowMoPtr.pointee = newValue ? 1 : 0 }
    }
    
    var isPlayingMusic: Bool {
        get { isPlayingMusicPtr.pointee != 0 }
        set { isPlayingMusicPtr.pointee = newValue ? 1 : 0 }
    }
    
    var venueType: VenueType {
        get {
            switch venueTypeRawPtr.pointee {
            case 0: return .outdoorVenice
            case 1: return .indoorDojo
            default: return .packedStadium
            }
        }
        set {
            switch newValue {
            case .outdoorVenice: venueTypeRawPtr.pointee = 0
            case .indoorDojo: venueTypeRawPtr.pointee = 1
            case .packedStadium: venueTypeRawPtr.pointee = 2
            }
            updateReverbPreset()
        }
    }
    
    private init() {
        cheerIntensityPtr.initialize(to: 0.0)
        applauseIntensityPtr.initialize(to: 0.0)
        gaspIntensityPtr.initialize(to: 0.0)
        comboPtr.initialize(to: 0)
        timeRemainingPtr.initialize(to: 60)
        venueTypeRawPtr.initialize(to: 0)
        isPlayingMusicPtr.initialize(to: 1)
        isSlowMoPtr.initialize(to: 0)
    }
    
    deinit {
        cheerIntensityPtr.deallocate()
        applauseIntensityPtr.deallocate()
        gaspIntensityPtr.deallocate()
        comboPtr.deallocate()
        timeRemainingPtr.deallocate()
        venueTypeRawPtr.deallocate()
        isPlayingMusicPtr.deallocate()
        isSlowMoPtr.deallocate()
    }
    
    /// Master gate — gameplay audio is cut until proper sound design ships.
    /// Re-enable per-user via UserDefaults key "fel.audio.enabled" = true.
    static var audioEnabled: Bool {
        UserDefaults.standard.bool(forKey: "fel.audio.enabled")
    }

    func start(for mode: GameModeId) {
        guard Self.audioEnabled else { return }
        stateQueue.sync {
            guard !_isRunning else { return }
            _isRunning = true
        }
        
        self.venueType = venueType(for: mode)
        self.combo = 0
        self.timeRemaining = 60
        self.isSlowMo = false
        self.isPlayingMusic = true
        
        setupAudioEngine()
    }
    
    func stop() {
        stateQueue.sync {
            guard _isRunning else { return }
            _isRunning = false
        }
        
        teardownAudioEngine()
    }
    
    func triggerCheer(intensity: Float = 1.0) {
        cheerIntensity = intensity
        applauseIntensity = intensity * 0.85
    }
    
    func triggerGasp(intensity: Float = 1.0) {
        gaspIntensity = intensity
    }
    
    func triggerApplause(intensity: Float = 1.0) {
        applauseIntensity = intensity
    }
    
    private func venueType(for mode: GameModeId) -> VenueType {
        switch mode {
        case .basketballHeadToHead, .venicePickup, .basketballDunkContest3D, .marketBrowse, .surfing, .skateboarding, .courtCarnival:
            return .outdoorVenice
        case .karate, .karateEndless:
            return .indoorDojo
        case .brainBrawl, .whoSceneIt:
            return .indoorDojo
        default:
            return .packedStadium
        }
    }
    
    private func updateReverbPreset() {
        guard let reverbNode = reverbNode else { return }
        let venue = venueType
        DispatchQueue.main.async {
            switch venue {
            case .outdoorVenice:
                reverbNode.loadFactoryPreset(.plate)
                reverbNode.wetDryMix = 15.0
            case .indoorDojo:
                reverbNode.loadFactoryPreset(.mediumRoom)
                reverbNode.wetDryMix = 35.0
            case .packedStadium:
                reverbNode.loadFactoryPreset(.largeHall2)
                reverbNode.wetDryMix = 55.0
            }
        }
    }
    
    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let reverb = AVAudioUnitReverb()
        let mixer = AVAudioMixerNode()
        
        self.audioEngine = engine
        self.reverbNode = reverb
        self.mixerNode = mixer
        
        engine.attach(reverb)
        engine.attach(mixer)
        
        // 1. Ambient Soundscape Node
        var windFilterState: Float = 0.0
        var crowdHumFilterState: Float = 0.0
        var ambientPhase: Float = 0.0
        
        let ambient = AVAudioSourceNode { [venueTypeRawPtr] (silence, timeStamp, frameCount, audioBufferList) -> OSStatus in
            let venueRaw = venueTypeRawPtr.pointee
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for buffer in ablPointer {
                let buf = UnsafeMutableBufferPointer<Float>(buffer)
                for frame in 0..<Int(frameCount) {
                    let whiteNoise = Float.random(in: -1.0...1.0)
                    
                    ambientPhase += 0.00005
                    if ambientPhase > Float.pi * 2.0 { ambientPhase -= Float.pi * 2.0 }
                    let windMod = 0.02 + 0.015 * sin(ambientPhase)
                    windFilterState = windMod * whiteNoise + (1.0 - windMod) * windFilterState
                    
                    let humMod = 0.005 + 0.003 * cos(ambientPhase * 1.7)
                    crowdHumFilterState = humMod * whiteNoise + (1.0 - humMod) * crowdHumFilterState
                    
                    let windVol: Float
                    let humVol: Float
                    
                    if venueRaw == 0 { // Venice Beach
                        windVol = 0.12
                        humVol = 0.05
                    } else if venueRaw == 1 { // Zen Dojo
                        windVol = 0.02
                        humVol = 0.0
                    } else { // Packed Stadium
                        windVol = 0.04
                        humVol = 0.18
                    }
                    
                    let sample = (windFilterState * windVol) + (crowdHumFilterState * humVol)
                    buf[frame] = sample
                }
            }
            return noErr
        }
        self.ambientNode = ambient
        engine.attach(ambient)
        
        // 2. Reaction Node (Cheers, Applause, Gasps)
        struct Clapper {
            var samplesLeft = 0
            var initialSamples = 0
            var filterState: Float = 0.0
            
            mutating func tick() -> Float {
                guard samplesLeft > 0 else { return 0.0 }
                samplesLeft -= 1
                let white = Float.random(in: -1.0...1.0)
                filterState = 0.15 * white + 0.85 * filterState
                let envelope = Float(samplesLeft) / Float(initialSamples)
                return filterState * envelope * 0.25
            }
            
            mutating func trigger(durationSamples: Int) {
                self.samplesLeft = durationSamples
                self.initialSamples = durationSamples
                self.filterState = 0.0
            }
        }
        
        var clappers = [Clapper(), Clapper(), Clapper(), Clapper(), Clapper(), Clapper()]
        var reactionFilterState: Float = 0.0
        var reactionPhase: Float = 0.0
        var gaspFilterState: Float = 0.0
        
        let reaction = AVAudioSourceNode { [cheerIntensityPtr, applauseIntensityPtr, gaspIntensityPtr] (silence, timeStamp, frameCount, audioBufferList) -> OSStatus in
            let cheer = cheerIntensityPtr.pointee
            let applause = applauseIntensityPtr.pointee
            let gasp = gaspIntensityPtr.pointee
            
            let decayCheer = Float(frameCount) / (44100.0 * 3.5)
            let decayApplause = Float(frameCount) / (44100.0 * 4.0)
            let decayGasp = Float(frameCount) / (44100.0 * 0.8)
            
            cheerIntensityPtr.pointee = max(0.0, cheer - decayCheer)
            applauseIntensityPtr.pointee = max(0.0, applause - decayApplause)
            gaspIntensityPtr.pointee = max(0.0, gasp - decayGasp)
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in ablPointer {
                let buf = UnsafeMutableBufferPointer<Float>(buffer)
                for frame in 0..<Int(frameCount) {
                    var applauseSample: Float = 0.0
                    for i in 0..<clappers.count {
                        if clappers[i].samplesLeft > 0 {
                            applauseSample += clappers[i].tick()
                        } else if Float.random(in: 0...1) < (applause * 0.0012) {
                            let dur = Int.random(in: 600...1800)
                            clappers[i].trigger(durationSamples: dur)
                        }
                    }
                    
                    var cheerSample: Float = 0.0
                    if cheer > 0 {
                        reactionPhase += 0.0001
                        if reactionPhase > Float.pi * 2.0 { reactionPhase -= Float.pi * 2.0 }
                        
                        let white = Float.random(in: -1.0...1.0)
                        let alpha = 0.06 + 0.04 * sin(reactionPhase)
                        reactionFilterState = alpha * white + (1.0 - alpha) * reactionFilterState
                        
                        let f1 = 180.0 + 120.0 * cheer
                        let f2 = 270.0 + 180.0 * cheer
                        let sin1 = sin(Float(frame) * Float.pi * 2.0 * f1 / 44100.0)
                        let sin2 = sin(Float(frame) * Float.pi * 2.0 * f2 / 44100.0)
                        
                        cheerSample = (reactionFilterState * 0.6 + (sin1 + sin2) * 0.2) * cheer
                    }
                    
                    var gaspSample: Float = 0.0
                    if gasp > 0 {
                        let white = Float.random(in: -1.0...1.0)
                        let alpha = 0.05 + 0.15 * (1.0 - gasp)
                        gaspFilterState = alpha * white + (1.0 - alpha) * gaspFilterState
                        gaspSample = gaspFilterState * gasp * 0.4
                    }
                    
                    let sample = (applauseSample * 0.7) + (cheerSample * 0.5) + (gaspSample * 0.6)
                    buf[frame] = sample
                }
            }
            return noErr
        }
        self.reactionNode = reaction
        engine.attach(reaction)
        
        // 3. Retro Synth Music Node
        let bassVoice = SynthVoice(oscillatorType: .square, attack: 0.005, decay: 0.12, sustain: 0.3, release: 0.08)
        let leadVoice = SynthVoice(oscillatorType: .sawtooth, attack: 0.01, decay: 0.22, sustain: 0.5, release: 0.12)
        
        let bassSeq: [Int?] = [33, 33, 33, 33, 36, 36, 36, 36, 31, 31, 31, 31, 35, 35, 35, 35]
        let leadSeq: [Int?] = [57, nil, 60, nil, 64, nil, 62, nil, 57, 60, 64, 67, 69, nil, 67, nil]
        
        var currentStep = 0
        var sampleCountInStep = 0
        
        let synthMusic = AVAudioSourceNode { [isPlayingMusicPtr, comboPtr, timeRemainingPtr, isSlowMoPtr] (silence, timeStamp, frameCount, audioBufferList) -> OSStatus in
            guard isPlayingMusicPtr.pointee != 0 else {
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in ablPointer {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf.initialize(repeating: 0.0)
                }
                return noErr
            }
            
            let comboVal = comboPtr.pointee
            let timeVal = timeRemainingPtr.pointee
            let slowMoVal = isSlowMoPtr.pointee != 0
            
            var currentBpm = 115.0
            var transpose = 0
            
            if slowMoVal {
                currentBpm = 60.0
                transpose = -5
            } else {
                if comboVal >= 10 {
                    currentBpm = 155.0
                    transpose = 4
                } else if comboVal >= 5 {
                    currentBpm = 135.0
                    transpose = 2
                } else if timeVal <= 10 && timeVal > 0 {
                    currentBpm = 145.0
                    transpose = 3
                }
            }
            
            let stepDuration = 60.0 / (currentBpm * 4.0)
            let samplesPerStep = stepDuration * 44100.0
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in ablPointer {
                let buf = UnsafeMutableBufferPointer<Float>(buffer)
                for frame in 0..<Int(frameCount) {
                    if sampleCountInStep >= Int(samplesPerStep) {
                        sampleCountInStep = 0
                        currentStep = (currentStep + 1) % 16
                        
                        if let bassNote = bassSeq[currentStep] {
                            let transposedNote = bassNote + transpose
                            let freq = 440.0 * pow(2.0, Float(transposedNote - 69) / 12.0)
                            bassVoice.trigger(frequency: freq)
                        }
                        
                        if let leadNote = leadSeq[currentStep] {
                            let transposedNote = leadNote + transpose
                            let freq = 440.0 * pow(2.0, Float(transposedNote - 69) / 12.0)
                            leadVoice.trigger(frequency: freq)
                        } else {
                            leadVoice.releaseNote()
                        }
                    }
                    
                    sampleCountInStep += 1
                    
                    let bassSample = bassVoice.nextSample()
                    let leadSample = leadVoice.nextSample()
                    
                    let sample = (bassSample * 0.18) + (leadSample * 0.08)
                    buf[frame] = sample
                }
            }
            return noErr
        }
        self.synthMusicNode = synthMusic
        engine.attach(synthMusic)
        
        // Connect nodes
        let format = engine.outputNode.outputFormat(forBus: 0)
        
        engine.connect(ambient, to: reverb, format: format)
        engine.connect(reverb, to: mixer, format: format)
        engine.connect(reaction, to: mixer, format: format)
        engine.connect(synthMusic, to: mixer, format: format)
        engine.connect(mixer, to: engine.outputNode, format: format)
        
        updateReverbPreset()
        
        do {
            try engine.start()
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }
    
    private func teardownAudioEngine() {
        guard let engine = audioEngine else { return }
        engine.stop()
        
        if let ambient = ambientNode { engine.detach(ambient) }
        if let reaction = reactionNode { engine.detach(reaction) }
        if let synthMusic = synthMusicNode { engine.detach(synthMusic) }
        if let reverb = reverbNode { engine.detach(reverb) }
        if let mixer = mixerNode { engine.detach(mixer) }
        
        ambientNode = nil
        reactionNode = nil
        synthMusicNode = nil
        reverbNode = nil
        mixerNode = nil
        audioEngine = nil
    }
}
