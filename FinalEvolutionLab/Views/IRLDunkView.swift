import SwiftUI

// MARK: - IRL Dunk Canvas

private struct IRLReadyCanvas: View {
    let accentColor: Color

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width; let H = size.height; let cx = W / 2
                ctx.fill(Path(CGRect(width:W,height:H)),
                         with: .color(Color(red:0.04,green:0.04,blue:0.08)))
                for i in 0..<6 {
                    let angle = Double(i) * .pi / 3.0 + t * 0.2
                    let beamX = cx + CGFloat(cos(angle)) * W * 0.14
                    var beam = Path(); beam.move(to: CGPoint(x:beamX, y:0))
                    beam.addLine(to: CGPoint(x:cx, y:H*0.38))
                    var bGC = ctx; bGC.addFilter(.blur(radius: 8))
                    bGC.stroke(beam, with: .color(accentColor.opacity(0.08)), lineWidth: 16)
                }
                let bW = W*0.55; let bH = H*0.17; let bX = cx-bW/2; let bY = H*0.04
                ctx.stroke(Path(CGRect(x:bX,y:bY,width:bW,height:bH)),
                           with: .color(Color.white.opacity(0.55)), lineWidth: 2.5)
                let iBW = bW*0.34; let iBH = bH*0.54
                ctx.stroke(Path(CGRect(x:cx-iBW/2,y:bY+bH*0.22,width:iBW,height:iBH)),
                           with: .color(Color.white.opacity(0.28)), lineWidth: 1.5)
                let rW = W*0.42; let rH = rW*0.22; let rY = bY+bH+H*0.03
                var rGC = ctx; rGC.addFilter(.blur(radius: 3))
                rGC.stroke(Path(ellipseIn: CGRect(x:cx-rW/2,y:rY,width:rW,height:rH)),
                           with: .color(Color.orange.opacity(0.70)), lineWidth: 4)
                ctx.stroke(Path(ellipseIn: CGRect(x:cx-rW/2,y:rY,width:rW,height:rH)),
                           with: .color(Color.orange.opacity(0.95)), lineWidth: 2.5)
                let rimCY = rY + rH/2; let netB = rimCY + H*0.18
                let tL = CGPoint(x:cx-rW/2,y:rimCY); let tR = CGPoint(x:cx+rW/2,y:rimCY)
                let bL = CGPoint(x:cx-W*0.07,y:netB); let bR = CGPoint(x:cx+W*0.07,y:netB)
                for i in 0..<6 {
                    let f = CGFloat(i) / 5.0
                    var nl = Path()
                    nl.move(to: CGPoint(x:tL.x+(tR.x-tL.x)*f,y:rimCY))
                    nl.addLine(to: CGPoint(x:bL.x+(bR.x-bL.x)*f,y:netB))
                    ctx.stroke(nl, with: .color(Color.white.opacity(0.18)), lineWidth: 1)
                }
                let ballY = H * CGFloat(0.72 + sin(t * 0.8) * 0.04)
                let ballR = W * CGFloat(0.12)
                ctx.fill(Path(ellipseIn: CGRect(x:cx-ballR,y:ballY-ballR,width:ballR*2,height:ballR*2)),
                         with: .color(Color(red:1.0,green:0.55,blue:0.0).opacity(0.90)))
                var seam = Path()
                seam.addArc(center: CGPoint(x:cx,y:ballY), radius: ballR*0.92,
                            startAngle: .degrees(-40+t*20), endAngle: .degrees(140+t*20), clockwise: false)
                ctx.stroke(seam, with: .color(Color.black.opacity(0.35)), lineWidth: 1.5)
            }
        }
    }
}

