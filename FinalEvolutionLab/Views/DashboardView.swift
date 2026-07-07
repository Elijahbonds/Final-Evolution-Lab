import SwiftUI
import UIKit

struct DashboardView: View {
    let viewModel: LabViewModel
    @State private var motionHelper = CoreMotionHelper.shared
    @State private var appeared: Bool = false
    @State private var gaugeAnimationProgress: Double = 0
    @State private var showShareToFeed: Bool = false
    @State private var showScanToGenerate: Bool = false
    @State private var showGameGenerator: Bool = false
    @State private var bridgeToastVisible: Bool = false
    @State private var pendingArenaMode: GameMode?
    @State private var sessionReadiness: Double = 50
    @State private var navigateToArenaGame: Bool = false
    @State private var showBodyIQLab: Bool = false
    @State private var showBioDigital: Bool = false
    @State private var showTrainingHub: Bool = false
    @State private var showAgentChat: Bool = false
    @State private var showMoCapStudio: Bool = false
    @State private var showFaceScanStudio: Bool = false
    @State private var receiptQueueSnapshot: SessionReceiptUploadService.QueueSnapshot = SessionReceiptUploadService.queueSnapshot()
    @State private var receiptStatusMessage: String?
#if DEBUG
    @State private var simulateScanBusy: Bool = false
    @State private var simulateScanMessage: String?
#endif

