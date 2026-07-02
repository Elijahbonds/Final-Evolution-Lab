import SwiftUI
import SceneKit
import UIKit

/// Interactive **Drawing In** module: visual tension maps, staged cues, breath-sync IAP, haptic torque loop.
struct DrawingInTutorialView: View {
    @State private var stage: DrawingInTutorialStage = .torqueInternalRotation
    @State private var torqueProgress: Double = 0.35
    @State private var simulateKneeValgus = false
    @State private var torqueHapticTimer: Timer?
    @State private var liveSensorEnabled = false

    // Calibration and filtering state variables
    @State private var isCalibrating = false
    @State private var calibrationProgress: Double = 0.0
    @State private var sampleCount = 0
    @State private var accumulatedGyroX: Double = 0.0
    @State private var accumulatedGyroY: Double = 0.0
    @State private var accumulatedGyroZ: Double = 0.0
    @State private var gyroBiasX: Double = 0.0
    @State private var gyroBiasY: Double = 0.0
    @State private var gyroBiasZ: Double = 0.0
    @State private var filteredGyroX: Double = 0.0
    @State private var filteredGyroY: Double = 0.0
    @State private var filteredGyroZ: Double = 0.0

    // Attitude calibration and filtering state
    @State private var filteredPitch: Double = 0.0
    @State private var filteredRoll: Double = 0.0
    @State private var filteredYaw: Double = 0.0
    @State private var pitchBias: Double = 0.0
    @State private var rollBias: Double = 0.0
    @State private var yawBias: Double = 0.0
    @State private var accumulatedPitch: Double = 0.0
    @State private var accumulatedRoll: Double = 0.0
    @State private var accumulatedYaw: Double = 0.0
    @State private var currentPelvicTuckAngle: Double = 0.0
    @State private var alignmentAccuracy: Double = 1.0
    @State private var lastFaultTime: Date = .distantPast

