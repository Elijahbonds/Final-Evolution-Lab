import SwiftUI
import AVFoundation

// MARK: - Camera Session

private final class IRLCameraSession: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var isAuthorized = false

    override init() {
        super.init()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.configure() }
                }
            }
        default:
            break
        }
    }

    private func configure() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            self.session.commitConfiguration()
        }
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .background).async { self.session.startRunning() }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .background).async { self.session.stopRunning() }
    }
}

// MARK: - Camera Preview

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView { PreviewView(session: session) }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
}

// MARK: - Kai Proctor Canvas

private struct KaiProctorCanvas: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width; let H = size.height
                let cx = W / 2; let cy = H * 0.44
                let acc = Color(red: 0.0, green: 0.9, blue: 1.0)

                ctx.fill(Path(CGRect(width: W, height: H)),
                         with: .color(Color(red: 0.04, green: 0.06, blue: 0.10)))

                ctx.stroke(Path(ellipseIn: CGRect(x: cx-22, y: cy-28, width: 44, height: 52)),
                           with: .color(acc.opacity(0.52)), lineWidth: 1.5)

                var ibW = Path()
                ibW.addRect(CGRect(x: cx-12, y: cy-32, width: 24, height: 8))
                ctx.fill(ibW, with: .color(Color(red:0.04,green:0.06,blue:0.10)))

                let blink = sin(t * 3.5) > 0.92
                if !blink {
                    for ex in [cx - 8.5, cx + 8.5] as [CGFloat] {
                        var eGC = ctx; eGC.addFilter(.blur(radius: 2))
                        eGC.fill(Path(ellipseIn: CGRect(x: ex-4, y: cy-13, width: 8, height: 5)),
                                 with: .color(acc.opacity(0.90)))
                    }
                }

                let scanY = cy - 28 + CGFloat(fmod(t * 0.9, 1.0)) * 52
                var scanLine = Path()
                scanLine.move(to: CGPoint(x: cx-20, y: scanY))
                scanLine.addLine(to: CGPoint(x: cx+20, y: scanY))
                var sGC = ctx; sGC.addFilter(.blur(radius: 1.5))
                sGC.stroke(scanLine, with: .color(acc.opacity(0.35)), lineWidth: 1.5)

                for i in 0..<3 {
                    let dp = fmod(t * 2.0 + Double(i) * 0.4, 1.0)
                    let dx = cx - 8 + CGFloat(i) * 8
                    ctx.fill(Path(ellipseIn: CGRect(x: dx-2, y: cy+26, width: 4, height: 4)),
                             with: .color(acc.opacity(dp < 0.5 ? 0.85 : 0.18)))
                }
            }
        }
    }
}

// MARK: - IRLDunkView

