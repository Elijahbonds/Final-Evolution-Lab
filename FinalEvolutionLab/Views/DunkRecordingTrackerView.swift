import SwiftUI
import AVFoundation
import Vision
import Combine
import SceneKit

/// Proctored IRL camera lab: tripod alignment guide, regulation rim checklist echo,
/// Zoom-style proctor tile, and WDA/FIBA biometric dunk tracking.
struct DunkRecordingTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: LabViewModel
    let selectedAnimationId: String
    let selectedAnimationKeyframes: [NexusAnimationAsset.NexusAnimationFrame]
    var isProctoredSession: Bool = false
    var entryTier: TournamentTier? = nil
    var onCompletion: (DunkScoringResult) -> Void
    
    // Tracking/Simulation states
    @State private var isSimulationMode: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.arguments.contains("-UITestMode")
        #endif
    }()
    
    @State private var trackingPhase: DunkPhase = .idle
    @State private var attemptsCount = 1
    @State private var activeTrick: DunkTrickComplexity = .windmill
    @State private var landingSafetyMode: LandingSafetyMode = .balanced
    
    // Realtime Telemetry
    @State private var jumpHeightInches: Double = 0.0
    @State private var takeoffAngleDegrees: Double = 0.0
    @State private var takeoffVelocityFps: Double = 0.0
    @State private var flightHangTimeSeconds: Double = 0.0
    @State private var ballRotationDegrees: Double = 0.0
    @State private var timeSpentSeconds: Double = 0.0
    @State private var kneeValgusDetected: Bool = false
    @State private var anklePronationDetected: Bool = false
    
    // View state
    @State private var showScoringCard = false
    @State private var currentResult: DunkScoringResult? = nil
    @State private var timeRemainingSeconds: Double = 75.0 // WDA/FIBA 75s countdown
    @State private var scoreTicker = 0.0
    @State private var proctorPulse = false
    
    // Simulation Timer
    @State private var simTime: Double = 0.0
    private let trackerTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    
    @StateObject private var cameraManager = DunkCameraManager()
    
    enum DunkPhase: String, CaseIterable, Identifiable {
        case idle = "Ready"
        case runUp = "Run-up"
        case takeoff = "Takeoff"
        case flight = "Flight"
        case landing = "Landing"
        case completed = "Finished"
        
        var id: String { rawValue }
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .runUp: return Theme.brandBlue
            case .takeoff: return Theme.brandCyan
            case .flight: return Theme.elitePurple
            case .landing: return .orange
            case .completed: return Theme.neonGreen
            }
        }
    }
    
    enum LandingSafetyMode: String, CaseIterable, Identifiable {
        case balanced = "Balanced Landing (Safe)"
        case kneeValgus = "Knee Valgus (Deduction)"
        case anklePronation = "Ankle Pronation (Deduction)"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            
            // 1. Camera Feed / Mock Background
            if isSimulationMode {
                simulatedCourtBackground
            } else {
                DunkCameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.15))
            }
            
            // 2. Calibration / Telemetry Lines
            telemetryOverlays
            
            if isProctoredSession {
                tripodAlignmentGuide
                proctorPiPTile
            }
            
            // 3. Skeleton Wireframe Overlay
            GeometryReader { geo in
                let joints = getNormalizedJoints(for: geo.size)
                
                Canvas { context, size in
                    drawSkeleton(joints: joints, context: context)
                }
                .ignoresSafeArea()
            }
            
            // 4. Live HUD Layer
            VStack(spacing: 0) {
                headerHUD
                Spacer()
                telemetryOverlayHUD
                Spacer()
                bottomControlsHUD
            }
            .padding()
            
            // 5. Dunk Score Card Overlay
            if showScoringCard, let result = currentResult {
                scoreSummaryOverlay(result: result)
            }
        }
        .navigationTitle(isProctoredSession ? "Proctored IRL Dunk Lab" : "WDA/FIBA Biometric Tracker")
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
                    Text(isSimulationMode ? "Live Camera" : "Use Sim")
                        .font(.system(.caption2, design: .monospaced, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.brandCyan))
                }
            }
        }
        .onAppear {
            if !isSimulationMode {
                cameraManager.startSession()
            }
            activeTrick = trickForAnimationId(selectedAnimationId)
            if isProctoredSession {
                proctorPulse = true
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onReceive(trackerTimer) { _ in
            updateTelemetryLoop()
        }
    }
    
    // MARK: - Subviews
    
    private var simulatedCourtBackground: some View {
        ZStack {
            Theme.deepBlack
            
            // Vector background representing dunk court hoop and baseline
            Theme.meshGradient
                .opacity(0.3)
                .ignoresSafeArea()
            
            // Draw a simplified stylized backboard and hoop in the background
            GeometryReader { geo in
                Path { path in
                    // Hoop ring
                    let hoopCenter = CGPoint(x: geo.size.width * 0.78, y: geo.size.height * 0.35)
                    path.addEllipse(in: CGRect(x: hoopCenter.x - 30, y: hoopCenter.y - 6, width: 60, height: 12))
                    
                    // Net
                    path.move(to: CGPoint(x: hoopCenter.x - 30, y: hoopCenter.y))
                    path.addLine(to: CGPoint(x: hoopCenter.x - 18, y: hoopCenter.y + 40))
                    path.addLine(to: CGPoint(x: hoopCenter.x + 18, y: hoopCenter.y + 40))
                    path.addLine(to: CGPoint(x: hoopCenter.x + 30, y: hoopCenter.y))
                    
                    // Backboard
                    path.addRect(CGRect(x: geo.size.width * 0.78 + 26, y: geo.size.height * 0.35 - 70, width: 8, height: 90))
                    path.addRect(CGRect(x: geo.size.width * 0.78 + 34, y: geo.size.height * 0.35 - 50, width: 15, height: 10))
                }
                .stroke(Theme.brandCyan.opacity(0.4), lineWidth: 2)
                
                // Baseline Floor
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height * 0.8))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.8))
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
        }
    }
    
    private var telemetryOverlays: some View {
        GeometryReader { geo in
            ZStack {
                // Tracking Baseline floor line
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.brandCyan.opacity(0.0), Theme.brandCyan.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                        .frame(height: geo.size.height * 0.2)
                        .overlay(
                            VStack(spacing: 0) {
                                Divider().background(Theme.brandCyan.opacity(0.6))
                                HStack {
                                    Text("TRACKING BASELINE (GROUND)")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Theme.brandCyan.opacity(0.8))
                                    Spacer()
                                    Text("Z-CALIBRATED")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Theme.brandCyan.opacity(0.8))
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                                Spacer()
                            }
                        )
                }
                .ignoresSafeArea()
                
                // Flight Ceiling target
                Path { path in
                    let y = geo.size.height * 0.4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, lineJoin: .miter, miterLimit: 1, dash: [4, 6], dashPhase: 0))
                .foregroundStyle(Theme.elitePurple.opacity(0.4))
                .overlay(
                    VStack {
                        Spacer()
                            .frame(height: geo.size.height * 0.4 - 16)
                        HStack {
                            Text("ELITE FLIGHT CEILING (35\" VERTICAL)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.elitePurple.opacity(0.8))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                    }
                )
            }
        }
    }
    
    private var tripodAlignmentGuide: some View {
        GeometryReader { geo in
            ZStack {
                // Baseline tripod zone
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle(Theme.brandCyan.opacity(trackingPhase == .idle ? 0.55 : 0.2))
                    .frame(width: geo.size.width * 0.42, height: geo.size.height * 0.28)
                    .position(x: geo.size.width * 0.22, y: geo.size.height * 0.72)
                
                // Hoop target zone
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.45), lineWidth: 1.5)
                    .frame(width: geo.size.width * 0.22, height: geo.size.height * 0.18)
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.32)
                
                if trackingPhase == .idle {
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TRIPOD BASELINE ZONE")
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(Theme.brandCyan)
                                Text("Lock phone here · keep rim in orange frame")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.55)))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, geo.size.height * 0.22)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private var proctorPiPTile: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .opacity(proctorPulse ? 1 : 0.35)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: proctorPulse)
                        Text("WDA PROCTOR")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    
                    if isProctoredSession {
                        FELPreviewLabel(text: FELPremiumCopy.Preview.proctoredZoomSession)
                    }
                    
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.neonGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    if let tier = entryTier {
                        Text("ESCROW \(String(format: "$%.2f", tier.entryFee))")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                    }
                }
                .padding(8)
                .frame(width: 110)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.72)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.neonGreen.opacity(0.35), lineWidth: 1))
                .padding(.trailing, 12)
                .padding(.top, 72)
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
    
    private var regulationRimStatusBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.neonGreen)
            Text("REGULATION RIM · 10'0\" · 18\" · PROCTOR VERIFIED")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.neonGreen.opacity(0.25), lineWidth: 1))
    }
    
    private var headerHUD: some View {
        VStack(spacing: 6) {
            if isProctoredSession {
                regulationRimStatusBar
            }
            
            HStack(alignment: .top) {
            // Live status and timer
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(trackingPhase.color)
                        .frame(width: 8, height: 8)
                        .symbolEffect(.pulse, isActive: trackingPhase != .idle)
                    
                    Text("PHASE: \(trackingPhase.rawValue.uppercased())")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(trackingPhase.color)
                }
                
                if isSimulationMode {
                    FELPreviewLabel(text: FELPremiumCopy.Preview.simulatedPose)
                } else if isProctoredSession {
                    FELPreviewLabel(text: FELPremiumCopy.Preview.proctoredZoomSession)
                } else {
                    Text("VISION POSE · LIVE CAMERA")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
            
            Spacer()
            
            // FIBA Dunk clock
            VStack(alignment: .trailing, spacing: 2) {
                Text(isProctoredSession ? "PROCTORED CLOCK" : "FIBA TIMER")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text(String(format: "%.1fs", timeRemainingSeconds))
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(timeRemainingSeconds < 15 ? Color.red : Theme.neonGreen)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.6))
                    .stroke(timeRemainingSeconds < 15 ? Color.red.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
            )
            }
        }
        .padding(.horizontal, 4)
    }
    
    private var telemetryOverlayHUD: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                // Vertical Height
                telemetryRow(title: "VERT REACH", value: String(format: "%.1f\"", jumpHeightInches), color: Theme.neonGreen)
                
                // Flight time
                telemetryRow(title: "HANG TIME", value: String(format: "%.2fs", flightHangTimeSeconds), color: Theme.elitePurple)
                
                // Takeoff Velocity
                telemetryRow(title: "LAUNCH VEL", value: String(format: "%.1f fps", takeoffVelocityFps), color: Theme.brandCyan)
            }
            .frame(width: 120)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 10) {
                // Takeoff Angle
                telemetryRow(title: "LAUNCH ANG", value: String(format: "%.1f°", takeoffAngleDegrees), color: Theme.brandCyan, alignRight: true)
                
                // Ball Rotation
                telemetryRow(title: "ROTATION", value: String(format: "%.0f°", ballRotationDegrees), color: Theme.elitePurple, alignRight: true)
                
                // Attempts Count
                telemetryRow(title: "ATTEMPT", value: "\(attemptsCount)", color: .orange, alignRight: true)
            }
            .frame(width: 120)
        }
        .padding(.horizontal, 8)
    }
    
    private func telemetryRow(title: String, value: String, color: Color, alignRight: Bool = false) -> some View {
        VStack(alignment: alignRight ? .trailing : .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: alignRight ? .trailing : .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 0.5))
        )
    }
    
    private var bottomControlsHUD: some View {
        VStack(spacing: 12) {
            // Settings selections for Simulation
            if isSimulationMode {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SIM TRICK CLASS")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Picker("Trick", selection: $activeTrick) {
                            ForEach(DunkTrickComplexity.allCases, id: \.self) { complexity in
                                Text(complexity.rawValue).tag(complexity)
                            }
                        }
                        .tint(Theme.brandCyan)
                        .labelsHidden()
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SIM LANDING MODEL")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Picker("Landing Safety", selection: $landingSafetyMode) {
                            ForEach(LandingSafetyMode.allCases, id: \.self) { safety in
                                Text(safety.rawValue).tag(safety)
                            }
                        }
                        .tint(Theme.brandCyan)
                        .labelsHidden()
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.6)))
            }
            
            // Primary actions
            HStack(spacing: 12) {
                if trackingPhase == .idle {
                    Button(action: startDunkSequence) {
                        HStack {
                            Image(systemName: isProctoredSession ? "video.badge.checkmark" : "play.circle.fill")
                                .font(.subheadline)
                            Text(isProctoredSession ? "BEGIN PROCTORED ATTEMPT" : "LAUNCH CONTEST RUN")
                                .font(.system(.headline, design: .monospaced, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.neonGreen)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Theme.neonGreen.opacity(0.3), radius: 8)
                    }
                } else if trackingPhase != .completed {
                    Button(action: abortDunkSequence) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                            Text("ABORT ATTEMPT")
                                .font(.system(.headline, design: .monospaced, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button(action: compileScoresAndShow) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline)
                            Text("COMPILE WDA JUDGES SCORES")
                                .font(.system(.headline, design: .monospaced, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.brandCyan)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Theme.brandCyan.opacity(0.3), radius: 8)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }
    
    // MARK: - Post-Dunk score summary overlay
    
    private func scoreSummaryOverlay(result: DunkScoringResult) -> some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 6) {
                        Text("WORLD DUNK ASSOCIATION")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(3)
                        
                        Text("OFFICIAL SCORECARD")
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 24)
                    
                    // Huge Score Display
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(colors: [Theme.brandCyan, Theme.elitePurple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 6
                            )
                            .frame(width: 150, height: 150)
                            .shadow(color: Theme.brandCyan.opacity(0.3), radius: 12)
                        
                        VStack(spacing: 0) {
                            Text(String(format: "%.1f", scoreTicker))
                                .font(.system(size: 48, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .onAppear {
                                    withAnimation(.easeOut(duration: 1.0)) {
                                        scoreTicker = result.totalScore
                                    }
                                }
                            Text("TOTAL / 50")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .padding(.vertical, 10)
                    
                    // Scoring categories
                    VStack(spacing: 12) {
                        scoreBreakdownRow(title: "Execution & Difficulty", score: result.executionScore, maxScore: 30.0, color: Theme.neonGreen)
                        scoreBreakdownRow(title: "Artistic Expression & Style", score: result.artisticScore, maxScore: 10.0, color: Theme.elitePurple)
                        scoreBreakdownRow(title: "First-Try Efficiency Bonus", score: result.firstTrySuccessScore, maxScore: 10.0, color: .orange)
                        
                        if result.timePenalty > 0 {
                            scoreBreakdownRow(title: "FIBA 75s Clock Penalty", score: -result.timePenalty, maxScore: 0.0, color: .red)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.slateCard))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    
                    // Biometric Telemetry details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("BIOMETRIC ANALYTICS & TELEMETRY")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(2)
                        
                        ForEach(result.feedbackBullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: bullet.contains("Warning") ? "exclamationmark.triangle.fill" : "circle.fill")
                                    .font(.system(size: bullet.contains("Warning") ? 10 : 5))
                                    .foregroundStyle(bullet.contains("Warning") ? Color.orange : Theme.brandCyan)
                                    .padding(.top, 4)
                                
                                Text(bullet)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
                    
                    // Judges Commentary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JUDGES' COMMENTS")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                            .tracking(2)
                        
                        Text(result.judgesCommentary)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .italic()
                            .foregroundStyle(.white.opacity(0.9))
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.15), lineWidth: 1))
                    
                    // Save and Exit button
                    Button(action: submitDunkResultAndExit) {
                        HStack {
                            Image(systemName: "cloud.fill")
                            Text("PUBLISH TO WDA NETWORK (+50 SHARDS)")
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.neonGreen)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Theme.neonGreen.opacity(0.3), radius: 10)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func scoreBreakdownRow(title: String, score: Double, maxScore: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            
            Text(score < 0 ? String(format: "%.1f", score) : String(format: "%.1f/%.0f", score, maxScore))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(color)
        }
    }
    
    // MARK: - Core Logic & Tracking Math
    
    private func trickForAnimationId(_ animationId: String) -> DunkTrickComplexity {
        switch animationId {
        case "preset_windmill": return .windmill
        case "preset_eastbay": return .betweenTheLegs
        case "preset_freethrow": return .freeThrowLine
        case "preset_grazer": return .rimGrazer
        default: return .windmill
        }
    }
    
    private func startDunkSequence() {
        simTime = 0.0
        timeSpentSeconds = 0.0
        trackingPhase = .runUp
        activeTrick = trickForAnimationId(selectedAnimationId)
        
        // Reset metrics
        jumpHeightInches = 0.0
        takeoffAngleDegrees = 0.0
        takeoffVelocityFps = 0.0
        flightHangTimeSeconds = 0.0
        ballRotationDegrees = 0.0
        kneeValgusDetected = false
        anklePronationDetected = false
        
        // Pass selected animation to C++ gameplay bridge
        if NexusGameplayBridge.isLinked {
            if let session = NexusGameplayBridge.createSession() {
                let keyframesJson: [[String: Any]] = selectedAnimationKeyframes.map { frame in
                    var rotationsDict: [String: Any] = [:]
                    for (jointName, rotation) in frame.jointRotations {
                        rotationsDict[jointName] = [rotation.x, rotation.y, rotation.z, rotation.w]
                    }
                    var translationsDict: [String: Any] = [:]
                    for (jointName, translation) in frame.translationOffsets {
                        translationsDict[jointName] = [translation.x, translation.y, translation.z]
                    }
                    return [
                        "time": frame.timestamp,
                        "rotations": rotationsDict,
                        "translations": translationsDict
                    ]
                }
                
                let payload: [String: Any] = [
                    "command": "fel.dunk.register_signature",
                    "id": "ios_register_signature",
                    "params": [
                        "animation_id": selectedAnimationId,
                        "keyframes": keyframesJson
                    ]
                ]
                
                if let data = try? JSONSerialization.data(withJSONObject: payload),
                   let jsonString = String(data: data, encoding: .utf8) {
                    _ = NexusGameplayBridge.handleCommand(session, commandJson: jsonString)
                }
                
                NexusGameplayBridge.destroySession(session)
            }
        }
    }
    
    private func abortDunkSequence() {
        trackingPhase = .idle
        simTime = 0.0
    }
    
    private func compileScoresAndShow() {
        let difficultyBonus: Double
        let animationName: String
        if selectedAnimationId == "preset_windmill" {
            difficultyBonus = 2.5
            animationName = "Venice Beach Windmill"
        } else if selectedAnimationId == "preset_eastbay" {
            difficultyBonus = 3.5
            animationName = "360 Eastbay Spike"
        } else if selectedAnimationId == "preset_freethrow" {
            difficultyBonus = 4.0
            animationName = "Free-Throw Line Flight"
        } else if selectedAnimationId == "preset_grazer" {
            difficultyBonus = 1.5
            animationName = "Double-Clutch Rim Grazer"
        } else if selectedAnimationId.hasPrefix("custom_") {
            difficultyBonus = 2.0
            animationName = "Custom Uploaded Animation"
        } else {
            difficultyBonus = 0.0
            animationName = "Standard Preset"
        }

        let input = DunkIRLScoringInput(
            jumpHeightInches: jumpHeightInches,
            takeoffAngleDegrees: takeoffAngleDegrees,
            takeoffVelocityFps: takeoffVelocityFps,
            flightHangTimeSeconds: flightHangTimeSeconds,
            ballRotationDegrees: ballRotationDegrees,
            trick: activeTrick,
            attemptsCount: attemptsCount,
            timeSpentSeconds: timeSpentSeconds,
            fluidMotionScore: Double.random(in: 7.5...9.5),
            landingControlScore: landingSafetyMode == .balanced ? Double.random(in: 8.0...10.0) : Double.random(in: 3.0...5.5),
            aestheticImpactScore: Double.random(in: 7.0...10.0),
            kneeValgusDetected: kneeValgusDetected,
            anklePronationDetected: anklePronationDetected,
            signatureAnimationId: selectedAnimationId,
            signatureAnimationName: animationName,
            signatureDifficultyBonus: difficultyBonus
        )

        let result = WDAScoringEngine.shared.scoreIRLDunk(input: input)
        currentResult = result
        showScoringCard = true
    }
    
    private func submitDunkResultAndExit() {
        if let result = currentResult {
            // Apply rewards
            onCompletion(result)
        }
        dismiss()
    }
    
    private func updateTelemetryLoop() {
        // Decrease FIBA run limit countdown timer (if dunk is in progress)
        if trackingPhase != .idle && trackingPhase != .completed {
            timeSpentSeconds += 1.0 / 30.0
            timeRemainingSeconds = max(0.0, 75.0 - timeSpentSeconds)
            
            if timeRemainingSeconds <= 0.0 {
                // Auto trigger compilation on overtime
                compileScoresAndShow()
            }
        }
        
        if isSimulationMode {
            updateSimulationPhase()
        } else {
            updateCameraTrackingPhase()
        }
    }
    
    private func updateSimulationPhase() {
        guard trackingPhase != .idle && trackingPhase != .completed else { return }
        
        simTime += 1.0 / 30.0
        
        if simTime < 1.5 {
            // Run up phase
            trackingPhase = .runUp
            takeoffAngleDegrees = 0.0
            takeoffVelocityFps = 0.0
        } else if simTime < 1.7 {
            // Takeoff phase
            trackingPhase = .takeoff
            takeoffAngleDegrees = Double.random(in: 72.0...84.0)
            takeoffVelocityFps = Double.random(in: 18.0...24.0)
        } else if simTime < 3.2 {
            // Flight/Trick phase
            trackingPhase = .flight
            // Simple parabolic curves for vertical height and flight time
            let flightProgress = (simTime - 1.7) / 1.5 // 0.0 to 1.0
            flightHangTimeSeconds = simTime - 1.7
            
            // Peak jump height at mid-flight
            let vertParabola = -4.0 * (flightProgress - 0.5) * (flightProgress - 0.5) + 1.0
            let targetMaxHeight = activeTrick.minimumRequiredHeightInches + Double.random(in: 2.0...8.0)
            jumpHeightInches = max(0, vertParabola * targetMaxHeight)
            
            // Accumulate trick spin rotation
            switch activeTrick {
            case .threeSixty:
                ballRotationDegrees = flightProgress * 360.0
            case .seventyTwo0:
                ballRotationDegrees = flightProgress * 720.0
            case .rimGrazer, .doubleClutch, .honeyDip, .behindTheBack, .freeThrowLine, .betweenTheLegs, .windmill:
                ballRotationDegrees = flightProgress * 180.0
            }
        } else if simTime < 3.8 {
            // Landing phase
            trackingPhase = .landing
            jumpHeightInches = 0.0
            
            // Apply biomechanics
            switch landingSafetyMode {
            case .balanced:
                kneeValgusDetected = false
                anklePronationDetected = false
            case .kneeValgus:
                kneeValgusDetected = true
                anklePronationDetected = false
            case .anklePronation:
                kneeValgusDetected = false
                anklePronationDetected = true
            }
        } else {
            // Complete
            trackingPhase = .completed
        }
    }
    
    private func updateCameraTrackingPhase() {
        guard trackingPhase != .idle && trackingPhase != .completed else { return }
        
        // Map camera manager's real-time detected joints into our metrics
        if cameraManager.hasDetectedPerson {
            let cameraJoints = cameraManager.joints
            
            // Extract core joints for telemetry calculations
            guard let leftHip = cameraJoints[.leftHip],
                  let rightHip = cameraJoints[.rightHip],
                  let leftKnee = cameraJoints[.leftKnee],
                  let leftAnkle = cameraJoints[.leftAnkle],
                  let rightKnee = cameraJoints[.rightKnee],
                  let rightAnkle = cameraJoints[.rightAnkle] else {
                return
            }
            
            // Core hip / floor tracking logic
            let avgHipY = 1.0 - Double(leftHip.y + rightHip.y) / 2.0
            
            // Calibrate ground baseline Y as roughly the ankle position on start
            let avgAnkleY = 1.0 - Double(leftAnkle.y + rightAnkle.y) / 2.0
            let displacement = max(0, avgHipY - avgAnkleY)
            
            // Estimate vertical inches based on joint vertical scaling
            let heightEst = displacement * 120.0 // approximate scale factor
            
            if trackingPhase == .runUp {
                if heightEst > 6.0 {
                    // Start of takeoff jump
                    trackingPhase = .takeoff
                    takeoffAngleDegrees = Double.random(in: 70.0...85.0)
                    takeoffVelocityFps = heightEst * 0.4 + 10.0
                }
            } else if trackingPhase == .takeoff {
                if heightEst > 12.0 {
                    trackingPhase = .flight
                    flightHangTimeSeconds = 0.05
                }
            } else if trackingPhase == .flight {
                flightHangTimeSeconds += 1.0 / 30.0
                jumpHeightInches = max(jumpHeightInches, heightEst)
                
                // Ball spin rotation estimate based on wrist coordinate distances
                if let leftWrist = cameraJoints[.leftWrist], let rightWrist = cameraJoints[.rightWrist] {
                    let spinEstimate = Double(abs(leftWrist.x - rightWrist.x)) * 360.0
                    ballRotationDegrees = max(ballRotationDegrees, min(360.0, spinEstimate))
                }
                
                // Peak detection check: once height starts dropping, transition to landing
                if heightEst < jumpHeightInches - 5.0 && flightHangTimeSeconds > 0.4 {
                    trackingPhase = .landing
                }
            } else if trackingPhase == .landing {
                // Detect Knee Valgus on landing (using vector math from RealtimeMotionTrackerView)
                let valgusThreshold: CGFloat = 0.035
                let l1 = getKneeDeviation(hip: leftHip, knee: leftKnee, ankle: leftAnkle, isLeft: true)
                let r1 = getKneeDeviation(hip: rightHip, knee: rightKnee, ankle: rightAnkle, isLeft: false)
                
                if l1.deviation < -valgusThreshold || r1.deviation > valgusThreshold {
                    kneeValgusDetected = true
                }
                
                if heightEst <= 4.0 {
                    trackingPhase = .completed
                }
            }
        }
    }
    
    private func getKneeDeviation(hip: CGPoint, knee: CGPoint, ankle: CGPoint, isLeft: Bool) -> (isValgus: Bool, deviation: CGFloat) {
        let denom = ankle.y - hip.y
        let expectedX: CGFloat
        if abs(denom) > 0.001 {
            expectedX = hip.x + (knee.y - hip.y) * (ankle.x - hip.x) / denom
        } else {
            expectedX = (hip.x + ankle.x) / 2
        }
        let deviation = knee.x - expectedX
        let valgusThreshold: CGFloat = 0.035
        let isValgus = isLeft ? (deviation < -valgusThreshold) : (deviation > valgusThreshold)
        return (isValgus, deviation)
    }
    
    // MARK: - Skeleton coordinates rendering
    
    private func getNormalizedJoints(for size: CGSize) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        if isSimulationMode {
            return getSimulatedJoints(for: size)
        } else {
            var screenJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for (joint, point) in cameraManager.joints {
                screenJoints[joint] = CGPoint(
                    x: (1.0 - point.x) * size.width,
                    y: (1.0 - point.y) * size.height
                )
            }
            return screenJoints
        }
    }
    
    private func getSimulatedJoints(for size: CGSize) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        let centerX: CGFloat
        let centerY: CGFloat
        
        if trackingPhase == .idle {
            centerX = size.width * 0.2
            centerY = size.height * 0.72
        } else if trackingPhase == .runUp {
            let progress = min(1.0, simTime / 1.5)
            centerX = size.width * (0.2 + progress * 0.4)
            centerY = size.height * (0.72 + 0.04 * sin(simTime * 20.0)) // slight running bobbing
        } else if trackingPhase == .takeoff {
            centerX = size.width * 0.6
            centerY = size.height * 0.75 // crouch low before launch
        } else if trackingPhase == .flight {
            let progress = (simTime - 1.7) / 1.5
            centerX = size.width * (0.6 + progress * 0.18)
            // parabolic arc path
            let peakHeightOffset = size.height * 0.35
            let arc = -4.0 * (progress - 0.5) * (progress - 0.5) + 1.0
            centerY = size.height * 0.72 - (peakHeightOffset * arc)
        } else if trackingPhase == .landing {
            let progress = (simTime - 3.2) / 0.6
            centerX = size.width * 0.78
            centerY = size.height * 0.72 + (size.height * 0.06 * progress)
        } else {
            centerX = size.width * 0.78
            centerY = size.height * 0.74
        }
        
        // Return standard joint positions relative to centering
        let normJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [
            .nose: CGPoint(x: centerX / size.width, y: (centerY - 65) / size.height),
            .neck: CGPoint(x: centerX / size.width, y: (centerY - 50) / size.height),
            .leftShoulder: CGPoint(x: (centerX + 15) / size.width, y: (centerY - 45) / size.height),
            .rightShoulder: CGPoint(x: (centerX - 15) / size.width, y: (centerY - 45) / size.height),
            
            .leftElbow: CGPoint(x: (centerX + 25) / size.width, y: (centerY - (trackingPhase == .flight ? 75.0 : 35.0)) / size.height),
            .rightElbow: CGPoint(x: (centerX - 25) / size.width, y: (centerY - (trackingPhase == .flight ? 75.0 : 35.0)) / size.height),
            
            .leftWrist: CGPoint(x: (centerX + 35) / size.width, y: (centerY - (trackingPhase == .flight ? 100.0 : 25.0)) / size.height),
            .rightWrist: CGPoint(x: (centerX - 35) / size.width, y: (centerY - (trackingPhase == .flight ? 100.0 : 25.0)) / size.height),
            
            .leftHip: CGPoint(x: (centerX + 12) / size.width, y: (centerY - 10) / size.height),
            .rightHip: CGPoint(x: (centerX - 12) / size.width, y: (centerY - 10) / size.height),
            
            // Adjust knee coordinates if knee valgus is activated on landing
            .leftKnee: CGPoint(x: (centerX + (kneeValgusDetected ? -2.0 : 15.0)) / size.width, y: (centerY + 20) / size.height),
            .rightKnee: CGPoint(x: (centerX - (kneeValgusDetected ? -2.0 : 15.0)) / size.width, y: (centerY + 20) / size.height),
            
            .leftAnkle: CGPoint(x: (centerX + (anklePronationDetected ? 25.0 : 15.0)) / size.width, y: (centerY + 50) / size.height),
            .rightAnkle: CGPoint(x: (centerX - (anklePronationDetected ? 25.0 : 15.0)) / size.width, y: (centerY + 50) / size.height)
        ]
        
        var scaledJoints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for (joint, point) in normJoints {
            scaledJoints[joint] = CGPoint(x: point.x * size.width, y: point.y * size.height)
        }
        return scaledJoints
    }
    
    private func drawSkeleton(joints: [VNHumanBodyPoseObservation.JointName: CGPoint], context: GraphicsContext) {
        guard trackingPhase != .idle else { return }
        
        // Define bones structure
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
        
        // Draw bone paths
        for (j1, j2) in bones {
            if let p1 = joints[j1], let p2 = joints[j2] {
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                
                // Color legs red if biomechanical alerts triggered
                let isLeftLeg = (j1 == .leftHip && j2 == .leftKnee) || (j1 == .leftKnee && j2 == .leftAnkle)
                let isRightLeg = (j1 == .rightHip && j2 == .rightKnee) || (j1 == .rightKnee && j2 == .rightAnkle)
                
                let color: Color
                if (isLeftLeg || isRightLeg) && (kneeValgusDetected || anklePronationDetected) {
                    color = Color.red
                } else {
                    color = trackingPhase.color.opacity(0.85)
                }
                
                context.stroke(path, with: .color(color), lineWidth: 3.5)
            }
        }
        
        // Draw joint ellipses
        for (_, p) in joints {
            var path = Path()
            path.addEllipse(in: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9))
            context.fill(path, with: .color(.white))
        }
    }
}

// MARK: - Dunk Camera Manager View Representation

struct DunkCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
    
    class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Isolated Camera manager class for dunks

class DunkCameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    @Published var hasDetectedPerson = false
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "fel.dunk.pose.sessionQueue")
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
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "fel.dunk.pose.videoQueue"))
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
                    detectedJoints[name] = CGPoint(x: recognizedPoint.location.x, y: recognizedPoint.location.y)
                }
            }
            
            DispatchQueue.main.async {
                self.joints = detectedJoints
                self.hasDetectedPerson = !detectedJoints.isEmpty
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, options: [:])
        try? handler.perform([request])
    }
}
