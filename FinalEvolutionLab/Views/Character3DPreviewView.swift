import SwiftUI
import SceneKit
import UniformTypeIdentifiers
import QuartzCore
import Combine

// --- Keyframe Animation Models ---

struct NexusAnimJointKeyframe: Codable, Sendable {
    let time: Double
    let rotation: [Float] // Quaternion [x, y, z, w]
    let position: [Float]? // Position [x, y, z] (optional)
}

struct NexusAnim: Codable, Sendable {
    let name: String
    let duration: Double
    let frameRate: Double
    let joints: [String: [NexusAnimJointKeyframe]]
}

// Ensure AvatarSkinConfig is Equatable for smart rebuilding
extension AvatarSkinConfig: Equatable {
    public static func == (lhs: AvatarSkinConfig, rhs: AvatarSkinConfig) -> Bool {
        return lhs.heightScale == rhs.heightScale &&
               lhs.weightScale == rhs.weightScale &&
               lhs.limbLength == rhs.limbLength &&
               lhs.skinTone == rhs.skinTone &&
               lhs.outfitStyle == rhs.outfitStyle &&
               lhs.auraColorR == rhs.auraColorR &&
               lhs.auraColorG == rhs.auraColorG &&
               lhs.auraColorB == rhs.auraColorB &&
               lhs.trailIntensity == rhs.trailIntensity &&
               lhs.hairstyle == rhs.hairstyle
    }
}

// --- Playback Engine View Model ---