    private var prqScore: Int { Int(viewModel.competitivePRQScore) }
    private var prqNormalized: Double { viewModel.competitivePRQScore / 100.0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: FELDesign.Space.lg) {
                    headerSection
                    backendConnectionCard
                    quickRoutesCard
                    arenaLaunchCard
                    educationRoutesCard
                    sessionReceiptCard
                    BioFuelDashboardView(viewModel: viewModel)
                    prqGaugeCard
                    healthKitRow
                    motionStreamCard
                    scanToGenerateCard
                    gameGeneratorCard
                    neuralSyncCard
                    nexusStudioCard
#if DEBUG
                    simulateSystemScanDebugCard
#endif
                    shareToFeedButton
                }
                .padding(.horizontal)
                .padding(.bottom, FELDesign.Space.xl)
            }
            .scrollIndicators(.hidden)
            .background(FELDesign.Colors.ink)

            if bridgeToastVisible {
                bridgeSyncToast
                    .padding(.horizontal, FELDesign.Space.lg)
                    .padding(.bottom, FELDesign.Space.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showShareToFeed) {
            NavigationStack {
                ShareToFeedView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showShareToFeed = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
        .sheet(isPresented: $showMoCapStudio) {
            NexusMoCapStudioView(viewModel: viewModel)
        }
        .sheet(isPresented: $showFaceScanStudio) {
            NexusFaceScanView(viewModel: viewModel)
        }
        .sheet(isPresented: $showScanToGenerate) {
            ScanToGenerateView()
        }
        .sheet(isPresented: $showGameGenerator) {
            NavigationStack {
                NexusGameGeneratorView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showGameGenerator = false }
                        }
                    }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                gaugeAnimationProgress = prqNormalized
            }
        }
        .onChange(of: prqScore) { _, newValue in
            withAnimation(.spring(duration: 0.6)) {
                gaugeAnimationProgress = Double(newValue) / 100.0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felSystemScanBridgeCompleted)) { _ in
            triggerBridgeSyncFeedback()
        }
        .navigationDestination(isPresented: $navigateToArenaGame) {
            if let mode = pendingArenaMode {
                GamePlayView(viewModel: viewModel, gameMode: mode, sessionReadiness: sessionReadiness)
            }
        }
        .navigationDestination(isPresented: $showBodyIQLab) {
            BodyIQEducationLabView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showBioDigital) {
            BioDigitalAnatomyView(moduleId: "dashboard_preview")
        }
        .navigationDestination(isPresented: $showTrainingHub) {
            TrainingHubView(labViewModel: viewModel)
        }
        .navigationDestination(isPresented: $showAgentChat) {
            NexusAgentChatView()
        }
    }

    private var bridgeSyncToast: some View {
        HStack(spacing: FELDesign.Space.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(FELDesign.Typography.body.weight(.semibold))
                .foregroundStyle(FELDesign.Colors.success)
            Text("Scan synced · bridge sent")
                .font(FELDesign.Typography.stat)
                .foregroundStyle(FELDesign.Colors.textPrimary)
        }
        .padding(.horizontal, FELDesign.Space.md)
        .padding(.vertical, FELDesign.Space.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(FELDesign.Colors.glow(FELDesign.Colors.success), lineWidth: FELDesign.Stroke.hairline)
        )
    }

    private func triggerBridgeSyncFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            bridgeToastVisible = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_850_000_000)
            withAnimation(.easeOut(duration: 0.28)) {
                bridgeToastVisible = false
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
            FELMicroLabel(text: "Your performance", color: FELDesign.Colors.cyan)

            Text("Status")
                .font(FELDesign.Typography.display)
                .foregroundStyle(FELDesign.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, FELDesign.Space.xs)
    }

    private var backendConnectionCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            Text("Connections")
                .font(FELDesign.Typography.label)
                .foregroundStyle(FELDesign.Colors.textSecondary)

            backendLaneRow(
                title: "AI Studio",
                subtitle: "Gemini · agent · generator · BioFuel",
                icon: "sparkles",
                pill: aiStudioStatusPill,
                detail: NexusAIStudioBootstrap.statusLabel
            )

            backendLaneRow(
                title: "Firebase",
                subtitle: "Auth · Firestore · Crashlytics · distribution",
                icon: "flame.fill",
                pill: firebaseStatusPill,
                detail: FirebaseBootstrap.statusLabel
            )

            Text("Core app boot requires AI Studio only. Firebase is optional for distribution and cloud sync.")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .felCard()
    }

    private var aiStudioStatusPill: FELStatusPill {
        if NexusAIStudioBootstrap.connectionStatus == .connected {
            return FELStatusPill(text: "Connected", style: .connected)
        }
        return FELStatusPill(text: "Offline", style: .offline)
    }

    private var firebaseStatusPill: FELStatusPill {
        switch FirebaseBootstrap.connectionStatus {
        case .live:
            return FELStatusPill(text: "Live", style: .live)
        case .preview:
            return FELStatusPill(text: "Preview", style: .preview)
        case .unavailable:
            return FELStatusPill(text: "Offline", style: .offline)
        case .disabled:
            return FELStatusPill(text: "Off", style: .disabled)
        }
    }

    private var quickRoutesCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            Text("Quick access")
                .font(FELDesign.Typography.label)
                .foregroundStyle(FELDesign.Colors.textSecondary)

            Button { showTrainingHub = true } label: {
                dashboardRouteRow(
                    title: "Train",
                    subtitle: "Workouts · drills · recovery",
                    icon: "figure.highintensity.intervaltraining",
                    color: FELDesign.Colors.cyan,
                    previewText: nil
                )
            }
            .buttonStyle(.plain)

            Button { showAgentChat = true } label: {
                dashboardRouteRow(
                    title: "Agent",
                    subtitle: "List modes · playtest · build gate",
                    icon: "sparkles",
                    color: FELDesign.Colors.purple,
                    previewText: FELPremiumCopy.Preview.toolChips
                )
            }
            .buttonStyle(.plain)

            Button { showMoCapStudio = true } label: {
                dashboardRouteRow(
                    title: "3D MoCap Studio",
                    subtitle: "Markerless 3D motion capture & playback",
                    icon: "figure.walk.motion",
                    color: FELDesign.Colors.cyan,
                    previewText: "BETA"
                )
            }
            .buttonStyle(.plain)

            Button { showFaceScanStudio = true } label: {
                dashboardRouteRow(
                    title: "Face Scan Studio",
                    subtitle: "Markerless 3D face scan & Live Link",
                    icon: "faceid",
                    color: FELDesign.Colors.cyan,
                    previewText: "LIVE LINK"
                )
            }
            .buttonStyle(.plain)
        }
        .felCard()
    }

    private func backendLaneRow(
        title: String,
        subtitle: String,
        icon: String,
        pill: FELStatusPill,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.xs) {
            HStack(spacing: FELDesign.Space.sm) {
                Image(systemName: icon)
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(pill.style.color)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(pill.style.color.opacity(0.12)))

                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    HStack(spacing: FELDesign.Space.xs) {
                        Text(title)
                            .font(FELDesign.Typography.label)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                        pill
                    }
                    Text(subtitle)
                        .font(FELDesign.Typography.caption)
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                }
                Spacer()
            }

            Text(detail)
                .font(FELDesign.Typography.statSmall)
                .foregroundStyle(FELDesign.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var arenaLaunchCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.cyan)
                FELMicroLabel(text: "Arena · Nexus", color: FELDesign.Colors.textSecondary)
                Spacer()
                Text("\(GameModeRegistry.catalogModes.count) MODES")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(FELDesign.Colors.cyan)
            }

            Text("Dunk Contest → Metal when venue mesh bundled · else SceneKit · NEXUS_USE_METAL=1 forces Metal")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)

            HStack(spacing: FELDesign.Space.sm) {
                ForEach(GameModeRegistry.nexusSprintModes.prefix(3)) { mode in
                    Button {
                        pendingArenaMode = mode
                        sessionReadiness = viewModel.effectiveMetrics.neuralDrive
                        navigateToArenaGame = true
                    } label: {
                        Text(mode.name)
                            .font(FELDesign.Typography.micro)
                            .foregroundStyle(FELDesign.Colors.textPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, FELDesign.Space.sm)
                            .padding(.vertical, FELDesign.Space.xs)
                            .background(mode.accentColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            NavigationLink {
                GameModeSelectionView(viewModel: viewModel)
            } label: {
                HStack {
                    Text("OPEN MODE PICKER")
                        .font(FELDesign.Typography.micro)
                        .tracking(FELDesign.Typography.microTracking)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(FELDesign.Colors.cyan)
                .padding(.vertical, FELDesign.Space.sm)
            }
        }
        .felCard()
    }

    private var educationRoutesCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            FELMicroLabel(text: "Education")

            Button { showBodyIQLab = true } label: {
                dashboardRouteRow(
                    title: "Body IQ Lab",
                    subtitle: "Movement snacks · drawing-in · prescriptions",
                    icon: "figure.flexibility",
                    color: FELDesign.Colors.purple,
                    previewText: FELPremiumCopy.Preview.nexusEducation
                )
            }
            .buttonStyle(.plain)

            Button { showBioDigital = true } label: {
                dashboardRouteRow(
                    title: "Bio-Digital Anatomy",
                    subtitle: "SceneKit anatomy stub — not UE FELEducationEngine",
                    icon: "figure.stand",
                    color: FELDesign.Colors.cyan,
                    previewText: FELPremiumCopy.Preview.sceneKitStub
                )
            }
            .buttonStyle(.plain)
        }
        .felCard()
    }

    private func dashboardRouteRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        previewText: String?
    ) -> some View {
        HStack(spacing: FELDesign.Space.sm) {
            Image(systemName: icon)
                .font(FELDesign.Typography.body.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(color.opacity(0.12)))
            VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                HStack(spacing: FELDesign.Space.xs) {
                    Text(title)
                        .font(FELDesign.Typography.label)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                    if let previewText {
                        FELFeaturePreviewIndicator(previewText: previewText)
                    }
                }
                Text(subtitle)
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)
        }
        .padding(.vertical, FELDesign.Space.xxs)
    }

    private var sessionReceiptCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.cyan)
                FELMicroLabel(text: "Session Receipts", color: FELDesign.Colors.textSecondary)
                Spacer()
                FELStatusPill(
                    text: receiptQueueSnapshot.canPost ? "Live post" : "Local only",
                    style: receiptQueueSnapshot.canPost ? .live : .preview,
                    compact: true
                )
            }

            if !NexusAIStudioBootstrap.isConfigured || !receiptQueueSnapshot.canPost {
                FELFeaturePreviewIndicator(previewText: receiptQueueSnapshot.laneLabel)
            }

            Text("\(receiptQueueSnapshot.pendingCount) pending · \(receiptQueueSnapshot.queueDirectory)")
                .font(FELDesign.Typography.statSmall)
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .lineLimit(2)

            if let receiptStatusMessage {
                Text(receiptStatusMessage)
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(receiptQueueSnapshot.canPost ? FELDesign.Colors.success : FELDesign.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Gameplay ends → flush to ~/.fel/pending_receipts → POST \(Config.gameplaySessionReceiptURL) when backend auth is available (FEL_BACKEND_AUTH_TOKEN or Firebase). Shards/PRQ apply only on HTTP 2xx (see NexusEconomyAuthority).")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    let summary = await SessionReceiptUploadService.uploadPendingReceipts()
                    receiptQueueSnapshot = SessionReceiptUploadService.queueSnapshot()
                    if let message = summary.lastErrorMessage, summary.isPreviewLane {
                        // Preview lane: informational only — no error toast on automatic foreground drain.
                        receiptStatusMessage = message
                    } else if summary.succeeded > 0, summary.failed == 0 {
                        receiptStatusMessage = "Drained \(summary.succeeded) receipt\(summary.succeeded == 1 ? "" : "s")."
                    } else if let message = summary.lastErrorMessage {
                        receiptStatusMessage = message
                    } else {
                        receiptStatusMessage = nil
                    }
                }
            } label: {
                Text(receiptQueueSnapshot.canPost ? FELPremiumCopy.Receipt.uploadPending : FELPremiumCopy.Receipt.refreshQueue)
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FELDesign.Space.sm)
                    .background(FELDesign.Colors.cyan)
                    .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
            }
        }
        .felCard()
        .onAppear {
            receiptQueueSnapshot = SessionReceiptUploadService.queueSnapshot()
            receiptStatusMessage = SessionReceiptUploadService.lastDrainSummary?.lastErrorMessage
        }
    }

    private var prqGaugeCard: some View {
        VStack(spacing: FELDesign.Space.md) {
            ZStack {
                Circle()
                    .stroke(FELDesign.Colors.hairline, lineWidth: 12)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: gaugeAnimationProgress)
                    .stroke(
                        FELDesign.Colors.cyan,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(FELDesign.Colors.glow(FELDesign.Colors.cyan, 0.05))
                    .frame(width: 156, height: 156)

                VStack(spacing: FELDesign.Space.xxs) {
                    Text("\(prqScore)")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                        .contentTransition(.numericText())

                    Text("PRQ")
                        .font(FELDesign.Typography.micro)
                        .tracking(FELDesign.Typography.microTracking)
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                }
            }

            HStack(spacing: FELDesign.Space.sm) {
                Text(viewModel.userPRQTier.rawValue)
                    .font(FELDesign.Typography.micro)
                    .foregroundStyle(tierColor)
                    .padding(.horizontal, FELDesign.Space.sm)
                    .padding(.vertical, FELDesign.Space.xxs)
                    .background(tierColor.opacity(0.12))
                    .clipShape(Capsule())

                Text("\(viewModel.profile.totalWorkouts) sessions")
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .felCard(padding: FELDesign.Space.lg)
    }

    private var healthKitRow: some View {
        HStack(spacing: FELDesign.Space.sm) {
            healthMetricTile(
                icon: "flame.fill",
                value: String(format: "%.0f", viewModel.healthKit.activeCalories),
                unit: "kcal",
                label: "ACTIVE",
                color: FELDesign.Colors.cyan
            )

            healthMetricTile(
                icon: "figure.walk",
                value: "—",
                unit: "steps",
                label: "STEPS",
                color: FELDesign.Colors.cyan
            )

            healthMetricTile(
                icon: "heart.fill",
                value: viewModel.healthKit.heartRate > 0 ? String(format: "%.0f", viewModel.healthKit.heartRate) : "—",
                unit: "bpm",
                label: "HR",
                color: FELDesign.Colors.cyan
            )
        }
    }

    private func healthMetricTile(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: FELDesign.Space.xs) {
            Image(systemName: icon)
                .font(FELDesign.Typography.body.weight(.semibold))
                .foregroundStyle(color)

            VStack(spacing: FELDesign.Space.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(FELDesign.Typography.statLarge)
                        .foregroundStyle(FELDesign.Colors.textPrimary)
                    Text(unit)
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                }

                Text(label)
                    .font(FELDesign.Typography.micro)
                    .tracking(FELDesign.Typography.microTracking)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .felCard()
    }

    private var motionStreamCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Image(systemName: "gyroscope")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.cyan)

                FELMicroLabel(text: "Biometric Stream", color: FELDesign.Colors.textSecondary)

                Spacer()

                Circle()
                    .fill(motionHelper.isStreaming ? FELDesign.Colors.success : FELDesign.Colors.textTertiary)
                    .frame(width: 8, height: 8)

                Text(motionHelper.isStreaming ? "LIVE" : "OFF")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(motionHelper.isStreaming ? FELDesign.Colors.success : FELDesign.Colors.textSecondary)
            }

            if motionHelper.isStreaming {
                HStack(spacing: FELDesign.Space.md) {
                    motionAxis(label: "X", value: motionHelper.accelerationX, color: FELDesign.Colors.textSecondary)
                    motionAxis(label: "Y", value: motionHelper.accelerationY, color: FELDesign.Colors.cyan)
                    motionAxis(label: "Z", value: motionHelper.accelerationZ, color: FELDesign.Colors.textPrimary)
                }
            }

            Button {
                if motionHelper.isStreaming {
                    motionHelper.stopStreaming()
                } else {
                    motionHelper.startStreaming()
                }
            } label: {
                Text(motionHelper.isStreaming ? "STOP STREAM" : "START STREAM")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(motionHelper.isStreaming ? FELDesign.Colors.textPrimary : FELDesign.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FELDesign.Space.sm)
                    .background(motionHelper.isStreaming ? FELDesign.Colors.surfaceRaised : FELDesign.Colors.cyan)
                    .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
            }
        }
        .felCard()
    }

    private func motionAxis(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: FELDesign.Space.xxs) {
            Text(label)
                .font(FELDesign.Typography.statSmall)
                .foregroundStyle(color)

            Text(String(format: "%.2f", value))
                .font(FELDesign.Typography.stat)
                .foregroundStyle(FELDesign.Colors.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private var scanToGenerateCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Image(systemName: "viewfinder.circle.fill")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.cyan)

                FELMicroLabel(text: "Scan to Generate", color: FELDesign.Colors.textSecondary)

                Spacer()

                FELFeaturePreviewIndicator(previewText: FELPremiumCopy.Preview.nexus)
            }

            Text(FELPremiumCopy.Emulator.scanToArena)
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showScanToGenerate = true
            } label: {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "sparkles")
                    Text("OPEN SCAN FLOW")
                }
                .font(FELDesign.Typography.label)
                .foregroundStyle(FELDesign.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FELDesign.Space.sm)
                .background(FELDesign.Colors.cyan)
                .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
            }
        }
        .felCard()
    }

    private var gameGeneratorCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.purple)

                FELMicroLabel(text: "Game Generator", color: FELDesign.Colors.textSecondary)

                Spacer()

                FELFeaturePreviewIndicator(previewText: FELPremiumCopy.Preview.nexus)
            }

            Text(FELPremiumCopy.Emulator.describeToGame)
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showGameGenerator = true
            } label: {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "gamecontroller.fill")
                    Text("OPEN GENERATOR")
                }
                .font(FELDesign.Typography.label)
                .foregroundStyle(FELDesign.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FELDesign.Space.sm)
                .background(FELDesign.Colors.cyan)
                .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
            }
        }
        .felCard()
    }

    private var neuralSyncCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.cyan)

                FELMicroLabel(text: "Neural Sync", color: FELDesign.Colors.textSecondary)

                Spacer()

                let isLinked = NexusGameplayBridge.isLinked
                Circle()
                    .fill(isLinked ? FELDesign.Colors.success : FELDesign.Colors.textTertiary)
                    .frame(width: 8, height: 8)

                Text(isLinked ? "LINKED" : "STANDBY")
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(isLinked ? FELDesign.Colors.success : FELDesign.Colors.textTertiary)
            }

            HStack(spacing: FELDesign.Space.sm) {
                syncMetric(label: "Neural Drive", value: String(format: "%.0f", viewModel.effectiveMetrics.neuralDrive), icon: "bolt.fill")
                syncMetric(label: "Readiness", value: String(format: "%.0f", viewModel.effectiveMetrics.readinessScore), icon: "waveform.path.ecg")
                syncMetric(label: "Efficiency", value: String(format: "%.0f", viewModel.effectiveMetrics.efficiencyScore), icon: "gauge.with.dots.needle.33percent")
            }
        }
        .felCard()
    }

    private func syncMetric(label: String, value: String, icon: String) -> some View {
        VStack(spacing: FELDesign.Space.xxs) {
            Image(systemName: icon)
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)

            Text(value)
                .font(FELDesign.Typography.stat)
                .foregroundStyle(FELDesign.Colors.textPrimary)

            Text(label.uppercased())
                .font(FELDesign.Typography.micro)
                .tracking(FELDesign.Typography.microTracking)
                .foregroundStyle(FELDesign.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

#if DEBUG
    private var simulateSystemScanDebugCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.danger)

                FELMicroLabel(text: "Debug · System Scan", color: FELDesign.Colors.textSecondary)

                Spacer()
            }

            Text("Writes a mock scan to Firestore and queues JSON for NEXUS gameplay bridge (if linked). Check Xcode console for bridge logs.")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)

            Button {
                Task {
                    simulateScanBusy = true
                    simulateScanMessage = nil
                    defer { simulateScanBusy = false }
                    do {
                        try await SystemScanFirestoreSync.shared.syncSimulatedDebugScan()
                        simulateScanMessage = nil
                    } catch {
                        simulateScanMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: FELDesign.Space.xs) {
                    if simulateScanBusy {
                        ProgressView()
                            .tint(FELDesign.Colors.ink)
                    } else {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(FELDesign.Typography.label)
                    }
                    Text(simulateScanBusy ? "SYNCING…" : "SIMULATE SCAN")
                        .font(FELDesign.Typography.label)
                }
                .foregroundStyle(FELDesign.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FELDesign.Space.sm)
                .background(FELDesign.Colors.danger)
                .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
            }
            .disabled(simulateScanBusy)

            if let simulateScanMessage {
                Text(simulateScanMessage)
                    .font(FELDesign.Typography.statSmall)
                    .foregroundStyle(simulateScanMessage.contains("synced") ? FELDesign.Colors.success : FELDesign.Colors.danger)
            }
        }
        .felCard()
    }
