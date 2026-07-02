import SwiftUI
import Combine
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

                ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
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

// MARK: - Jump Height Meter

private struct JumpHeightMeter: View {
    let currentHeight: Double   // 0.0 – 1.0 normalised
    let maxHeight: Double       // 0.0 – 1.0 normalised peak marker

    private func fillColor(_ ratio: Double) -> Color {
        if ratio > 0.75 { return .red }
        if ratio > 0.45 { return .yellow }
        return Color(red: 0.0, green: 0.85, blue: 0.45)
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let fillH = h * CGFloat(max(0, min(1, currentHeight)))
            let peakY = h * (1.0 - CGFloat(max(0, min(1, maxHeight))))

            ZStack(alignment: .bottom) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: w, height: h)

                // Fill bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                fillColor(currentHeight).opacity(0.9),
                                fillColor(currentHeight).opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w, height: fillH)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentHeight)

                // Peak marker line
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: w + 4, height: 2)
                    .offset(y: -(h - peakY - 1))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: maxHeight)

                // Tick marks
                ForEach([0.25, 0.5, 0.75], id: \.self) { tick in
                    Rectangle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: w * 0.5, height: 1)
                        .offset(y: -(h * CGFloat(tick) - 1))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - Session Arc Timer

private struct SessionArcTimer: View {
    let remaining: Int   // seconds
    let total: Int       // seconds (90)

    private var fraction: Double {
        Double(remaining) / Double(max(1, total))
    }

    private var arcColor: Color {
        if remaining <= 10 { return .red }
        if remaining <= 30 { return .orange }
        return Color(red: 0.0, green: 0.9, blue: 1.0)
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 5)

            // Progress arc (drains clockwise)
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(
                    arcColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)

            // Time text
            VStack(spacing: 1) {
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(arcColor)
                    .contentTransition(.numericText())
                Text("LEFT")
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
        }
    }
}

// MARK: - Jump Count Badge

private struct JumpCountBadge: View {
    let count: Int
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 52, height: 52)
                .scaleEffect(pulse ? 1.22 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: pulse)

            VStack(spacing: 0) {
                Text("\(count)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("JUMPS")
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
        }
        .onChange(of: count) {
            pulse = true
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                await MainActor.run { pulse = false }
            }
        }
    }
}

// MARK: - Personal Best Flash Overlay

private struct PersonalBestFlash: View {
    let isVisible: Bool

    var body: some View {
        ZStack {
            Color.yellow.opacity(0.18)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)
                Text("NEW BEST!")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .tracking(3)
                    .shadow(color: .yellow.opacity(0.7), radius: 8)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: isVisible)
    }
}

// MARK: - Ten-Second Warning Border

private struct TenSecondBorder: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let alpha = isActive ? (0.55 + 0.45 * sin(t * 5.0)) : 0.0
            Rectangle()
                .strokeBorder(Color.red.opacity(alpha), lineWidth: 6)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Kai Reaction Line

private struct KaiReactionLine: View {
    let score: Double
    let isVisible: Bool

    private var line: String {
        if score > 8.5 { return "ELITE HANG TIME! Certified." }
        if score >= 7.0 { return "That's it! Push through!" }
        return "Work harder! I need elevation."
    }

    private var lineColor: Color {
        if score > 8.5 { return .yellow }
        if score >= 7.0 { return Color(red: 0.0, green: 0.9, blue: 1.0) }
        return .orange
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "quote.opening")
                .font(.system(size: 9))
                .foregroundStyle(lineColor.opacity(0.7))
            Text(line)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(lineColor)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(lineColor.opacity(0.30), lineWidth: 1)
                )
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 8)
        .animation(.spring(response: 0.30, dampingFraction: 0.75), value: isVisible)
    }
}

// MARK: - IRLDunkView