    private var isKneeUnstable: Bool {
        if liveSensorEnabled {
            if isCalibrating { return false }
            let threshold = 1.2
            let dx = filteredGyroX - gyroBiasX
            let dy = filteredGyroY - gyroBiasY
            let dz = filteredGyroZ - gyroBiasZ
            return abs(dx) > threshold || abs(dy) > threshold || abs(dz) > threshold
        } else {
            return simulateKneeValgus
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FELPreviewLabel(text: FELPremiumCopy.Preview.drawingTutorial)
                stagePicker

                DrawingInSceneContainer(
                    stage: stage,
                    torqueProgress: torqueProgress,
                    showKneeLeakage: isKneeUnstable,
                    alignmentAccuracy: liveSensorEnabled ? alignmentAccuracy : 1.0
                )
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.brandCyan.opacity(0.55), Theme.elitePurple.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

                if stage == .replaceDownTuck {
                    breathSyncOverlay
                        .padding(.top, 4)
                }

                cueCard

                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $liveSensorEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LIVE SENSOR FEEDBACK")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.brandCyan)
                            Text("Use device gyroscope for real-time knee instability warnings")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .tint(Theme.brandCyan)
                    
                    if liveSensorEnabled {
                        if isCalibrating {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("CALIBRATING NEUTRAL STANCE...")
                                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                                        .foregroundStyle(.yellow)
                                    Spacer()
                                    Text(String(format: "%.0f%%", calibrationProgress * 100))
                                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                                        .foregroundStyle(.yellow)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 4)
                                        Capsule()
                                            .fill(Color.yellow)
                                            .frame(width: geo.size.width * CGFloat(calibrationProgress), height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Gyro rate (smoothed):")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Spacer()
                                    let dx = filteredGyroX - gyroBiasX
                                    let dy = filteredGyroY - gyroBiasY
                                    let dz = filteredGyroZ - gyroBiasZ
                                    Text(String(format: "X: %.2f  Y: %.2f  Z: %.2f", dx, dy, dz))
                                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                                        .foregroundStyle(isKneeUnstable ? Color.red : Theme.brandCyan)
                                }
                                
                                HStack {
                                    Text("Pelvic Tuck Angle:")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Spacer()
                                    Text(String(format: "%.1f°", currentPelvicTuckAngle))
                                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                                        .foregroundStyle(alignmentAccuracy >= 0.85 ? Theme.brandBlue : (alignmentAccuracy >= 0.45 ? Color.green : Color.red))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("ALIGNMENT ACCURACY")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.5))
                                        Spacer()
                                        Text(alignmentAccuracy >= 0.85 ? "LOCKED" : (alignmentAccuracy >= 0.45 ? "ALIGNED" : "TILT / FAULT"))
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                            .foregroundStyle(alignmentAccuracy >= 0.85 ? Theme.brandBlue : (alignmentAccuracy >= 0.45 ? Color.green : Color.red))
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(height: 6)
                                            Capsule()
                                                .fill(alignmentAccuracy >= 0.85 ? Theme.brandBlue : (alignmentAccuracy >= 0.45 ? Color.green : Color.red))
                                                .frame(width: geo.size.width * CGFloat(alignmentAccuracy), height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                                .padding(.vertical, 2)
                                
                                Button {
                                    startCalibration()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption2)
                                        Text("RECALIBRATE NEUTRAL")
                                            .font(.system(size: 9, weight: .black, design: .monospaced))
                                    }
                                    .foregroundStyle(.black)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.brandCyan))
                                }
                            }
                        }
                    } else {
                        Toggle(isOn: $simulateKneeValgus) {
                            Text("Demo: manual knee valgus warning")
                                .font(.system(.caption, design: .rounded))
                        }
                        .tint(Theme.brandCyan)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    NavigationLink(destination: RealtimeMotionTrackerView()) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 14, weight: .bold))
                            Text("LAUNCH KINECT AI TRACKER")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(.black)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.brandCyan))
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))

                if stage == .torqueInternalRotation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TORQUE TARGET")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandBlue)
                        Slider(value: $torqueProgress, in: 0...1)
                            .tint(Theme.brandCyan)
                        Text("Slide to complete internal rotation — haptics stop when you reach the blue zone.")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
                }

                whySection
            }
            .padding()
        }
        .background(Theme.deepBlack)
        .navigationTitle("Drawing In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            startTorqueHapticsIfNeeded()
        }
        .onChange(of: stage) { _, _ in
            torqueHapticTimer?.invalidate()
            torqueHapticTimer = nil
            startTorqueHapticsIfNeeded()
        }
        .onChange(of: torqueProgress) { old, new in
            if new >= 0.92 {
                torqueHapticTimer?.invalidate()
                torqueHapticTimer = nil
                if old < 0.92 {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } else {
                startTorqueHapticsIfNeeded()
            }
        }
        .onDisappear {
            torqueHapticTimer?.invalidate()
            torqueHapticTimer = nil
            stopHapticTimer()
            if liveSensorEnabled {
                CoreMotionHelper.shared.stopStreaming()
            }
        }
        .onChange(of: liveSensorEnabled) { _, enabled in
            if enabled {
                CoreMotionHelper.shared.startStreaming()
                startCalibration()
                startHapticTimer()
            } else {
                CoreMotionHelper.shared.stopStreaming()
                resetCalibration()
                stopHapticTimer()
            }
        }
        .onChange(of: isKneeUnstable) { _, newUnstable in
            if newUnstable {
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.warning)
            }
        }
        .onChange(of: CoreMotionHelper.shared.gyroX) { _, _ in
            guard liveSensorEnabled else { return }
            
            let rawX = CoreMotionHelper.shared.gyroX
            let rawY = CoreMotionHelper.shared.gyroY
            let rawZ = CoreMotionHelper.shared.gyroZ
            
            let rawPitch = CoreMotionHelper.shared.pitch
            let rawRoll = CoreMotionHelper.shared.roll
            let rawYaw = CoreMotionHelper.shared.yaw
            
            // Low-pass filter (alpha = 0.15 for smoothing)
            let alpha = 0.15
            filteredGyroX = alpha * rawX + (1.0 - alpha) * filteredGyroX
            filteredGyroY = alpha * rawY + (1.0 - alpha) * filteredGyroY
            filteredGyroZ = alpha * rawZ + (1.0 - alpha) * filteredGyroZ
            
            // Attitude low-pass filter (alpha = 0.10 for stable orientation)
            let alphaAttitude = 0.10
            filteredPitch = alphaAttitude * rawPitch + (1.0 - alphaAttitude) * filteredPitch
            filteredRoll = alphaAttitude * rawRoll + (1.0 - alphaAttitude) * filteredRoll
            filteredYaw = alphaAttitude * rawYaw + (1.0 - alphaAttitude) * filteredYaw
            
            if isCalibrating {
                accumulatedGyroX += rawX
                accumulatedGyroY += rawY
                accumulatedGyroZ += rawZ
                accumulatedPitch += rawPitch
                accumulatedRoll += rawRoll
                accumulatedYaw += rawYaw
                sampleCount += 1
                calibrationProgress = min(1.0, Double(sampleCount) / 180.0) // 180 samples at 60Hz is 3 seconds
                
                if sampleCount >= 180 {
                    gyroBiasX = accumulatedGyroX / 180.0
                    gyroBiasY = accumulatedGyroY / 180.0
                    gyroBiasZ = accumulatedGyroZ / 180.0
                    pitchBias = accumulatedPitch / 180.0
                    rollBias = accumulatedRoll / 180.0
                    yawBias = accumulatedYaw / 180.0
                    isCalibrating = false
                    
                    // Trigger a heavy pulse when calibration completes successfully
                    let gen = UIImpactFeedbackGenerator(style: .heavy)
                    gen.prepare()
                    gen.impactOccurred(intensity: 1.0)
                }
            } else {
                // Calculate pelvic tuck angle (difference in pitch from neutral, in degrees)
                currentPelvicTuckAngle = (filteredPitch - pitchBias) * 180.0 / .pi
                
                // Calculate current step alignment accuracy
                updateAlignmentAccuracy()
            }
        }
    }

    private func startCalibration() {
        isCalibrating = true
        calibrationProgress = 0.0
        sampleCount = 0
        accumulatedGyroX = 0.0
        accumulatedGyroY = 0.0
        accumulatedGyroZ = 0.0
        accumulatedPitch = 0.0
        accumulatedRoll = 0.0
        accumulatedYaw = 0.0
    }

    private func resetCalibration() {
        isCalibrating = false
        calibrationProgress = 0.0
        sampleCount = 0
        gyroBiasX = 0.0
        gyroBiasY = 0.0
        gyroBiasZ = 0.0
        pitchBias = 0.0
        rollBias = 0.0
        yawBias = 0.0
        filteredGyroX = 0.0
        filteredGyroY = 0.0
        filteredGyroZ = 0.0
        filteredPitch = 0.0
        filteredRoll = 0.0
        filteredYaw = 0.0
        currentPelvicTuckAngle = 0.0
        alignmentAccuracy = 1.0
    }

    private func updateAlignmentAccuracy() {
        let dx = filteredGyroX - gyroBiasX
        let dy = filteredGyroY - gyroBiasY
        let dz = filteredGyroZ - gyroBiasZ
        let totalGyroDeviation = sqrt(dx*dx + dy*dy + dz*dz)
        
        let rollDiff = (filteredRoll - rollBias) * 180.0 / .pi
        let yawDiff = (filteredYaw - yawBias) * 180.0 / .pi
        
        switch stage {
        case .torqueInternalRotation:
            // Internal rotation: femur internally rotates, which we map to a yaw rotation (body/femur spiral)
            // Let's dynamically map yawDiff (0 to 20 degrees) to torqueProgress
            let progress = min(1.0, max(0.0, abs(yawDiff) / 20.0))
            torqueProgress = progress
            alignmentAccuracy = progress
            
        case .hipHikeLoading:
            // Hip hike: lateral tilt (roll change) primes the obliques/QL
            // Target is a roll change of 6 to 12 degrees
            let targetRoll = 9.0
            let rollError = abs(rollDiff - targetRoll)
            let accuracy = 1.0 - min(1.0, rollError / 6.0)
            alignmentAccuracy = accuracy
            
        case .replaceDownTuck:
            // Pelvic tuck: posterior pelvic tilt (pitch change)
            // Target pelvic tuck is 8 to 18 degrees
            let targetTuck = 13.0
            let tuckError = abs(currentPelvicTuckAngle - targetTuck)
            var accuracy = 1.0 - min(1.0, tuckError / 8.0)
            
            // Penalize lateral tilt (roll deviation)
            let rollPenalty = min(0.3, abs(rollDiff) / 10.0)
            accuracy -= rollPenalty
            alignmentAccuracy = max(0.0, accuracy)
        }
    }

    private func startHapticTimer() {
        torqueHapticTimer?.invalidate()
        torqueHapticTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            guard liveSensorEnabled && !isCalibrating else { return }
            
            let dx = filteredGyroX - gyroBiasX
            let dy = filteredGyroY - gyroBiasY
            let dz = filteredGyroZ - gyroBiasZ
            let totalGyroDeviation = sqrt(dx*dx + dy*dy + dz*dz)
            
            // Fault check: knee instability or extreme tilt
            if totalGyroDeviation > 1.5 || isKneeUnstable {
                if Date().timeIntervalSince(lastFaultTime) > 1.5 {
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.error)
                    lastFaultTime = Date()
                }
            } else if alignmentAccuracy >= 0.85 {
                let gen = UIImpactFeedbackGenerator(style: .heavy)
                gen.prepare()
                gen.impactOccurred(intensity: 0.9)
            } else if alignmentAccuracy >= 0.45 {
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.prepare()
                gen.impactOccurred(intensity: 0.4)
            }
        }
    }
    
    private func stopHapticTimer() {
        torqueHapticTimer?.invalidate()
        torqueHapticTimer = nil
    }

    private var stagePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VISUAL TENSION MAP")
                .font(.system(.caption2, design: .monospaced, weight: .black))
                .foregroundStyle(Theme.elitePurple)
                .tracking(2)
            Picker("Stage", selection: $stage) {
                ForEach(DrawingInTutorialStage.allCases) { s in
                    Text(s.shortTitle).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var cueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stage.headlineCue)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            Text(stage.detailCue)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            if stage == .hipHikeLoading {
                Text(stage.educationalNote)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.brandCyan.opacity(0.95))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.brandCyan.opacity(0.1)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06)))
        )
    }

    private var breathSyncOverlay: some View {
        BreathSyncPulseRing()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHY THIS WORKS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
            Text(
                "The staggered V stance plus intentional internal rotation organizes lateral line tension so the hip can load in tensegrity. Drawing-in coordinates intra-abdominal pressure with posterior pelvic tuck — the Bonds Standard bridge from kinetic leakage to structural integrity."
            )
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground.opacity(0.95)))
    }

    private func startTorqueHapticsIfNeeded() {
        guard stage == .torqueInternalRotation, torqueProgress < 0.92 else { return }
        torqueHapticTimer?.invalidate()
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        torqueHapticTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { _ in
            guard torqueProgress < 0.92 else {
                torqueHapticTimer?.invalidate()
                torqueHapticTimer = nil
                return
            }
            gen.impactOccurred(intensity: CGFloat(0.5 + torqueProgress * 0.45))
        }
        RunLoop.main.add(torqueHapticTimer!, forMode: .common)
    }
}

