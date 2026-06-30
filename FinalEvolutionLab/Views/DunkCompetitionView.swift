import SwiftUI
import AVFoundation

// MARK: - Models

private struct LobbyPlayer: Identifiable {
    let id: String
    let displayName: String
    let prq: Int
    let wins: Int
    let losses: Int
    let entryFee: CompFee
    let avatarColor: Color
    let city: String
}

private enum CompFee: Equatable {
    case practice
    case shards(Int)
    case cashComingSoon(Int)

    var label: String {
        switch self {
        case .practice:          return "Free Practice"
        case .shards(let n):     return "\(n) shards"
        case .cashComingSoon(let d): return "$\(d) — Coming Soon"
        }
    }

    var shortLabel: String {
        switch self {
        case .practice:          return "FREE"
        case .shards(let n):     return "⟁ \(n)"
        case .cashComingSoon(let d): return "$\(d) 🔒"
        }
    }

    var color: Color {
        switch self {
        case .practice:          return .green
        case .shards:            return Color(red: 0, green: 0.83, blue: 1.0)
        case .cashComingSoon:    return .yellow
        }
    }

    var isLocked: Bool {
        if case .cashComingSoon = self { return true }
        return false
    }
}

private enum CompPhase {
    case lobby, matched, setup, countdown(Int), battle, result
}

private struct CompResult {
    let playerJumps: Int
    let playerMaxHeight: Double
    let opponentJumps: Int
    let opponentMaxHeight: Double
    var playerWon: Bool { playerMaxHeight >= opponentMaxHeight }
    var payout: Int
}

// MARK: - Static Lobby Data

private let lobbyPlayers: [LobbyPlayer] = [
    LobbyPlayer(id: "sky", displayName: "SkyWalker_88", prq: 82, wins: 14, losses: 3,
                entryFee: .shards(500), avatarColor: Color(red: 0.1, green: 0.7, blue: 1.0), city: "Compton, CA"),
    LobbyPlayer(id: "highrise", displayName: "HighRise", prq: 71, wins: 8, losses: 5,
                entryFee: .shards(100), avatarColor: .orange, city: "Atlanta, GA"),
    LobbyPlayer(id: "solomac", displayName: "SoloMac", prq: 65, wins: 22, losses: 12,
                entryFee: .practice, avatarColor: .green, city: "Chicago, IL"),
    LobbyPlayer(id: "vertking", displayName: "Vert_King", prq: 90, wins: 31, losses: 4,
                entryFee: .shards(1000), avatarColor: .purple, city: "Houston, TX"),
    LobbyPlayer(id: "breezy", displayName: "BreezyDunk", prq: 58, wins: 5, losses: 8,
                entryFee: .shards(100), avatarColor: Color(red: 0.95, green: 0.49, blue: 0.15), city: "Miami, FL"),
    LobbyPlayer(id: "cooljay", displayName: "CoolJay_NYC", prq: 76, wins: 17, losses: 9,
                entryFee: .shards(500), avatarColor: .cyan, city: "Brooklyn, NY"),
]

// MARK: - Main View

struct DunkCompetitionView: View {
    let viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthKit = HealthKitService()

    @State private var phase: CompPhase = .lobby
    @State private var selectedFee: CompFee = .practice
    @State private var selectedOpponent: LobbyPlayer? = nil
    @State private var countdownVal: Int = 3
    @State private var battleTime: Int = 180
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var jumpCount: Int = 0
    @State private var maxHeight: Double = 0
    @State private var lastHeight: String = ""
    @State private var jumpFlash: Bool = false
    @State private var opponentJumps: Int = 0
    @State private var opponentMax: Double = 0
    @State private var opponentUpdateTask: Task<Void, Never>? = nil
    @State private var result: CompResult? = nil
    @State private var showCashAlert: Bool = false
    @State private var lobbyRefreshTick: Int = 0