struct IRLDunkView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = IRLCameraSession()
    @State private var healthKit = HealthKitService()
    @State private var phase: IRLPhase = .ready
    @State private var jumpCount = 0
    @State private var scores: [Double] = []
    @State private var lastScore: Double? = nil
    @State private var kaiFeedback = ""
    @State private var showPopup = false
    @State private var sessionTime = 90
    @State private var heartRate: Double = 72
    @State private var timerTask: Task<Void, Never>?

    // Visual enhancement state
    @State private var currentJumpNorm: Double = 0.0    // 0–1 for jump meter fill
    @State private var peakJumpNorm: Double = 0.0       // 0–1 for peak marker
    @State private var sessionBestRaw: Double = 0.0     // raw height cm for PB tracking
    @State private var showPBFlash = false
    @State private var showKaiReaction = false
    @State private var kaiReactionScore: Double = 0.0
    @State private var countdownWarningFired: Set<Int> = []   // track which marks fired

    private enum IRLPhase { case ready, active, result }

    private let kaiReactions = [
        "ELEVATION!", "HANG TIME!", "PURE POWER!", "CLEAN FORM",
        "EXPLOSIVE!", "LOCKED IN!", "TEXTBOOK!", "NASTY!", "HEAT CHECK!", "MAXIMUM EFFORT"
    ]

    private var totalScore: Double { scores.sorted(by: >).prefix(5).reduce(0, +) }
    private var bestScore: Double { scores.max() ?? 0 }

    // Normalise raw height (cm) to 0–1 across typical dunk range 30–80 cm
    private func normHeight(_ h: Double) -> Double {
        min(1.0, max(0.0, (h - 30.0) / 50.0))
    }

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

            // 10-second pulsing border
            TenSecondBorder(isActive: sessionTime <= 10)

            // Personal best gold flash
            PersonalBestFlash(isVisible: showPBFlash)

            // Jump height meter on left edge
            VStack {
                Spacer().frame(height: 120)
                JumpHeightMeter(currentHeight: currentJumpNorm, maxHeight: peakJumpNorm)
                    .frame(width: 14)
                    .padding(.leading, 10)
                Spacer().frame(height: 120)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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

                    // Session arc timer (replaces plain text timer)
                    SessionArcTimer(remaining: sessionTime, total: 90)
                        .frame(width: 76, height: 76)

                    Spacer()

                    // Jump count badge + total score
                    VStack(alignment: .trailing, spacing: 6) {
                        JumpCountBadge(count: jumpCount)
                        Text(String(format: "%.1f", totalScore))
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(gameMode.accentColor)
                        Text("TOTAL")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
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

                // ── Kai Reaction Dialog ──────────────────────────────
                KaiReactionLine(score: kaiReactionScore, isVisible: showKaiReaction)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

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

    // MARK: - Haptic Helpers

    private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    // MARK: - Logic

    private func startSession() {
        sessionTime = 90
        jumpCount = 0
        scores = []
        sessionBestRaw = 0.0
        peakJumpNorm = 0.0
        currentJumpNorm = 0.0
        countdownWarningFired = []

        // Haptic 4: .soft — session start (phase transitions to .active)
        hapticImpact(.soft)

        timerTask?.cancel()
        timerTask = Task {
            while sessionTime > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    sessionTime -= 1
                    handleTimerTick()
                }
            }
            await MainActor.run { endSession() }
        }

        if healthKit.isAuthorized {
            healthKit.startJumpTracking { height in
                Task { @MainActor in self.recordJump(height: height) }
            }
        }
    }

    private func handleTimerTick() {
        // Haptic 3: .medium — every 30-second mark (t=60, t=30, t=10 warn)
        let warningMarks = [60, 30, 10]
        for mark in warningMarks {
            if sessionTime == mark && !countdownWarningFired.contains(mark) {
                countdownWarningFired.insert(mark)
                hapticImpact(.medium)
            }
        }

        // Haptic 5: .light — each second of final 10-second countdown
        if sessionTime <= 10 && sessionTime > 0 {
            hapticImpact(.light)
        }

        // Drain the jump meter gradually between jumps
        if currentJumpNorm > 0 {
            currentJumpNorm = max(0, currentJumpNorm - 0.08)
        }
    }

    private func recordJump(height: Double) {
        let score = min(10.0, max(6.0, height * 0.145 + 3.5))
        scores.append(score)
        jumpCount += 1
        lastScore = score
        kaiFeedback = kaiReactions.randomElement() ?? "NICE!"
        heartRate = 80 + Double(jumpCount) * 1.2 + Double.random(in: -3...3)

        // Update jump meter
        let norm = normHeight(height)
        currentJumpNorm = norm

        // Haptic 1: .heavy — on each jump detected (kept from original)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Haptic 2: .rigid — personal best jump height during session
        let isPersonalBest = height > sessionBestRaw && jumpCount > 1
        if isPersonalBest {
            sessionBestRaw = height
            peakJumpNorm = norm
            hapticImpact(.rigid)
            // Show PB flash
            showPBFlash = true
            Task {
                try? await Task.sleep(for: .milliseconds(1200))
                await MainActor.run { withAnimation { showPBFlash = false } }
            }
        } else if jumpCount == 1 {
            // First jump always sets the baseline best
            sessionBestRaw = height
            peakJumpNorm = norm
        }

        // Kai reaction line
        kaiReactionScore = score
        withAnimation { showKaiReaction = true }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            await MainActor.run { withAnimation { showKaiReaction = false } }
        }

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

        // Haptic 6: .error — session ends with zero jumps (no activity detected)
        if jumpCount == 0 {
            hapticNotification(.error)
        }

        GameResultService.saveResult(modeId: "basketball_irl", userScore: Int(totalScore * 10))
        phase = .result
    }
}