// MARK: - SceneKit host

private struct DrawingInSceneContainer: UIViewRepresentable {
    var stage: DrawingInTutorialStage
    var torqueProgress: Double
    var showKneeLeakage: Bool
    var alignmentAccuracy: Double

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = GameSceneFactory.buildDrawingInTutorialScene()
        v.autoenablesDefaultLighting = false
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        context.coordinator.scene = v.scene
        context.coordinator.apply(stage: stage, torque01: torqueProgress, kneeLeak: showKneeLeakage, accuracy: alignmentAccuracy)
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(stage: stage, torque01: torqueProgress, kneeLeak: showKneeLeakage, accuracy: alignmentAccuracy)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var scene: SCNScene?

        func apply(stage: DrawingInTutorialStage, torque01: Double, kneeLeak: Bool, accuracy: Double) {
            guard let scene else { return }
            guard let avatar = scene.rootNode.childNode(withName: "drawingAvatar", recursively: false) else { return }

            let ring = avatar.childNode(withName: "rLeg", recursively: true)?.childNode(withName: "overlayTorqueRing", recursively: false)
            let arrowUp = avatar.childNode(withName: "hip", recursively: true)?.childNode(withName: "overlayHipArrowUp", recursively: false)
            let arrowDown = avatar.childNode(withName: "hip", recursively: true)?.childNode(withName: "overlayHipArrowDown", recursively: false)
            let fascia = avatar.childNode(withName: "overlayFasciaBeam", recursively: true)
            let corset = avatar.childNode(withName: "overlayCorset", recursively: true)
            let kneePulse = avatar.childNode(withName: "kneeLeakagePulse", recursively: true)

            // Dynamic 3D Posture Ring on the hip node
            let hipNode = avatar.childNode(withName: "hip", recursively: true)
            var postureRing = hipNode?.childNode(withName: "overlayPostureRing", recursively: false)
            if postureRing == nil {
                let ringGeo = SCNTorus(ringRadius: 0.18, pipeRadius: 0.016)
                let mat = SCNMaterial()
                mat.diffuse.contents = UIColor.systemRed
                mat.emission.contents = UIColor.systemRed.withAlphaComponent(0.5)
                ringGeo.materials = [mat]
                let ringNode = SCNNode(geometry: ringGeo)
                ringNode.name = "overlayPostureRing"
                ringNode.position = SCNVector3(0, 0.05, 0)
                ringNode.eulerAngles.x = Float.pi / 2
                hipNode?.addChildNode(ringNode)
                postureRing = ringNode
            }

            // Update Posture Ring color based on alignment accuracy
            // Red for tilt (< 0.4), Green for aligned (0.4 to 0.85), Glowing Blue for locked (>= 0.85)
            if let pRing = postureRing,
               let torus = pRing.geometry as? SCNTorus,
               let mat = torus.materials.first {
                let color: UIColor
                if accuracy < 0.4 {
                    let t = CGFloat(accuracy / 0.4)
                    color = UIColor.mixDrawing(.systemRed, .systemGreen, t)
                } else if accuracy < 0.85 {
                    let t = CGFloat((accuracy - 0.4) / 0.45)
                    let glowingBlue = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 1.0)
                    color = UIColor.mixDrawing(.systemGreen, glowingBlue, t)
                } else {
                    color = UIColor(red: 0.0, green: 0.83, blue: 1.0, alpha: 1.0)
                }
                mat.diffuse.contents = color.withAlphaComponent(0.85)
                mat.emission.contents = color.withAlphaComponent(0.65)
            }