    private let accentColor = Color(red: 1.0, green: 0.3, blue: 0.1)

    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.02, blue: 0.02), Theme.deepBlack],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            switch phase {
            case .lobby:
                lobbyBody
            case .matched:
                matchedBody
            case .setup:
                setupBody
            case .countdown(let n):
                countdownBody(n)
            case .battle:
                battleBody
            case .result:
                if let r = result { resultBody(r) }
            }
        }
        .alert("Cash Mode Coming Soon", isPresented: $showCashAlert) {
            Button("Got It", role: .cancel) {}
        } message: {
            Text("Real-money competition powered by Apple Pay is in development. Use shards to compete now and earn your spot on the leaderboard.")
        }
        .onDisappear {
            timerTask?.cancel()
            opponentUpdateTask?.cancel()
            healthKit.stopJumpTracking()
        }
    }

    // MARK: - Lobby

    private var lobbyBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("IRL DUNK COMPETITION")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .tracking(3)
                    Text("1v1 · Set up at a hoop · Make money")
                        .font(.system(size: 28, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                    Text("Battle someone live in the queue or challenge a player directly. HealthKit tracks your jump height. Highest max wins.")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Entry Fee Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR ENTRY FEE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach([CompFee.practice, .shards(100), .shards(500), .shards(1000), .cashComingSoon(5), .cashComingSoon(20)], id: \.label) { fee in
                                feeChip(fee)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Queue Controls
                HStack(spacing: 12) {
                    Button { enterQueue() } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "list.number")
                                .font(.system(size: 20, weight: .bold))
                            Text("JOIN QUEUE")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                    }

                    Button {
                        // Future: quick match with similar PRQ
                        enterQueue()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 20, weight: .bold))
                            Text("QUICK MATCH")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentColor.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.3), lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)

                // Live Lobby
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("LIVE LOBBY")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        Circle().fill(.green).frame(width: 6, height: 6).symbolEffect(.pulse)
                        Text("\(lobbyPlayers.count) online")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        ForEach(lobbyPlayers) { player in
                            lobbyRow(player)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // How It Works
                howItWorksCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func feeChip(_ fee: CompFee) -> some View {
        Button {
            if fee.isLocked { showCashAlert = true; return }
            selectedFee = fee
        } label: {
            Text(fee.shortLabel)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(selectedFee == fee ? .black : (fee.isLocked ? .secondary : fee.color))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedFee == fee ? fee.color : fee.color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(fee.isLocked ? Color.white.opacity(0.1) : fee.color.opacity(0.3), lineWidth: 1))
                .clipShape(Capsule())
                .opacity(fee.isLocked ? 0.5 : 1.0)
        }
    }

    private func lobbyRow(_ player: LobbyPlayer) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(player.avatarColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(player.displayName.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(player.avatarColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(player.displayName)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text("PRQ \(player.prq)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(player.wins)W \(player.losses)L")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(player.city)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(player.entryFee.shortLabel)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(player.entryFee.color)

                Button {
                    if player.entryFee.isLocked { showCashAlert = true; return }
                    selectedOpponent = player
                    enterQueue()
                } label: {
                    Text("CHALLENGE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW IT WORKS")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)

            ForEach(Array(zip(
                ["1", "2", "3", "4"],
                [
                    ("camera.fill", "Set up your phone on a tripod facing a regulation 10-ft rim"),
                    ("heart.fill", "Enable HealthKit — it tracks every jump height automatically"),
                    ("timer", "3-minute window · Both players jump as many times as possible"),
                    ("trophy.fill", "Highest max vertical wins the entry fee pot"),
                ]
            )), id: \.0) { num, item in
                HStack(alignment: .top, spacing: 14) {
                    Text(num)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .frame(width: 20)
                    Image(systemName: item.0)
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor.opacity(0.7))
                        .frame(width: 18)
                    Text(item.1)
                        .font(.system(.caption))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: - Matched

    private var matchedBody: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("MATCH FOUND")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .tracking(4)

            HStack(spacing: 24) {
                playerPod(name: "YOU",
                          sub: "PRQ \(Int(viewModel.effectiveMetrics.prqScore))",
                          color: accentColor)
                Text("VS")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                playerPod(name: selectedOpponent?.displayName ?? "Opponent",
                          sub: "PRQ \(selectedOpponent?.prq ?? 70)",
                          color: selectedOpponent?.avatarColor ?? .red)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 6) {
                Text("Entry Fee: \(selectedFee.label)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(selectedFee.color)
                Text("Highest max jump in 3 minutes wins")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }

            Button { phase = .setup } label: {
                Text("ACCEPT & SETUP")
                    .font(.system(.subheadline, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button { phase = .lobby } label: {
                Text("Decline")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func playerPod(name: String, sub: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 64, height: 64)
                Text(String(name.prefix(2)).uppercased())
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }
            Text(name)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Setup

    private var setupBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("SETUP REQUIRED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .tracking(3)
                        .padding(.top, 32)
                    Text("Proctored Session")
                        .font(.system(size: 28, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                }

                setupSteps

                // HealthKit status
                HStack(spacing: 10) {
                    Image(systemName: healthKit.isAuthorized ? "checkmark.circle.fill" : "heart.fill")
                        .foregroundStyle(healthKit.isAuthorized ? .green : .red)
                    Text(healthKit.isAuthorized ? "HealthKit connected — jumps will be tracked automatically" : "HealthKit required for verified competition")
                        .font(.system(.caption))
                        .foregroundStyle(healthKit.isAuthorized ? .green : .red)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill((healthKit.isAuthorized ? Color.green : Color.red).opacity(0.08)))
                .padding(.horizontal, 20)

                if !healthKit.isAuthorized {
                    Button { healthKit.requestAuthorization() } label: {
                        Text("CONNECT HEALTHKIT")
                            .font(.system(.subheadline, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(accentColor)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    beginCountdown()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                        Text(healthKit.isAuthorized ? "I'M SET UP — START" : "START (Simulation Mode)")
                    }
                    .font(.system(.subheadline, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(healthKit.isAuthorized ? accentColor : Color.white.opacity(0.25))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var setupSteps: some View {
        VStack(spacing: 12) {
            ForEach(Array(zip(
                ["01", "02", "03", "04"],
                [
                    ("iphone.and.arrow.forward", "Place your phone on a tripod angled to capture your full vertical leap"),
                    ("figure.basketball", "Position yourself under a regulation 10-foot rim"),
                    ("camera.on.rectangle.fill", "Make sure your full body is in frame from feet to peak jump"),
                    ("checkmark.shield.fill", "Both players confirm ready — competition starts simultaneously"),
                ]
            )), id: \.0) { num, item in
                HStack(alignment: .top, spacing: 14) {
                    Text(num)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .frame(width: 24)
                    Image(systemName: item.0)
                        .font(.system(size: 16))
                        .foregroundStyle(accentColor)
                        .frame(width: 24)
                    Text(item.1)
                        .font(.system(.subheadline))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)).overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.1), lineWidth: 1)))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Countdown

    private func countdownBody(_ n: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text("GET READY")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .tracking(4)
            Text("\(n)")
                .font(.system(size: 120, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: n)
            Text("JUMP ON THE RIM")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(3)
            Spacer()
        }
    }

    // MARK: - Battle

    private var battleBody: some View {
        VStack(spacing: 0) {
            // Timer bar
            HStack {
                Text("TIME")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(timeFormatted)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(battleTime <= 30 ? .red : .white)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Scoreboard
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("YOU")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f\"", maxHeight))
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())
                    Text("\(jumpCount) jumps")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 64)

                VStack(spacing: 4) {
                    Text(selectedOpponent?.displayName.uppercased() ?? "OPPONENT")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f\"", opponentMax))
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(selectedOpponent?.avatarColor ?? .red)
                        .contentTransition(.numericText())
                    Text("\(opponentJumps) jumps")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 16)
            .background(Theme.cardBackground)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .clipShape(.rect(cornerRadius: 16))

            Spacer()

            // Jump indicator
            ZStack {
                Circle()
                    .fill(accentColor.opacity(jumpFlash ? 0.25 : 0.06))
                    .frame(width: 180, height: 180)
                    .animation(.easeOut(duration: 0.25), value: jumpFlash)

                Circle()
                    .strokeBorder(accentColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 180, height: 180)

                VStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(accentColor)
                    if !lastHeight.isEmpty {
                        Text(lastHeight)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
            }

            Spacer()

            if !healthKit.isAuthorized {
                Button { recordSimulatedJump() } label: {
                    Text("RECORD JUMP")
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
            } else {
                Text("Jump on the rim — HealthKit is counting")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button { endBattle() } label: {
                Text("END EARLY")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Result

    private func resultBody(_ r: CompResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(r.playerWon ? "YOU WIN" : "DEFEATED")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(r.playerWon ? .yellow : .red)
                        .tracking(4)
                        .padding(.top, 32)
                    Text("IRL Dunk Result")
                        .font(.system(size: 30, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                }

                HStack(spacing: 16) {
                    compStat("YOUR MAX", value: String(format: "%.1f\"", r.playerMaxHeight), icon: "arrow.up.circle.fill", color: accentColor)
                    compStat("JUMPS", value: "\(r.playerJumps)", icon: "figure.basketball", color: .cyan)
                    compStat("THEIR MAX", value: String(format: "%.1f\"", r.opponentMaxHeight), icon: "person.fill", color: selectedOpponent?.avatarColor ?? .red)
                }
                .padding(.horizontal, 20)

                if r.playerWon {
                    HStack(spacing: 8) {
                        Image(systemName: "diamond.fill")
                            .foregroundStyle(Theme.brandCyan)
                        Text("+\(r.payout) shards earned")
                            .font(.system(.headline, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.green.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.3), lineWidth: 1)))
                    .padding(.horizontal, 20)
                }

                Button { dismiss() } label: {
                    Text("BACK TO LOBBY")
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func compStat(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 20, weight: .black, design: .monospaced)).foregroundStyle(.white)
            Text(label).font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.06)))
    }

    // MARK: - Helpers

    private var timeFormatted: String {
        let m = battleTime / 60; let s = battleTime % 60
        return String(format: "%d:%02d", m, s)
    }

    private func enterQueue() {
        if selectedOpponent == nil {
            selectedOpponent = lobbyPlayers.randomElement()
        }
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.5...3.0)))
            await MainActor.run { phase = .matched }
        }
    }

    private func beginCountdown() {
        countdownVal = 3
        phase = .countdown(3)
        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run {
                    countdownVal = i
                    phase = .countdown(i)
                }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run { startBattle() }
        }
    }

    private func startBattle() {
        jumpCount = 0
        maxHeight = 0
        opponentJumps = 0
        opponentMax = 0
        battleTime = 180
        phase = .battle

        // Main countdown timer
        timerTask = Task {
            while battleTime > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { battleTime -= 1 }
            }
            await MainActor.run { endBattle() }
        }

        // HealthKit
        if healthKit.isAuthorized {
            healthKit.startJumpTracking { h in
                Task { @MainActor in
                    jumpCount += 1
                    maxHeight = max(maxHeight, h)
                    lastHeight = String(format: "%.1f\"", h)
                    jumpFlash = true
                    Task { try? await Task.sleep(for: .milliseconds(300)); jumpFlash = false }
                }
            }
        }

        // Simulated opponent updates
        opponentUpdateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 4...9)))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    opponentJumps += 1
                    let h = Double.random(in: 18...42)
                    opponentMax = max(opponentMax, h)
                }
            }
        }
    }

    private func recordSimulatedJump() {
        let h = Double.random(in: 20...46)
        jumpCount += 1
        maxHeight = max(maxHeight, h)
        lastHeight = String(format: "%.1f\"", h)
        jumpFlash = true
        Task { try? await Task.sleep(for: .milliseconds(300)); await MainActor.run { jumpFlash = false } }
    }

    private func endBattle() {
        timerTask?.cancel()
        opponentUpdateTask?.cancel()
        healthKit.stopJumpTracking()
        let won = maxHeight >= opponentMax
        let payout: Int
        switch selectedFee {
        case .practice:      payout = 0
        case .shards(let n): payout = won ? n * 2 : 0
        case .cashComingSoon: payout = 0
        }
        if won && payout > 0 {
            viewModel.profile.evolutionShards += payout
        }
        result = CompResult(playerJumps: jumpCount, playerMaxHeight: maxHeight,
                            opponentJumps: opponentJumps, opponentMaxHeight: opponentMax,
                            payout: payout)
        phase = .result
    }
}
