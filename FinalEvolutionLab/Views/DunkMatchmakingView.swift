import SwiftUI
import Combine

/// Proctored Zoom-style 1v1 IRL dunk lobby: tripod setup guide, regulation rim checklist,
/// Triumph preview-labeled cash entry, active queue, and WDA judges panel.
struct DunkMatchmakingView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: LabViewModel
    
    private enum MatchFlowPhase {
        case preflight
        case queued
        case searching
        case matched
    }
    
    private struct RimChecklistItem: Identifiable {
        let id: String
        let title: String
        let detail: String
        var isChecked: Bool
    }
    
    // Matchmaking / Lobby states
    @State private var flowPhase: MatchFlowPhase = .preflight
    @State private var isSearching = false
    @State private var matchedOpponent: DunkOpponent? = nil
    @State private var showCameraLab = false
    @State private var playerDunkResult: DunkScoringResult? = nil
    @State private var triumphEngine = TriumphTournamentEngine.shared
    @State private var selectedTier: TournamentTier = TournamentTier.tiers[0]
    @State private var entryEscrowLocked = false
    @State private var queuePosition = 0
    @State private var activeLobbyCount = 12
    @State private var proctorConnected = false
    @State private var tripodGuideAcknowledged = false
    @State private var balanceToastMessage: String? = nil
    @State private var rimChecklist: [RimChecklistItem] = [
        RimChecklistItem(id: "rim_height", title: "Regulation 10 ft rim", detail: "Measured rim apex at 10'0\" (305 cm) from court surface.", isChecked: false),
        RimChecklistItem(id: "rim_diameter", title: "18\" regulation rim", detail: "Standard diameter ring with intact net visible in frame.", isChecked: false),
        RimChecklistItem(id: "backboard", title: "Backboard in full frame", detail: "Rectangular backboard edges visible for proctor verification.", isChecked: false),
        RimChecklistItem(id: "tripod_lock", title: "Tripod locked baseline angle", detail: "Phone locked on tripod; full runway + hoop captured without handheld drift.", isChecked: false),
        RimChecklistItem(id: "runway", title: "Clear 15 ft approach lane", detail: "Unobstructed run-up path from baseline to takeoff zone.", isChecked: false),
        RimChecklistItem(id: "zoom_proctor", title: "Zoom proctor session joined", detail: "WDA proctor tile live — say your athlete tag to confirm identity.", isChecked: false)
    ]
    
    // Judges Scoring Animation states
    @State private var judgesScoringTriggered = false
    @State private var judge1ScoreTicker = 0.0
    @State private var judge2ScoreTicker = 0.0
    @State private var judge3ScoreTicker = 0.0
    @State private var isPlayerWinner = false
    @State private var showWinnerBanner = false
    @State private var hasClaimedRewards = false
    @State private var isSubmittingRewardReceipt = false
    @State private var rewardReceiptMessage: String? = nil
    
    @State private var selectedSignatureAnimation: NexusAnimationAsset? = nil
    @State private var showSignatureSelector = false
    @State private var showCreatorCardSelector = false
    
    // Radar / scan effects
    @State private var scanLineOffset: CGFloat = -120.0
    @State private var searchingProgress = 0.0
    private let lobbyTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    
    struct DunkOpponent: Identifiable, Sendable {
        let id: String
        let displayName: String
        let athleteTag: String
        let avatarSystemName: String
        let prqScore: Double
        let creatorCardTitle: String?
        let creatorCardColor: Color?
        let difficultyScore: Double
        let artisticScore: Double
        let firstTryScore: Double
        let totalScore: Double
        let clipTitle: String
    }
    
    private let availableOpponents = [
        DunkOpponent(
            id: "opp_flight",
            displayName: "FlightRisk",
            athleteTag: "0xFlight",
            avatarSystemName: "flame.fill",
            prqScore: 79.0,
            creatorCardTitle: "Bonds Bounce",
            creatorCardColor: Color(red: 0.95, green: 0.49, blue: 0.15),
            difficultyScore: 24.5,
            artisticScore: 8.5,
            firstTryScore: 10.0,
            totalScore: 43.0,
            clipTitle: "360 Eastbay Spike"
        ),
        DunkOpponent(
            id: "opp_skywalker",
            displayName: "SkyWalker",
            athleteTag: "0xSky42",
            avatarSystemName: "bolt.fill",
            prqScore: 85.0,
            creatorCardTitle: "Coach V Elite",
            creatorCardColor: .yellow,
            difficultyScore: 26.0,
            artisticScore: 9.0,
            firstTryScore: 7.0,
            totalScore: 42.0,
            clipTitle: "Free-Throw Line Windmill"
        ),
        DunkOpponent(
            id: "opp_vertking",
            displayName: "VertKing",
            athleteTag: "0xVert",
            avatarSystemName: "figure.basketball",
            prqScore: 74.0,
            creatorCardTitle: nil,
            creatorCardColor: nil,
            difficultyScore: 21.0,
            artisticScore: 7.5,
            firstTryScore: 10.0,
            totalScore: 38.5,
            clipTitle: "Double-Clutch Rim Grazer"
        )
    ]
    
    var body: some View {
        ZStack {
            Theme.deepBlack.ignoresSafeArea()
            Theme.meshGradient.opacity(0.35).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header HUD
                headerHUD
                    .padding(.top, 10)
                
                switch flowPhase {
                case .preflight:
                    preflightLobby
                case .queued:
                    queuedLobby
                case .searching:
                    searchingLobby
                case .matched:
                    if let opponent = matchedOpponent {
                        activeMatchLobby(opponent: opponent)
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
                    .accessibilityIdentifier("DunkMatchmakingClose")
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showCameraLab) {
            NavigationStack {
                DunkRecordingTrackerView(
                    viewModel: viewModel,
                    selectedAnimationId: selectedSignatureAnimation?.id ?? "",
                    selectedAnimationKeyframes: selectedSignatureAnimation?.keyframes ?? [],
                    isProctoredSession: true,
                    entryTier: entryEscrowLocked ? selectedTier : nil
                ) { result in
                    self.playerDunkResult = result
                    self.showCameraLab = false
                    triggerJudgesScoringSequence()
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = balanceToastMessage {
                Text(msg)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.85)))
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(lobbyTimer) { _ in
            if flowPhase == .queued {
                if queuePosition > 1 {
                    queuePosition -= 1
                } else {
                    flowPhase = .searching
                    isSearching = true
                    searchingProgress = 0.0
                    proctorConnected = true
                }
            }
            if isSearching {
                searchingProgress += 0.015
                if searchingProgress >= 1.0 {
                    isSearching = false
                    flowPhase = .matched
                    matchedOpponent = availableOpponents.randomElement()
                }
            }
            
            // Animate scanline
            scanLineOffset += 3.0
            if scanLineOffset > 150.0 {
                scanLineOffset = -150.0
            }
        }
        .onAppear {
            // Load active signature animation
            if let activeId = viewModel.profile.activeSignatureAnimationId {
                selectedSignatureAnimation = viewModel.profile.competitionAnimations.first { $0.id == activeId }
                    ?? NexusCompetitionAnimationUploader.shared.getStandardPresets().first { $0.id == activeId }
            }
            // Default to first preset if none selected
            if selectedSignatureAnimation == nil {
                selectedSignatureAnimation = NexusCompetitionAnimationUploader.shared.getStandardPresets().first
            }
        }
        .sheet(isPresented: $showSignatureSelector) {
            signatureAnimationSelectorSheet
        }
        .sheet(isPresented: $showCreatorCardSelector) {
            creatorCardSelectorSheet
        }
    }
    
    // MARK: - Lobby Header
    
    private var headerHUD: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                FELPreviewLabel(text: FELPremiumCopy.Preview.proctoredDunkLobby)
                FELPreviewLabel(text: FELPremiumCopy.Preview.triumphCashEntry)
            }
            
            HStack {
                Image(systemName: "video.badge.checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)
                
                Text("PROCTORED IRL H2H DUNK")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(2)
            }

            Text("Set up in front of a hoop · tripod · 1v1 · compete for $")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            if flowPhase != .preflight {
                HStack(spacing: 8) {
                    Circle()
                        .fill(proctorConnected ? Theme.neonGreen : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(proctorConnected ? "WDA PROCTOR LIVE" : "AWAITING PROCTOR")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(proctorConnected ? Theme.neonGreen : Color.orange)
                    
                    if entryEscrowLocked {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("ESCROW \(String(format: "$%.2f", selectedTier.entryFee))")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                    }
                }
            }
        }
        .accessibilityIdentifier("DunkMatchmakingHeader")
    }

    private var allChecklistComplete: Bool {
        rimChecklist.allSatisfy(\.isChecked) && tripodGuideAcknowledged
    }
    
    // MARK: - Preflight: Tripod guide, rim checklist, Triumph entry
    
    private var preflightLobby: some View {
        ScrollView {
            VStack(spacing: 16) {
                tripodSetupGuideCard
                
                regulationRimChecklistCard
                
                triumphEntryCard
                
                signatureAndCreatorSelectors
                
                Button(action: joinProctoredQueue) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.badge.gearshape.fill")
                        Text("JOIN PROCTORED QUEUE · \(String(format: "$%.2f", selectedTier.entryFee))")
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(allChecklistComplete && triumphEngine.cashBalance >= selectedTier.entryFee ? Theme.neonGreen : Color.gray.opacity(0.35))
                    .foregroundStyle(allChecklistComplete ? .black : .white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: allChecklistComplete ? Theme.neonGreen.opacity(0.3) : .clear, radius: 10)
                }
                .disabled(!allChecklistComplete || triumphEngine.cashBalance < selectedTier.entryFee)
                .accessibilityIdentifier("DunkJoinQueueButton")
                .padding(.bottom, 20)
            }
        }
    }
    
    private var tripodSetupGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRIPOD SETUP GUIDE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)
            
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 88, height: 110)
                    VStack(spacing: 4) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.brandCyan)
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 2, height: 28)
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(180))
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    guideStep("1", "Lock phone on tripod at baseline — landscape, chest height.")
                    guideStep("2", "Frame full hoop, backboard, and 15 ft runway in view.")
                    guideStep("3", "Join Zoom proctor room; keep your tile unmuted for identity check.")
                }
            }
            
            Toggle(isOn: $tripodGuideAcknowledged) {
                Text("Tripod angle verified — ready for proctor review")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .tint(Theme.neonGreen)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.brandCyan.opacity(0.2), lineWidth: 1))
    }
    
    private func guideStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(number)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Theme.brandCyan))
            Text(text)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var regulationRimChecklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REGULATION RIM CHECKLIST")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)
            
            ForEach($rimChecklist) { $item in
                Toggle(isOn: $item.isChecked) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(item.detail)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Theme.neonGreen)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }
    
    private var triumphEntryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TRIUMPH CASH ENTRY")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                Spacer()
                FELPreviewLabel(text: FELPremiumCopy.Preview.triumphCashEntry)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BALANCE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.2f USD", triumphEngine.cashBalance))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("PRIZE POOL")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.2f", selectedTier.prizePool))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                }
            }
            
            ForEach(TournamentTier.tiers) { tier in
                Button(action: { selectedTier = tier }) {
                    HStack {
                        Circle()
                            .stroke(selectedTier.id == tier.id ? Theme.brandCyan : Color.gray.opacity(0.4), lineWidth: 2)
                            .fill(selectedTier.id == tier.id ? Theme.brandCyan : Color.clear)
                            .frame(width: 14, height: 14)
                        Text(tier.name.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "$%.2f entry", tier.entryFee))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(selectedTier.id == tier.id ? Theme.brandCyan.opacity(0.08) : Color.white.opacity(0.03)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.slateCard))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1))
    }
    
    private var signatureAndCreatorSelectors: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("PROCTORED 1v1 LOBBY")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("Zoom-style WDA proctor verifies your rim setup, then pairs you with a matched PRQ opponent. Cash entry locks in escrow until judges finalize scores.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // Signature Animation Selector Card
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVE SIGNATURE DUNK")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                
                Button(action: { showSignatureSelector = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.brandCyan.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "figure.basketball")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.brandCyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedSignatureAnimation?.header.title.uppercased() ?? "STANDARD DUNK")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                            Text(selectedSignatureAnimation?.header.competitionName ?? "Preset Animation")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.brandCyan.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            
            // Active Creator Card selector
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVE CREATOR CARD")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                
                Button(action: { showCreatorCardSelector = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill((activeCreatorCard?.accentColor ?? Theme.brandCyan).opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: activeCreatorCard?.iconName ?? "person.crop.rectangle")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(activeCreatorCard?.accentColor ?? Theme.brandCyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activeCreatorCard?.creatorName.uppercased() ?? "NO CARD EQUIPPED")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                            Text(activeCreatorCard?.title ?? "Tap to equip a Creator Card boost")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke((activeCreatorCard?.accentColor ?? Theme.brandCyan).opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Active Queue Lobby
    
    private var queuedLobby: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                    .frame(width: 150, height: 150)
                
                VStack(spacing: 6) {
                    Text("IN QUEUE")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                    
                    Text("#\(queuePosition)")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            
            VStack(spacing: 8) {
                Text("ACTIVE PROCTORED LOBBIES: \(activeLobbyCount)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                
                FELPreviewLabel(text: FELPremiumCopy.Preview.proctoredZoomSession)
                
                Text("WDA proctor reviewing rim checklist · pairing PRQ tier \(Int(viewModel.competitivePRQScore))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            proctorZoomTile(name: "WDA PROCTOR", tag: "PROCTOR · LIVE", icon: "person.badge.shield.checkmark.fill", accent: Theme.neonGreen, isLive: true)
                .padding(.horizontal, 8)
            
            Spacer()
            
            Button(action: leaveQueue) {
                Text("LEAVE QUEUE · REFUND ESCROW")
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Searching Lobby
    
    private var searchingLobby: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                // Outer rotating ring
                Circle()
                    .stroke(
                        AngularGradient(colors: [Theme.brandCyan, .clear, Theme.brandCyan], center: .center),
                        lineWidth: 3
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(searchingProgress * 720.0))
                
                VStack(spacing: 4) {
                    Text("SEARCHING")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                    
                    Text(String(format: "%.0f%%", searchingProgress * 100.0))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            
            VStack(spacing: 6) {
                Text("PAIRING PROCTORED OPPONENT...")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                
                FELPreviewLabel(text: FELPremiumCopy.Preview.proctoredZoomSession)
                
                Text("Escrow locked · Zoom room held open for both athletes")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Active Multiplayer Lobby View
    
    private var activeMatchLobby: some View {
        VStack(spacing: 0) {
            Spacer()
        }
    }
    
    private func activeMatchLobby(opponent: DunkOpponent) -> some View {
        VStack(spacing: 12) {
            // Zoom-style proctor session tiles
            VStack(alignment: .leading, spacing: 8) {
                Text("PROCTORED ZOOM SESSION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                
                HStack(spacing: 8) {
                    proctorZoomTile(
                        name: viewModel.profile.displayName,
                        tag: viewModel.profile.athleteTag,
                        icon: viewModel.profile.avatarSystemName,
                        accent: Theme.brandCyan,
                        isLive: true
                    )
                    proctorZoomTile(
                        name: opponent.displayName,
                        tag: opponent.athleteTag,
                        icon: opponent.avatarSystemName,
                        accent: .orange,
                        isLive: true
                    )
                    proctorZoomTile(
                        name: "WDA PROCTOR",
                        tag: "VERIFIED",
                        icon: "person.badge.shield.checkmark.fill",
                        accent: Theme.neonGreen,
                        isLive: proctorConnected
                    )
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.brandCyan.opacity(0.2), lineWidth: 1))
            
            // Head-to-Head Cards Section
            HStack(spacing: 12) {
                // Player Card (Left)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.profile.avatarSystemName)
                            .foregroundStyle(Theme.brandCyan)
                        Text(viewModel.profile.displayName.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 4) {
                        Text(viewModel.profile.athleteTag)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("PRQ: \(Int(viewModel.competitivePRQScore))")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                    }
                    
                    // Active Creator Card State
                    if let active = viewModel.profile.activeCreatorCard,
                       let card = CreatorCard.catalog.first(where: { $0.id == active.cardId }) {
                        HStack(spacing: 4) {
                            Image(systemName: card.iconName)
                                .font(.system(size: 8))
                            Text(card.creatorName.uppercased())
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(card.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(card.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    } else {
                        Text("NO CREATOR CARD")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    
                    // Video/Wireframe preview box
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.4))
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        
                        if let result = playerDunkResult {
                            VStack(spacing: 6) {
                                Image(systemName: "video.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.neonGreen)
                                    .symbolEffect(.pulse)
                                
                                Text(result.metrics.trick.rawValue.uppercased())
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 6)
                                
                                Text("Dunk Verified")
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundStyle(Theme.neonGreen.opacity(0.8))
                            }
                        } else {
                            CourtSceneView(
                                neuralDrive: viewModel.profile.metrics.neuralDrive,
                                verticalPotential: viewModel.profile.metrics.verticalPotential,
                                auraLevel: .baseline,
                                movementSignature: viewModel.activeMovementSignature,
                                onDunkTriggered: {},
                                dunkPhase: .idle,
                                selectedTrick: .windmill,
                                sprintCharge: 0,
                                jumpHeight: 0,
                                rotationProgress: 0,
                                selectedAnimation: selectedSignatureAnimation
                            )
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.brandCyan.opacity(playerDunkResult != nil ? 0.4 : 0.1), lineWidth: 1.5))
                
                // VS Divider
                VStack {
                    Text("VS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                        .padding(8)
                        .background(Circle().fill(Theme.deepBlack).overlay(Circle().stroke(Color.orange.opacity(0.4), lineWidth: 1)))
                }
                .zIndex(2)
                
                // Opponent Card (Right)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: opponent.avatarSystemName)
                            .foregroundStyle(.orange)
                        Text(opponent.displayName.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 4) {
                        Text(opponent.athleteTag)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("PRQ: \(Int(opponent.prqScore))")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    
                    // Creator Card State
                    if let cardTitle = opponent.creatorCardTitle, let cardColor = opponent.creatorCardColor {
                        Text(cardTitle.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(cardColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(cardColor.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Text("NO CREATOR CARD")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    
                    // Video/Wireframe preview box
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.4))
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        
                        // Opponent skeleton rendering looping simulation
                        VStack(spacing: 6) {
                            FELPreviewLabel(text: FELPremiumCopy.Preview.simulatedPose)
                            
                            Image(systemName: "waveform.path")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .symbolEffect(.bounce)
                            
                            Text(opponent.clipTitle.uppercased())
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 6)
                            
                            Text("Playback Active")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.2), lineWidth: 1.5))
            }
            
            // Winners Banner
            if showWinnerBanner {
                VStack(spacing: 4) {
                    Text(isPlayerWinner ? "VICTORY" : "DEFEAT")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(isPlayerWinner ? Theme.neonGreen : Color.red)
                        .shadow(color: (isPlayerWinner ? Theme.neonGreen : Color.red).opacity(0.4), radius: 6)
                    
                    Text(isPlayerWinner ? "YOUR DUNK ECLIPSED \(opponent.displayName) IN STYLE & HANGTIME!" : "\(opponent.displayName) WON THIS ROUND. ADJUST YOUR LANDING SAFETY.")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill((isPlayerWinner ? Theme.neonGreen : Color.red).opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke((isPlayerWinner ? Theme.neonGreen : Color.red).opacity(0.25), lineWidth: 1))
                .transition(.scale.combined(with: .opacity))
            }
            
            // WDA Live Judges' Panel Section
            VStack(alignment: .leading, spacing: 10) {
                Text("WDA LIVE JUDGES' BOARD")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                    .padding(.horizontal, 4)
                
                HStack(spacing: 8) {
                    // Randy
                    judgeCard(
                        name: "RANDY (WDA HEAD)",
                        playerScore: judge1ScoreTicker,
                        opponentScore: opponent.difficultyScore * 0.33 + 3.3, // Randy scales
                        isScored: playerDunkResult != nil
                    )
                    
                    // Dominique
                    judgeCard(
                        name: "DOMINIQUE (DUNKER)",
                        playerScore: judge2ScoreTicker,
                        opponentScore: opponent.artisticScore + 4.5,
                        isScored: playerDunkResult != nil
                    )
                    
                    // Lisa
                    judgeCard(
                        name: "LISA (FORM/GYM)",
                        playerScore: judge3ScoreTicker,
                        opponentScore: opponent.firstTryScore + 5.0,
                        isScored: playerDunkResult != nil
                    )
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.slateCard))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            if let result = playerDunkResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("JUDGES' LIVE COMMENTARY")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                        .tracking(2)
                        .padding(.horizontal, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.randyCommentary)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        Text(result.dominiqueCommentary)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        Text(result.lisaCommentary)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.15), lineWidth: 1))
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .scale))
            }
            
            Spacer()
            
            // Lobby actions
            VStack(spacing: 10) {
                if playerDunkResult == nil {
                    Button(action: { showCameraLab = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "video.fill")
                            Text("ENTER PROCTORED CAMERA LAB")
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.neonGreen)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Theme.neonGreen.opacity(0.3), radius: 8)
                    }
                } else if !hasClaimedRewards {
                    Button(action: claimRewardsAndSave) {
                        HStack(spacing: 8) {
                            Image(systemName: isSubmittingRewardReceipt ? "arrow.triangle.2.circlepath" : "checkmark.seal.fill")
                            Text(isSubmittingRewardReceipt ? "VERIFYING SERVER RECEIPT..." : "SUBMIT VERIFIED REWARD RECEIPT")
                                .font(.system(.subheadline, design: .monospaced, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.brandCyan)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Theme.brandCyan.opacity(0.3), radius: 8)
                    }
                    .disabled(isSubmittingRewardReceipt)
                } else {
                    Button(action: { dismiss() }) {
                        Text("DISMISS LOBBY")
                            .font(.system(.subheadline, design: .monospaced, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.white.opacity(0.08))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                if let rewardReceiptMessage {
                    Text(rewardReceiptMessage)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }
    
    private func judgeCard(name: String, playerScore: Double, opponentScore: Double, isScored: Bool) -> some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("YOU")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan.opacity(0.8))
                    
                    Text(isScored ? String(format: "%.1f", playerScore) : "--")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .frame(height: 16)
                
                VStack(spacing: 2) {
                    Text("OPP")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.8))
                    
                    Text(String(format: "%.1f", opponentScore))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
    
    private func proctorZoomTile(name: String, tag: String, icon: String, accent: Color, isLive: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 72)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 28))
                            .foregroundStyle(accent.opacity(0.85))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.35), lineWidth: 1))
                
                if isLive {
                    HStack(spacing: 3) {
                        Circle().fill(Color.red).frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .padding(6)
                }
            }
            
            Text(name.uppercased())
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Text(tag)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(accent.opacity(0.9))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Logic & Matchmaking Core
    
    private func joinProctoredQueue() {
        guard allChecklistComplete else { return }
        guard triumphEngine.joinTournament(tier: selectedTier) else {
            withAnimation {
                balanceToastMessage = "Insufficient Triumph balance for \(String(format: "$%.2f", selectedTier.entryFee)) entry"
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                balanceToastMessage = nil
            }
            return
        }
        entryEscrowLocked = true
        queuePosition = Int.random(in: 2...5)
        activeLobbyCount = Int.random(in: 8...18)
        flowPhase = .queued
        proctorConnected = false
    }
    
    private func leaveQueue() {
        if entryEscrowLocked {
            TriumphTournamentEngine.shared.cancelTournament()
            entryEscrowLocked = false
        }
        flowPhase = .preflight
        isSearching = false
        matchedOpponent = nil
        searchingProgress = 0.0
        proctorConnected = false
    }
    
    private func startMatchmakingSearch() {
        flowPhase = .searching
        isSearching = true
        searchingProgress = 0.0
    }
    
    private func triggerJudgesScoringSequence() {
        guard let result = playerDunkResult, let opponent = matchedOpponent else { return }
        
        judgesScoringTriggered = true
        
        // Distribute player's dunk totalScore into 3 judges' scores
        let targetJ1 = result.executionScore * 0.33 + 3.0
        let targetJ2 = result.artisticScore + 4.0
        let targetJ3 = result.firstTrySuccessScore + 5.0
        
        isPlayerWinner = result.totalScore > opponent.totalScore
        
        // Multi-stage animations for judges typing on their scoreboards
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring()) {
                judge1ScoreTicker = targetJ1
            }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring()) {
                judge2ScoreTicker = targetJ2
            }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring()) {
                judge3ScoreTicker = targetJ3
            }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.bouncy()) {
                showWinnerBanner = true
            }
        }
    }
    
    private func claimRewardsAndSave() {
        guard let result = playerDunkResult, !hasClaimedRewards, !isSubmittingRewardReceipt else { return }

        isSubmittingRewardReceipt = true
        rewardReceiptMessage = "Submitting dunk receipt to server authority. Local rewards stay locked until verified."

        let activeBoost = viewModel.profile.activeCreatorCard != nil
        let playerScore = Int((result.totalScore * 10.0).rounded(.toNearestOrAwayFromZero))
        let opponentScore = Int(((matchedOpponent?.totalScore ?? 0.0) * 10.0).rounded(.toNearestOrAwayFromZero))
        let matchSessionId = UUID()

        Task {
            let verified = await GameplaySessionReceiptCoordinator.shared.submitNativeSessionReceipt(
                matchSessionId: matchSessionId,
                gameModeId: GameModeId.basketballDunkContestIRL.rawValue,
                playerScore: playerScore,
                opponentScore: opponentScore,
                durationSeconds: 75,
                comboCount: isPlayerWinner ? 3 : 1,
                criticalCount: activeBoost ? 2 : 0,
                pacingScore: Int(result.metrics.fluidMotionScore.rounded(.toNearestOrAwayFromZero)),
                isMultiplayer: true
            )

            await MainActor.run {
                isSubmittingRewardReceipt = false
                if verified && NexusEconomyAuthority.allowsLocalEconomyGrant(
                    modeId: .basketballDunkContestIRL,
                    trustLevel: .serverVerified
                ) {
                    hasClaimedRewards = true
                    rewardReceiptMessage = "Server receipt verified. Ranked PRQ and rewards will sync through the receipt ledger."
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    rewardReceiptMessage = "Server verification unavailable. No local shards or ranked PRQ were granted; retry when connected."
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        }
    }

    private var activeCreatorCard: CreatorCard? {
        guard let active = viewModel.profile.activeCreatorCard else { return nil }
        return CreatorCard.catalog.first(where: { $0.id == active.cardId })
    }

    private var creatorCardSelectorSheet: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.3).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SELECT CREATOR CARD")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(2)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        Button(action: {
                            viewModel.clearCreatorCard()
                            showCreatorCardSelector = false
                        }) {
                            HStack {
                                Text("NO CREATOR CARD")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                                Spacer()
                                if viewModel.profile.activeCreatorCard == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.neonGreen)
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(CreatorCard.catalog) { card in
                            Button(action: {
                                viewModel.applyCreatorCard(card)
                                showCreatorCardSelector = false
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: card.iconName)
                                        .foregroundStyle(card.accentColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(card.creatorName.uppercased())
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .foregroundStyle(.white)
                                        Text(card.title)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if viewModel.profile.activeCreatorCard?.cardId == card.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.neonGreen)
                                    }
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.profile.activeCreatorCard?.cardId == card.id ? Theme.neonGreen.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                                )
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Creator Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showCreatorCardSelector = false }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var signatureAnimationSelectorSheet: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                Theme.meshGradient.opacity(0.3).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("SELECT SIGNATURE DUNK ANIMATION")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(2)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        // User's Uploaded Animations
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MY COMPETITION ANIMATIONS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal)
                            
                            let userDunks = viewModel.profile.competitionAnimations.filter { $0.header.category.lowercased() == "dunk" }
                            if userDunks.isEmpty {
                                Text("No uploaded competition dunks found. Mint or upload animations in the Creator Hub!")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.02)))
                                    .padding(.horizontal)
                            } else {
                                ForEach(userDunks) { anim in
                                    animationRow(for: anim, isPreset: false)
                                }
                            }
                        }
                        
                        // Standard Presets
                        VStack(alignment: .leading, spacing: 10) {
                            Text("STANDARD PRESETS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal)
                            
                            let presets = NexusCompetitionAnimationUploader.shared.getStandardPresets().filter { $0.header.category.lowercased() == "dunk" }
                            ForEach(presets) { anim in
                                animationRow(for: anim, isPreset: true)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Signature Animations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showSignatureSelector = false }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func animationRow(for anim: NexusAnimationAsset, isPreset: Bool) -> some View {
        Button(action: {
            selectedSignatureAnimation = anim
            viewModel.profile.activeSignatureAnimationId = anim.id
            SaveSystem.saveProfile(viewModel.profile)
            showSignatureSelector = false
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(anim.header.title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        Text(anim.header.competitionName)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text(isPreset ? "PRESET" : "UPLOADED")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(isPreset ? Theme.brandBlue : Theme.neonGreen)
                    }
                }
                Spacer()
                
                if selectedSignatureAnimation?.id == anim.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.neonGreen)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedSignatureAnimation?.id == anim.id ? Theme.neonGreen.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}
