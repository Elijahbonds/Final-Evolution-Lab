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
                VStack(spacing: 20) {
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
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.slateBackground)

            if bridgeToastVisible {
                bridgeSyncToast
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
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
                GameModeRouter(
                    viewModel: viewModel,
                    gameMode: mode,
                    sessionReadiness: sessionReadiness,
                    onDismiss: { navigateToArenaGame = false }
                )
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
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.neonGreen)
            Text("Scan synced · bridge sent")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Theme.neonGreen.opacity(0.35), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Your performance")
                .font(FELTypography.caption())
                .foregroundStyle(Theme.neonGreen)
                .tracking(1)

            Text("Status")
                .font(FELTypography.display(44))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var backendConnectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connections")
                .font(FELTypography.headline(13))
                .foregroundStyle(.secondary)

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
                .font(FELTypography.caption(10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.brandBlue.opacity(0.15), lineWidth: 0.5)
                )
        )
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick access")
                .font(FELTypography.headline(13))
                .foregroundStyle(.secondary)

            Button { showTrainingHub = true } label: {
                dashboardRouteRow(
                    title: "Train",
                    subtitle: "Workouts · drills · recovery",
                    icon: "figure.highintensity.intervaltraining",
                    color: Theme.brandBlue,
                    previewText: nil
                )
            }
            .buttonStyle(.plain)

            Button { showAgentChat = true } label: {
                dashboardRouteRow(
                    title: "Agent",
                    subtitle: "List modes · playtest · build gate",
                    icon: "sparkles",
                    color: Theme.elitePurple,
                    previewText: FELPremiumCopy.Preview.toolChips
                )
            }
            .buttonStyle(.plain)

            Button { showMoCapStudio = true } label: {
                dashboardRouteRow(
                    title: "3D MoCap Studio",
                    subtitle: "Markerless 3D motion capture & playback",
                    icon: "figure.walk.motion",
                    color: Theme.brandCyan,
                    previewText: "BETA"
                )
            }
            .buttonStyle(.plain)

            Button { showFaceScanStudio = true } label: {
                dashboardRouteRow(
                    title: "Face Scan Studio",
                    subtitle: "Markerless 3D face scan & Live Link",
                    icon: "faceid",
                    color: Theme.brandCyan,
                    previewText: "LIVE LINK"
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private func backendLaneRow(
        title: String,
        subtitle: String,
        icon: String,
        pill: FELStatusPill,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(pill.style.color)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(pill.style.color.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(FELTypography.headline(13))
                            .foregroundStyle(.white)
                        pill
                    }
                    Text(subtitle)
                        .font(FELTypography.caption(10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }

            Text(detail)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var arenaLaunchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                Text("ARENA · NEXUS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
                Spacer()
                Text("\(GameModeRegistry.catalogModes.count) MODES")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
            }

            Text("Dunk Contest → Metal when venue mesh bundled · else SceneKit · NEXUS_USE_METAL=1 forces Metal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

            HStack(spacing: 10) {
                ForEach(GameModeRegistry.nexusSprintModes.prefix(3)) { mode in
                    Button {
                        pendingArenaMode = mode
                        sessionReadiness = viewModel.effectiveMetrics.neuralDrive
                        navigateToArenaGame = true
                    } label: {
                        Text(mode.name)
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
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
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(Theme.brandCyan)
                .padding(.vertical, 10)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.brandCyan.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var educationRoutesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EDUCATION")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)

            Button { showBodyIQLab = true } label: {
                dashboardRouteRow(
                    title: "Body IQ Lab",
                    subtitle: "Movement snacks · drawing-in · prescriptions",
                    icon: "figure.flexibility",
                    color: Theme.elitePurple,
                    previewText: FELPremiumCopy.Preview.nexusEducation
                )
            }
            .buttonStyle(.plain)

            Button { showBioDigital = true } label: {
                dashboardRouteRow(
                    title: "Bio-Digital Anatomy",
                    subtitle: "SceneKit anatomy stub — not UE FELEducationEngine",
                    icon: "figure.stand",
                    color: Theme.brandCyan,
                    previewText: FELPremiumCopy.Preview.sceneKitStub
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.elitePurple.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func dashboardRouteRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        previewText: String?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(color.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(FELTypography.headline(13))
                        .foregroundStyle(.white)
                    if let previewText {
                        FELFeaturePreviewIndicator(previewText: previewText)
                    }
                }
                Text(subtitle)
                    .font(FELTypography.caption())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }

    private var sessionReceiptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.neonGreen)
                Text("SESSION RECEIPTS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
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
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            if let receiptStatusMessage {
                Text(receiptStatusMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(receiptQueueSnapshot.canPost ? Theme.neonGreen : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Gameplay ends → flush to ~/.fel/pending_receipts → POST \(Config.gameplaySessionReceiptURL) when backend auth is available (FEL_BACKEND_AUTH_TOKEN or Firebase). Shards/PRQ apply only on HTTP 2xx (see NexusEconomyAuthority).")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
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
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.neonGreen)
                    .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.neonGreen.opacity(0.15), lineWidth: 0.5)
                )
        )
        .onAppear {
            receiptQueueSnapshot = SessionReceiptUploadService.queueSnapshot()
            receiptStatusMessage = SessionReceiptUploadService.lastDrainSummary?.lastErrorMessage
        }
    }

    private var prqGaugeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 12)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: gaugeAnimationProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.neonGreen.opacity(0.4), Theme.neonGreen, Theme.neonGreen.opacity(0.8)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Theme.neonGreen.opacity(0.05))
                    .frame(width: 156, height: 156)

                VStack(spacing: 4) {
                    Text("\(prqScore)")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text("PRQ")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                        .tracking(4)
                }
            }

            HStack(spacing: 12) {
                Text(viewModel.userPRQTier.rawValue)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(tierColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(tierColor.opacity(0.12))
                    .clipShape(Capsule())

                Text("\(viewModel.profile.totalWorkouts) sessions")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Theme.neonGreen.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var healthKitRow: some View {
        HStack(spacing: 12) {
            healthMetricTile(
                icon: "flame.fill",
                value: String(format: "%.0f", viewModel.healthKit.activeCalories),
                unit: "kcal",
                label: "ACTIVE",
                color: .orange
            )

            healthMetricTile(
                icon: "figure.walk",
                value: "—",
                unit: "steps",
                label: "STEPS",
                color: Theme.neonGreen
            )

            healthMetricTile(
                icon: "heart.fill",
                value: viewModel.healthKit.heartRate > 0 ? String(format: "%.0f", viewModel.healthKit.heartRate) : "—",
                unit: "bpm",
                label: "HR",
                color: .red
            )
        }
    }

    private func healthMetricTile(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }

                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(color.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private var motionStreamCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gyroscope")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.neonGreen)

                Text("BIOMETRIC STREAM")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()

                Circle()
                    .fill(motionHelper.isStreaming ? Theme.neonGreen : Color.gray)
                    .frame(width: 8, height: 8)

                Text(motionHelper.isStreaming ? "LIVE" : "OFF")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(motionHelper.isStreaming ? Theme.neonGreen : .secondary)
            }

            if motionHelper.isStreaming {
                HStack(spacing: 16) {
                    motionAxis(label: "X", value: motionHelper.accelerationX, color: .red)
                    motionAxis(label: "Y", value: motionHelper.accelerationY, color: Theme.neonGreen)
                    motionAxis(label: "Z", value: motionHelper.accelerationZ, color: Theme.brandBlue)
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
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(motionHelper.isStreaming ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(motionHelper.isStreaming ? Color.white.opacity(0.08) : Theme.neonGreen)
                    .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    private func motionAxis(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)

            Text(String(format: "%.2f", value))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    private var scanToGenerateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)

                Text("SCAN TO GENERATE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()

                FELFeaturePreviewIndicator(previewText: FELPremiumCopy.Preview.nexus)
            }

            Text(FELPremiumCopy.Emulator.scanToArena)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showScanToGenerate = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("OPEN SCAN FLOW")
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Theme.brandCyan, Theme.brandBlue.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.brandCyan.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var gameGeneratorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.elitePurple)

                Text("GAME GENERATOR")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()

                FELFeaturePreviewIndicator(previewText: FELPremiumCopy.Preview.nexus)
            }

            Text(FELPremiumCopy.Emulator.describeToGame)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showGameGenerator = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                    Text("OPEN GENERATOR")
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Theme.elitePurple, Theme.brandCyan.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.elitePurple.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var neuralSyncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandBlue)

                Text("NEURAL SYNC")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()

                let isLinked = NexusGameplayBridge.isLinked
                Circle()
                    .fill(isLinked ? Theme.neonGreen : .orange)
                    .frame(width: 8, height: 8)

                Text(isLinked ? "LINKED" : "STANDBY")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(isLinked ? Theme.neonGreen : .orange)
            }

            HStack(spacing: 12) {
                syncMetric(label: "Neural Drive", value: String(format: "%.0f", viewModel.effectiveMetrics.neuralDrive), icon: "bolt.fill")
                syncMetric(label: "Readiness", value: String(format: "%.0f", viewModel.effectiveMetrics.readinessScore), icon: "waveform.path.ecg")
                syncMetric(label: "Efficiency", value: String(format: "%.0f", viewModel.effectiveMetrics.efficiencyScore), icon: "gauge.with.dots.needle.33percent")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.brandBlue.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private func syncMetric(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.brandBlue)

            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)

            Text(label.uppercased())
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

#if DEBUG
    private var simulateSystemScanDebugCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)

                Text("DEBUG · SYSTEM SCAN")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(2)

                Spacer()
            }

            Text("Writes a mock scan to Firestore and queues JSON for NEXUS gameplay bridge (if linked). Check Xcode console for bridge logs.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)

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
                HStack(spacing: 8) {
                    if simulateScanBusy {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(simulateScanBusy ? "SYNCING…" : "SIMULATE SCAN")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.9))
                .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(simulateScanBusy)

            if let simulateScanMessage {
                Text(simulateScanMessage)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(simulateScanMessage.contains("synced") ? Theme.neonGreen : .orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
                )
        )
    }
#endif

    private var nexusStudioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXUS STUDIO")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                    Text("Editor · Run · Cursor bridge")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                FELFeaturePreviewIndicator(previewText: FELPremiumCopy.Preview.ideV03, dotColor: Theme.brandCyan)
            }

            Text("Embedded code browser for engine/, FinalEvolutionLab/, app/gameplay/, and assets/. Search, recent files, sandbox edits, and in-app playtest.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                NexusStudioCoordinator.shared.open(panel: .editor)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 14, weight: .bold))
                    Text("OPEN NEXUS STUDIO")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.brandCyan)
                .clipShape(.rect(cornerRadius: 12))
            }

            Button {
                NexusStudioCoordinator.shared.openRunPanel(modeId: nil)
            } label: {
                Label("Open Studio Run panel", systemImage: "play.rectangle")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.neonGreen)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.slateCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.brandCyan.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    private var shareToFeedButton: some View {
        Button {
            showShareToFeed = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("SHARE TO FEED")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(2)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.neonGreen)
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    private var tierColor: Color {
        switch viewModel.userPRQTier {
        case .diamond: .yellow
        case .platinum: Theme.elitePurple
        case .gold: .orange
        case .silver: Theme.brandBlue
        case .bronze: Theme.neonGreen
        case .unranked: .gray
        }
    }
}
