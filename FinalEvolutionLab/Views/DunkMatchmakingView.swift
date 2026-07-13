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
            creatorCardColor: FELDesign.Colors.cyan,
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
            creatorCardColor: FELDesign.Colors.purple,
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
            FELDesign.Colors.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header HUD
                headerHUD
                    .padding(.top, FELDesign.Space.xs)

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
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                    .padding(.horizontal, FELDesign.Space.md)
                    .padding(.vertical, FELDesign.Space.xs)
                    .background(RoundedRectangle(cornerRadius: FELDesign.Radius.sm).fill(FELDesign.Colors.danger.opacity(0.85)))
                    .padding(.bottom, FELDesign.Space.lg)
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
        VStack(spacing: FELDesign.Space.xs) {
            HStack(spacing: FELDesign.Space.xs) {
                FELPreviewLabel(text: FELPremiumCopy.Preview.proctoredDunkLobby)
                FELPreviewLabel(text: FELPremiumCopy.Preview.triumphCashEntry)
            }

            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "video.badge.checkmark")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.cyan)

                Text("PROCTORED IRL H2H DUNK")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                    .tracking(1)
            }

            Text("Set up in front of a hoop · tripod · 1v1 · compete for $")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FELDesign.Space.xs)

            if flowPhase != .preflight {
                HStack(spacing: FELDesign.Space.xs) {
                    Circle()
                        .fill(proctorConnected ? FELDesign.Colors.success : FELDesign.Colors.textTertiary)
                        .frame(width: 6, height: 6)
                    FELMicroLabel(
                        text: proctorConnected ? "WDA Proctor Live" : "Awaiting Proctor",
                        color: proctorConnected ? FELDesign.Colors.success : FELDesign.Colors.textTertiary
                    )

                    if entryEscrowLocked {
                        Text("·")
                            .foregroundStyle(FELDesign.Colors.textTertiary)
                        Text("ESCROW \(String(format: "$%.2f", selectedTier.entryFee))")
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.cyan)
                    }
                }
            }
        }
        .accessibilityIdentifier("DunkMatchmakingHeader")
    }

    private var allChecklistComplete: Bool {
        rimChecklist.allSatisfy(\.isChecked) && tripodGuideAcknowledged
    }

    private var canJoinQueue: Bool {
        allChecklistComplete && triumphEngine.cashBalance >= selectedTier.entryFee
    }

    // MARK: - Preflight: Tripod guide, rim checklist, Triumph entry

    private var preflightLobby: some View {
        ScrollView {
            VStack(spacing: FELDesign.Space.md) {
                tripodSetupGuideCard

                regulationRimChecklistCard

                triumphEntryCard

                signatureAndCreatorSelectors

                Button(action: joinProctoredQueue) {
                    HStack(spacing: FELDesign.Space.xs) {
                        Image(systemName: "person.2.badge.gearshape.fill")
                        Text("JOIN PROCTORED QUEUE · \(String(format: "$%.2f", selectedTier.entryFee))")
                    }
                    .font(FELDesign.Typography.label)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FELDesign.Space.md)
                    .background(canJoinQueue ? FELDesign.Colors.cyan : FELDesign.Colors.surfaceRaised)
                    .foregroundStyle(canJoinQueue ? FELDesign.Colors.ink : FELDesign.Colors.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.md))
                }
                .disabled(!canJoinQueue)
                .accessibilityIdentifier("DunkJoinQueueButton")
                .padding(.bottom, FELDesign.Space.lg)
            }
        }
    }

    private var tripodSetupGuideCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Tripod Setup Guide")

            HStack(spacing: FELDesign.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                        .fill(FELDesign.Colors.ink)
                        .frame(width: 88, height: 110)
                    VStack(spacing: FELDesign.Space.xxs) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 22))
                            .foregroundStyle(FELDesign.Colors.cyan)
                        Rectangle()
                            .fill(FELDesign.Colors.hairlineStrong)
                            .frame(width: 2, height: 28)
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                            .rotationEffect(.degrees(180))
                    }
                }

                VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
                    guideStep("1", "Lock phone on tripod at baseline — landscape, chest height.")
                    guideStep("2", "Frame full hoop, backboard, and 15 ft runway in view.")
                    guideStep("3", "Join Zoom proctor room; keep your tile unmuted for identity check.")
                }
            }

            Toggle(isOn: $tripodGuideAcknowledged) {
                Text("Tripod angle verified — ready for proctor review")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
            }
            .tint(FELDesign.Colors.cyan)
        }
        .felCard()
    }

    private func guideStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: FELDesign.Space.xs) {
            Text(number)
                .font(FELDesign.Typography.micro)
                .foregroundStyle(FELDesign.Colors.ink)
                .frame(width: 16, height: 16)
                .background(Circle().fill(FELDesign.Colors.cyan))
            Text(text)
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var regulationRimChecklistCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Regulation Rim Checklist")

            ForEach($rimChecklist) { $item in
                Toggle(isOn: $item.isChecked) {
                    VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                        Text(item.title)
                            .font(FELDesign.Typography.label)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                        Text(item.detail)
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }
                }
                .tint(FELDesign.Colors.cyan)
            }
        }
        .felCard()
    }

    private var triumphEntryCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                FELMicroLabel(text: "Triumph Cash Entry")
                Spacer()
                FELPreviewLabel(text: FELPremiumCopy.Preview.triumphCashEntry)
            }

            HStack {
                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: "Balance")
                    Text(String(format: "$%.2f USD", triumphEngine.cashBalance))
                        .font(FELDesign.Typography.statLarge)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: "Prize Pool")
                    Text(String(format: "$%.2f", selectedTier.prizePool))
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.success)
                }
            }

            ForEach(TournamentTier.tiers) { tier in
                Button(action: { selectedTier = tier }) {
                    HStack {
                        Circle()
                            .stroke(selectedTier.id == tier.id ? FELDesign.Colors.cyan : FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.accent)
                            .fill(selectedTier.id == tier.id ? FELDesign.Colors.cyan : Color.clear)
                            .frame(width: 14, height: 14)
                        Text(tier.name.uppercased())
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                        Spacer()
                        Text(String(format: "$%.2f entry", tier.entryFee))
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }
                    .padding(FELDesign.Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                            .fill(selectedTier.id == tier.id ? FELDesign.Colors.surfaceRaised : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .felCard()
    }

    private var signatureAndCreatorSelectors: some View {
        VStack(spacing: FELDesign.Space.md) {
            VStack(spacing: FELDesign.Space.xs) {
                Text("PROCTORED 1v1 LOBBY")
                    .font(FELDesign.Typography.heading)
                    .foregroundStyle(FELDesign.Colors.textPrimary)

                Text("Zoom-style WDA proctor verifies your rim setup, then pairs you with a matched PRQ opponent. Cash entry locks in escrow until judges finalize scores.")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Signature Animation Selector Card
            VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
                FELMicroLabel(text: "Active Signature Dunk")

                Button(action: { showSignatureSelector = true }) {
                    HStack(spacing: FELDesign.Space.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                .fill(FELDesign.Colors.surfaceRaised)
                                .frame(width: 36, height: 36)
                            Image(systemName: "figure.basketball")
                                .font(FELDesign.Typography.caption)
                                .foregroundStyle(FELDesign.Colors.cyan)
                        }

                        VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                            Text(selectedSignatureAnimation?.header.title.uppercased() ?? "STANDARD DUNK")
                                .font(FELDesign.Typography.label)
                                .foregroundStyle(FELDesign.Colors.textPrimary)
                            Text(selectedSignatureAnimation?.header.competitionName ?? "Preset Animation")
                                .font(FELDesign.Typography.caption)
                                .foregroundStyle(FELDesign.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(FELDesign.Typography.micro)
                            .foregroundStyle(FELDesign.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .felCard(padding: FELDesign.Space.sm)
            }

            // Active Creator Card selector
            VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
                FELMicroLabel(text: "Active Creator Card")

                Button(action: { showCreatorCardSelector = true }) {
                    HStack(spacing: FELDesign.Space.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                                .fill(FELDesign.Colors.surfaceRaised)
                                .frame(width: 36, height: 36)
                            Image(systemName: activeCreatorCard?.iconName ?? "person.crop.rectangle")
                                .font(FELDesign.Typography.caption)
                                .foregroundStyle(activeCreatorCard != nil ? FELDesign.Colors.cyan : FELDesign.Colors.textTertiary)
                        }

                        VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                            Text(activeCreatorCard?.creatorName.uppercased() ?? "NO CARD EQUIPPED")
                                .font(FELDesign.Typography.label)
                                .foregroundStyle(FELDesign.Colors.textPrimary)
                            Text(activeCreatorCard?.title ?? "Tap to equip a Creator Card boost")
                                .font(FELDesign.Typography.caption)
                                .foregroundStyle(FELDesign.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(FELDesign.Typography.micro)
                            .foregroundStyle(FELDesign.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .felCard(padding: FELDesign.Space.sm)
            }
        }
    }

    // MARK: - Active Queue Lobby

    private var queuedLobby: some View {
        VStack(spacing: FELDesign.Space.lg) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)
                    .frame(width: 150, height: 150)

                VStack(spacing: FELDesign.Space.xs) {
                    FELMicroLabel(text: "In Queue", color: FELDesign.Colors.cyan)

                    Text("#\(queuePosition)")
                        .font(FELDesign.Typography.statLarge)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                }
            }

            VStack(spacing: FELDesign.Space.xs) {
                Text("ACTIVE PROCTORED LOBBIES: \(activeLobbyCount)")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)

                FELPreviewLabel(text: FELPremiumCopy.Preview.proctoredZoomSession)

                Text("WDA proctor reviewing rim checklist · pairing PRQ tier \(Int(viewModel.competitivePRQScore))")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FELDesign.Space.lg)
            }

            proctorZoomTile(name: "WDA PROCTOR", tag: "PROCTOR · LIVE", icon: "person.badge.shield.checkmark.fill", accent: FELDesign.Colors.success, isLive: true)
                .padding(.horizontal, FELDesign.Space.xs)

            Spacer()

            Button(action: leaveQueue) {
                Text("LEAVE QUEUE · REFUND ESCROW")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FELGhostButtonStyle())
            .padding(.bottom, FELDesign.Space.sm)
        }
    }

    // MARK: - Searching Lobby

    private var searchingLobby: some View {
        VStack(spacing: FELDesign.Space.lg) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.accent)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(FELDesign.Colors.cyan, style: StrokeStyle(lineWidth: FELDesign.Stroke.accent, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(searchingProgress * 720.0))

                VStack(spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: "Searching", color: FELDesign.Colors.cyan)

                    Text(String(format: "%.0f%%", searchingProgress * 100.0))
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                }
            }

            VStack(spacing: FELDesign.Space.xs) {
                Text("PAIRING PROCTORED OPPONENT…")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)

                FELPreviewLabel(text: FELPremiumCopy.Preview.proctoredZoomSession)

                Text("Escrow locked · Zoom room held open for both athletes")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
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
        VStack(spacing: FELDesign.Space.sm) {
            // Zoom-style proctor session tiles
            VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
                FELMicroLabel(text: "Proctored Zoom Session")

                HStack(spacing: FELDesign.Space.xs) {
                    proctorZoomTile(
                        name: viewModel.profile.displayName,
                        tag: viewModel.profile.athleteTag,
                        icon: viewModel.profile.avatarSystemName,
                        accent: FELDesign.Colors.cyan,
                        isLive: true
                    )
                    proctorZoomTile(
                        name: opponent.displayName,
                        tag: opponent.athleteTag,
                        icon: opponent.avatarSystemName,
                        accent: FELDesign.Colors.textSecondary,
                        isLive: true
                    )
                    proctorZoomTile(
                        name: "WDA PROCTOR",
                        tag: "VERIFIED",
                        icon: "person.badge.shield.checkmark.fill",
                        accent: FELDesign.Colors.success,
                        isLive: proctorConnected
                    )
                }
            }
            .felCard(padding: FELDesign.Space.sm)

            // Head-to-Head Cards Section
            HStack(spacing: FELDesign.Space.sm) {
                // Player Card (Left)
                VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
                    HStack(spacing: FELDesign.Space.xs) {
                        Image(systemName: viewModel.profile.avatarSystemName)
                            .foregroundStyle(FELDesign.Colors.cyan)
                        Text(viewModel.profile.displayName.uppercased())
                            .font(FELDesign.Typography.label)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                            .lineLimit(1)
                    }

                    HStack(spacing: FELDesign.Space.xxs) {
                        Text(viewModel.profile.athleteTag)
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textTertiary)
                        Spacer()
                        Text("PRQ: \(Int(viewModel.competitivePRQScore))")
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.cyan)
                    }

                    // Active Creator Card State
                    if let active = viewModel.profile.activeCreatorCard,
                       let card = CreatorCard.catalog.first(where: { $0.id == active.cardId }) {
                        HStack(spacing: FELDesign.Space.xxs) {
                            Image(systemName: card.iconName)
                                .font(FELDesign.Typography.micro)
                            FELMicroLabel(text: card.creatorName, color: FELDesign.Colors.textPrimary)
                        }
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                        .padding(.horizontal, FELDesign.Space.xs)
                        .padding(.vertical, FELDesign.Space.xxs)
                        .background(FELDesign.Colors.surfaceRaised)
                        .clipShape(Capsule())
                    } else {
                        FELMicroLabel(text: "No Creator Card")
                    }

                    // Video/Wireframe preview box
                    ZStack {
                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                            .fill(FELDesign.Colors.ink)
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: FELDesign.Radius.sm).stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline))

                        if let result = playerDunkResult {
                            VStack(spacing: FELDesign.Space.xs) {
                                Image(systemName: "video.fill")
                                    .font(FELDesign.Typography.heading)
                                    .foregroundStyle(FELDesign.Colors.success)
                                    .symbolEffect(.pulse)

                                Text(result.metrics.trick.rawValue.uppercased())
                                    .font(FELDesign.Typography.micro)
                                    .foregroundStyle(FELDesign.Colors.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, FELDesign.Space.xs)

                                Text("Dunk Verified")
                                    .font(FELDesign.Typography.statSmall)
                                    .foregroundStyle(FELDesign.Colors.success)
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
                            .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.sm))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(FELDesign.Space.sm)
                .background(FELDesign.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                        .stroke(playerDunkResult != nil ? FELDesign.Colors.cyan : FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                )

                // VS Divider
                VStack {
                    Text("VS")
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                        .padding(FELDesign.Space.xs)
                        .background(Circle().fill(FELDesign.Colors.surfaceRaised).overlay(Circle().stroke(FELDesign.Colors.hairlineStrong, lineWidth: FELDesign.Stroke.hairline)))
                }
                .zIndex(2)

                // Opponent Card (Right)
                VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
                    HStack(spacing: FELDesign.Space.xs) {
                        Image(systemName: opponent.avatarSystemName)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                        Text(opponent.displayName.uppercased())
                            .font(FELDesign.Typography.label)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                            .lineLimit(1)
                    }

                    HStack(spacing: FELDesign.Space.xxs) {
                        Text(opponent.athleteTag)
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textTertiary)
                        Spacer()
                        Text("PRQ: \(Int(opponent.prqScore))")
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }

                    // Creator Card State
                    if let cardTitle = opponent.creatorCardTitle, let cardColor = opponent.creatorCardColor {
                        FELMicroLabel(text: cardTitle, color: cardColor)
                            .padding(.horizontal, FELDesign.Space.xs)
                            .padding(.vertical, FELDesign.Space.xxs)
                            .background(FELDesign.Colors.surfaceRaised)
                            .clipShape(Capsule())
                    } else {
                        FELMicroLabel(text: "No Creator Card")
                    }

                    // Video/Wireframe preview box
                    ZStack {
                        RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                            .fill(FELDesign.Colors.ink)
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: FELDesign.Radius.sm).stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline))

                        // Opponent skeleton rendering looping simulation
                        VStack(spacing: FELDesign.Space.xs) {
                            FELPreviewLabel(text: FELPremiumCopy.Preview.simulatedPose)

                            Image(systemName: "waveform.path")
                                .font(FELDesign.Typography.heading)
                                .foregroundStyle(FELDesign.Colors.textSecondary)
                                .symbolEffect(.bounce)

                            Text(opponent.clipTitle.uppercased())
                                .font(FELDesign.Typography.micro)
                                .foregroundStyle(FELDesign.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, FELDesign.Space.xs)

                            Text("Playback Active")
                                .font(FELDesign.Typography.statSmall)
                                .foregroundStyle(FELDesign.Colors.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .felCard(padding: FELDesign.Space.sm)
            }

            // Winners Banner
            if showWinnerBanner {
                VStack(spacing: FELDesign.Space.xxs) {
                    Text(isPlayerWinner ? "VICTORY" : "DEFEAT")
                        .font(FELDesign.Typography.heading)
                        .foregroundStyle(isPlayerWinner ? FELDesign.Colors.success : FELDesign.Colors.danger)

                    Text(isPlayerWinner ? "YOUR DUNK ECLIPSED \(opponent.displayName) IN STYLE & HANGTIME!" : "\(opponent.displayName) WON THIS ROUND. ADJUST YOUR LANDING SAFETY.")
                        .font(FELDesign.Typography.caption)
                        .foregroundStyle(FELDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FELDesign.Space.md)
                }
                .padding(.vertical, FELDesign.Space.sm)
                .frame(maxWidth: .infinity)
                .background(FELDesign.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: FELDesign.Radius.md)
                        .stroke((isPlayerWinner ? FELDesign.Colors.success : FELDesign.Colors.danger).opacity(0.4), lineWidth: FELDesign.Stroke.hairline)
                )
                .transition(.scale.combined(with: .opacity))
            }

            // WDA Live Judges' Panel Section
            VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
                FELMicroLabel(text: "WDA Live Judges' Board")

                HStack(spacing: FELDesign.Space.xs) {
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
            .felCard(padding: FELDesign.Space.sm)

            if let result = playerDunkResult {
                VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
                    FELMicroLabel(text: "Judges' Live Commentary")

                    VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
                        Text(result.randyCommentary)
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textSecondary)

                        Divider().background(FELDesign.Colors.hairline)

                        Text(result.dominiqueCommentary)
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textSecondary)

                        Divider().background(FELDesign.Colors.hairline)

                        Text(result.lisaCommentary)
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textSecondary)
                    }
                    .felCard(padding: FELDesign.Space.sm)
                }
                .padding(.top, FELDesign.Space.xs)
                .transition(.opacity.combined(with: .scale))
            }

            Spacer()

            // Lobby actions
            VStack(spacing: FELDesign.Space.sm) {
                if playerDunkResult == nil {
                    Button(action: { showCameraLab = true }) {
                        HStack(spacing: FELDesign.Space.xs) {
                            Image(systemName: "video.fill")
                            Text("ENTER PROCTORED CAMERA LAB")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FELPrimaryButtonStyle())
                } else if !hasClaimedRewards {
                    Button(action: claimRewardsAndSave) {
                        HStack(spacing: FELDesign.Space.xs) {
                            Image(systemName: "diamond.fill")
                            Text("CLAIM MULTIPLAYER REWARDS (+50 SHARDS)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FELPrimaryButtonStyle())
                } else {
                    Button(action: { dismiss() }) {
                        Text("DISMISS LOBBY")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FELGhostButtonStyle())
                }
            }
        }
    }

    private func judgeCard(name: String, playerScore: Double, opponentScore: Double, isScored: Bool) -> some View {
        VStack(spacing: FELDesign.Space.xs) {
            FELMicroLabel(text: name)
                .lineLimit(1)

            HStack(spacing: FELDesign.Space.xs) {
                VStack(spacing: FELDesign.Space.xxs) {
                    Text("YOU")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.cyan)

                    Text(isScored ? String(format: "%.1f", playerScore) : "--")
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .background(FELDesign.Colors.hairline)
                    .frame(height: 16)

                VStack(spacing: FELDesign.Space.xxs) {
                    Text("OPP")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.textSecondary)

                    Text(String(format: "%.1f", opponentScore))
                        .font(FELDesign.Typography.stat)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, FELDesign.Space.xs)
            .background(FELDesign.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.sm))
        }
        .padding(FELDesign.Space.xs)
        .frame(maxWidth: .infinity)
    }

    private func proctorZoomTile(name: String, tag: String, icon: String, accent: Color, isLive: Bool) -> some View {
        VStack(spacing: FELDesign.Space.xs) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: FELDesign.Radius.sm)
                    .fill(FELDesign.Colors.ink)
                    .frame(height: 72)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 28))
                            .foregroundStyle(accent)
                    )
                    .overlay(RoundedRectangle(cornerRadius: FELDesign.Radius.sm).stroke(FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline))

                if isLive {
                    HStack(spacing: FELDesign.Space.xxs) {
                        Circle().fill(FELDesign.Colors.danger).frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(FELDesign.Typography.statSmall)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                    }
                    .padding(FELDesign.Space.xs)
                }
            }

            FELMicroLabel(text: name, color: FELDesign.Colors.textPrimary)
                .lineLimit(1)

            Text(tag)
                .font(FELDesign.Typography.statSmall)
                .foregroundStyle(FELDesign.Colors.textTertiary)
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
        guard let result = playerDunkResult, !hasClaimedRewards else { return }

        // Award Shards
        viewModel.profile.evolutionShards += 50

        // Calculate new PRQ rating using PRQ.rankingSessionPRQ
        let activeBoost = viewModel.profile.activeCreatorCard != nil
        let deltaPRQ = PRQ.rankingSessionPRQ(
            mode: .basketballDunkContestIRL,
            won: isPlayerWinner,
            tied: false,
            combo: isPlayerWinner ? 3 : 1,
            criticals: activeBoost ? 2 : 0,
            scoreDifferential: max(0, Int(result.totalScore - (matchedOpponent?.totalScore ?? 40.0))),
            participationEligible: true,
            sessionReadiness: viewModel.profile.metrics.neuralDrive
        )

        let newPrq = min(100.0, max(0.0, viewModel.competitivePRQScore + deltaPRQ))
        FELScoreManager.shared.applyClampedPrq(Int(newPrq))

        // Save profile
        SaveSystem.saveProfile(viewModel.profile)

        hasClaimedRewards = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var activeCreatorCard: CreatorCard? {
        guard let active = viewModel.profile.activeCreatorCard else { return nil }
        return CreatorCard.catalog.first(where: { $0.id == active.cardId })
    }

    private var creatorCardSelectorSheet: some View {
        NavigationStack {
            ZStack {
                FELDesign.Colors.ink.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
                        FELMicroLabel(text: "Select Creator Card")
                            .padding(.horizontal)
                            .padding(.top, FELDesign.Space.md)

                        Button(action: {
                            viewModel.clearCreatorCard()
                            showCreatorCardSelector = false
                        }) {
                            HStack {
                                Text("NO CREATOR CARD")
                                    .font(FELDesign.Typography.label)
                                    .foregroundStyle(FELDesign.Colors.textSecondary)
                                Spacer()
                                if viewModel.profile.activeCreatorCard == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(FELDesign.Colors.cyan)
                                }
                            }
                            .felCard()
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)

                        ForEach(CreatorCard.catalog) { card in
                            Button(action: {
                                viewModel.applyCreatorCard(card)
                                showCreatorCardSelector = false
                            }) {
                                HStack(spacing: FELDesign.Space.sm) {
                                    Image(systemName: card.iconName)
                                        .foregroundStyle(viewModel.profile.activeCreatorCard?.cardId == card.id ? FELDesign.Colors.cyan : FELDesign.Colors.textSecondary)
                                    VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                                        Text(card.creatorName.uppercased())
                                            .font(FELDesign.Typography.label)
                                            .foregroundStyle(FELDesign.Colors.textPrimary)
                                        Text(card.title)
                                            .font(FELDesign.Typography.caption)
                                            .foregroundStyle(FELDesign.Colors.textSecondary)
                                    }
                                    Spacer()
                                    if viewModel.profile.activeCreatorCard?.cardId == card.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(FELDesign.Colors.cyan)
                                    }
                                }
                                .padding()
                                .background(FELDesign.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                                        .stroke(viewModel.profile.activeCreatorCard?.cardId == card.id ? FELDesign.Colors.cyan : FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
                                )
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, FELDesign.Space.lg)
                }
            }
            .navigationTitle("Creator Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showCreatorCardSelector = false }
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var signatureAnimationSelectorSheet: some View {
        NavigationStack {
            ZStack {
                FELDesign.Colors.ink.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FELDesign.Space.lg) {
                        FELMicroLabel(text: "Select Signature Dunk Animation")
                            .padding(.horizontal)
                            .padding(.top, FELDesign.Space.md)

                        // User's Uploaded Animations
                        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
                            FELMicroLabel(text: "My Competition Animations")
                                .padding(.horizontal)

                            let userDunks = viewModel.profile.competitionAnimations.filter { $0.header.category.lowercased() == "dunk" }
                            if userDunks.isEmpty {
                                Text("No uploaded competition dunks found. Mint or upload animations in the Creator Hub!")
                                    .font(FELDesign.Typography.caption)
                                    .foregroundStyle(FELDesign.Colors.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .felCard()
                                    .padding(.horizontal)
                            } else {
                                ForEach(userDunks) { anim in
                                    animationRow(for: anim, isPreset: false)
                                }
                            }
                        }

                        // Standard Presets
                        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
                            FELMicroLabel(text: "Standard Presets")
                                .padding(.horizontal)

                            let presets = NexusCompetitionAnimationUploader.shared.getStandardPresets().filter { $0.header.category.lowercased() == "dunk" }
                            ForEach(presets) { anim in
                                animationRow(for: anim, isPreset: true)
                            }
                        }
                    }
                    .padding(.bottom, FELDesign.Space.lg)
                }
            }
            .navigationTitle("Signature Animations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showSignatureSelector = false }
                        .foregroundStyle(FELDesign.Colors.cyan)
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
                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    Text(anim.header.title.uppercased())
                        .font(FELDesign.Typography.label)
                        .foregroundStyle(FELDesign.Colors.textPrimary)

                    HStack(spacing: FELDesign.Space.xs) {
                        Text(anim.header.competitionName)
                            .font(FELDesign.Typography.caption)
                            .foregroundStyle(FELDesign.Colors.textSecondary)

                        Text("·")
                            .foregroundStyle(FELDesign.Colors.textTertiary)

                        FELMicroLabel(text: isPreset ? "Preset" : "Uploaded")
                    }
                }
                Spacer()

                if selectedSignatureAnimation?.id == anim.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
            }
            .padding()
            .background(FELDesign.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: FELDesign.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: FELDesign.Radius.lg)
                    .stroke(selectedSignatureAnimation?.id == anim.id ? FELDesign.Colors.cyan : FELDesign.Colors.hairline, lineWidth: FELDesign.Stroke.hairline)
            )
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}
