import SwiftUI
import AVFoundation
import Vision
import Combine

/// A high-fidelity, Kinect-style camera pose tracker.
/// Uses Apple's Vision framework to detect joint positions and compute real-time knee valgus collapse.
/// Includes an advanced Simulation Mode for Simulator or automated UI test environments.
struct RealtimeMotionTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var miniSelfProfile: UserProfile = SaveSystem.loadProfile()
    
    // Toggle for Simulation mode. Defaults to true on Simulator or if camera is unauthorized/unavailable.
    @State private var isSimulationMode: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.arguments.contains("-UITestMode")
        #endif
    }()
    
    @State private var showJointAngles = true
    @State private var squatCount = 0
    @State private var lastRepCount = 0
    
    // Animation timer for Simulation mode
    @State private var time: Double = 0
    private let simTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    
    // Core motion tracker metrics
    @State private var leftKneeAngle: Double = 180
    @State private var rightKneeAngle: Double = 180
    @State private var leftKneeValgus: Bool = false
    @State private var rightKneeValgus: Bool = false
    @State private var coreStability: Double = 100.0
    @State private var isSquatDown = false
    
    // Camera state mapping
    private var hasPerson: Bool {
        if isSimulationMode {
            return true
        } else {
            return cameraManager.hasDetectedPerson
        }
    }
    
    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            
            // 1. Camera Feed / Mock Background
            if isSimulationMode {
                simulatedCameraBackground
            } else {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.2)) // dim camera slightly for neon contrast
            }
            
            // 2. Neon Grid Overlay (aesthetic)
            scanGrid
                .opacity(0.15)
            
            // 3. Skeleton Wireframe Overlay
            GeometryReader { geo in
                let joints = getNormalizedJoints(for: geo.size)
                
                Canvas { context, size in
                    drawSkeleton(joints: joints, context: context)
                }
                .ignoresSafeArea()
                
                // Floating Joint Angle Labels
                if showJointAngles && hasPerson {
                    jointAngleLabels(joints: joints)
                }
            }
            
            // 4. HUD Interface Layer
            VStack {
                headerHUD
                Spacer()
                alertHUD
                Spacer()
                bottomHUD
            }
            .padding()

            miniSelfPreviewOverlay
        }
        .navigationTitle("AI Stance Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: {
                    cameraManager.stopSession()
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Exit")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    isSimulationMode.toggle()
                    if !isSimulationMode {
                        cameraManager.startSession()
                    }
                }) {
                    Text(isSimulationMode ? "Use Live Camera" : "Use Simulation")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.brandCyan))
                }
            }
        }
        .onAppear {
            miniSelfProfile = SaveSystem.loadProfile()
            if !isSimulationMode {
                cameraManager.startSession()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onReceive(simTimer) { _ in
            if isSimulationMode {
                time += 0.033
                updateSimulationMetrics()
            } else {
                updateCameraMetrics()
            }
        }
    }
    
    // MARK: - Subviews

    private var miniSelfPreviewOverlay: some View {
        VStack {
            HStack {
                Spacer()
                NexusMiniSelfPreviewView(
                    profile: miniSelfProfile,
                    layout: .compact,
                    previewHeight: 128,
                    motionNote: isSimulationMode
                        ? FELPremiumCopy.Preview.simulatedPose
                        : "Live camera tracks your body · mini-self shows scan skin."
                )
                .frame(width: 148)
                .padding(10)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1))
            }
            .padding(.top, 56)
            .padding(.trailing, 8)
            Spacer()
        }
    }
    
    private var simulatedCameraBackground: some View {
        ZStack {
            Theme.deepBlack
            
            // Neon mesh background representing simulated capture lab
            Theme.meshGradient
                .opacity(0.4)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Text("SIMULATION ENVIRONMENT ACTIVE")
                    .font(.system(.caption2, design: .monospaced, weight: .black))
                    .foregroundStyle(Theme.brandCyan.opacity(0.7))
                    .padding(8)
                    .background(Capsule().stroke(Theme.brandCyan.opacity(0.3)))
                Text("Squat biomechanics loop simulating stance correction")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
        }
    }
    
    private var scanGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 40
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            
            for col in 0...cols {
                let x = CGFloat(col) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Theme.brandBlue.opacity(0.1)), lineWidth: 0.5)
            }
            for row in 0...rows {
                let y = CGFloat(row) * spacing
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Theme.brandBlue.opacity(0.1)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
    
    private var headerHUD: some View {
        HStack(alignment: .top) {
            // Left HUD Panel: Track stats
            VStack(alignment: .leading, spacing: 6) {
                Text("AI MOTION COMPILER")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(isSimulationMode ? Theme.elitePurple : Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isSimulationMode ? 1.0 : 1.2)
                    
                    Text(isSimulationMode ? "SIMULATED FEED" : "LIVE CAMERA FEED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Text("Squats Detected: \(squatCount)")
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            )
            
            Spacer()
            
            // Right HUD Panel: Stability Indicators
            VStack(alignment: .trailing, spacing: 6) {
                Text("ALIGNMENT STATUS")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                
                HStack(spacing: 6) {
                    Text(leftKneeValgus || rightKneeValgus ? "VALGUS DANGER" : "OPTIMAL")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(leftKneeValgus || rightKneeValgus ? Color.red : Theme.neonGreen)
                    
                    Image(systemName: leftKneeValgus || rightKneeValgus ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                        .foregroundStyle(leftKneeValgus || rightKneeValgus ? Color.red : Theme.neonGreen)
                }
                
                Text(String(format: "Stability index: %.0f%%", coreStability))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(coreStability < 80 ? Color.red : Theme.brandCyan)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            )
        }
    }
    
    @ViewBuilder
    private var alertHUD: some View {
        if (leftKneeValgus || rightKneeValgus) && hasPerson {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                        .flashingEffect()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KNEE VALGUS DETECTED")
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                            .foregroundStyle(.red)
                        Text("Push knees outward. Drive force laterally.")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red, lineWidth: 2))
                )
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var bottomHUD: some View {
        HStack(spacing: 16) {
            Toggle(isOn: $showJointAngles) {
                Text("SHOW ANGLES")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
            }
            .tint(Theme.brandCyan)
            .frame(width: 160)
            
            Spacer()
            
            Text("Rotate device to Portrait for stance calibration")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
        )
    }
    
    // MARK: - Joint Angle Label Overlays
    
    @ViewBuilder
    private func jointAngleLabels(joints: [VNHumanBodyPoseObservation.JointName: CGPoint]) -> some View {
        if let lKnee = joints[.leftKnee] {
            Text(String(format: "L: %.0f°", leftKneeAngle))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(leftKneeValgus ? Color.red : Theme.neonGreen)
                .padding(4)
                .background(Color.black.opacity(0.75).clipShape(RoundedRectangle(cornerRadius: 4)))
                .position(CGPoint(x: lKnee.x + 40, y: lKnee.y))
        }
        
        if let rKnee = joints[.rightKnee] {
            Text(String(format: "R: %.0f°", rightKneeAngle))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(rightKneeValgus ? Color.red : Theme.neonGreen)
                .padding(4)
                .background(Color.black.opacity(0.75).clipShape(RoundedRectangle(cornerRadius: 4)))
                .position(CGPoint(x: rKnee.x - 40, y: rKnee.y))
        }
    }
    
    // MARK: - Drawing & Coordinate Calculations
    
    private func getNormalizedJoints(for size: CGSize) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        if isSimulationMode {
            return getSimulatedJoints(for: size)
        } else {
            var screenJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for (joint, point) in cameraManager.joints {
                // Front camera (mirrored) Vision points have origin bottom-left:
                // Map to screen coordinates:
                // x = (1.0 - vision.x) * screenWidth
                // y = (1.0 - vision.y) * screenHeight
                screenJoints[joint] = CGPoint(
                    x: (1.0 - point.x) * size.width,
                    y: (1.0 - point.y) * size.height
                )
            }
            return screenJoints
        }
    }
    
    private func drawSkeleton(joints: [VNHumanBodyPoseObservation.JointName: CGPoint], context: GraphicsContext) {
        guard hasPerson else { return }
        
        // Define skeleton connections (bones)
        let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.nose, .neck),
            (.neck, .leftShoulder), (.neck, .rightShoulder),
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .rightHip),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
        ]
        
        // Draw bones
        for (j1, j2) in bones {
            if let p1 = joints[j1], let p2 = joints[j2] {
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                
                // Color legs based on instability
                let isLegBone = (j1 == .leftHip && j2 == .leftKnee) || (j1 == .leftKnee && j2 == .leftAnkle) ||
                                 (j1 == .rightHip && j2 == .rightKnee) || (j1 == .rightKnee && j2 == .rightAnkle)
                
                let color: Color
                if isLegBone {
                    let isLeftLeg = (j1 == .leftHip || j2 == .leftAnkle)
                    let unstable = isLeftLeg ? leftKneeValgus : rightKneeValgus
                    color = unstable ? Color.red : Theme.neonGreen
                } else {
                    color = Theme.brandCyan.opacity(0.8)
                }
                
                context.stroke(path, with: .color(color), lineWidth: 3)
            }
        }
        
        // Draw joint points
        for (_, p) in joints {
            var path = Path()
            path.addEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
            context.fill(path, with: .color(.white))
        }
    }
    
    // MARK: - Simulation Engine Generator
    
    private func getSimulatedJoints(for size: CGSize) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        let cycleDuration = 6.0
        let phase = (time.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration
        
        let squatProgress: Double
        if phase < 0.2 {
            squatProgress = 0
        } else if phase < 0.5 {
            // Squatting down (smooth curve)
            let t = (phase - 0.2) / 0.3
            squatProgress = t * t * (3 - 2 * t)
        } else if phase < 0.7 {
            // Hold bottom
            squatProgress = 1
        } else {
            // Standing up
            let t = (phase - 0.7) / 0.3
            let r = t * t * (3 - 2 * t)
            squatProgress = 1 - r
        }
        
        let repCount = Int(time / cycleDuration)
        let isValgusRep = repCount % 2 == 1
        
        // Base standing positions (normalized)
        let hipY = 0.45 + squatProgress * 0.16
        let kneeY = 0.65 + squatProgress * 0.08
        let ankleY = 0.85
        
        var leftKneeX = 0.58
        var rightKneeX = 0.42
        
        if isValgusRep && squatProgress > 0.5 {
            // Squat bottom collapse: knees move inward
            let collapseIntensity = (squatProgress - 0.5) / 0.5
            leftKneeX = 0.58 - collapseIntensity * 0.075
            rightKneeX = 0.42 + collapseIntensity * 0.075
        }
        
        let normJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [
            .nose: CGPoint(x: 0.5, y: 0.15),
            .neck: CGPoint(x: 0.5, y: 0.23),
            .leftShoulder: CGPoint(x: 0.58, y: 0.25),
            .rightShoulder: CGPoint(x: 0.42, y: 0.25),
            .leftElbow: CGPoint(x: 0.64, y: 0.35 + squatProgress * 0.08),
            .rightElbow: CGPoint(x: 0.36, y: 0.35 + squatProgress * 0.08),
            .leftWrist: CGPoint(x: 0.66, y: 0.45 + squatProgress * 0.08),
            .rightWrist: CGPoint(x: 0.34, y: 0.45 + squatProgress * 0.08),
            .leftHip: CGPoint(x: 0.57, y: hipY),
            .rightHip: CGPoint(x: 0.43, y: hipY),
            .leftKnee: CGPoint(x: leftKneeX, y: kneeY),
            .rightKnee: CGPoint(x: rightKneeX, y: kneeY),
            .leftAnkle: CGPoint(x: 0.57, y: ankleY),
            .rightAnkle: CGPoint(x: 0.43, y: ankleY)
        ]
        
        // Scale to size
        var scaledJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (joint, p) in normJoints {
            scaledJoints[joint] = CGPoint(x: p.x * size.width, y: p.y * size.height)
        }
        return scaledJoints
    }
    
    private func updateSimulationMetrics() {
        let cycleDuration = 6.0
        let phase = (time.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration
        let repCount = Int(time / cycleDuration)
        
        // Increment squats on rep boundary
        if repCount != lastRepCount {
            squatCount += 1
            lastRepCount = repCount
        }
        
        let squatProgress: Double
        if phase < 0.2 {
            squatProgress = 0
        } else if phase < 0.5 {
            squatProgress = (phase - 0.2) / 0.3
        } else if phase < 0.7 {
            squatProgress = 1
        } else {
            squatProgress = 1 - ((phase - 0.7) / 0.3)
        }
        
        let isValgusRep = repCount % 2 == 1
        
        if isValgusRep && squatProgress > 0.55 {
            leftKneeValgus = true
            rightKneeValgus = true
            coreStability = 60.0 + (1.0 - squatProgress) * 20.0
        } else {
            leftKneeValgus = false
            rightKneeValgus = false
            coreStability = 100.0 - (squatProgress * 12.0)
        }
        
        // Knee angles simulate squat flexion: 180 (standing) -> 92 (bottom)
        let angle = 180.0 - (squatProgress * 88.0)
        leftKneeAngle = angle
        rightKneeAngle = angle
    }
    
    // MARK: - Camera Metrics Processor
    
    private func updateCameraMetrics() {
        guard cameraManager.hasDetectedPerson else { return }
        
        let joints = cameraManager.joints
        
        guard let hipL = joints[.leftHip],
              let kneeL = joints[.leftKnee],
              let ankleL = joints[.leftAnkle],
              let hipR = joints[.rightHip],
              let kneeR = joints[.rightKnee],
              let ankleR = joints[.rightAnkle] else {
            return
        }
        
        // Transform to normalized top-left coordinates for detection logic
        let normHipL = CGPoint(x: 1.0 - hipL.x, y: 1.0 - hipL.y)
        let normKneeL = CGPoint(x: 1.0 - kneeL.x, y: 1.0 - kneeL.y)
        let normAnkleL = CGPoint(x: 1.0 - ankleL.x, y: 1.0 - ankleL.y)
        
        let normHipR = CGPoint(x: 1.0 - hipR.x, y: 1.0 - hipR.y)
        let normKneeR = CGPoint(x: 1.0 - kneeR.x, y: 1.0 - kneeR.y)
        let normAnkleR = CGPoint(x: 1.0 - ankleR.x, y: 1.0 - ankleR.y)
        
        let leftRes = detectValgus(hip: normHipL, knee: normKneeL, ankle: normAnkleL, isLeft: true)
        let rightRes = detectValgus(hip: normHipR, knee: normKneeR, ankle: normAnkleR, isLeft: false)
        
        leftKneeAngle = leftRes.angle
        rightKneeAngle = rightRes.angle
        leftKneeValgus = leftRes.isValgus
        rightKneeValgus = rightRes.isValgus
        
        // Adjust stability indicator
        let instability = (leftKneeValgus ? 20.0 : 0) + (rightKneeValgus ? 20.0 : 0)
        coreStability = max(40.0, 100.0 - instability)
        
        // Basic squat count algorithm: hip height tracking
        let midHipY = (normHipL.y + normHipR.y) / 2
        // Hips are low when Y is larger (since Y=0 at top)
        let standingThreshold: CGFloat = 0.50
        let bottomThreshold: CGFloat = 0.65
        
        // Simple state machine via tracking
        if midHipY > bottomThreshold && !isSquatDown {
            isSquatDown = true
        }
        if midHipY < standingThreshold && isSquatDown {
            isSquatDown = false
            squatCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    private func detectValgus(hip: CGPoint, knee: CGPoint, ankle: CGPoint, isLeft: Bool) -> (isValgus: Bool, angle: Double, deviation: CGFloat) {
        let v1 = CGVector(dx: hip.x - knee.x, dy: hip.y - knee.y)
        let v2 = CGVector(dx: ankle.x - knee.x, dy: ankle.y - knee.y)
        let len1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let len2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        
        guard len1 > 0.001, len2 > 0.001 else {
            return (false, 180.0, 0)
        }
        
        let angleRad = acos((v1.dx * v2.dx + v1.dy * v2.dy) / (len1 * len2))
        let angleDeg = angleRad * 180.0 / .pi
        
        let denom = ankle.y - hip.y
        let expectedX: CGFloat
        if abs(denom) > 0.001 {
            expectedX = hip.x + (knee.y - hip.y) * (ankle.x - hip.x) / denom
        } else {
            expectedX = (hip.x + ankle.x) / 2
        }
        
        let deviation = knee.x - expectedX
        let valgusThreshold: CGFloat = 0.035 // 3.5% of width
        let isValgus: Bool
        
        if isLeft {
            // Left leg is screen right. Valgus means knee collapses inward (towards center, i.e. left/smaller X).
            isValgus = deviation < -valgusThreshold && angleDeg < 170
        } else {
            // Right leg is screen left. Valgus means knee collapses inward (towards center, i.e. right/larger X).
            isValgus = deviation > valgusThreshold && angleDeg < 170
        }
        
        return (isValgus, angleDeg, deviation)
    }
}

// MARK: - Camera Core Helpers

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var hasDetectedPerson = false
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "fel.pose.sessionQueue")
    private var isSetup = false
    
    func startSession() {
        #if targetEnvironment(simulator)
        self.hasDetectedPerson = true
        #else
        sessionQueue.async {
            if !self.isSetup {
                self.setupSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
        #endif
    }
    
    func stopSession() {
        #if !targetEnvironment(simulator)
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
        #endif
    }
    
    private func setupSession() {
        session.beginConfiguration()
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            session.commitConfiguration()
            return
        }
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "fel.pose.videoQueue"))
        }
        
        session.commitConfiguration()
        isSetup = true
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else {
                DispatchQueue.main.async {
                    self?.hasDetectedPerson = false
                }
                return
            }
            
            var detectedJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            let jointNames: [VNHumanBodyPoseObservation.JointName] = [
                .nose, .neck,
                .leftShoulder, .rightShoulder,
                .leftElbow, .rightElbow,
                .leftWrist, .rightWrist,
                .leftHip, .rightHip,
                .leftKnee, .rightKnee,
                .leftAnkle, .rightAnkle
            ]
            
            for name in jointNames {
                if let recognizedPoint = try? observation.recognizedPoint(name),
                   recognizedPoint.confidence > 0.3 {
                    detectedJoints[name] = recognizedPoint.location
                }
            }
            
            DispatchQueue.main.async {
                self.joints = detectedJoints
                self.hasDetectedPerson = !detectedJoints.isEmpty
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .up, options: [:])
        try? handler.perform([request])
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
        if let connection = context.coordinator.previewLayer?.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// Micro-animation utility for warnings
extension View {
    func flashingEffect() -> some View {
        self.modifier(FlashingModifier())
    }
}

struct FlashingModifier: ViewModifier {
    @State private var isHigh = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isHigh ? 1.0 : 0.25)
            .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: isHigh)
            .onAppear {
                isHigh = true
            }
    }
}