#endif

    private var nexusStudioCard: some View {
        VStack(alignment: .leading, spacing: FELDesign.Space.sm) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.cyan)

                VStack(alignment: .leading, spacing: FELDesign.Space.xxs) {
                    FELMicroLabel(text: "Nexus Studio", color: FELDesign.Colors.textSecondary)
                    Text("Editor · Run · Cursor bridge")
                        .font(FELDesign.Typography.statSmall)
                        .foregroundStyle(FELDesign.Colors.textTertiary)
                }

                Spacer()

                FELFeaturePreviewIndicator(previewText: FELPremiumCopy.Preview.ideV03, dotColor: FELDesign.Colors.cyan)
            }

            Text("Embedded code browser for engine/, FinalEvolutionLab/, app/gameplay/, and assets/. Search, recent files, sandbox edits, and in-app playtest.")
                .font(FELDesign.Typography.caption)
                .foregroundStyle(FELDesign.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                NexusStudioCoordinator.shared.open(panel: .editor)
            } label: {
                HStack(spacing: FELDesign.Space.xs) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(FELDesign.Typography.label)
                    Text("OPEN NEXUS STUDIO")
                        .font(FELDesign.Typography.label)
                }
                .foregroundStyle(FELDesign.Colors.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FELDesign.Space.sm)
                .background(FELDesign.Colors.cyan)
                .clipShape(.rect(cornerRadius: FELDesign.Radius.md))
            }

            Button {
                NexusStudioCoordinator.shared.openRunPanel(modeId: nil)
            } label: {
                Label("Open Studio Run panel", systemImage: "play.rectangle")
                    .font(FELDesign.Typography.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(FELDesign.Colors.cyan)
        }
        .felCard()
    }

    private var shareToFeedButton: some View {
        Button {
            showShareToFeed = true
        } label: {
            HStack(spacing: FELDesign.Space.xs) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(FELDesign.Typography.label)
                Text("SHARE TO FEED")
                    .font(FELDesign.Typography.label)
                    .tracking(FELDesign.Typography.microTracking)
            }
            .foregroundStyle(FELDesign.Colors.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FELDesign.Space.md)
            .background(FELDesign.Colors.cyan)
            .clipShape(.rect(cornerRadius: FELDesign.Radius.lg))
        }
    }

    private var tierColor: Color {
        switch viewModel.userPRQTier {
        case .diamond: FELDesign.Colors.cyan
        case .platinum: FELDesign.Colors.purple
        case .gold: FELDesign.Colors.textPrimary
        case .silver: FELDesign.Colors.textSecondary
        case .bronze: FELDesign.Colors.textTertiary
        case .unranked: FELDesign.Colors.textTertiary
        }
    }
}