@MainActor
final class Character3DPlaybackViewModel: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false {
        didSet {
            if isPlaying {
                startDisplayLink()
            } else {
                stopDisplayLink()
            }
        }
    }
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 2.0
    @Published var currentAnimationName: String = "Idle Walk"
    @Published var activeAnimation: NexusAnim?
    
    var builtInAnimations: [String: NexusAnim] = [:]
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0.0
    
    let supportedJoints = [
        "hip", "torso", "lowerTorso", "neck", "head",
        "shoulderL", "shoulderR", "lArm", "rArm",
        "lLeg", "rLeg", "kneeL", "kneeR", "lShin", "rShin",
        "lFoot", "rFoot"
    ]
    
    override init() {
        super.init()
        generateDefaultAnimations()
        loadAnimation(named: "Idle Walk")
    }
    
    func play() {
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
    
    func stop() {
        isPlaying = false
        currentTime = 0.0
    }
    
    func scrubTo(time: Double) {
        isPlaying = false
        currentTime = max(0.0, min(time, duration))
    }
    
    func loadAnimation(named name: String) {
        if let anim = builtInAnimations[name] {
            activeAnimation = anim
            duration = anim.duration
            currentAnimationName = anim.name
            currentTime = 0.0
        }
    }
    
    func loadCustomAnimation(_ anim: NexusAnim) {
        builtInAnimations[anim.name] = anim
        activeAnimation = anim
        duration = anim.duration
        currentAnimationName = anim.name
        currentTime = 0.0
        isPlaying = false
    }
    
    private func startDisplayLink() {
        displayLink?.invalidate()
        lastTimestamp = CACurrentMediaTime()
        let dl = CADisplayLink(target: self, selector: #selector(step(link:)))
        dl.add(to: .main, forMode: .common)
        displayLink = dl
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func step(link: CADisplayLink) {
        let current = CACurrentMediaTime()
        let elapsed = current - lastTimestamp
        lastTimestamp = current
        
        var nextTime = currentTime + elapsed
        if nextTime > duration {
            nextTime = nextTime.truncatingRemainder(dividingBy: duration)
        }
        currentTime = nextTime
    }
    
    // Euler to Quaternion helper [x, y, z, w]
    private func quaternionFromEuler(pitch: Float, yaw: Float, roll: Float) -> [Float] {
        let cy = cos(roll * 0.5)
        let sy = sin(roll * 0.5)
        let cp = cos(yaw * 0.5)
        let sp = sin(yaw * 0.5)
        let cr = cos(pitch * 0.5)
        let sr = sin(pitch * 0.5)
        
        let w = cr * cp * cy + sr * sp * sy
        let x = sr * cp * cy - cr * sp * sy
        let y = cr * sp * cy + sr * cp * sy
        let z = cr * cp * sy - sr * sp * cy
        
        return [x, y, z, w]
    }
    
    private func addJointRotation(joint: String, time: Double, pitch: Float, yaw: Float, roll: Float, to animJoints: inout [String: [NexusAnimJointKeyframe]]) {
        let q = quaternionFromEuler(pitch: pitch, yaw: yaw, roll: roll)
        let keyframe = NexusAnimJointKeyframe(time: time, rotation: q, position: nil)
        if animJoints[joint] == nil {
            animJoints[joint] = []
        }
        animJoints[joint]?.append(keyframe)
    }
    
    private func addJointKeyframe(joint: String, time: Double, pitch: Float, yaw: Float, roll: Float, position: [Float]?, to animJoints: inout [String: [NexusAnimJointKeyframe]]) {
        let q = quaternionFromEuler(pitch: pitch, yaw: yaw, roll: roll)
        let keyframe = NexusAnimJointKeyframe(time: time, rotation: q, position: position)
        if animJoints[joint] == nil {
            animJoints[joint] = []
        }
        animJoints[joint]?.append(keyframe)
    }
    
    private func generateDefaultAnimations() {
        // 1. Idle Walk (Smooth looping walk cycle)
        var idleJoints: [String: [NexusAnimJointKeyframe]] = [:]
        let idleDuration = 2.0
        let idleSteps = 20
        for i in 0...idleSteps {
            let t = Double(i) * (idleDuration / Double(idleSteps))
            let phase = Float(t * .pi * 2.0)
            
            // Hip bounces up/down and sways slightly
            let hipY = Float(0.94 + 0.03 * sin(phase))
            addJointKeyframe(joint: "hip", time: t, pitch: 0.0, yaw: 0.0, roll: 0.05 * sin(phase), position: [0.0, hipY, 0.0], to: &idleJoints)
            
            // Torso rotates opposite to hips
            addJointRotation(joint: "torso", time: t, pitch: 0.04 * cos(phase), yaw: 0.02 * sin(phase), roll: 0.0, to: &idleJoints)
            
            // Left and Right legs swing out of phase
            addJointRotation(joint: "lLeg", time: t, pitch: 0.35 * sin(phase), yaw: 0.0, roll: 0.0, to: &idleJoints)
            addJointRotation(joint: "rLeg", time: t, pitch: -0.35 * sin(phase), yaw: 0.0, roll: 0.0, to: &idleJoints)
            
            // Knees bend during swing phase (when leg is moving backward)
            let kneeLVal = sin(phase) < 0 ? 0.3 * abs(sin(phase)) : 0.05
            let kneeRVal = sin(phase) > 0 ? 0.3 * abs(sin(phase)) : 0.05
            addJointRotation(joint: "kneeL", time: t, pitch: kneeLVal, yaw: 0.0, roll: 0.0, to: &idleJoints)
            addJointRotation(joint: "kneeR", time: t, pitch: kneeRVal, yaw: 0.0, roll: 0.0, to: &idleJoints)
            
            // Arms swing out of phase with legs for balance
            addJointRotation(joint: "lArm", time: t, pitch: -0.25 * sin(phase), yaw: 0.0, roll: 0.25, to: &idleJoints)
            addJointRotation(joint: "rArm", time: t, pitch: 0.25 * sin(phase), yaw: 0.0, roll: -0.25, to: &idleJoints)
        }
        builtInAnimations["Idle Walk"] = NexusAnim(name: "Idle Walk", duration: idleDuration, frameRate: 30.0, joints: idleJoints)
        
        // 2. Jump Dunk (Crouch -> Jump -> Slam Apex -> Fall -> Land)
        var dunkJoints: [String: [NexusAnimJointKeyframe]] = [:]
        
        // Bind Pose (0.0s)
        addJointKeyframe(joint: "hip", time: 0.0, pitch: 0, yaw: 0, roll: 0, position: [0.0, 0.94, 0.0], to: &dunkJoints)
        addJointRotation(joint: "torso", time: 0.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "lArm", time: 0.0, pitch: 0, yaw: 0, roll: 0.25, to: &dunkJoints)
        addJointRotation(joint: "rArm", time: 0.0, pitch: 0, yaw: 0, roll: -0.25, to: &dunkJoints)
        addJointRotation(joint: "lLeg", time: 0.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "rLeg", time: 0.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeL", time: 0.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeR", time: 0.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        
        // Crouch (0.4s)
        addJointKeyframe(joint: "hip", time: 0.4, pitch: 0.05, yaw: 0, roll: 0, position: [0.0, 0.72, 0.0], to: &dunkJoints)
        addJointRotation(joint: "torso", time: 0.4, pitch: 0.2, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "lArm", time: 0.4, pitch: -0.6, yaw: 0, roll: 0.15, to: &dunkJoints)
        addJointRotation(joint: "rArm", time: 0.4, pitch: -0.6, yaw: 0, roll: -0.15, to: &dunkJoints)
        addJointRotation(joint: "lLeg", time: 0.4, pitch: 0.5, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "rLeg", time: 0.4, pitch: 0.5, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeL", time: 0.4, pitch: 0.6, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeR", time: 0.4, pitch: 0.6, yaw: 0, roll: 0, to: &dunkJoints)
        
        // Launch Rise (1.0s)
        addJointKeyframe(joint: "hip", time: 1.0, pitch: -0.05, yaw: 0, roll: 0, position: [0.0, 1.75, 0.0], to: &dunkJoints)
        addJointRotation(joint: "torso", time: 1.0, pitch: -0.1, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "lArm", time: 1.0, pitch: 1.5, yaw: 0, roll: 0.4, to: &dunkJoints)
        addJointRotation(joint: "rArm", time: 1.0, pitch: 1.5, yaw: 0, roll: -0.4, to: &dunkJoints)
        addJointRotation(joint: "lLeg", time: 1.0, pitch: -0.1, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "rLeg", time: 1.0, pitch: -0.1, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeL", time: 1.0, pitch: 0.1, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeR", time: 1.0, pitch: 0.1, yaw: 0, roll: 0, to: &dunkJoints)
        
        // Apex Dunk / Slam (1.5s)
        addJointKeyframe(joint: "hip", time: 1.5, pitch: 0.1, yaw: 0, roll: 0, position: [0.0, 2.3, 0.0], to: &dunkJoints)
        addJointRotation(joint: "torso", time: 1.5, pitch: 0.3, yaw: 0.1, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "lArm", time: 1.5, pitch: 1.2, yaw: 0, roll: 0.3, to: &dunkJoints)
        addJointRotation(joint: "rArm", time: 1.5, pitch: 0.3, yaw: 0, roll: -0.5, to: &dunkJoints) // Hard slam down
        addJointRotation(joint: "lLeg", time: 1.5, pitch: 0.3, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "rLeg", time: 1.5, pitch: 0.3, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeL", time: 1.5, pitch: 0.4, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeR", time: 1.5, pitch: 0.4, yaw: 0, roll: 0, to: &dunkJoints)
        
        // Landing (2.1s)
        addJointKeyframe(joint: "hip", time: 2.1, pitch: 0.05, yaw: 0, roll: 0, position: [0.0, 0.75, 0.0], to: &dunkJoints)
        addJointRotation(joint: "torso", time: 2.1, pitch: 0.15, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "lArm", time: 2.1, pitch: 0.1, yaw: 0, roll: 0.2, to: &dunkJoints)
        addJointRotation(joint: "rArm", time: 2.1, pitch: 0.1, yaw: 0, roll: -0.2, to: &dunkJoints)
        addJointRotation(joint: "lLeg", time: 2.1, pitch: 0.45, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "rLeg", time: 2.1, pitch: 0.45, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeL", time: 2.1, pitch: 0.55, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeR", time: 2.1, pitch: 0.55, yaw: 0, roll: 0, to: &dunkJoints)
        
        // Recover (3.0s)
        addJointKeyframe(joint: "hip", time: 3.0, pitch: 0, yaw: 0, roll: 0, position: [0.0, 0.94, 0.0], to: &dunkJoints)
        addJointRotation(joint: "torso", time: 3.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "lArm", time: 3.0, pitch: 0, yaw: 0, roll: 0.25, to: &dunkJoints)
        addJointRotation(joint: "rArm", time: 3.0, pitch: 0, yaw: 0, roll: -0.25, to: &dunkJoints)
        addJointRotation(joint: "lLeg", time: 3.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "rLeg", time: 3.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeL", time: 3.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        addJointRotation(joint: "kneeR", time: 3.0, pitch: 0, yaw: 0, roll: 0, to: &dunkJoints)
        builtInAnimations["Jump Dunk"] = NexusAnim(name: "Jump Dunk", duration: 3.0, frameRate: 30.0, joints: dunkJoints)
        
        // 3. Victory Wave (Raised waving hand)
        var waveJoints: [String: [NexusAnimJointKeyframe]] = [:]
        let waveDuration = 2.0
        let waveSteps = 20
        for i in 0...waveSteps {
            let t = Double(i) * (waveDuration / Double(waveSteps))
            let phase = Float(t * .pi * 2.0)
            
            addJointKeyframe(joint: "hip", time: t, pitch: 0, yaw: 0, roll: 0, position: [0.0, 0.94, 0.0], to: &waveJoints)
            addJointRotation(joint: "torso", time: t, pitch: 0, yaw: 0, roll: 0, to: &waveJoints)
            addJointRotation(joint: "lArm", time: t, pitch: 0.0, yaw: 0.0, roll: 0.25, to: &waveJoints)
            
            let waveAngle = Float(0.4 * sin(t * .pi * 4.0))
            addJointRotation(joint: "rArm", time: t, pitch: 1.3, yaw: waveAngle, roll: -1.0, to: &waveJoints)
            
            addJointRotation(joint: "lLeg", time: t, pitch: 0, yaw: 0, roll: 0, to: &waveJoints)
            addJointRotation(joint: "rLeg", time: t, pitch: 0, yaw: 0, roll: 0, to: &waveJoints)
            addJointRotation(joint: "kneeL", time: t, pitch: 0, yaw: 0, roll: 0, to: &waveJoints)
            addJointRotation(joint: "kneeR", time: t, pitch: 0, yaw: 0, roll: 0, to: &waveJoints)
        }
        builtInAnimations["Victory Wave"] = NexusAnim(name: "Victory Wave", duration: waveDuration, frameRate: 30.0, joints: waveJoints)
    }
}

// --- Main SwiftUI Character Preview View ---

struct Character3DPreviewView: View {
    let config: AvatarSkinConfig
    @State private var rotationY: Float = 0.0
    @State private var lastDragX: CGFloat = 0.0
    @State private var isFileImporterPresented: Bool = false
    
    @StateObject private var playbackVM = Character3DPlaybackViewModel()

    var body: some View {
        ZStack {
            // Viewport with standard character representable but linked to playback engine
            CharacterSCNViewRepresentable(
                config: config,
                rotationY: $rotationY,
                currentTime: playbackVM.currentTime,
                activeAnimation: playbackVM.activeAnimation
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = Float(value.translation.width - lastDragX) * 0.01
                        rotationY += delta
                        lastDragX = value.translation.width
                    }
                    .onEnded { _ in
                        lastDragX = 0.0
                    }
            )

            // Sci-fi HUD overlay on the 3D viewport
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("3D SCAN LINK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB))
                            .tracking(1.5)
                        Text("AVATAR_V1.1_MOCAP_ACTIVE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB))
                }
                .padding(12)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(10)

                Spacer()

                // --- SCI-FI MOCAP TIMELINE CONTROLLER ---
                VStack(spacing: 8) {
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(playbackVM.isPlaying ? Color.red : Color.gray)
                                .frame(width: 6, height: 6)
                            Text("MOCAP ENGINE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB))
                        }
                        Spacer()
                        Text(playbackVM.currentAnimationName.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    // Timeline Slider & Scrubber
                    HStack(spacing: 8) {
                        Text(String(format: "%0.2f s", playbackVM.currentTime))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .leading)
                        
                        Slider(value: Binding(
                            get: { playbackVM.currentTime },
                            set: { newValue in
                                playbackVM.scrubTo(time: newValue)
                            }
                        ), in: 0...playbackVM.duration)
                        .tint(Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB))
                        
                        Text(String(format: "%0.2f s", playbackVM.duration))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    // Controls Hub (Play, Pause, Stop, Load File Picker)
                    HStack(spacing: 16) {
                        Button(action: {
                            if playbackVM.isPlaying {
                                playbackVM.pause()
                            } else {
                                playbackVM.play()
                            }
                        }) {
                            Image(systemName: playbackVM.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB).opacity(0.35))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB).opacity(0.6), lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            playbackVM.stop()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Select Built-in Action Picker or Import
                        Menu {
                            Section("Preset Actions") {
                                ForEach(Array(playbackVM.builtInAnimations.keys).sorted(), id: \.self) { key in
                                    Button(action: {
                                        playbackVM.loadAnimation(named: key)
                                    }) {
                                        HStack {
                                            Text(key)
                                            if playbackVM.currentAnimationName == key {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Section("External Input") {
                                Button(action: {
                                    isFileImporterPresented = true
                                }) {
                                    Label("Import .nexusanim.json", systemImage: "arrow.down.doc.fill")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "opticaldisc.fill")
                                    .font(.system(size: 9))
                                Text("CLIP LIBRARY")
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

                HStack {
                    Text("DRAG TO ROTATE SCN")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Spacer()
                    Text(String(format: "AURA_INT: %.0f%%", config.trailIntensity * 100))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: config.auraColorR, green: config.auraColorG, blue: config.auraColorB))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground.opacity(0.6))
        )
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        let decoder = JSONDecoder()
                        let anim = try decoder.decode(NexusAnim.self, from: data)
                        playbackVM.loadCustomAnimation(anim)
                    } catch {
                        print("Failed to parse .nexusanim.json file: \(error)")
                    }
                }
            case .failure(let error):
                print("Failed to import file: \(error)")
            }
        }
    }
}

// --- SCNView Representable with Keyframe Rotations ---

private struct CharacterSCNViewRepresentable: UIViewRepresentable {
    let config: AvatarSkinConfig
    @Binding var rotationY: Float
    let currentTime: Double
    let activeAnimation: NexusAnim?
    
    class Coordinator: NSObject {
        var lastAppliedConfig: AvatarSkinConfig?
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100.0
        cameraNode.position = SCNVector3(x: 0, y: 1.1, z: 3.2)
        scene.rootNode.addChildNode(cameraNode)

        // Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.15, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        let mainLight = SCNNode()
        mainLight.light = SCNLight()
        mainLight.light?.type = .directional
        mainLight.light?.color = UIColor(white: 0.85, alpha: 1.0)
        mainLight.light?.castsShadow = true
        mainLight.position = SCNVector3(x: 5, y: 10, z: 5)
        scene.rootNode.addChildNode(mainLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.color = UIColor(red: CGFloat(config.auraColorR), green: CGFloat(config.auraColorG), blue: CGFloat(config.auraColorB), alpha: 1.0).withAlphaComponent(0.6)
        rimLight.position = SCNVector3(x: -5, y: 2, z: -5)
        scene.rootNode.addChildNode(rimLight)

        // Character Root Node
        let characterNode = SCNNode()
        characterNode.name = "character"
        characterNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(characterNode)

        // Build character parts
        rebuildCharacter(characterNode)

        // Spin action (slow auto-rotation when not dragged)
        let autoSpin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0.005, z: 0, duration: 0.1))
        characterNode.runAction(autoSpin, forKey: "autoSpin")

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if let characterNode = uiView.scene?.rootNode.childNode(withName: "character", recursively: false) {
            // Update rotation from binding
            characterNode.eulerAngles.y = rotationY

            // Rebuild character parts to reflect active customization ONLY when config changes
            if context.coordinator.lastAppliedConfig == nil || context.coordinator.lastAppliedConfig! != config {
                rebuildCharacter(characterNode)
                context.coordinator.lastAppliedConfig = config
            }
            
            // Apply slerp interpolated keyframe transformations
            if let anim = activeAnimation {
                applyAnimation(anim, to: characterNode, at: currentTime)
                applyFacialAnimation(to: characterNode, at: currentTime)
            }
        }
    }

    private func applyFacialAnimation(to characterNode: SCNNode, at time: Double) {
        guard let headNode = characterNode.childNode(withName: "head", recursively: true) else { return }
        if let activeScan = NexusFaceScanAssetPipeline.shared.recordedFaceScans.first {
            let duration = activeScan.header.duration
            if duration > 0 {
                let sampleTime = time.truncatingRemainder(dividingBy: duration)
                if let closestKeyframe = activeScan.keyframes.min(by: { abs($0.timestamp - sampleTime) < abs($1.timestamp - sampleTime) }) {
                    NexusFaceAnimationMapper.applyBlendshapes(closestKeyframe.blendshapes, to: headNode)
                }
            }
        }
    }

    // Programmatically updates joint orientations and root translations
    private func applyAnimation(_ anim: NexusAnim, to characterNode: SCNNode, at time: Double) {
        let hScale = Float(config.heightScale)
        let wScale = Float(config.weightScale)
        
        for jointName in anim.joints.keys {
            guard let node = characterNode.childNode(withName: jointName, recursively: true) else { continue }
            
            // 1. Interpolate joint rotation using Quaternion SLERP
            if let rot = interpolateRotation(for: jointName, at: time, in: anim) {
                node.orientation = rot
            }
            
            // 2. Interpolate joint position with custom body config scaling
            if let pos = interpolatePosition(for: jointName, at: time, in: anim) {
                var scaledPos = pos
                if jointName == "hip" {
                    scaledPos.y *= hScale
                    scaledPos.x *= wScale
                    scaledPos.z *= wScale
                }
                node.position = scaledPos
            }
        }
    }

    // Spherical Linear Interpolation (SLERP) for Quaternions
    private func slerp(q1: SCNVector4, q2: SCNVector4, t: Float) -> SCNVector4 {
        var dot = q1.x * q2.x + q1.y * q2.y + q1.z * q2.z + q1.w * q2.w
        var q2Selected = q2
        if dot < 0.0 {
            dot = -dot
            q2Selected = SCNVector4(-q2.x, -q2.y, -q2.z, -q2.w)
        }
        
        // Handle collinear or extremely close quaternions with Linear Interpolation (LERP)
        if dot > 0.9995 {
            let x = q1.x + t * (q2Selected.x - q1.x)
            let y = q1.y + t * (q2Selected.y - q1.y)
            let z = q1.z + t * (q2Selected.z - q1.z)
            let w = q1.w + t * (q2Selected.w - q1.w)
            let len = sqrt(x*x + y*y + z*z + w*w)
            return SCNVector4(x/len, y/len, z/len, w/len)
        }
        
        let theta_0 = acos(dot)
        let theta = theta_0 * t
        let sin_theta = sin(theta)
        let sin_theta_0 = sin(theta_0)
        
        let s0 = sin(theta_0 - theta) / sin_theta_0
        let s1 = sin_theta / sin_theta_0
        
        return SCNVector4(
            s0 * q1.x + s1 * q2Selected.x,
            s0 * q1.y + s1 * q2Selected.y,
            s0 * q1.z + s1 * q2Selected.z,
            s0 * q1.w + s1 * q2Selected.w
        )
    }

    private func interpolateRotation(for joint: String, at time: Double, in anim: NexusAnim) -> SCNVector4? {
        guard let keyframes = anim.joints[joint], !keyframes.isEmpty else { return nil }
        
        if keyframes.count == 1 {
            let q = keyframes[0].rotation
            guard q.count == 4 else { return nil }
            return SCNVector4(q[0], q[1], q[2], q[3])
        }
        
        var idx = 0
        while idx < keyframes.count && keyframes[idx].time < time {
            idx += 1
        }
        
        if idx == 0 {
            let q = keyframes[0].rotation
            guard q.count == 4 else { return nil }
            return SCNVector4(q[0], q[1], q[2], q[3])
        }
        if idx >= keyframes.count {
            let q = keyframes.last!.rotation
            guard q.count == 4 else { return nil }
            return SCNVector4(q[0], q[1], q[2], q[3])
        }
        
        let k1 = keyframes[idx - 1]
        let k2 = keyframes[idx]
        
        let span = k2.time - k1.time
        guard span > 0.0001 else {
            let q = k2.rotation
            guard q.count == 4 else { return nil }
            return SCNVector4(q[0], q[1], q[2], q[3])
        }
        
        let factor = Float((time - k1.time) / span)
        
        guard k1.rotation.count == 4 && k2.rotation.count == 4 else { return nil }
        let q1 = SCNVector4(k1.rotation[0], k1.rotation[1], k1.rotation[2], k1.rotation[3])
        let q2 = SCNVector4(k2.rotation[0], k2.rotation[1], k2.rotation[2], k2.rotation[3])
        
        return slerp(q1: q1, q2: q2, t: factor)
    }

    private func interpolatePosition(for joint: String, at time: Double, in anim: NexusAnim) -> SCNVector3? {
        guard let keyframes = anim.joints[joint], !keyframes.isEmpty else { return nil }
        
        let posKeyframes = keyframes.filter { $0.position != nil }
        guard !posKeyframes.isEmpty else { return nil }
        
        if posKeyframes.count == 1 {
            let p = posKeyframes[0].position!
            guard p.count == 3 else { return nil }
            return SCNVector3(p[0], p[1], p[2])
        }
        
        var idx = 0
        while idx < posKeyframes.count && posKeyframes[idx].time < time {
            idx += 1
        }
        
        if idx == 0 {
            let p = posKeyframes[0].position!
            guard p.count == 3 else { return nil }
            return SCNVector3(p[0], p[1], p[2])
        }
        if idx >= posKeyframes.count {
            let p = posKeyframes.last!.position!
            guard p.count == 3 else { return nil }
            return SCNVector3(p[0], p[1], p[2])
        }
        
        let k1 = posKeyframes[idx - 1]
        let k2 = posKeyframes[idx]
        
        let span = k2.time - k1.time
        guard span > 0.0001 else {
            let p = k2.position!
            guard p.count == 3 else { return nil }
            return SCNVector3(p[0], p[1], p[2])
        }
        
        let factor = Float((time - k1.time) / span)
        
        guard let p1 = k1.position, let p2 = k2.position, p1.count == 3 && p2.count == 3 else { return nil }
        let x = p1[0] + factor * (p2[0] - p1[0])
        let y = p1[1] + factor * (p2[1] - p1[1])
        let z = p1[2] + factor * (p2[2] - p1[2])
        
        return SCNVector3(x, y, z)
    }

    private func rebuildCharacter(_ root: SCNNode) {
        // Remove existing children to rebuild cleanly
        root.childNodes.forEach { $0.removeFromParentNode() }

        let skinColor = skinToneColor(config.skinTone)
        let primaryMat = SCNMaterial()
        primaryMat.diffuse.contents = skinColor
        primaryMat.metalness.contents = 0.3
        primaryMat.roughness.contents = 0.4

        let jointMat = SCNMaterial()
        jointMat.diffuse.contents = UIColor(red: CGFloat(config.auraColorR), green: CGFloat(config.auraColorG), blue: CGFloat(config.auraColorB), alpha: 1.0)
        jointMat.emission.contents = jointMat.diffuse.contents

        // Outfit material mapping
        let outfitMat = SCNMaterial()
        switch config.outfitStyle {
        case .standard:
            outfitMat.diffuse.contents = UIColor.darkGray
            outfitMat.roughness.contents = 0.6
        case .developing:
            outfitMat.diffuse.contents = UIColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1)
            outfitMat.emission.contents = UIColor(red: 0.05, green: 0.15, blue: 0.4, alpha: 1)
        case .flight:
            outfitMat.diffuse.contents = UIColor(red: 0.0, green: 0.6, blue: 0.8, alpha: 1)
            outfitMat.emission.contents = UIColor(red: 0.0, green: 0.3, blue: 0.5, alpha: 1)
        case .elite:
            outfitMat.diffuse.contents = UIColor(red: 0.4, green: 0.1, blue: 0.7, alpha: 1)
            outfitMat.emission.contents = UIColor(red: 0.2, green: 0.05, blue: 0.4, alpha: 1)
            outfitMat.metalness.contents = 0.8
        case .neon:
            outfitMat.diffuse.contents = UIColor.black
            outfitMat.emission.contents = UIColor(red: 0, green: 0.95, blue: 0.9, alpha: 1)
            outfitMat.metalness.contents = 0.1
        case .shadow:
            outfitMat.diffuse.contents = UIColor(white: 0.05, alpha: 1)
            outfitMat.emission.contents = UIColor(red: 0.95, green: 0.3, blue: 0.1, alpha: 1).withAlphaComponent(0.2)
            outfitMat.roughness.contents = 0.9
        case .chrome:
            outfitMat.diffuse.contents = UIColor(white: 0.9, alpha: 1)
            outfitMat.metalness.contents = 1.0
            outfitMat.roughness.contents = 0.05
        case .gold:
            outfitMat.diffuse.contents = UIColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1)
            outfitMat.metalness.contents = 0.9
            outfitMat.roughness.contents = 0.1
        }

        // Apply scales
        let hScale = Float(config.heightScale)
        let wScale = Float(config.weightScale)
        let lScale = Float(config.limbLength)

        // 1. Head
        let headNode = SCNNode(geometry: SCNSphere(radius: 0.12))
        headNode.position = SCNVector3(0, 1.8 * hScale, 0)
        headNode.geometry?.materials = [primaryMat]
        headNode.name = "head"
        root.addChildNode(headNode)
        
        // Add procedural facial features
        NexusFaceAnimationMapper.addFacialFeatures(to: headNode)

        // Visor/Eyes
        let visorNode = SCNNode(geometry: SCNBox(width: 0.18, height: 0.04, length: 0.03, chamferRadius: 0.01))
        visorNode.position = SCNVector3(0, 0, 0.11)
        visorNode.geometry?.materials = [jointMat]
        visorNode.name = "visor"
        headNode.addChildNode(visorNode)

        // Hairstyle
        addHairstyle(config.hairstyle, to: headNode, color: skinColor)

        // 2. Neck
        let neckNode = SCNNode(geometry: SCNSphere(radius: 0.04))
        neckNode.position = SCNVector3(0, 1.66 * hScale, 0)
        neckNode.geometry?.materials = [jointMat]
        neckNode.name = "neck"
        root.addChildNode(neckNode)

        // 3. Torso (Upper & Lower)
        let upperTorsoNode = SCNNode(geometry: SCNCapsule(capRadius: CGFloat(0.08 * wScale), height: CGFloat(0.38 * hScale)))
        upperTorsoNode.position = SCNVector3(0, 1.42 * hScale, 0)
        upperTorsoNode.geometry?.materials = [outfitMat]
        upperTorsoNode.name = "torso"
        root.addChildNode(upperTorsoNode)

        let lowerTorsoNode = SCNNode(geometry: SCNCapsule(capRadius: CGFloat(0.07 * wScale), height: CGFloat(0.28 * hScale)))
        lowerTorsoNode.position = SCNVector3(0, 1.12 * hScale, 0)
        lowerTorsoNode.geometry?.materials = [outfitMat]
        lowerTorsoNode.name = "lowerTorso"
        root.addChildNode(lowerTorsoNode)

        // 4. Shoulders & Arms
        let shoulderOffset = Float(0.24 * wScale)
        let shoulderL = SCNNode(geometry: SCNSphere(radius: 0.045))
        shoulderL.position = SCNVector3(-shoulderOffset, 1.54 * hScale, 0)
        shoulderL.geometry?.materials = [jointMat]
        shoulderL.name = "shoulderL"
        root.addChildNode(shoulderL)

        let shoulderR = SCNNode(geometry: SCNSphere(radius: 0.045))
        shoulderR.position = SCNVector3(shoulderOffset, 1.54 * hScale, 0)
        shoulderR.geometry?.materials = [jointMat]
        shoulderR.name = "shoulderR"
        root.addChildNode(shoulderR)

        let armLength = CGFloat(0.34 * lScale)
        let upperArmL = SCNNode(geometry: SCNCapsule(capRadius: 0.03, height: armLength))
        upperArmL.position = SCNVector3(-shoulderOffset - 0.04, 1.36 * hScale, 0)
        upperArmL.eulerAngles.z = 0.25
        upperArmL.geometry?.materials = [outfitMat]
        upperArmL.name = "lArm"
        root.addChildNode(upperArmL)

        let upperArmR = SCNNode(geometry: SCNCapsule(capRadius: 0.03, height: armLength))
        upperArmR.position = SCNVector3(shoulderOffset + 0.04, 1.36 * hScale, 0)
        upperArmR.eulerAngles.z = -0.25
        upperArmR.geometry?.materials = [outfitMat]
        upperArmR.name = "rArm"
        root.addChildNode(upperArmR)

        // 5. Hip & Legs
        let hipNode = SCNNode(geometry: SCNSphere(radius: CGFloat(0.06 * wScale)))
        hipNode.position = SCNVector3(0, 0.94 * hScale, 0)
        hipNode.geometry?.materials = [jointMat]
        hipNode.name = "hip"
        root.addChildNode(hipNode)

        let legOffset = Float(0.10 * wScale)
        let legLength = CGFloat(0.44 * lScale)

        let upperLegL = SCNNode(geometry: SCNCapsule(capRadius: 0.04, height: legLength))
        upperLegL.position = SCNVector3(-legOffset, 0.72 * hScale, 0)
        upperLegL.geometry?.materials = [outfitMat]
        upperLegL.name = "lLeg"
        root.addChildNode(upperLegL)

        let upperLegR = SCNNode(geometry: SCNCapsule(capRadius: 0.04, height: legLength))
        upperLegR.position = SCNVector3(legOffset, 0.72 * hScale, 0)
        upperLegR.geometry?.materials = [outfitMat]
        upperLegR.name = "rLeg"
        root.addChildNode(upperLegR)

        let kneeL = SCNNode(geometry: SCNSphere(radius: 0.035))
        kneeL.position = SCNVector3(-legOffset, 0.48 * hScale, 0)
        kneeL.geometry?.materials = [jointMat]
        kneeL.name = "kneeL"
        root.addChildNode(kneeL)

        let kneeR = SCNNode(geometry: SCNSphere(radius: 0.035))
        kneeR.position = SCNVector3(legOffset, 0.48 * hScale, 0)
        kneeR.geometry?.materials = [jointMat]
        kneeR.name = "kneeR"
        root.addChildNode(kneeR)

        let shinLength = CGFloat(0.40 * lScale)
        let shinL = SCNNode(geometry: SCNCapsule(capRadius: 0.035, height: shinLength))
        shinL.position = SCNVector3(-legOffset, 0.26 * hScale, 0)
        shinL.geometry?.materials = [primaryMat]
        shinL.name = "lShin"
        root.addChildNode(shinL)

        let shinR = SCNNode(geometry: SCNCapsule(capRadius: 0.035, height: shinLength))
        shinR.position = SCNVector3(legOffset, 0.26 * hScale, 0)
        shinR.geometry?.materials = [primaryMat]
        shinR.name = "rShin"
        root.addChildNode(shinR)

        // Feet
        let footL = SCNNode(geometry: SCNBox(width: 0.06, height: 0.03, length: 0.12, chamferRadius: 0.01))
        footL.position = SCNVector3(-legOffset, 0.03, 0.03)
        footL.geometry?.materials = [outfitMat]
        footL.name = "lFoot"
        root.addChildNode(footL)

        let footR = SCNNode(geometry: SCNBox(width: 0.06, height: 0.03, length: 0.12, chamferRadius: 0.01))
        footR.position = SCNVector3(legOffset, 0.03, 0.03)
        footR.geometry?.materials = [outfitMat]
        footR.name = "rFoot"
        root.addChildNode(footR)

        // 6. Aura Ring/Emitters (if trail intensity is high)
        if config.trailIntensity > 0.1 {
            let auraRing = SCNTorus(ringRadius: CGFloat(0.28 * wScale), pipeRadius: 0.01)
            let auraMat = SCNMaterial()
            let auraColor = UIColor(red: CGFloat(config.auraColorR), green: CGFloat(config.auraColorG), blue: CGFloat(config.auraColorB), alpha: 1.0)
            auraMat.diffuse.contents = auraColor.withAlphaComponent(0.2)
            auraMat.emission.contents = auraColor.withAlphaComponent(CGFloat(config.trailIntensity))
            auraRing.materials = [auraMat]
            let auraNode = SCNNode(geometry: auraRing)
            auraNode.position = SCNVector3(0, 1.12 * hScale, 0)
            auraNode.eulerAngles.x = Float.pi / 2
            auraNode.name = "aura"
            root.addChildNode(auraNode)

            // Spin the aura ring
            let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: 0.02, duration: 0.1))
            auraNode.runAction(spin)
        }
    }

    private func addHairstyle(_ style: AvatarHairstyle, to head: SCNNode, color: UIColor) {
        let hairMat = SCNMaterial()
        hairMat.diffuse.contents = UIColor.black
        hairMat.roughness.contents = 0.8

        switch style {
        case .buzzcut:
            let hairGeo = SCNSphere(radius: 0.125)
            hairGeo.materials = [hairMat]
            let hairNode = SCNNode(geometry: hairGeo)
            hairNode.position = SCNVector3(0, 0.01, 0)
            hairNode.name = "hair_buzzcut"
            head.addChildNode(hairNode)

        case .mohawk:
            let hairGeo = SCNBox(width: 0.03, height: 0.06, length: 0.18, chamferRadius: 0.01)
            hairGeo.materials = [hairMat]
            let hairNode = SCNNode(geometry: hairGeo)
            hairNode.position = SCNVector3(0, 0.11, 0)
            hairNode.name = "hair_mohawk"
            head.addChildNode(hairNode)

        case .dreadlocks:
            for i in 0..<6 {
                let strandGeo = SCNCapsule(capRadius: 0.01, height: 0.12)
                strandGeo.materials = [hairMat]
                let strandNode = SCNNode(geometry: strandGeo)
                let angle = Float(i) * (Float.pi / 2.5) - (Float.pi / 2)
                strandNode.position = SCNVector3(sin(angle) * 0.1, 0.02, cos(angle) * 0.1)
                strandNode.eulerAngles.z = sin(angle) * 0.4
                strandNode.eulerAngles.x = cos(angle) * 0.4
                strandNode.name = "hair_dreadlock_\(i)"
                head.addChildNode(strandNode)
            }

        case .undercut:
            let hairGeo = SCNSphere(radius: 0.128)
            hairGeo.materials = [hairMat]
            let hairNode = SCNNode(geometry: hairGeo)
            hairNode.position = SCNVector3(0, 0.02, 0)
            hairNode.name = "hair_undercut"
            head.addChildNode(hairNode)

            // Add side shaved look
            let sideGeo = SCNSphere(radius: 0.122)
            let sideMat = SCNMaterial()
            sideMat.diffuse.contents = color.withAlphaComponent(0.6)
            sideGeo.materials = [sideMat]
            let sideNode = SCNNode(geometry: sideGeo)
            sideNode.position = SCNVector3(0, 0.01, 0)
            sideNode.name = "hair_undercut_shaved"
            head.addChildNode(sideNode)

        case .ponytail:
            let hairGeo = SCNSphere(radius: 0.125)
            hairGeo.materials = [hairMat]
            let hairNode = SCNNode(geometry: hairGeo)
            hairNode.position = SCNVector3(0, 0.01, 0)
            hairNode.name = "hair_ponytail"
            head.addChildNode(hairNode)

            let tailGeo = SCNCapsule(capRadius: 0.015, height: 0.18)
            tailGeo.materials = [hairMat]
            let tailNode = SCNNode(geometry: tailGeo)
            tailNode.position = SCNVector3(0, -0.06, -0.12)
            tailNode.eulerAngles.x = -Float.pi / 4
            tailNode.name = "hair_ponytail_strand"
            head.addChildNode(tailNode)

        case .none:
            break
        }
    }

    private func skinToneColor(_ tone: AvatarSkinTone) -> UIColor {
        switch tone {
        case .cyan: return UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)
        case .blue: return UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1)
        case .green: return UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1)
        case .elitePurple: return UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1)
        case .orange: return UIColor.orange
        }
    }
}