            ring?.isHidden = stage != .torqueInternalRotation
            arrowUp?.isHidden = stage != .hipHikeLoading
            fascia?.isHidden = stage != .hipHikeLoading
            arrowDown?.isHidden = stage != .replaceDownTuck
            corset?.isHidden = stage != .replaceDownTuck
            postureRing?.isHidden = false

            kneePulse?.isHidden = !kneeLeak
            if kneeLeak {
                let blink = SCNAction.sequence([
                    SCNAction.fadeOpacity(to: 0.25, duration: 0.35),
                    SCNAction.fadeOpacity(to: 1.0, duration: 0.35)
                ])
                kneePulse?.removeAction(forKey: "blink")
                kneePulse?.runAction(SCNAction.repeatForever(blink), forKey: "blink")
            } else {
                kneePulse?.removeAction(forKey: "blink")
                kneePulse?.opacity = 1
            }

            Self.paintRearLegIntegrity(avatar: avatar, torque01: torque01)

            arrowUp?.opacity = stage == .replaceDownTuck ? 0 : 1
        }

        private static func paintRearLegIntegrity(avatar: SCNNode, torque01: Double) {
            guard let leg = avatar.childNode(withName: "rLeg", recursively: true),
                  let geo = leg.geometry as? SCNCapsule,
                  let mat = geo.materials.first as? SCNMaterial else { return }

            let stableBlue = UIColor(red: 0.2, green: 0.45, blue: 1.0, alpha: 1)
            let leakRed = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1)
            let t = CGFloat(min(1, max(0, torque01)))
            let mixed = UIColor.mixDrawing(leakRed, stableBlue, t)
            mat.emission.contents = mixed.withAlphaComponent(0.35 + 0.45 * CGFloat(torque01))
            mat.diffuse.contents = mixed.withAlphaComponent(0.85)
        }
    }
}

private extension UIColor {
    static func mixDrawing(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: 1
        )
    }
}

private struct BreathSyncPulseRing: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = sin(t / 5.0 * (Double.pi * 2))
            let scale = 0.88 + 0.14 * CGFloat((phase + 1) / 2)
            let opacity = 0.42 + 0.42 * CGFloat((phase + 1) / 2)
            ZStack {
                Circle()
                    .stroke(Theme.brandCyan.opacity(0.35), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)
                    .opacity(opacity)
                Text("IAP · slow expansion")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}