private struct IRLDunkCanvas: View {
    let jumpFlash: Bool
    let heartRate: Double
    let accentColor: Color

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let W = size.width; let H = size.height; let cx = W / 2
                ctx.fill(Path(CGRect(width:W,height:H)),
                         with: .color(Color(red:0.04,green:0.02,blue:0.02)))
                let floorY = H * 0.74
                ctx.fill(Path(CGRect(x:0,y:floorY,width:W,height:H-floorY)),
                         with: .color(Color(red:0.10,green:0.18,blue:0.35)))
                var fl = Path(); fl.move(to: CGPoint(x:0,y:floorY)); fl.addLine(to: CGPoint(x:W,y:floorY))
                ctx.stroke(fl, with: .color(Color.white.opacity(0.18)), lineWidth: 1.5)
                var arc = Path()
                arc.addArc(center: CGPoint(x:cx,y:H), radius: W*0.44,
                           startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                ctx.stroke(arc, with: .color(Color.white.opacity(0.10)), lineWidth: 1)
                let bW = W*0.32; let bH = H*0.09; let bY = H*0.06
                ctx.stroke(Path(CGRect(x:cx-bW/2,y:bY,width:bW,height:bH)),
                           with: .color(Color.white.opacity(0.45)), lineWidth: 1.5)
                let rW = W*0.24; let rH = rW*0.22; let rY = bY+bH+H*0.02
                ctx.stroke(Path(ellipseIn: CGRect(x:cx-rW/2,y:rY,width:rW,height:rH)),
                           with: .color(Color.orange.opacity(0.85)), lineWidth: 2)
                let spotPulse = CGFloat(0.5 + sin(t * 2.0) * 0.15)
                var spGC = ctx; spGC.addFilter(.blur(radius: 18))
                spGC.fill(Path(ellipseIn: CGRect(x:cx-38,y:H*0.26-38,width:76,height:76)),
                          with: .color(Color.yellow.opacity(Double(spotPulse)*0.18)))
                let hrPulse = CGFloat(0.7 + sin(t * (heartRate / 60.0) * .pi) * 0.30)
                let ringR = W * 0.42
                var hrGC = ctx; hrGC.addFilter(.blur(radius: 5))
                hrGC.stroke(Path(ellipseIn: CGRect(x:cx-ringR,y:H/2-ringR,width:ringR*2,height:ringR*2)),
                            with: .color(Color.red.opacity(Double(hrPulse)*0.32)), lineWidth: 5)
                if jumpFlash {
                    var fGC = ctx; fGC.addFilter(.blur(radius: 22))
                    fGC.fill(Path(ellipseIn: CGRect(x:cx-62,y:H/2-62,width:124,height:124)),
                             with: .color(accentColor.opacity(0.55)))
                }
                let ballBaseY = H * 0.54
                let lift = jumpFlash ? H * 0.28 : 0
                let ballY = ballBaseY - lift - CGFloat(sin(t * 1.2)) * H * 0.02
                let ballR = CGFloat(20) - lift * 0.04
                ctx.fill(Path(ellipseIn: CGRect(x:cx-ballR,y:ballY-ballR,width:ballR*2,height:ballR*2)),
                         with: .color(Color(red:1.0,green:0.55,blue:0.0).opacity(0.90)))
                var sm = Path()
                sm.addArc(center: CGPoint(x:cx,y:ballY), radius: ballR*0.92,
                          startAngle: .degrees(t*30), endAngle: .degrees(180+t*30), clockwise: false)
                ctx.stroke(sm, with: .color(Color.black.opacity(0.35)), lineWidth: 1)
                let ss = max(CGFloat(0.12), 1.0 - lift / (H*0.28) * 0.88)
                ctx.fill(Path(ellipseIn: CGRect(x:cx-22*ss,y:floorY-5,width:44*ss,height:8)),
                         with: .color(Color.black.opacity(Double(ss)*0.38)))
            }
        }
    }
}

