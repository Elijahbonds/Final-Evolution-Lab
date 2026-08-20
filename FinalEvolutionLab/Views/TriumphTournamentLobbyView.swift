import SwiftUI

struct TriumphTournamentLobbyView: View {
    @Bindable var viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var engine = TriumphTournamentEngine.shared
    @State private var selectedTier: TournamentTier = TournamentTier.tiers[0]
    
    // Matchmaking & Gameplay States
    enum MatchState {
        case idle
        case searching
        case matched
        case playing
        case verifying
        case completed
    }
    
    @State private var matchState: MatchState = .idle
    @State private var searchTimer: Timer? = nil
    @State private var searchProgress: Double = 0.0
    @State private var opponentName: String = ""
    @State private var opponentPrq: Double = 0.0
    @State private var opponentAvatar: String = "figure.basketball"
    
    // Gameplay Simulation
    @State private var gameTimer: Timer? = nil
    @State private var gameProgress: Double = 0.0
    @State private var playerScore: Double = 0.0
    @State private var opponentScore: Double = 0.0
    @State private var selectedGameMode: String = "WDA Dunk Contest"
    
    // Verification State
    @State private var verificationStep: Int = 0
    @State private var verificationTimer: Timer? = nil
    
    // Post-game
    @State private var didPlayerWin: Bool = false
    @State private var shardsAwarded: Int = 0
    @State private var prqChange: Double = 0.0
    
    // Sheets
    @State private var isDepositSheetPresented = false
    @State private var isWithdrawSheetPresented = false
    
    // Deposit Form
    @State private var depositAmount: String = "10.00"
    @State private var cardNumber: String = ""
    @State private var cardExpiry: String = ""
    @State private var cardCvv: String = ""
    @State private var cardholderName: String = ""
    
    // Withdraw Form
    @State private var withdrawAmount: String = "10.00"
    @State private var paypalEmail: String = ""
    
    // Toasts
    @State private var toastMessage: String? = nil
    @State private var showToast = false
    @State private var isToastError = false
    
    private let gameModes = ["WDA Dunk Contest", "2D Brain Brawl", "Court Carnival"]
    
