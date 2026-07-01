import SwiftUI
import ARKit
import SceneKit

struct NexusFaceScanView: View {
    let viewModel: LabViewModel
    
    @StateObject private var faceEngine = NexusLiveLinkFaceEngine()
    @StateObject private var assetPipeline = NexusFaceScanAssetPipeline.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: StudioTab = .studio
    @State private var selectedFaceScan: NexusFaceScanAsset?
    
    // Playback state
    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0.0
    @State private var playbackTimer: Timer?
    @State private var currentFrameIndex = 0
    @State private var activeBlendshapes: [String: Float] = [:]
    
    // Share sheet state
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    
    enum StudioTab: String, CaseIterable {
        case studio = "Studio"
        case vault = "Vault"
    }
    
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
            assetPipeline.loadRecordedFaceScans()
        }
        .onDisappear {
            faceEngine.stopSession()
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
                HStack(spacing: 8) {
                    Text("NEXUS FACE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)
                    
                    FELPreviewLabel(text: "LIVE LINK FACE SCAN · V-016")
                }
                Text("Face Scan Studio")
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
                            faceEngine.startSession()
                        } else {
                            faceEngine.stopSession()
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
    
    // MARK: - Studio Tab (Live Tracking & Recording)
    
    private var studioTabContent: some View {
        VStack(spacing: 16) {
            ZStack {
                // Live AR Face Tracking View with Glowing Wireframe Mesh
                ARFaceSCNViewRepresentable(engine: faceEngine)
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.brandCyan.opacity(0.3), .clear, Theme.brandCyan.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                // Floating Sci-Fi Telemetry Overlay
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(faceEngine.isTrackingActive ? Theme.neonGreen : .red)
                                    .frame(width: 6, height: 6)
                                Text(faceEngine.isTrackingActive ? "TRACKING ACTIVE" : "CAMERA IDLE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(faceEngine.isTrackingActive ? Theme.neonGreen : .red)
                            }
                            Text("ENGINE: ARKIT_TRUEDEPTH_V2.0")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        if faceEngine.isTrackingActive {
                            Text("FPS: 60")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(12)
                    
                    Spacer()
                    
                    // Live Blendshape Progress Indicators
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            telemetryRow(title: "EYE BLINK L", value: faceEngine.blendshapes["eyeBlinkLeft"] ?? 0.0)
                            telemetryRow(title: "EYE BLINK R", value: faceEngine.blendshapes["eyeBlinkRight"] ?? 0.0)
                            telemetryRow(title: "JAW OPEN", value: faceEngine.blendshapes["jawOpen"] ?? 0.0)
                            telemetryRow(title: "SMILE L", value: faceEngine.blendshapes["mouthSmileLeft"] ?? 0.0)
                            telemetryRow(title: "SMILE R", value: faceEngine.blendshapes["mouthSmileRight"] ?? 0.0)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(12)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Controls Panel
            VStack(spacing: 12) {
                // Live Link Streaming Configuration
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TARGET IP")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        TextField("IP Address", text: $faceEngine.targetIP)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PORT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        TextField("Port", value: $faceEngine.targetPort, formatter: NumberFormatter())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    Button {
                        faceEngine.toggleStreaming()
                    } label: {
                        Text(faceEngine.isStreaming ? "STOP STREAM" : "LIVE LINK")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(faceEngine.isStreaming ? .red : .black)
                            .frame(height: 32)
                            .padding(.horizontal, 12)
                            .background(faceEngine.isStreaming ? Color.red.opacity(0.2) : Theme.brandCyan)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cardBorder, lineWidth: 1))
                
                // Record Controls
                HStack(spacing: 16) {
                    Button {
                        if faceEngine.isSessionRunning {
                            faceEngine.stopSession()
                        } else {
                            faceEngine.startSession()
                        }
                    } label: {
                        HStack {
                            Image(systemName: faceEngine.isSessionRunning ? "camera.fill" : "camera.badge.ellipsis")
                            Text(faceEngine.isSessionRunning ? "STOP CAMERA" : "START CAMERA")
                        }
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(faceEngine.isSessionRunning ? Color.red.opacity(0.2) : Theme.brandBlue.opacity(0.2))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(faceEngine.isSessionRunning ? Color.red : Theme.brandBlue, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if assetPipeline.isRecording {
                            if let asset = assetPipeline.stopRecording() {
                                selectedFaceScan = asset
                                withAnimation {
                                    selectedTab = .vault
                                }
                            }
                        } else {
                            assetPipeline.startRecording(
                                athleteID: viewModel.profile.id,
                                scanID: "FaceScan_\(Int(Date().timeIntervalSince1970))"
                            )
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(assetPipeline.isRecording ? .red : .white)
                                .frame(width: 8, height: 8)
                            Text(assetPipeline.isRecording ? "STOP RECORD" : "RECORD")
                        }
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(assetPipeline.isRecording ? .red : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(assetPipeline.isRecording ? .clear : Theme.brandCyan)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(assetPipeline.isRecording ? Color.red : .clear, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!faceEngine.isSessionRunning)
                    .opacity(faceEngine.isSessionRunning ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            faceEngine.startSession()
        }
        .onDisappear {
            faceEngine.stopSession()
        }
        .onChange(of: faceEngine.blendshapes) { newBlendshapes in
            if assetPipeline.isRecording {
                assetPipeline.addKeyframe(blendshapes: newBlendshapes)
            }
        }
    }
    
    // MARK: - Vault Tab (Clip Library & Playback)
    
    private var vaultTabContent: some View {
        VStack(spacing: 16) {
            if assetPipeline.recordedFaceScans.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "face.dashed")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("NO RECORDED FACE SCANS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxHeight: .infinity)
            } else {
                // 3D Playback Viewport
                ZStack {
                    FacePlaybackSCNViewRepresentable(blendshapes: activeBlendshapes)
                        .frame(maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                    
                    // Timing Overlay
                    if let scan = selectedFaceScan {
                        VStack {
                            HStack {
                                Text("CLIP: \(scan.header.scanID)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                                Spacer()
                                Text(String(format: "%.2f s", scan.header.duration))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.brandCyan)
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(12)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Playback controls
                if let scan = selectedFaceScan {
                    VStack(spacing: 10) {
                        // Progress Bar
                        HStack(spacing: 12) {
                            Text(String(format: "%.2f", playbackProgress * scan.header.duration))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Slider(value: $playbackProgress, in: 0...1) { editing in
                                if editing {
                                    stopPlayback()
                                } else {
                                    currentFrameIndex = Int(playbackProgress * Double(scan.keyframes.count - 1))
                                    updateActiveFrame(scan: scan)
                                }
                            }
                            .tint(Theme.brandCyan)
                            
                            Text(String(format: "%.2f", scan.header.duration))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        // Play/Pause, Delete, Share
                        HStack(spacing: 20) {
                            Button {
                                if isPlaying {
                                    stopPlayback()
                                } else {
                                    startPlayback(scan: scan)
                                }
                            } label: {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.black)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Theme.brandCyan))
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            // Export Button
                            Button {
                                if let url = assetPipeline.exportFaceScanAsJson(scan) {
                                    exportURL = url
                                    showShareSheet = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("EXPORT")
                                }
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 40)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            
                            // Delete Button
                            Button {
                                stopPlayback()
                                assetPipeline.deleteFaceScan(scan)
                                selectedFaceScan = assetPipeline.recordedFaceScans.first
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red.opacity(0.8))
                                    .frame(width: 40, height: 40)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Scan List
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(assetPipeline.recordedFaceScans) { scan in
                            Button {
                                stopPlayback()
                                selectedFaceScan = scan
                                currentFrameIndex = 0
                                playbackProgress = 0.0
                                updateActiveFrame(scan: scan)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(scan.header.scanID)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text(String(format: "%.1fs · %d frames", scan.header.duration, scan.keyframes.count))
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(12)
                                .frame(width: 140, height: 60, alignment: .leading)
                                .background(selectedFaceScan?.id == scan.id ? Theme.brandCyan.opacity(0.15) : Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedFaceScan?.id == scan.id ? Theme.brandCyan : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 70)
                .padding(.bottom, 10)
            }
        }
        .onAppear {
            if selectedFaceScan == nil {
                selectedFaceScan = assetPipeline.recordedFaceScans.first
            }
            if let scan = selectedFaceScan {
                updateActiveFrame(scan: scan)
            }
        }
    }
    
    // MARK: - Telemetry Row Helper
    
    private func telemetryRow(title: String, value: Float) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.brandCyan)
                        .frame(width: geo.size.width * CGFloat(value), height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(width: 120)
    }
    
    // MARK: - Playback Logic
    
    private func startPlayback(scan: NexusFaceScanAsset) {
        isPlaying = true
        let interval = 1.0 / scan.header.frameRate
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if currentFrameIndex < scan.keyframes.count - 1 {
                currentFrameIndex += 1
                playbackProgress = Double(currentFrameIndex) / Double(scan.keyframes.count - 1)
                updateActiveFrame(scan: scan)
            } else {
                // Loop
                currentFrameIndex = 0
                playbackProgress = 0.0
            }
        }
    }
    
    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updateActiveFrame(scan: NexusFaceScanAsset) {
        guard !scan.keyframes.isEmpty else { return }
        let frame = scan.keyframes[currentFrameIndex]
        activeBlendshapes = frame.blendshapes
    }
}

// MARK: - ARFaceSCNViewRepresentable

struct ARFaceSCNViewRepresentable: UIViewRepresentable {
    let engine: NexusLiveLinkFaceEngine
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.backgroundColor = .clear
        arView.delegate = context.coordinator
        arView.automaticallyUpdatesLighting = true
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        arView.session.delegate = engine
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let device = renderer.device,
                  let _ = anchor as? ARFaceAnchor else {
                return nil
            }
            
            let faceGeometry = ARSCNFaceGeometry(device: device)
            let node = SCNNode(geometry: faceGeometry)
            
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.clear
            material.fillMode = .lines // wireframe!
            material.emission.contents = UIColor(red: 0, green: 0.95, blue: 0.9, alpha: 1) // glowing brandCyan
            material.metalness.contents = 0.8
            material.roughness.contents = 0.1
            
            node.geometry?.materials = [material]
            
            return node
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
                return
            }
            
            faceGeometry.update(from: faceAnchor.geometry)
        }
    }
}

// MARK: - FacePlaybackSCNViewRepresentable

struct FacePlaybackSCNViewRepresentable: UIViewRepresentable {
    let blendshapes: [String: Float]
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = true
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.4)
        scene.rootNode.addChildNode(cameraNode)
        
        // Mannequin Head Sphere
        let headNode = SCNNode(geometry: SCNSphere(radius: 0.1))
        headNode.name = "head"
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.15, alpha: 1.0)
        mat.emission.contents = UIColor(red: 0, green: 0.15, blue: 0.3, alpha: 1.0)
        mat.metalness.contents = 0.5
        mat.roughness.contents = 0.4
        headNode.geometry?.materials = [mat]
        scene.rootNode.addChildNode(headNode)
        
        // Add facial features
        NexusFaceAnimationMapper.addFacialFeatures(to: headNode)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let headNode = uiView.scene?.rootNode.childNode(withName: "head", recursively: true) else { return }
        NexusFaceAnimationMapper.applyBlendshapes(blendshapes, to: headNode)
    }
}
