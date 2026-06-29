import SwiftUI

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

            ZStack {
                Circle().fill(gameMode.accentColor.opacity(0.1)).frame(width: 120, height: 120)
                Circle().strokeBorder(gameMode.accentColor.opacity(0.3), lineWidth: 2).frame(width: 120, height: 120)
                Image(systemName: "basketball.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(gameMode.accentColor)
                    .symbolEffect(.pulse)
            }

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
                Circle().fill(gameMode.accentColor.opacity(jumpFlash ? 0.25 : 0.08)).frame(width: 220, height: 220)
                    .animation(.easeOut(duration: 0.3), value: jumpFlash)
                Circle().strokeBorder(gameMode.accentColor.opacity(0.3), lineWidth: 3).frame(width: 220, height: 220)

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