    var body: some View {
        ZStack {
            // Background
            Theme.deepBlack.ignoresSafeArea()
            Theme.meshGradient.opacity(0.35).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        if matchState == .idle {
                            // Balance Card
                            balanceCardView
                            
                            // Tournament Tiers Selector
                            tierSelectorView
                            
                            // Transaction History / Ledger
                            ledgerHistoryView
                        } else {
                            // Matchmaking / Gameplay / Verification Overlay
                            matchmakingFlowView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
            
            // Toast Overlay
            if showToast, let msg = toastMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: isToastError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(isToastError ? .red : Theme.brandCyan)
                        Text(msg)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.surfaceElevated.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isToastError ? Color.red.opacity(0.4) : Theme.brandCyan.opacity(0.4), lineWidth: 1)
                            )
                    )
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(.keyboard)
                .zIndex(10)
            }
        }
        .sheet(isPresented: $isDepositSheetPresented) {
            depositSheetView
        }
        .sheet(isPresented: $isWithdrawSheetPresented) {
            withdrawSheetView
        }
        .onDisappear {
            cancelAllTimers()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: {
                if matchState == .idle {
                    dismiss()
                } else {
                    // Ask for confirmation or cancel tournament
                    TriumphTournamentEngine.shared.cancelTournament()
                    cancelAllTimers()
                    matchState = .idle
                    showToast(message: "Tournament cancelled. Entry fee refunded.", isError: true)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text(matchState == .idle ? "Back" : "Cancel")
                }
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 2) {
                Text("CASH ARENA")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                
                FELPreviewLabel(text: "Early Access · Cash Tournament")
            }
            
            Spacer()
            
            // Shard display
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .foregroundStyle(Theme.brandCyan)
                Text("\(viewModel.profile.evolutionShards)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.cardBackground.opacity(0.5))
        .overlay(
            VStack {
                Spacer()
                Rectangle().fill(Theme.cardBorder).frame(height: 1)
            }
        )
    }
    
    // MARK: - Balance Card
    private var balanceCardView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRIUMPH CASH BALANCE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan.opacity(0.8))
                    
                    Text(String(format: "$%.2f USD", engine.cashBalance))
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.brandCyan)
            }
            
            HStack(spacing: 12) {
                Button(action: { isDepositSheetPresented = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("DEPOSIT")
                    }
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.brandCyan)
                    )
                }
                
                Button(action: { isWithdrawSheetPresented = true }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("WITHDRAW")
                    }
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.brandCyan, lineWidth: 1.5)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Tournament Tiers Selector
    private var tierSelectorView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SELECT TOURNAMENT WAGER")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 12) {
                ForEach(TournamentTier.tiers) { tier in
                    Button(action: { selectedTier = tier }) {
                        HStack(spacing: 16) {
                            // Selector Indicator
                            Circle()
                                .stroke(selectedTier.id == tier.id ? Theme.brandCyan : Color.gray.opacity(0.5), lineWidth: 2)
                                .fill(selectedTier.id == tier.id ? Theme.brandCyan : Color.clear)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .fill(.black)
                                        .frame(width: 6, height: 6)
                                        .opacity(selectedTier.id == tier.id ? 1 : 0)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tier.name.uppercased())
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                
                                HStack(spacing: 8) {
                                    Text("Entry: \(String(format: "$%.2f", tier.entryFee))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Prize: \(String(format: "$%.2f", tier.prizePool))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Theme.brandCyan)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("+\(tier.shardsReward) Shards")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.brandBlue)
                                
                                Text("+\(String(format: "%.1f", tier.prqBonus)) PRQ")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.elitePurple)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTier.id == tier.id ? Theme.brandCyan.opacity(0.08) : Theme.cardBackground.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTier.id == tier.id ? Theme.brandCyan.opacity(0.5) : Theme.cardBorder, lineWidth: 1)
                                )
                        )
                    }
                }
            }
            
            // Game Mode Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("GAME MODE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                HStack {
                    ForEach(gameModes, id: \.self) { mode in
                        Button(action: { selectedGameMode = mode }) {
                            Text(mode)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedGameMode == mode ? Theme.brandCyan.opacity(0.15) : Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedGameMode == mode ? Theme.brandCyan : Color.clear, lineWidth: 1)
                                        )
                                )
                                .foregroundStyle(selectedGameMode == mode ? Theme.brandCyan : .secondary)
                        }
                    }
                }
            }
            .padding(.top, 8)
            
            // Matchmaking Button
            Button(action: startMatchmaking) {
                Text("ENTER CASH MATCHMAKING")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.brandCyan)
                            .shadow(color: Theme.brandCyan.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - Ledger History
    private var ledgerHistoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRANSACTION LEDGER")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 8) {
                if engine.ledgerEntries.isEmpty {
                    Text("No transactions recorded.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    ForEach(engine.ledgerEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.description)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Text(entry.date, style: .date)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%@$%.2f", entry.amount >= 0 ? "+" : "", entry.amount))
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(entry.amount >= 0 ? Theme.brandCyan : .red)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Theme.cardBackground.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Theme.cardBorder, lineWidth: 0.5)
                                )
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Matchmaking Flow View
    private var matchmakingFlowView: some View {
        VStack(spacing: 24) {
            switch matchState {
            case .searching:
                searchingView
            case .matched:
                matchedView
            case .playing:
                playingView
            case .verifying:
                verifyingView
            case .completed:
                completedView
            default:
                EmptyView()
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Searching View
    private var searchingView: some View {
        VStack(spacing: 20) {
            Text("MATCHMAKING")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: 0.4)
                    .stroke(Theme.brandCyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(searchProgress * 360))
                
                VStack {
                    Text(String(format: "$%.2f", selectedTier.entryFee))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("WAGER")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            
            VStack(spacing: 4) {
                Text("Searching for Opponents...")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("PRQ Tier: \(viewModel.userPRQTier.rawValue) (\(String(format: "%.1f", viewModel.competitivePRQScore)))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            Button(action: {
                TriumphTournamentEngine.shared.cancelTournament()
                cancelAllTimers()
                matchState = .idle
                showToast(message: "Matchmaking cancelled. Wager refunded.", isError: true)
            }) {
                Text("CANCEL SEARCH")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - Matched View
    private var matchedView: some View {
        VStack(spacing: 24) {
            Text("MATCH FOUND!")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
            
            HStack(spacing: 20) {
                // Player
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.brandCyan)
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                    
                    Text(viewModel.profile.displayName)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text("PRQ: \(String(format: "%.1f", viewModel.competitivePRQScore))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // VS
                Text("VS")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                
                // Opponent
                VStack(spacing: 8) {
                    Image(systemName: opponentAvatar)
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.elitePurple)
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                    
                    Text(opponentName)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text("PRQ: \(String(format: "%.1f", opponentPrq))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 10)
            
            VStack(spacing: 6) {
                Text("COMPETING IN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Text(selectedGameMode.uppercased())
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("Prize Pool: \(String(format: "$%.2f", selectedTier.prizePool))")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
            }
            
            Button(action: startSimulatedGame) {
                Text("START MATCH")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.brandCyan)
                    )
            }
        }
    }
    
    // MARK: - Playing View
    private var playingView: some View {
        VStack(spacing: 24) {
            Text("MATCH IN PROGRESS")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
            
            VStack(spacing: 16) {
                HStack {
                    Text(viewModel.profile.displayName.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(playerScore))")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                }
                
                ProgressView(value: gameProgress, total: 1.0)
                    .tint(Theme.brandCyan)
                    .background(Color.white.opacity(0.05))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    Text(opponentName.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(opponentScore))")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.elitePurple)
                }
            }
            .padding(.vertical, 10)
            
            Text("Keep pushing! Biomechanical sensors are tracking your performance live.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Verifying View
    private var verifyingView: some View {
        VStack(spacing: 24) {
            Text("SCORING VERIFICATION")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
            
            ProgressView()
                .tint(Theme.brandCyan)
                .scaleEffect(1.5)
                .padding(.vertical, 10)
            
            VStack(spacing: 8) {
                Text(verificationStepText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text("Triumph Oracle is checking cryptographic signatures and validating anti-cheat layers.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var verificationStepText: String {
        switch verificationStep {
        case 0: return "Syncing device telemetry..."
        case 1: return "Verifying scores with Triumph Oracle..."
        case 2: return "Checking biomechanical signatures..."
        default: return "Finalizing payout ledger..."
        }
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        VStack(spacing: 24) {
            Image(systemName: didPlayerWin ? "trophy.fill" : "hand.thumbsdown.fill")
                .font(.system(size: 60))
                .foregroundStyle(didPlayerWin ? Theme.brandCyan : .secondary)
                .padding(.vertical, 10)
            
            VStack(spacing: 6) {
                Text(didPlayerWin ? "VICTORY!" : "DEFEAT")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(didPlayerWin ? Theme.brandCyan : .red)
                
                Text(didPlayerWin ? "You won the cash tournament!" : "Better luck next tournament!")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("Final Score:")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(playerScore)) - \(Int(opponentScore))")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Divider().background(Theme.cardBorder)
                
                HStack {
                    Text("Cash Payout:")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(didPlayerWin ? String(format: "+$%.2f USD", selectedTier.prizePool) : "$0.00 USD")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(didPlayerWin ? Theme.brandCyan : .secondary)
                }
                
                HStack {
                    Text("Evolution Shards:")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("+\(shardsAwarded)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandBlue)
                }
                
                HStack {
                    Text("PRQ Rating:")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%@%.2f", prqChange >= 0 ? "+" : "", prqChange))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(prqChange >= 0 ? Theme.brandCyan : .red)
                }
            }
            .padding(16)
            .background(Theme.cardBackground.opacity(0.5))
            .cornerRadius(12)
            
            Button(action: { matchState = .idle }) {
                Text("RETURN TO LOBBY")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.brandCyan)
                    )
            }
        }
    }
    
    // MARK: - Deposit Sheet
    private var depositSheetView: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.25).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DEPOSIT AMOUNT (USD)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                        
                        TextField("10.00", text: $depositAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CARD DETAILS (EARLY ACCESS PREVIEW)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        TextField("Cardholder Name", text: $cardholderName)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                        
                        TextField("Card Number", text: $cardNumber)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 12) {
                            TextField("MM/YY", text: $cardExpiry)
                                .keyboardType(.numbersAndPunctuation)
                                .padding()
                                .background(Theme.cardBackground)
                                .cornerRadius(10)
                                .foregroundStyle(.white)
                            
                            TextField("CVV", text: $cardCvv)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(Theme.cardBackground)
                                .cornerRadius(10)
                                .foregroundStyle(.white)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: executeDeposit) {
                        Text("CONFIRM DEPOSIT")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.brandCyan)
                            )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Deposit Cash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isDepositSheetPresented = false }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
        }
    }
    
    // MARK: - Withdraw Sheet
    private var withdrawSheetView: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.25).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("WITHDRAW AMOUNT (USD)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                        
                        TextField("10.00", text: $withdrawAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                            .foregroundStyle(.white)
                        
                        Text(String(format: "Available Balance: $%.2f USD", engine.cashBalance))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PAYOUT ACCOUNT (EARLY ACCESS PREVIEW)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        TextField("paypal@example.com", text: $paypalEmail)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: executeWithdrawal) {
                        Text("CONFIRM WITHDRAWAL")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.brandCyan)
                            )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Withdraw Cash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isWithdrawSheetPresented = false }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
        }
    }
    
    // MARK: - Logic & Actions
    
    private func startMatchmaking() {
        guard engine.cashBalance >= selectedTier.entryFee else {
            showToast(message: "Insufficient cash balance. Please deposit funds.", isError: true)
            return
        }
        
        // Join tournament & lock fee in escrow
        let success = TriumphTournamentEngine.shared.joinTournament(tier: selectedTier)
        guard success else {
            showToast(message: "Failed to join tournament.", isError: true)
            return
        }
        
        matchState = .searching
        searchProgress = 0.0
        
        // Start searching timer
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            searchProgress += 0.02
            if searchProgress >= 1.0 {
                searchProgress = 0.0
            }
        }
        
        // Simulate finding an opponent after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard matchState == .searching else { return }
            searchTimer?.invalidate()
            
            // Generate opponent details
            let opponentFirstNames = ["Apex", "Hyper", "Volt", "Zenith", "Turbo", "Quantum"]
            let opponentLastNames = ["Dunker", "Brawler", "Striker", "Flyer", "Rider", "Shooter"]
            opponentName = "\(opponentFirstNames.randomElement()!)_\(opponentLastNames.randomElement()!)_\(Int.random(in: 10...99))"
            
            // Opponent PRQ close to player PRQ
            let variance = Double.random(in: -4.5...4.5)
            opponentPrq = PRQ.clamp(viewModel.competitivePRQScore + variance)
            
            let avatars = ["figure.basketball", "figure.run", "figure.climbing", "figure.gymnastics"]
            opponentAvatar = avatars.randomElement() ?? "figure.run"
            
            matchState = .matched
        }
    }
    
    private func startSimulatedGame() {
        matchState = .playing
        gameProgress = 0.0
        playerScore = 0.0
        opponentScore = 0.0
        
        // Start game loop timer
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            gameProgress += 0.025
            
            // Randomly increase scores based on PRQ
            let playerIncrement = Double.random(in: 0...5) * (viewModel.competitivePRQScore / 75.0)
            let opponentIncrement = Double.random(in: 0...5) * (opponentPrq / 75.0)
            
            playerScore += playerIncrement
            opponentScore += opponentIncrement
            
            if gameProgress >= 1.0 {
                gameTimer?.invalidate()
                startVerification()
            }
        }
    }
    
    private func startVerification() {
        matchState = .verifying
        verificationStep = 0
        
        // Step-by-step verification simulation
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { timer in
            verificationStep += 1
            if verificationStep >= 3 {
                timer.invalidate()
                finalizeTournament()
            }
        }
    }
    
    private func finalizeTournament() {
        // Determine winner
        let playerWon = playerScore > opponentScore
        didPlayerWin = playerWon
        
        // Complete tournament and distribute payout
        let gameModeId: String
        switch selectedGameMode {
        case "2D Brain Brawl": gameModeId = "brainBrawl"
        case "Court Carnival": gameModeId = "courtCarnival"
        default: gameModeId = GameModeId.basketballDunkContestIRL.rawValue
        }
        
        TriumphTournamentEngine.shared.completeTournament(
            didWin: playerWon,
            playerScore: playerScore,
            opponentScore: opponentScore,
            gameModeId: gameModeId,
            viewModel: viewModel
        )
        
        shardsAwarded = selectedTier.shardsReward + (playerWon ? 50 : 10)
        prqChange = playerWon ? selectedTier.prqBonus : -0.5
        
        matchState = .completed
        
        if playerWon {
            showToast(message: String(format: "Won H2H! Payout of $%.2f credited.", selectedTier.prizePool), isError: false)
        } else {
            showToast(message: "Tournament completed. Better luck next time!", isError: false)
        }
    }
    
    private func executeDeposit() {
        guard let amount = Double(depositAmount), amount > 0 else {
            showToast(message: "Invalid deposit amount.", isError: true)
            return
        }
        
        guard !cardNumber.isEmpty, !cardExpiry.isEmpty, !cardCvv.isEmpty else {
            showToast(message: "Please fill in all credit card fields.", isError: true)
            return
        }
        
        let success = TriumphTournamentEngine.shared.deposit(amount: amount, cardDetails: cardNumber)
        if success {
            isDepositSheetPresented = false
            showToast(message: String(format: "Successfully deposited $%.2f USD!", amount), isError: false)
            // Reset fields
            cardNumber = ""
            cardExpiry = ""
            cardCvv = ""
            cardholderName = ""
        } else {
            showToast(message: "Deposit failed.", isError: true)
        }
    }
    
    private func executeWithdrawal() {
        guard let amount = Double(withdrawAmount), amount > 0 else {
            showToast(message: "Invalid withdrawal amount.", isError: true)
            return
        }
        
        guard amount <= engine.cashBalance else {
            showToast(message: "Withdrawal amount exceeds available balance.", isError: true)
            return
        }
        
        guard !paypalEmail.isEmpty, paypalEmail.contains("@") else {
            showToast(message: "Please enter a valid PayPal email.", isError: true)
            return
        }
        
        let success = TriumphTournamentEngine.shared.withdraw(amount: amount, paypalEmail: paypalEmail)
        if success {
            isWithdrawSheetPresented = false
            showToast(message: String(format: "Successfully withdrew $%.2f USD!", amount), isError: false)
            // Reset fields
            paypalEmail = ""
        } else {
            showToast(message: "Withdrawal failed.", isError: true)
        }
    }
    
    private func showToast(message: String, isError: Bool) {
        toastMessage = message
        isToastError = isError
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showToast = false
        }
    }
    
    private func cancelAllTimers() {
        searchTimer?.invalidate()
        searchTimer = nil
        gameTimer?.invalidate()
        gameTimer = nil
        verificationTimer?.invalidate()
        verificationTimer = nil
    }
}
