import SwiftUI
import SceneKit
import Vision
import AVFoundation

struct NexusMoCapStudioView: View {
    let viewModel: LabViewModel
    
    @StateObject private var mocapEngine = NexusMotionCaptureEngine()
    @StateObject private var assetPipeline = NexusMovementAssetPipeline.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: StudioTab = .studio
    @State private var selectedMovementType = "Vertical Jump"
    @State private var selectedAnimation: NexusMovementCaptureAsset?
    
    // Playback state
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0.0
    @State private var playbackTimer: Timer?
    @State private var currentFrameIndex = 0
    
    // Share sheet state
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    
    enum StudioTab: String, CaseIterable {
        case studio = "Studio"
        case vault = "Vault"
    }
    
    let movementTypes = [
        "Vertical Jump",
        "Back Squat",
        "Roundhouse Kick",
        "Sprint Start",
        "Lateral Shuffling"
    ]
    
    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            Theme.meshGradient.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tab Selector
                tabSelector
                
                if selectedTab == .studio {
                    studioTabContent
                } else {
                    vaultTabContent
                }
            }
        }
        .onAppear {
            assetPipeline.loadRecordedAnimations()
        }
        .onDisappear {
            mocapEngine.stopCaptureSession()
            stopPlayback()
        }
        .sheet(isPresented: $showShareSheet, content: {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        })
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXUS MOTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue)
                    .tracking(2)
                Text("3D MoCap Studio")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(StudioTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                        if tab == .studio {
                            stopPlayback()
                        } else {
                            mocapEngine.stopCaptureSession()
                        }
                    }
                } label: {
                    Text(tab.rawValue.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(selectedTab == tab ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Theme.brandCyan : Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Studio Tab (Live MoCap)
    
    private var studioTabContent: some View {
        VStack(spacing: 16) {
            // 3D Preview Viewport
            ZStack {
                MoCapSCNViewRepresentable(
                    joints: mocapEngine.capturedJoints,
                    keyframe: nil,
                    isLive: true
                )
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.brandBlue.opacity(0.3), .clear, Theme.brandCyan.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                
                // Live camera overlay (small floating window)
                VStack {
                    HStack {
                        Spacer()
                        CameraPreviewOverlayView(engine: mocapEngine)
                            .frame(width: 90, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.brandCyan.opacity(0.5), lineWidth: 1)
                            )
                            .padding(16)
                    }
                    Spacer()
                }
                
                // Sci-Fi tracking HUD
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(mocapEngine.isTrackingActive ? Theme.neonGreen : .red)
                                    .frame(width: 6, height: 6)
                                    .symbolEffect(.pulse, isActive: mocapEngine.isTrackingActive)
                                Text(mocapEngine.isTrackingActive ? "TRACKING ACTIVE" : "CAMERA IDLE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(mocapEngine.isTrackingActive ? Theme.neonGreen : .red)
                            }
                            Text("ENGINE: VISION_3D_POSE_V1.0")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        if mocapEngine.isTrackingActive {
                            Text("FPS: 30")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(12)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            
            // Controls Panel
            VStack(spacing: 14) {
                // Movement Type Picker
                HStack {
                    Text("MOVEMENT TYPE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Picker("Movement", selection: $selectedMovementType) {
                        ForEach(movementTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.brandCyan)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                
                // Record Button
                HStack(spacing: 16) {
                    Button {
                        if mocapEngine.isSessionRunning {
                            mocapEngine.stopCaptureSession()
                        } else {
                            mocapEngine.startCaptureSession()
                        }
                    } label: {
                        HStack {
                            Image(systemName: mocapEngine.isSessionRunning ? "camera.fill" : "camera.badge.ellipsis")
                            Text(mocapEngine.isSessionRunning ? "STOP CAMERA" : "START CAMERA")
                        }
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(mocapEngine.isSessionRunning ? Color.red.opacity(0.2) : Theme.brandBlue.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(mocapEngine.isSessionRunning ? Color.red : Theme.brandBlue, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if assetPipeline.isRecording {
                            if let asset = assetPipeline.stopRecording() {
                                selectedAnimation = asset
                                withAnimation {
                                    selectedTab = .vault
                                }
                            }
                        } else {
                            assetPipeline.startRecording(
                                athleteID: viewModel.profile.id,
                                movementType: selectedMovementType
                            )
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(assetPipeline.isRecording ? .red : .white)
                                .frame(width: 8, height: 8)
                                .symbolEffect(.pulse, isActive: assetPipeline.isRecording)
                            Text(assetPipeline.isRecording ? "STOP RECORD" : "RECORD")
                        }
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(assetPipeline.isRecording ? .red : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(assetPipeline.isRecording ? .clear : Theme.brandCyan)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(assetPipeline.isRecording ? Color.red : .clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!mocapEngine.isSessionRunning)
                    .opacity(mocapEngine.isSessionRunning ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onReceive(mocapEngine.$capturedJoints) { joints in
            if assetPipeline.isRecording && !joints.isEmpty {
                assetPipeline.addKeyframe(joints: joints, rotations: mocapEngine.capturedRotations)
            }
        }
    }
    
    // MARK: - Vault Tab (Playback & Saved Captures)
    
    private var vaultTabContent: some View {
        VStack(spacing: 16) {
            if assetPipeline.recordedAnimations.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.brandBlue.opacity(0.4))
                    Text("No Recorded Captures")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Go to Studio and record your first movement.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                // 3D Preview Viewport
                ZStack {
                    MoCapSCNViewRepresentable(
                        joints: [:],
                        keyframe: currentKeyframe,
                        isLive: false
                    )
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandBlue.opacity(0.3), .clear, Theme.brandCyan.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    
                    // Floating joint angle inspector
                    if let keyframe = currentKeyframe {
                        VStack {
                            Spacer()
                            HStack {
                                JointAngleInspectorCard(keyframe: keyframe)
                                    .frame(width: 160)
                                    .padding(16)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Playback controls & Timeline
                VStack(spacing: 14) {
                    if let selected = selectedAnimation ?? assetPipeline.recordedAnimations.first {
                        // Timeline Scrubber
                        VStack(spacing: 6) {
                            HStack {
                                Text(selected.header.movementType.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.brandCyan)
                                Spacer()
                                Text(String(format: "%.2fs / %.2fs", currentTimestamp, selected.header.duration))
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Slider(value: $playbackProgress, in: 0...1.0) { editing in
                                if editing {
                                    stopPlayback()
                                } else {
                                    jumpToProgress(playbackProgress)
                                }
                            }
                            .tint(Theme.brandCyan)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        
                        // Play/Pause & Export/Share Panel
                        HStack(spacing: 12) {
                            Button {
                                if isPlaying {
                                    stopPlayback()
                                } else {
                                    startPlayback(for: selected)
                                }
                            } label: {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.black)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(Theme.brandCyan))
                            }
                            .buttonStyle(.plain)
                            
                            // Share to Feed Button
                            Button {
                                SocialShareCoordinator.shared.composerDraft = SocialFeedDraft(
                                    content: "Captured 3D MoCap: \(selected.header.movementType) — \(String(format: "%.1f", selected.header.duration))s at \(Int(selected.header.frameRate)) FPS",
                                    gameModeId: nil,
                                    trainingScore: Double(selected.header.jointCount),
                                    clipUrl: nil,
                                    feedSource: "mocap_capture"
                                )
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("SHARE TO FEED")
                                }
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Theme.elitePurple.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Theme.elitePurple, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Export Button
                            Button {
                                if let url = assetPipeline.exportAnimationAsJson(selected) {
                                    exportURL = url
                                    showShareSheet = true
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(Theme.cardBorder, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Saved Captures List
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(assetPipeline.recordedAnimations) { anim in
                                Button {
                                    withAnimation {
                                        selectedAnimation = anim
                                        jumpToProgress(0)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(anim.header.movementType)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                        Text(String(format: "%.1fs · %d joints", anim.header.duration, anim.header.jointCount))
                                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill((selectedAnimation ?? assetPipeline.recordedAnimations.first)?.id == anim.id ? Theme.brandBlue.opacity(0.2) : Color.white.opacity(0.03))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke((selectedAnimation ?? assetPipeline.recordedAnimations.first)?.id == anim.id ? Theme.brandBlue : Theme.cardBorder, lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .frame(height: 48)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Playback Logic
    
    private var currentKeyframe: NexusMovementCaptureAsset.Keyframe? {
        let anim = selectedAnimation ?? assetPipeline.recordedAnimations.first
        guard let keyframes = anim?.keyframes, !keyframes.isEmpty else { return nil }
        return keyframes[safe: currentFrameIndex] ?? keyframes.first
    }
    
    private var currentTimestamp: Double {
        currentKeyframe?.timestamp ?? 0.0
    }
    
    private func startPlayback(for asset: NexusMovementCaptureAsset) {
        stopPlayback()
        isPlaying = true
        
        let interval = 1.0 / asset.header.frameRate
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard currentFrameIndex < asset.keyframes.count - 1 else {
                stopPlayback()
                currentFrameIndex = 0
                playbackProgress = 0
                return
            }
            currentFrameIndex += 1
            playbackProgress = Double(currentFrameIndex) / Double(asset.keyframes.count - 1)
        }
    }
    
    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func jumpToProgress(_ progress: Double) {
        let anim = selectedAnimation ?? assetPipeline.recordedAnimations.first
        guard let count = anim?.keyframes.count, count > 0 else { return }
        currentFrameIndex = Int(progress * Double(count - 1))
    }
}

// MARK: - Camera Preview Overlay

struct CameraPreviewOverlayView: UIViewRepresentable {
    let engine: NexusMotionCaptureEngine
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Setup AVCaptureVideoPreviewLayer if we have access to the session
        // Note: In simulator, this will just be a black/gray box with a camera icon
        #if !targetEnvironment(simulator)
        // In real device, AVCaptureVideoPreviewLayer can be linked to the session
        #endif
        
        let icon = UIImageView(image: UIImage(systemName: "camera.fill"))
        icon.tintColor = .white.withAlphaComponent(0.3)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(icon)
        
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - SceneKit View Representable for MoCap Mannequin

struct MoCapSCNViewRepresentable: UIViewRepresentable {
    let joints: [String: SCNVector3]
    let keyframe: NexusMovementCaptureAsset.Keyframe?
    let isLive: Bool
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100.0
        cameraNode.position = SCNVector3(x: 0, y: 0.8, z: 2.5)
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
        mainLight.position = SCNVector3(x: 5, y: 10, z: 5)
        scene.rootNode.addChildNode(mainLight)
        
        // Grid Floor
        let gridNode = SCNNode()
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = UIColor(white: 0.05, alpha: 1.0)
        floor.firstMaterial?.emission.contents = UIColor(red: 0, green: 0.1, blue: 0.2, alpha: 1.0)
        floor.reflectivity = 0.2
        gridNode.geometry = floor
        gridNode.position = SCNVector3(0, -0.8, 0)
        scene.rootNode.addChildNode(gridNode)
        
        // Mannequin Rig
        let mannequin = NexusMotionCaptureEngine.buildMannequinRig()
        mannequin.name = "mannequin"
        mannequin.position = SCNVector3(0, -0.4, 0)
        scene.rootNode.addChildNode(mannequin)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let mannequin = uiView.scene?.rootNode.childNode(withName: "mannequin", recursively: true) else { return }
        
        if isLive {
            if !joints.isEmpty {
                NexusMotionCaptureEngine.retarget(joints: joints, to: mannequin)
            } else {
                // Return to T-pose/Default pose if no joints tracked
                let tPose = defaultTPose()
                NexusMotionCaptureEngine.retarget(joints: tPose, to: mannequin)
            }
        } else if let keyframe = keyframe {
            var mappedJoints: [String: SCNVector3] = [:]
            for (name, transform) in keyframe.joints {
                mappedJoints[name] = SCNVector3(transform.translation[0], transform.translation[1], transform.translation[2])
            }
            NexusMotionCaptureEngine.retarget(joints: mappedJoints, to: mannequin)
        }
    }
    
    private func defaultTPose() -> [String: SCNVector3] {
        return [
            "root": SCNVector3(0, 0, 0),
            "spine": SCNVector3(0, 0.3, 0),
            "centerShoulder": SCNVector3(0, 0.6, 0),
            "centerHead": SCNVector3(0, 0.75, 0),
            "topHead": SCNVector3(0, 0.9, 0),
            "leftShoulder": SCNVector3(-0.2, 0.6, 0),
            "leftElbow": SCNVector3(-0.45, 0.6, 0),
            "leftWrist": SCNVector3(-0.7, 0.6, 0),
            "rightShoulder": SCNVector3(0.2, 0.6, 0),
            "rightElbow": SCNVector3(0.45, 0.6, 0),
            "rightWrist": SCNVector3(0.7, 0.6, 0),
            "leftHip": SCNVector3(-0.12, -0.1, 0),
            "leftKnee": SCNVector3(-0.12, -0.45, 0),
            "leftAnkle": SCNVector3(-0.12, -0.8, 0),
            "rightHip": SCNVector3(0.12, -0.1, 0),
            "rightKnee": SCNVector3(0.12, -0.45, 0),
            "rightAnkle": SCNVector3(0.12, -0.8, 0)
        ]
    }
}

// MARK: - Joint Angle Inspector Card

struct JointAngleInspectorCard: View {
    let keyframe: NexusMovementCaptureAsset.Keyframe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JOINT ANGLES")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(1.5)
            
            VStack(spacing: 6) {
                angleRow(label: "L KNEE", angle: calculateKneeAngle(side: "left"))
                angleRow(label: "R KNEE", angle: calculateKneeAngle(side: "right"))
                angleRow(label: "L HIP", angle: calculateHipAngle(side: "left"))
                angleRow(label: "R HIP", angle: calculateHipAngle(side: "right"))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
    
    private func angleRow(label: String, angle: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(String(format: "%.1f°", angle))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
    
    private func calculateKneeAngle(side: String) -> Double {
        guard let hip = keyframe.joints["\(side)Hip"]?.translation,
              let knee = keyframe.joints["\(side)Knee"]?.translation,
              let ankle = keyframe.joints["\(side)Ankle"]?.translation else {
            return 180.0
        }
        
        let thigh = SCNVector3(knee[0] - hip[0], knee[1] - hip[1], knee[2] - hip[2])
        let shin = SCNVector3(ankle[0] - knee[0], ankle[1] - knee[1], ankle[2] - knee[2])
        
        return angleBetween(v1: thigh, v2: shin)
    }
    
    private func calculateHipAngle(side: String) -> Double {
        guard let spine = keyframe.joints["spine"]?.translation,
              let root = keyframe.joints["root"]?.translation,
              let hip = keyframe.joints["\(side)Hip"]?.translation,
              let knee = keyframe.joints["\(side)Knee"]?.translation else {
            return 180.0
        }
        
        let torso = SCNVector3(spine[0] - root[0], spine[1] - root[1], spine[2] - root[2])
        let thigh = SCNVector3(knee[0] - hip[0], knee[1] - hip[1], knee[2] - hip[2])
        
        return angleBetween(v1: torso, v2: thigh)
    }
    
    private func angleBetween(v1: SCNVector3, v2: SCNVector3) -> Double {
        let simd1 = simd_normalize(simd_float3(v1.x, v1.y, v1.z))
        let simd2 = simd_normalize(simd_float3(v2.x, v2.y, v2.z))
        let dot = simd_dot(simd1, simd2)
        let angleRad = acos(max(-1.0, min(1.0, dot)))
        return Double(angleRad) * 180.0 / .pi
    }
}

// MARK: - Share Sheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