// MARK: - Shared mini-self viewport (movement catalogue, workouts, training hub)

/// PRQ scan skin + equipped creator card — same procedural rig as NEXUS gameplay.
struct NexusMiniSelfPreviewView: View {
    let profile: UserProfile
    var layout: Layout = .standard
    var previewHeight: CGFloat = 220
    var motionNote: String? = nil
    var prqLabel: String? = nil

    enum Layout {
        case standard
        case compact
    }

    private var equippedCard: CreatorCard? {
        CreatorCard.activeCard(for: profile)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout == .compact ? 6 : 8) {
            headerRow
            Character3DPreviewView(config: profile.avatarConfig)
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: layout == .compact ? 14 : 16))
            if let motionNote, !motionNote.isEmpty {
                Text(motionNote)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR 3D MINI-SELF")
                    .font(.system(.caption2, design: .monospaced, weight: .black))
                    .foregroundStyle(Theme.brandCyan)
                if let card = equippedCard {
                    Text("CREATOR SKIN · \(card.creatorName.uppercased())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(card.accentColor)
                }
                if let prqLabel {
                    Text(prqLabel)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandBlue.opacity(0.85))
                }
            }
            Spacer(minLength: 8)
            FELPreviewLabel(text: FELPremiumCopy.Preview.sceneKitStub)
        }
    }
}

extension NexusMiniSelfPreviewView {
    static func prqPrescriptionLabel(for profile: UserProfile) -> String {
        let prq = Int(profile.metrics.prqScore.rounded())
        let track = profile.systemScan?.recommendedTrack ?? profile.goal ?? "General"
        return "PRQ \(prq) · \(track) prescription"
    }
}