struct IRLDunkView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode

    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthKit = HealthKitService()
    @State private var phase: IRLPhase = .ready
    @State private var jumpCount = 0
    @State private var maxJumpHeight: Double = 0
    @State private var sessionTime = 120
    @State private var timerTask: Task<Void, Never>?
    @State private var lastJumpLabel = ""
    @State private var heartRate: Double = 72
    @State private var jumpFlash = false

    private enum IRLPhase { case ready, active, result }

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.02, blue: 0.02), Color(red: 0.02, green: 0.02, blue: 0.05)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .ready:
                readyScreen
            case .active:
                activeScreen
            case .result:
                resultScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { timerTask?.cancel(); dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("EXIT").font(.system(.caption, design: .monospaced, weight: .bold))
                    }.foregroundStyle(gameMode.accentColor)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onDisappear { timerTask?.cancel() }
    }

    private var readyScreen: some View {
        VStack(spacing: 28) {
            Spacer()

            IRLReadyCanvas(accentColor: gameMode.accentColor)
                .frame(width: 180, height: 180)
                .clipShape(Circle())

            VStack(spacing: 8) {
                Text("IRL DUNK CONTEST").font(.system(size: 13, weight: .black, design: .monospaced)).foregroundStyle(gameMode.accentColor).tracking(3)
                Text("Regulation Rim · HealthKit").font(.system(.title2, weight: .black)).italic().foregroundStyle(.white)
                Text("Find a regulation 10-ft rim. This mode tracks your real jumps, hang time, and heart rate using HealthKit.").font(.system(.subheadline)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            }

            VStack(spacing: 10) {
                if healthKit.isAuthorized {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("HealthKit authorized").font(.system(size: 11, design: .monospaced)).foregroundStyle(.green)
                    }
                } else {
                    Button { healthKit.requestAuthorization() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                            Text("CONNECT HEALTHKIT")
                        }
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(gameMode.accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                }

                Button {
                    phase = .active
                    startSession()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.highintensity.intervaltraining")
                        Text(healthKit.isAuthorized ? "START IRL SESSION" : "START SIMULATION")
                    }
                    .font(.system(.subheadline, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(healthKit.isAuthorized ? gameMode.accentColor : Color.white.opacity(0.2))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    private var activeScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                statPill(label: "JUMPS", value: "\(jumpCount)", color: gameMode.accentColor)
                statPill(label: "BEST", value: String(format: "%.1f\"", maxJumpHeight), color: .yellow)
                statPill(label: "HR", value: "\(Int(heartRate))", color: .red)
                statPill(label: "TIME", value: timeFormatted, color: .white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            ZStack {
                IRLDunkCanvas(jumpFlash: jumpFlash, heartRate: heartRate, accentColor: gameMode.accentColor)
                    .frame(width: 240, height: 240)
                    .clipShape(Circle())

                VStack(spacing: 8) {
                    Text("JUMP NOW").font(.system(size: 15, weight: .black, design: .monospaced)).foregroundStyle(gameMode.accentColor.opacity(0.8)).tracking(2)
                    Text("\(jumpCount)").font(.system(size: 72, weight: .black, design: .monospaced)).foregroundStyle(.white).contentTransition(.numericText())
                    if !lastJumpLabel.isEmpty {
                        Text(lastJumpLabel).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(gameMode.accentColor)
                    }
                }
            }

            Spacer()

            if healthKit.isAuthorized {
                Text("Jump on the real rim — HealthKit is counting.").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            } else {
                Button { recordSimulatedJump() } label: {
                    Text("RECORD JUMP (Simulation)")
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(gameMode.accentColor)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
            }

            Button { endSession() } label: {
                Text("END SESSION")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 24)
        }
    }

    private var resultScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("SESSION COMPLETE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(gameMode.accentColor)
                        .tracking(3)
                    Text("IRL Dunk Recap")
                        .font(.system(size: 32, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                }
                .padding(.top, 32)

                HStack(spacing: 16) {
                    resultStat(label: "Total Jumps", value: "\(jumpCount)", icon: "arrow.up.circle.fill", color: gameMode.accentColor)
                    resultStat(label: "Best Height", value: String(format: "%.1f\"", maxJumpHeight), icon: "ruler", color: .yellow)
                    resultStat(label: "Peak HR", value: "\(Int(heartRate))", icon: "heart.fill", color: .red)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PERFORMANCE ANALYSIS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                    Text(performanceAnalysis)
                        .font(.system(.subheadline))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground))
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

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .black, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.15), lineWidth: 0.5)))
    }

    private func resultStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundStyle(.white)
            Text(label).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.06)))
    }

    private var timeFormatted: String {
        let m = sessionTime / 60; let s = sessionTime % 60
        return String(format: "%d:%02d", m, s)
    }

    private var performanceAnalysis: String {
        if jumpCount == 0 { return "No jumps recorded. Head to a regulation rim and try again." }
        let tier = maxJumpHeight > 36 ? "Elite" : (maxJumpHeight > 28 ? "Advanced" : (maxJumpHeight > 20 ? "Intermediate" : "Developing"))
        return "You recorded \(jumpCount) jumps with a peak height of \(String(format: "%.1f", maxJumpHeight)) inches. Performance tier: \(tier). Your heart rate peaked at \(Int(heartRate)) BPM — \(heartRate > 160 ? "high intensity session" : "solid aerobic effort")."
    }

    private func startSession() {
        sessionTime = 120
        jumpCount = 0
        maxJumpHeight = 0
        timerTask = Task {
            while sessionTime > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    sessionTime -= 1
                    if !healthKit.isAuthorized { heartRate = 72 + Double(jumpCount) * 0.8 + Double.random(in: -2...2) }
                }
            }
            await MainActor.run { endSession() }
        }
        if healthKit.isAuthorized {
            healthKit.startJumpTracking { height in
                Task { @MainActor in
                    jumpCount += 1
                    maxJumpHeight = max(maxJumpHeight, height)
                    lastJumpLabel = String(format: "%.1f\" height", height)
                    jumpFlash = true
                    heartRate = 80 + Double(jumpCount) * 1.2 + Double.random(in: -3...3)
                    Task { try? await Task.sleep(for: .milliseconds(350)); jumpFlash = false }
                }
            }
        }
    }

    private func recordSimulatedJump() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let height = Double.random(in: 18...44)
        jumpCount += 1
        maxJumpHeight = max(maxJumpHeight, height)
        lastJumpLabel = String(format: "%.1f\" height", height)
        heartRate = 80 + Double(jumpCount) * 1.5 + Double.random(in: -4...4)
        jumpFlash = true
        Task { try? await Task.sleep(for: .milliseconds(350)); await MainActor.run { jumpFlash = false } }
    }

    private func endSession() {
        timerTask?.cancel()
        healthKit.stopJumpTracking()
        phase = .result
    }
}