struct IRLDunkView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = IRLCameraSession()
    @StateObject private var healthKit = HealthKitService()
    @State private var phase: IRLPhase = .ready
    @State private var jumpCount = 0
    @State private var scores: [Double] = []
    @State private var lastScore: Double? = nil
    @State private var kaiFeedback = ""
    @State private var showPopup = false
    @State private var sessionTime = 90
    @State private var heartRate: Double = 72
    @State private var timerTask: Task<Void, Never>?

    private enum IRLPhase { case ready, active, result }

    private let kaiReactions = [
        "ELEVATION!", "HANG TIME!", "PURE POWER!", "CLEAN FORM",
        "EXPLOSIVE!", "LOCKED IN!", "TEXTBOOK!", "NASTY!", "HEAT CHECK!", "MAXIMUM EFFORT"
    ]

    private var totalScore: Double { scores.sorted(by: >).prefix(5).reduce(0, +) }
    private var bestScore: Double { scores.max() ?? 0 }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            switch phase {
            case .ready:  readyScreen
            case .active: activeScreen
            case .result: resultScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { camera.stop(); timerTask?.cancel(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { camera.stop(); timerTask?.cancel() }
    }

    // MARK: - Ready Screen

    private var readyScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 16) {
                KaiProctorCanvas(isActive: true)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red:0.0,green:0.9,blue:1.0).opacity(0.30), lineWidth: 1))

                VStack(alignment: .leading, spacing: 5) {
                    Text("YOUR PROCTOR")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary).tracking(2)
                    Text("Kai Nexus")
                        .font(.system(.title2, weight: .black)).italic().foregroundStyle(.white)
                    Text("AI JUDGE · LIVE SCORING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red:0.0,green:0.9,blue:1.0)).tracking(1)
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red:0.0,green:0.9,blue:1.0).opacity(0.14), lineWidth: 1))
            )
            .padding(.horizontal, 24)

            Spacer().frame(height: 28)

            VStack(spacing: 8) {
                Text("IRL DUNK CONTEST")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(gameMode.accentColor).tracking(3)
                Text("Proctored Competition")
                    .font(.system(.title2, weight: .black)).italic().foregroundStyle(.white)
                Text("Find a regulation 10-ft rim · Camera captures your run · Kai judges every jump live")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 28)

            VStack(spacing: 10) {
                ruleRow(icon: "camera.fill",            text: "Front camera opens — you're on screen")
                ruleRow(icon: "waveform.path.ecg",      text: "HealthKit auto-detects each jump")
                ruleRow(icon: "clock",                  text: "90 second competition window")
                ruleRow(icon: "star.fill",              text: "Best 5 scores count toward your total")
                ruleRow(icon: "person.fill.badge.plus",  text: "Kai scores 6.0–10.0 per jump")
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 32)

            Button {
                phase = .active
                camera.start()
                startSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text(camera.isAuthorized ? "START COMPETITION" : "ENABLE CAMERA + START")
                }
                .font(.system(.subheadline, weight: .black))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(gameMode.accentColor)
                .clipShape(.rect(cornerRadius: 16))
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func ruleRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(gameMode.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
            Spacer()
        }
    }

    // MARK: - Active Screen (Camera + Overlay)

    private var activeScreen: some View {
        ZStack {
            // Camera feed
            if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                Color(red: 0.04, green: 0.02, blue: 0.02).ignoresSafeArea()
            }

            // Gradient overlays for readability
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.black.opacity(0.75), Color.clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 160)
                Spacer()
                LinearGradient(colors: [Color.clear, Color.black.opacity(0.80)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 180)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top HUD ──────────────────────────────────────────
                HStack(alignment: .top, spacing: 14) {
                    // Kai panel
                    VStack(spacing: 4) {
                        KaiProctorCanvas(isActive: true)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red:0.0,green:0.9,blue:1.0).opacity(0.40), lineWidth: 1))
                        HStack(spacing: 3) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text("LIVE").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(.green)
                        }
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(timeFormatted)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(sessionTime < 20 ? .red : .white)
                            .contentTransition(.numericText())
                        Text("REMAINING")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", totalScore))
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(gameMode.accentColor)
                        Text("\(jumpCount) JUMPS")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // ── Score Popup ──────────────────────────────────────
                if showPopup, let sc = lastScore {
                    VStack(spacing: 6) {
                        Text(String(format: "%.1f", sc))
                            .font(.system(size: 72, weight: .black, design: .monospaced))
                            .foregroundStyle(sc >= 9.0 ? .yellow : sc >= 8.0 ? gameMode.accentColor : .white)
                        Text(kaiFeedback)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.white).tracking(2)
                        Text("KAI NEXUS")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(3)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.78))
                            .overlay(RoundedRectangle(cornerRadius: 20)
                                .stroke(sc >= 9.0 ? Color.yellow.opacity(0.55) : gameMode.accentColor.opacity(0.45),
                                        lineWidth: 1.5))
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }

                Spacer()

                // ── Bottom Controls ──────────────────────────────────
                VStack(spacing: 12) {
                    if healthKit.isAuthorized {
                        HStack(spacing: 6) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("HEALTHKIT · AUTO-DETECTING JUMPS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green).tracking(1)
                        }
                    } else {
                        Button { recordSimulatedJump() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("RECORD JUMP")
                            }
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(gameMode.accentColor)
                            .clipShape(.rect(cornerRadius: 16))
                        }
                        .padding(.horizontal, 24)
                    }

                    Button { endSession() } label: {
                        Text("END SESSION")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: showPopup)
    }

    // MARK: - Result Screen

    private var resultScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("SESSION COMPLETE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(gameMode.accentColor).tracking(3)
                    Text("IRL Dunk Recap")
                        .font(.system(size: 32, weight: .black)).italic().foregroundStyle(.white)
                }
                .padding(.top, 28)

                // Kai verdict
                HStack(spacing: 14) {
                    KaiProctorCanvas(isActive: false)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red:0.0,green:0.9,blue:1.0).opacity(0.25), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("KAI NEXUS — FINAL VERDICT")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(2)
                        Text(kaiVerdict)
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red:0.0,green:0.9,blue:1.0).opacity(0.12), lineWidth: 1)))
                .padding(.horizontal, 20)

                // Stats row
                HStack(spacing: 12) {
                    recapStat(label: "TOTAL", value: String(format: "%.1f", totalScore), color: gameMode.accentColor)
                    recapStat(label: "BEST", value: String(format: "%.1f", bestScore), color: .yellow)
                    recapStat(label: "JUMPS", value: "\(jumpCount)", color: .white)
                }
                .padding(.horizontal, 20)

                // Individual score cards
                if !scores.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("JUDGE SCORES — BEST 5 COUNT")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary).tracking(2)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(scores.indices, id: \.self) { i in
                                VStack(spacing: 3) {
                                    Text(String(format: "%.1f", scores[i]))
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundStyle(scores[i] >= 9.0 ? .yellow : .white)
                                    Text("J\(i+1)")
                                        .font(.system(size: 7, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground))
                    .padding(.horizontal, 20)
                }

                // PRQ gain banner
                HStack(spacing: 12) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 22)).foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("+\(prqGain) PRQ")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.yellow)
                        Text("Added to your Performance Readiness Quotient")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.yellow.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.18), lineWidth: 1)))
                .padding(.horizontal, 20)

                Button { dismiss() } label: {
                    Text("SAVE & EXIT")
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(gameMode.accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Helpers

    private var timeFormatted: String {
        String(format: "%d:%02d", sessionTime / 60, sessionTime % 60)
    }

    private var prqGain: Int {
        if totalScore >= 45 { return 18 }
        if totalScore >= 35 { return 12 }
        if totalScore >= 20 { return 6 }
        return jumpCount > 0 ? 3 : 0
    }

    private var kaiVerdict: String {
        guard jumpCount > 0 else {
            return "No jumps detected. Find a regulation rim and try again."
        }
        if totalScore >= 45 { return "Elite performance. \(jumpCount) dunks, \(String(format: "%.1f", bestScore)) peak. Exceptional athleticism." }
        if totalScore >= 35 { return "\(jumpCount) jumps, \(String(format: "%.1f", totalScore)) total. Advanced form. Strength training will push you further." }
        if totalScore >= 20 { return "Solid session. \(jumpCount) jumps recorded. Conditioning and plyometrics will elevate your vertical." }
        return "Session complete. \(jumpCount) jumps recorded. Keep training — the rim will feel lower."
    }

    private func recapStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary).tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.06)))
    }

    // MARK: - Logic

    private func startSession() {
        sessionTime = 90; jumpCount = 0; scores = []
        timerTask?.cancel()
        timerTask = Task {
            while sessionTime > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { sessionTime -= 1 }
            }
            await MainActor.run { endSession() }
        }
        if healthKit.isAuthorized {
            healthKit.startJumpTracking { height in
                Task { @MainActor in self.recordJump(height: height) }
            }
        }
    }

    private func recordJump(height: Double) {
        let score = min(10.0, max(6.0, height * 0.145 + 3.5))
        scores.append(score)
        jumpCount += 1
        lastScore = score
        kaiFeedback = kaiReactions.randomElement() ?? "NICE!"
        heartRate = 80 + Double(jumpCount) * 1.2 + Double.random(in: -3...3)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.28)) { showPopup = true }
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run { withAnimation { showPopup = false } }
        }
    }

    private func recordSimulatedJump() {
        recordJump(height: Double.random(in: 18...44))
    }

    private func endSession() {
        timerTask?.cancel()
        healthKit.stopJumpTracking()
        camera.stop()
        phase = .result
    }
}
