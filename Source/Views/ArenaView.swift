import Combine
import SwiftUI

/// Arena: built-out venues; each venue groups game modes. Tap a mode → Get Ready → Play → Result.
struct ArenaView: View {
    let viewModel: LabViewModel
    @Binding var selectedTab: AppTab

    @EnvironmentObject private var unrealRuntime: UFELUnrealOverlayRuntime

    @State private var selectedMode: GameMode?
    @State private var showLocalPlayLobby = false
    @State private var localPlayMode: GameMode?
    @State private var localPlayIsHost = false
    @State private var showReloadAlert = false
    @State private var arenaLevelLoadWatchdog: Task<Void, Never>?
    @State private var viewportSceneHandshakeTask: Task<Void, Never>?
    /// Gold Master: one-time cinematic welcome + handshake progress (ties to `setUnrealReady`).
    @AppStorage("felArenaWelcomeElijahComplete") private var welcomeElijahComplete = false
    /// First launch: Luma Venice Shop / System Initializing guidance (`GAMEPLAY_STATUS.md` onboarding).
    @AppStorage("felUniversalShipFirstLaunchOnboardingComplete") private var shipFirstLaunchOnboardingComplete = false
    @State private var welcomeHandshakeProgress: Double = 0
    @State private var showFatigueSystemScanBanner = false
    @State private var arenaSyncSettingsExpanded = false
    @AppStorage("felPixelStreamingFallbackURL") private var pixelStreamingFallbackURL = ""
    @State private var showPixelStreamingWebFallback = false
    @StateObject private var arenaLuminanceMonitor = FELArenaAmbientLuminanceMonitor()
    @State private var lastBridgedAmbientLuma: Float?
    /// Fills only while `felNeuroMechanicLightingOptimal` is true (~3.5s steady optimal light for AvatarRigBuilder capture).
    @State private var lightingCalibrationProgress01: Double = 0
    @AppStorage("felAvatarRigLightingCalibrationComplete") private var avatarRigLightingCalibrationComplete = false
    @AppStorage("felDemoModeShowcase") private var felDemoModeShowcase = false
    @State private var heroClipOffered = false
    @State private var heroClipRecording = false
    @State private var lastHeroClipApexInches: Double?
    @State private var heroClipStatusMessage: String?

#if FEL_NON_SHIPPING
    /// DA COMPOUND: live twin scales from last readiness `sync` (matches `readiness_snapshot.json` when export runs).
    @State private var twinScaleDebugLine: String = "avatarHeightScale — · avatarWeightScale —"
    /// InputLatencyMonitor parity (Unreal) — `UserDefaults` + `felInputLatencyJumpMsSample` from native bridge.
    @State private var inputLatencyWarningActive = false
    @State private var inputLatencyFlashPhase = false
    @State private var lastInputLatencyMsDisplay: String = "—"
#endif

    private var shouldShowForensicLightPauseOverlay: Bool {
        guard let lum = arenaLuminanceMonitor.lastNormalizedBrightness else { return false }
        return lum < 0.3
    }

    var body: some View {
        ZStack {
            if !unrealRuntime.bIsUnrealReady {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        localPlaySection
                        ForEach(GameModeRegistry.arenaVenues) { venue in
                            venueSection(venue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .background(Theme.deepBlack)
            }
            if unrealRuntime.bIsUnrealReady {
                UFELUnrealViewportContainer()
                arenaInputSchemeOverlay
                    .zIndex(50)
            }
            if showPixelStreamingWebFallback, let psURL = URL(string: pixelStreamingFallbackURL.trimmingCharacters(in: .whitespacesAndNewlines)),
               !pixelStreamingFallbackURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ZStack(alignment: .topTrailing) {
                    FELPixelStreamingWebView(url: psURL)
                        .ignoresSafeArea()
                    Button {
                        showPixelStreamingWebFallback = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.45))
                    }
                    .padding(16)
                    .accessibilityLabel("Close Pixel Streaming web view")
                }
                .zIndex(200)
            }
            if !welcomeElijahComplete {
                VStack {
                    welcomeElijahHandshakeOverlay
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(100)
            } else if !shipFirstLaunchOnboardingComplete {
                VStack {
                    lumaVeniceFirstLaunchOverlay
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(99)
            }
            if shouldShowForensicLightPauseOverlay {
                forensicLightingPauseOverlay
                    .zIndex(145)
            }
#if FEL_NON_SHIPPING
            readinessTwinScaleDebugOverlay
                .zIndex(160)
#endif
        }
        // Do not force `setUnrealReady(false)` here — it hid the Metal viewport whenever returning to Arena (black shell).
        // Readiness is driven by Arena game flow (`playing`), System Scan, or Info.plist `FELUnrealViewportReady`.
        .fullScreenCover(item: $selectedMode) { mode in
            ArenaGameFlowView(
                mode: mode,
                viewModel: viewModel,
                multipeer: nil,
                isLocalHost: false,
                onDismiss: { selectedMode = nil },
                onOpenLab: {
                    viewModel.openDunkOnNextLabAppearance = true
                    selectedTab = .lab
                    selectedMode = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showLocalPlayLobby) {
            LocalPlayLobbyView(
                multipeer: viewModel.multipeerService,
                onStartGame: { mode, isHost in
                    localPlayMode = mode
                    localPlayIsHost = isHost
                    showLocalPlayLobby = false
                },
                onDismiss: { showLocalPlayLobby = false }
            )
        }
        .fullScreenCover(item: $localPlayMode) { mode in
            ArenaGameFlowView(
                mode: mode,
                viewModel: viewModel,
                multipeer: viewModel.multipeerService,
                isLocalHost: localPlayIsHost,
                onDismiss: {
                    viewModel.multipeerService.stop()
                    localPlayMode = nil
                }
            )
        }
        .onAppear {
            FELHeroClipRecorder.startBuffering()
            PRQManager.shared.sync(from: viewModel)
#if FEL_NON_SHIPPING
            refreshTwinScaleDebugLine()
            refreshInputLatencyHudState()
#endif
            refreshCoachFatigueBanner()
            arenaLuminanceMonitor.start()
            performLuminanceCheck()
            if !welcomeElijahComplete {
                welcomeHandshakeProgress = 0.05
            }
            if let id = viewModel.preselectedArenaModeId {
                selectedMode = GameModeRegistry.mode(for: id)
                viewModel.preselectedArenaModeId = nil
                unrealRuntime.applyHandshakeInputScheme(for: selectedMode?.id)
                beginArenaUnrealHandshake()
            } else {
                unrealRuntime.applyHandshakeInputScheme(for: resolvedArenaInputModeId)
            }
        }
        .onDisappear {
            FELHeroClipRecorder.stopBuffering()
            arenaLuminanceMonitor.stop()
            UserDefaults.standard.removeObject(forKey: PRQManager.neuroMechanicLightingOptimalKey)
        }
        .onChange(of: arenaLuminanceMonitor.lastNormalizedBrightness) { _, _ in
            performLuminanceCheck()
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            guard !avatarRigLightingCalibrationComplete else { return }
            let optimal = UserDefaults.standard.object(forKey: PRQManager.neuroMechanicLightingOptimalKey) as? Bool == true
            if optimal {
                lightingCalibrationProgress01 = min(1.0, lightingCalibrationProgress01 + 0.05 / 3.5)
                if lightingCalibrationProgress01 >= 0.999 {
                    avatarRigLightingCalibrationComplete = true
                    lightingCalibrationProgress01 = 1.0
                }
            } else {
                lightingCalibrationProgress01 = max(0, lightingCalibrationProgress01 - 0.06)
            }
        }
        .onChange(of: unrealRuntime.bIsUnrealReady) { _, ready in
            guard !welcomeElijahComplete else { return }
            if ready {
                welcomeHandshakeProgress = 1.0
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(420))
                    welcomeElijahComplete = true
                }
            } else {
                welcomeHandshakeProgress = max(welcomeHandshakeProgress, 0.12)
            }
        }
        .onChange(of: selectedMode) { _, newMode in
            unrealRuntime.applyHandshakeInputScheme(for: newMode?.id)
            if newMode != nil {
                if !welcomeElijahComplete {
                    welcomeHandshakeProgress = max(welcomeHandshakeProgress, 0.14)
                }
                beginArenaUnrealHandshake()
            } else {
                cancelArenaLevelLoadWatchdog()
                viewportSceneHandshakeTask?.cancel()
            }
            if let mode = newMode {
                UserDefaults.standard.set(mode.id.rawValue, forKey: PRQManager.lastExportedArenaModeKey)
                PRQManager.shared.sync(from: viewModel)
            }
        }
        .onChange(of: localPlayMode) { _, newMode in
            unrealRuntime.applyHandshakeInputScheme(for: newMode?.id)
            if newMode != nil {
                if !welcomeElijahComplete {
                    welcomeHandshakeProgress = max(welcomeHandshakeProgress, 0.14)
                }
                beginArenaUnrealHandshake()
            } else {
                cancelArenaLevelLoadWatchdog()
                viewportSceneHandshakeTask?.cancel()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felUnrealLevelLoaded)) { _ in
            unrealRuntime.applyHandshakeInputScheme(for: selectedMode?.id ?? localPlayMode?.id ?? resolvedArenaInputModeId)
            if !welcomeElijahComplete {
                welcomeHandshakeProgress = max(welcomeHandshakeProgress, 0.58)
            }
            guard selectedMode != nil || localPlayMode != nil else { return }
            cancelArenaLevelLoadWatchdog()
            showReloadAlert = false
            viewportSceneHandshakeTask?.cancel()
            viewportSceneHandshakeTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled else { return }
                unrealRuntime.setUnrealReady(true)
                NotificationCenter.default.post(name: .felUnrealViewportSceneRendered, object: nil)
            }
        }
        .alert("Arena Load Timeout", isPresented: $showReloadAlert) {
            if !pixelStreamingFallbackURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Pixel Streaming (Web)") {
                    showPixelStreamingWebFallback = true
                }
            }
            Button("OK", role: .cancel) {
                if !welcomeElijahComplete {
                    welcomeElijahComplete = true
                }
            }
        } message: {
            Text("Unreal did not post FELUnrealLevelLoaded within 5s after starting arena — check bridge / map load. Optional: open Pixel Streaming URL from Settings & sync.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .felCoachPerformanceSnapshot)) { note in
            if let json = note.userInfo?["json"] as? String {
                FELCoachPerformanceSnapshot.cacheFromNotification(json)
            }
            refreshCoachFatigueBanner()
        }
        .onReceive(NotificationCenter.default.publisher(for: .felUniversalSyncExport)) { note in
            if let b64 = note.userInfo?["base64"] as? String {
                FELUniversalSyncBridge.cacheFromNotification(b64)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felHeroMomentExportReady)) { note in
            heroClipOffered = true
            lastHeroClipApexInches = note.userInfo?["estimatedApexInches"] as? Double
            heroClipStatusMessage = nil
            if let inches = lastHeroClipApexInches, inches >= 40.0 {
                Task { @MainActor in
                    if let rank = await PRQManager.shared.syncTopPerformance() {
                        viewModel.globalLeaderboard.sovereignWorldRank = rank
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .felUnrealReadinessHandshakeRequested)) { _ in
            unrealRuntime.setUnrealReady(false)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(90))
                unrealRuntime.setUnrealReady(true)
            }
        }
#if FEL_NON_SHIPPING
        .onReceive(NotificationCenter.default.publisher(for: felReadinessTwinScalesUpdatedNotification)) { _ in
            refreshTwinScaleDebugLine()
        }
        .onReceive(NotificationCenter.default.publisher(for: felReadinessExportDidUpdateNotification)) { _ in
            refreshTwinScaleDebugLine()
        }
        .onReceive(NotificationCenter.default.publisher(for: .felInputLatencyJumpMsSample)) { note in
            if let ms = note.userInfo?["latencyMs"] as? Double {
                UserDefaults.standard.set(ms, forKey: FELInputLatencyCalibration.userDefaultsKey)
                refreshInputLatencyHudState()
            }
        }
        .onReceive(Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()) { _ in
            refreshInputLatencyHudState()
            if inputLatencyWarningActive {
                inputLatencyFlashPhase.toggle()
            }
        }
#endif
    }

    private func downloadHeroClipTapped() {
        guard !heroClipRecording else { return }
        heroClipRecording = true
        heroClipStatusMessage = nil
        FELHeroClipRecorder.recordAndSaveToPhotos { result in
            heroClipRecording = false
            switch result {
            case .success:
                heroClipStatusMessage = "Saved to Photos"
                heroClipOffered = false
            case .failure(let error):
                heroClipStatusMessage = error.localizedDescription
            }
        }
    }

    private func refreshCoachFatigueBanner() {
        showFatigueSystemScanBanner = FELCoachPerformanceSnapshot.isFatigueDetected
    }

    /// Neuro-Mechanic: average luma from live `sampleBuffer` — gates `readiness_snapshot.json` when too dark for forensic scan.
    private func performLuminanceCheck() {
        let threshold: Float = 0.3
        guard let lum = arenaLuminanceMonitor.lastNormalizedBrightness else {
            return
        }
        let wasSuboptimal = UserDefaults.standard.object(forKey: PRQManager.neuroMechanicLightingOptimalKey) as? Bool == false
        if lum < threshold {
            UserDefaults.standard.set(false, forKey: PRQManager.neuroMechanicLightingOptimalKey)
        } else {
            UserDefaults.standard.set(true, forKey: PRQManager.neuroMechanicLightingOptimalKey)
            if wasSuboptimal {
                PRQManager.shared.sync(from: viewModel)
            }
        }
        let prevBridged = lastBridgedAmbientLuma
        lastBridgedAmbientLuma = lum
        if unrealRuntime.bIsUnrealReady {
            FELUnrealLuminanceBridge.notifyEmbeddedUnrealAmbientChanged(luma: lum, previous: prevBridged)
        }
    }

    private func beginArenaUnrealHandshake() {
        viewportSceneHandshakeTask?.cancel()
        unrealRuntime.setUnrealReady(false)
        startArenaLevelLoadWatchdog()
    }

    private func startArenaLevelLoadWatchdog() {
        arenaLevelLoadWatchdog?.cancel()
        arenaLevelLoadWatchdog = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            showReloadAlert = true
        }
    }

    private func cancelArenaLevelLoadWatchdog() {
        arenaLevelLoadWatchdog?.cancel()
        arenaLevelLoadWatchdog = nil
    }

    private var forensicLightingPauseOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                    )
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .orange.opacity(0.45), radius: 14)
                Text("Forensic Scan Paused: Increase Ambient Light for 1.0.0 Accuracy.")
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
            }
            .padding(36)
        }
    }

#if FEL_NON_SHIPPING
    private var readinessTwinScaleDebugOverlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEURO-MECHANIC · CALIBRATION (non-shipping)")
                        .font(.system(size: 10, weight: .bold, design: .default))
                        .foregroundStyle(Color.white)
                        .tracking(0.6)
                    Text(twinScaleDebugLine)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.35, green: 1.0, blue: 0.55))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 8) {
                        Text("Input→launch")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Text(lastInputLatencyMsDisplay)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(inputLatencyWarningActive ? Color.red : Color.white)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                )
                if inputLatencyWarningActive {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.red)
                        .shadow(color: .red.opacity(inputLatencyFlashPhase ? 0.95 : 0.25), radius: inputLatencyFlashPhase ? 12 : 4)
                        .opacity(inputLatencyFlashPhase ? 1 : 0.45)
                        .animation(.easeInOut(duration: 0.28), value: inputLatencyFlashPhase)
                        .accessibilityLabel("Input latency exceeds one frame at 60 hertz")
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.bottom, 28)
        }
        .allowsHitTesting(false)
    }

    private func refreshTwinScaleDebugLine() {
        if let s = PRQManager.shared.lastReadinessTwinScales {
            twinScaleDebugLine = String(format: "avatarHeightScale %.4f · avatarWeightScale %.4f", s.height, s.weight)
        } else {
            twinScaleDebugLine = "avatarHeightScale — · avatarWeightScale — (sync pending)"
        }
    }

    private func refreshInputLatencyHudState() {
        let key = FELInputLatencyCalibration.userDefaultsKey
        guard UserDefaults.standard.object(forKey: key) != nil else {
            inputLatencyWarningActive = false
            lastInputLatencyMsDisplay = "— (no sample)"
            return
        }
        let ms = UserDefaults.standard.double(forKey: key)
        lastInputLatencyMsDisplay = String(format: "%.2f ms (≤%.2f target)", ms, FELInputLatencyCalibration.oneFrame60HzMs)
        inputLatencyWarningActive = ms > FELInputLatencyCalibration.oneFrame60HzMs
    }
#endif

    /// Progress advances only while `felNeuroMechanicLightingOptimal` is true (FELLuminanceAnalyzer ≥ 0.3).
    @ViewBuilder
    private var lightingCalibrationStrip: some View {
        if avatarRigLightingCalibrationComplete {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.brandCyan)
                Text("Lighting calibration complete — AvatarRigBuilder / readiness capture ready.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.brandCyan.opacity(0.35), lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Calibration Progress")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(1.5)
                    Spacer(minLength: 8)
                    Text("\(Int(min(100, lightingCalibrationProgress01 * 100)))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: lightingCalibrationProgress01, total: 1.0)
                    .tint(Theme.brandCyan)
                Text("Stay still in optimal light until complete — required for 1.0.0 AvatarRigBuilder alignment.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
            .accessibilityElement(children: .combine)
        }
    }

    private var welcomeElijahHandshakeOverlay: some View {
        VStack(spacing: 14) {
            Text("Welcome Elijah")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("SYSTEM INITIALIZING")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(3)
            ProgressView(value: welcomeHandshakeProgress, total: 1.0)
                .tint(Theme.brandCyan)
                .padding(.horizontal, 28)
            Text("Handshake tracks Unreal `setUnrealReady` — pick a mode below to load the arena.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button("Skip intro") {
                welcomeElijahComplete = true
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.brandCyan.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.brandCyan.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    /// Luma Venice Shop + universal ship onboarding (after welcome handshake).
    private var lumaVeniceFirstLaunchOverlay: some View {
        VStack(spacing: 12) {
            Text("LUMA VENICE SHOP")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(2)
            Text("System Initializing")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) {
                Label("Sovereign gear & Neuro-Flow sync when Unreal finishes loading.", systemImage: "bolt.fill")
                Label("AI Coach metrics follow `readiness_snapshot.json` — stay signed in after System Scan.", systemImage: "heart.text.square.fill")
                Label("Use Arena modes to drive `active_mode` and input overlays (golf swipe, penalty, etc.).", systemImage: "gamecontroller.fill")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            Button("Enter Arena") {
                shipFirstLaunchOnboardingComplete = true
            }
            .font(.system(size: 14, weight: .bold))
            .buttonStyle(.borderedProminent)
            .tint(Theme.brandCyan)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.brandCyan.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    /// Resolved from selected mode, local play, last export, or `UFELUnrealOverlayRuntime` handshake.
    private var resolvedArenaInputModeId: GameModeId? {
        if let m = selectedMode { return m.id }
        if let m = localPlayMode { return m.id }
        if let raw = UserDefaults.standard.string(forKey: PRQManager.lastExportedArenaModeKey) {
            return GameModeId(rawValue: raw)
        }
        return nil
    }

    private var resolvedArenaInputScheme: InputScheme {
        if let m = selectedMode { return m.id.inputScheme }
        if let m = localPlayMode { return m.id.inputScheme }
        if let raw = UserDefaults.standard.string(forKey: PRQManager.lastExportedArenaModeKey),
           let id = GameModeId(rawValue: raw) {
            return id.inputScheme
        }
        return unrealRuntime.activeHandshakeInputScheme ?? .charge
    }

    @ViewBuilder
    private var arenaInputSchemeOverlay: some View {
        switch resolvedArenaInputScheme {
        case .swipeGolf:
            FELArenaSwipeGolfInputOverlay()
        case .penaltyKick:
            FELArenaPenaltyKickInputOverlay()
        default:
            EmptyView()
        }
    }

    private var activeAthleteCoachTag: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.brandBlue)
            Text("Active Athlete: \(viewModel.profile.displayName)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.brandBlue.opacity(0.35), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }

    private var demoModeCoachRibbon: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.tv.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.brandCyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("Demo Mode")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                Text("System Scan → Fast-Track uses cached AvatarRig.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.brandCyan.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.brandCyan.opacity(0.35), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("ARENAS")
                    .font(.system(size: 28, weight: .black))
                    .italic()
                    .tracking(2)
                    .foregroundStyle(.white)
                if viewModel.globalLeaderboard.sovereignWorldRank > 0 {
                    Text("#\(viewModel.globalLeaderboard.sovereignWorldRank) Global")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.brandCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                Spacer(minLength: 8)
                Button {
                    FELCoachPerformanceSnapshot.copyToPasteboardForShare()
                } label: {
                    Label("Share Performance", systemImage: "square.on.square")
                        .font(.system(size: 12, weight: .bold))
                        .labelStyle(.titleAndIcon)
                }
                .tint(Theme.brandCyan)
                .buttonStyle(.bordered)
                .accessibilityLabel("Share Performance JSON to clipboard")
            }
            Text("Choose a venue, then a mode. Get Ready → Play → Result.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    activeAthleteCoachTag
                    if felDemoModeShowcase { demoModeCoachRibbon }
                }
                VStack(alignment: .leading, spacing: 10) {
                    activeAthleteCoachTag
                    if felDemoModeShowcase { demoModeCoachRibbon }
                }
            }
            if heroClipOffered {
                VStack(alignment: .leading, spacing: 6) {
                    if let inches = lastHeroClipApexInches {
                        Text(String(format: "Bonds Apex estimate: %.1f\"+ (hero window)", inches))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan.opacity(0.95))
                    }
                    Button {
                        downloadHeroClipTapped()
                    } label: {
                        Label {
                            Text(heroClipRecording ? "Recording…" : "Download Hero Clip")
                                .font(.system(size: 13, weight: .bold))
                        } icon: {
                            Image(systemName: heroClipRecording ? "record.circle" : "arrow.down.circle.fill")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandCyan)
                    .disabled(heroClipRecording)
                    .accessibilityHint("Records the next three and a half seconds with ReplayKit and saves to Photos.")
                    if let heroClipStatusMessage {
                        Text(heroClipStatusMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(heroClipStatusMessage.contains("Saved") ? Theme.brandCyan : Color.orange)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.brandCyan.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            if showFatigueSystemScanBanner {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.brandCyan)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Scan")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(2)
                        Text("Fatigue detected. Suggesting recovery protocol.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                        )
                )
                .accessibilityElement(children: .combine)
            }
            lightingCalibrationStrip
            Toggle(isOn: Binding(
                get: { FELUnrealScalabilityBridge.isLowPowerMode },
                set: { FELUnrealScalabilityBridge.setLowPowerMode($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Low Power Mode")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("r.ScreenPercentage 75 — higher FPS during Bonds Apex (embedded UE host).")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.brandCyan)
            .accessibilityLabel("Low Power Mode for Unreal viewport")

            DisclosureGroup(isExpanded: $arenaSyncSettingsExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Universal Master — manual cloud sync (Firebase / iCloud). Payload is XOR + Base64 from Unreal save.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pixel Streaming fallback URL")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        TextField("https://…", text: $pixelStreamingFallbackURL)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 13, design: .monospaced))
                    }
                    Button {
                        let trimmed = pixelStreamingFallbackURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        if URL(string: trimmed) != nil, !trimmed.isEmpty {
                            showPixelStreamingWebFallback = true
                        }
                    } label: {
                        Label("Open Pixel Streaming", systemImage: "globe")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.brandCyan)
                    .disabled(pixelStreamingFallbackURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button {
                        FELUniversalSyncBridge.syncToCloudConsoleAndClipboard()
                    } label: {
                        Label("Sync to Cloud", systemImage: "icloud.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandCyan)
                    .accessibilityLabel("Sync to Cloud: copy Base64 payload to clipboard and print to console")
                }
                .padding(.top, 6)
            } label: {
                Label("Settings & sync", systemImage: "gearshape.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .tint(Theme.brandCyan)
        }
        .padding(.top, 8)
    }

    private var localPlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.brandCyan)
                Text("Local Play")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
            }
            Text("Play with someone on the same Wi‑Fi.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Button {
                showLocalPlayLobby = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wifi")
                    Text("Host or Join Game")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.brandCyan)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Local Play: Host or Join Game")
            .accessibilityHint("Opens lobby to play with a nearby device on same Wi‑Fi")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func venueSection(_ venue: GameModeRegistry.ArenaVenue) -> some View {
        let modes = GameModeRegistry.modes(for: venue)
        if !modes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                venueHeaderCard(venue)
                VStack(spacing: 10) {
                    ForEach(modes, id: \.id.id) { mode in
                        modeRow(mode: mode, venueAccent: venue.accentColor)
                    }
                }
            }
        }
    }

    private func venueHeaderCard(_ venue: GameModeRegistry.ArenaVenue) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [venue.accentColor.opacity(0.35), venue.accentColor.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(venue.accentColor.opacity(0.4), lineWidth: 1)
                    )
                Image(systemName: venue.iconName)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(venue.accentColor)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(venue.name)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Text(venue.tagline)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(venue.accentColor.opacity(0.95))
                Text(venue.atmosphere)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(venue.accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func modeRow(mode: GameMode, venueAccent: Color) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mode.accentColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: mode.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(mode.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(mode.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(mode.id.inspirationTag)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(mode.accentColor.opacity(0.9))
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(mode.accentColor.opacity(0.9))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(mode.accentColor.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Arena Dunk → Lab interstitial (solo only)

private struct ArenaDunkInterstitialView: View {
    var accentColor: Color
    let onOpenLab: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [accentColor.opacity(0.2), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 28) {
                Text("DUNK CONTEST")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(accentColor)
                Text("The 3D dunk court lives in Lab. Open Lab to sprint, launch, and stick the landing.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    onOpenLab()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sportscourt.fill")
                        Text("OPEN LAB")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
                Button("Back to Arena") {
                    onExit()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                onExit()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(20)
            }
            .accessibilityLabel("Exit")
        }
    }
}

// MARK: - Solo multi-round soccer / golf (mini-games respect `environmentRoundCount`)

private struct SoloSoccerArenaRoundsView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let onExit: () -> Void
    let onMatchEnd: (Int, Int, Int, Double, [(Int, Int)]) -> Void

    @State private var round: Int = 1
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var roundScores: [(Int, Int)] = []

    private var totalRounds: Int { mode.id.environmentRoundCount }

    var body: some View {
        ZStack {
            PenaltyStadiumArenaBackground(accentColor: mode.accentColor)
            VStack(spacing: 12) {
                Text("PENALTY \(round) OF \(totalRounds)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(mode.accentColor)
                PenaltyKickView(
                    mode: mode,
                    onExit: onExit,
                    onShotResolved: { quality, wasGoal in
                        resolveRound(shotQuality: quality, wasGoal: wasGoal)
                    }
                )
                .id(round)
            }
        }
    }

    private func resolveRound(shotQuality: Double, wasGoal: Bool) {
        let adjusted = max(0.62, min(0.9, shotQuality))
        let prq = viewModel.effectiveMetrics.prqScore
        let baseChance = PRQ.successChanceFromPRQ(prq, for: mode.id)
        let skillFactor = 0.28 + 0.72 * adjusted
        var chance = min(0.94, baseChance * skillFactor + (1 - skillFactor) * 0.15)
        if !wasGoal {
            chance *= 0.4
        }
        let p1WinsRound = Double.random(in: 0..<1) < chance
        let p1r = p1WinsRound ? 1 : 0
        let p2r = 1 - p1r
        roundScores.append((p1r, p2r))
        playerScore += p1r
        opponentScore += p2r
        if round >= totalRounds {
            finishMatch()
        } else {
            round += 1
        }
    }

    private func finishMatch() {
        let won = playerScore > opponentScore
        let tied = playerScore == opponentScore
        let diff = playerScore - opponentScore
        let gain = PRQ.modeReward(mode: mode.id, won: won, tied: tied, combo: 0, criticals: 0, scoreDifferential: diff)
        let baseShards = 6 + totalRounds * 2
        let shards = max(8, min(40, baseShards + (playerScore * 3) + (won ? 12 : 0) + (diff > 0 ? diff * 2 : 0)))
        onMatchEnd(playerScore, opponentScore, shards, gain, roundScores)
    }
}

private struct SoloGolfArenaRoundsView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let onExit: () -> Void
    let onMatchEnd: (Int, Int, Int, Double, [(Int, Int)]) -> Void

    @State private var round: Int = 1
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var roundScores: [(Int, Int)] = []

    private var totalRounds: Int { mode.id.environmentRoundCount }

    var body: some View {
        ZStack {
            GolfLinksArenaBackground(accentColor: mode.accentColor)
            VStack(spacing: 12) {
                Text("HOLE \(round) OF \(totalRounds)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(mode.accentColor)
                GolfSwingView(
                    mode: mode,
                    onExit: onExit,
                    onSwingResolved: { quality in
                        resolveRound(shotQuality: quality)
                    }
                )
                .id(round)
            }
        }
    }

    private func resolveRound(shotQuality: Double) {
        let adjusted = max(0.62, min(0.9, shotQuality))
        let prq = viewModel.effectiveMetrics.prqScore
        let baseChance = PRQ.successChanceFromPRQ(prq, for: mode.id)
        let skillFactor = 0.28 + 0.72 * adjusted
        let chance = min(0.94, baseChance * skillFactor + (1 - skillFactor) * 0.15)
        let p1Wins = Double.random(in: 0..<1) < chance
        let p1r = p1Wins ? 1 : 0
        let p2r = 1 - p1r
        roundScores.append((p1r, p2r))
        playerScore += p1r
        opponentScore += p2r
        if round >= totalRounds {
            finishMatch()
        } else {
            round += 1
        }
    }

    private func finishMatch() {
        let won = playerScore > opponentScore
        let tied = playerScore == opponentScore
        let diff = playerScore - opponentScore
        let gain = PRQ.modeReward(mode: mode.id, won: won, tied: tied, combo: 0, criticals: 0, scoreDifferential: diff)
        let baseShards = 6 + totalRounds * 2
        let shards = max(8, min(40, baseShards + (playerScore * 3) + (won ? 12 : 0) + (diff > 0 ? diff * 2 : 0)))
        onMatchEnd(playerScore, opponentScore, shards, gain, roundScores)
    }
}

// MARK: - Arena Game Flow (Get Ready → Play → Result)

private enum ArenaFlowPhase {
    case getReady
    case playing
    case result
}

private struct ArenaGameFlowView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let multipeer: MultipeerService?
    let isLocalHost: Bool
    let onDismiss: () -> Void
    /// When provided, Dunk Contest (solo) shows "Open Lab" interstitial and this opens Lab + dunk flow.
    var onOpenLab: (() -> Void)? = nil

    @EnvironmentObject private var unrealRuntime: UFELUnrealOverlayRuntime

    @State private var phase: ArenaFlowPhase = .getReady
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var shardsEarned: Int = 0
    @State private var prqGain: Double = 0
    @State private var gameResult: GameSessionResult?
    @State private var roundBreakdown: [(Int, Int)]? = nil

    private var prqCurrent: Double { viewModel.effectiveMetrics.prqScore }
    private var isLocalPlay: Bool { multipeer != nil }

    var body: some View {
        ZStack {
            Group {
            switch phase {
            case .getReady:
                GetReadyScreen(
                    title: isLocalPlay ? "\(mode.name) · Local" : mode.name,
                    subtitle: mode.id.getReadySubtitle,
                    inspirationTag: mode.id.inspirationTag,
                    accentColor: mode.accentColor,
                    onComplete: {
                        withAnimation(.easeInOut(duration: 0.35)) { phase = .playing }
                    }
                )
                .overlay(alignment: .topLeading) {
                    exitButton
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .playing:
                Group {
                    if !unrealRuntime.bIsUnrealReady {
                        Group {
                    if mode.id == .basketballDunkContest && multipeer == nil {
                        ArenaDunkPlayView(
                            mode: mode,
                            viewModel: viewModel,
                            onExit: onDismiss,
                            onGameEnd: { p1, p2, shards, prq in
                                playerScore = p1
                                opponentScore = p2
                                shardsEarned = shards
                                prqGain = prq
                                roundBreakdown = nil
                                let result = GameSessionResult(
                                    id: UUID().uuidString,
                                    gameModeId: mode.id.rawValue,
                                    date: Date(),
                                    score: p1,
                                    opponentScore: p2,
                                    shardsEarned: shards,
                                    prqBonus: prq,
                                    isMultiplayer: false,
                                    duration: 0,
                                    roundsPlayed: mode.id.environmentRoundCount
                                )
                                SaveSystem.saveGameResult(result)
                                viewModel.gameResults.append(result)
                                viewModel.profile.evolutionShards += shards
                                SaveSystem.saveProfile(viewModel.profile)
                                gameResult = result
                                withAnimation(.easeInOut(duration: 0.4)) { phase = .result }
                            }
                        )
                    } else if mode.id == .brainBrawl && multipeer == nil {
                        BrainBrawlPlayView(
                            mode: mode,
                            viewModel: viewModel,
                            multipeer: nil,
                            isLocalHost: false,
                            onExit: onDismiss,
                            onGameEnd: { p1, p2, shards, prq in
                                playerScore = p1
                                opponentScore = p2
                                shardsEarned = shards
                                prqGain = prq
                                roundBreakdown = nil
                                let result = GameSessionResult(
                                    id: UUID().uuidString,
                                    gameModeId: mode.id.rawValue,
                                    date: Date(),
                                    score: p1,
                                    opponentScore: p2,
                                    shardsEarned: shards,
                                    prqBonus: prq,
                                    isMultiplayer: false,
                                    duration: 0,
                                    roundsPlayed: mode.id.environmentRoundCount
                                )
                                SaveSystem.saveGameResult(result)
                                viewModel.gameResults.append(result)
                                viewModel.profile.evolutionShards += shards
                                SaveSystem.saveProfile(viewModel.profile)
                                gameResult = result
                                withAnimation(.easeInOut(duration: 0.4)) { phase = .result }
                            }
                        )
                    } else if mode.id == .soccer && multipeer == nil {
                        SoloSoccerArenaRoundsView(
                            mode: mode,
                            viewModel: viewModel,
                            onExit: onDismiss,
                            onMatchEnd: { p1, p2, shards, prq, rounds in
                                playerScore = p1
                                opponentScore = p2
                                shardsEarned = shards
                                prqGain = prq
                                roundBreakdown = rounds
                                let result = GameSessionResult(
                                    id: UUID().uuidString,
                                    gameModeId: mode.id.rawValue,
                                    date: Date(),
                                    score: p1,
                                    opponentScore: p2,
                                    shardsEarned: shards,
                                    prqBonus: prq,
                                    isMultiplayer: false,
                                    duration: 0,
                                    roundsPlayed: mode.id.environmentRoundCount
                                )
                                SaveSystem.saveGameResult(result)
                                viewModel.gameResults.append(result)
                                viewModel.profile.evolutionShards += shards
                                SaveSystem.saveProfile(viewModel.profile)
                                gameResult = result
                                withAnimation(.easeInOut(duration: 0.4)) { phase = .result }
                            }
                        )
                    } else if mode.id == .golf && multipeer == nil {
                        SoloGolfArenaRoundsView(
                            mode: mode,
                            viewModel: viewModel,
                            onExit: onDismiss,
                            onMatchEnd: { p1, p2, shards, prq, rounds in
                                playerScore = p1
                                opponentScore = p2
                                shardsEarned = shards
                                prqGain = prq
                                roundBreakdown = rounds
                                let result = GameSessionResult(
                                    id: UUID().uuidString,
                                    gameModeId: mode.id.rawValue,
                                    date: Date(),
                                    score: p1,
                                    opponentScore: p2,
                                    shardsEarned: shards,
                                    prqBonus: prq,
                                    isMultiplayer: false,
                                    duration: 0,
                                    roundsPlayed: mode.id.environmentRoundCount
                                )
                                SaveSystem.saveGameResult(result)
                                viewModel.gameResults.append(result)
                                viewModel.profile.evolutionShards += shards
                                SaveSystem.saveProfile(viewModel.profile)
                                gameResult = result
                                withAnimation(.easeInOut(duration: 0.4)) { phase = .result }
                            }
                        )
                    } else {
                        GenericArenaPlayView(
                            mode: mode,
                            viewModel: viewModel,
                            multipeer: multipeer,
                            isLocalHost: isLocalHost,
                            onExit: onDismiss,
                            onGameEnd: { p1, p2, shards, prq, rounds in
                                playerScore = p1
                                opponentScore = p2
                                shardsEarned = shards
                                prqGain = prq
                                roundBreakdown = rounds
                                let result = GameSessionResult(
                                    id: UUID().uuidString,
                                    gameModeId: mode.id.rawValue,
                                    date: Date(),
                                    score: p1,
                                    opponentScore: p2,
                                    shardsEarned: shards,
                                    prqBonus: prq,
                                    isMultiplayer: isLocalPlay,
                                    duration: 0,
                                    roundsPlayed: mode.id.environmentRoundCount
                                )
                                SaveSystem.saveGameResult(result)
                                viewModel.gameResults.append(result)
                                viewModel.profile.evolutionShards += shards
                                SaveSystem.saveProfile(viewModel.profile)
                                gameResult = result
                                withAnimation(.easeInOut(duration: 0.4)) { phase = .result }
                            }
                        )
                    }
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .result:
                ResultScreen(
                    winner: playerScore > opponentScore ? .p1 : (playerScore < opponentScore ? .p2 : .draw),
                    p1Score: playerScore,
                    p2Score: opponentScore,
                    title: mode.name,
                    accentColor: mode.accentColor,
                    shardsEarned: shardsEarned,
                    prqGain: prqGain,
                    prqCurrent: prqCurrent + prqGain,
                    modeAttributeLabel: PRQ.attributeLabel(for: mode.id),
                    modeAttributeValue: PRQ.attributeValue(prq: prqCurrent + prqGain, for: mode.id),
                    roundBreakdown: roundBreakdown,
                    vaultShardTotal: viewModel.profile.evolutionShards,
                    returnButtonTitle: "BACK TO ARENA",
                    onReturn: onDismiss
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            }
            if phase == .playing {
                UFELUnrealViewportContainer()
            }
        }
        .animation(.easeInOut(duration: 0.32), value: phase)
        .statusBarHidden(phase != .result)
        .onDisappear {
            FELHeroClipRecorder.stopBuffering()
            DispatchQueue.main.async {
                unrealRuntime.setUnrealReady(false)
            }
        }
    }

    private var exitButton: some View {
        Button {
            onDismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.6))
                .padding(20)
        }
        .accessibilityLabel("Exit game")
    }
}

// MARK: - Generic Play: tap to commit, no timing bar. Outcome from PRQ (quality 0.62–0.90). Creator vision: PROJECT_FLOWS.
// Arena = gradient + UI only. Lab dunk = RealityKitDunkView.

private struct GenericArenaPlayView: View {
    let mode: GameMode
    let viewModel: LabViewModel
    let multipeer: MultipeerService?
    let isLocalHost: Bool
    let onExit: () -> Void
    let onGameEnd: (Int, Int, Int, Double, [(Int, Int)]?) -> Void

    @EnvironmentObject private var unrealRuntime: UFELUnrealOverlayRuntime

    private var totalRounds: Int { mode.id.environmentRoundCount }
    private var isLocalPlay: Bool { multipeer != nil }
    private var iAmP1: Bool { isLocalHost }

    @State private var round: Int = 1
    @State private var playerScore: Int = 0
    @State private var opponentScore: Int = 0
    @State private var roundResult: (p1: Int, p2: Int)?
    @State private var showingRoundResult: Bool = false
    @State private var actionButtonPressed: Bool = false
    @State private var commitFeedback: String? = nil
    @State private var commitFeedbackScale: CGFloat = 1.0
    @State private var roundScores: [(Int, Int)] = []
    @State private var showTutorialOverlay: Bool = false
    @State private var showConnectionLostAlert: Bool = false
    @State private var hadPeerConnection: Bool = false
    @State private var ignoreMultipeerAfterDisconnect: Bool = false

    /// Head to Head only: contest phase after commit. NBA Street style.
    @State private var showContestWindow: Bool = false
    @State private var contestDecided: Bool? = nil // nil = waiting, true = contested, false = clean
    @State private var committedQualityForContest: Double? = nil
    @State private var contestTask: Task<Void, Never>?
    /// Head to Head local: P2 can tap Contest within 0.8s after P1's score is received.
    @State private var showP2ContestWindow: Bool = false
    @State private var didContestThisRound: Bool = false
    @State private var p2ContestWindowTask: Task<Void, Never>?

    /// Karate only: block phase after strike. Storm × Matrix style.
    @State private var showBlockWindow: Bool = false
    @State private var blockDecided: Bool? = nil
    @State private var committedQualityForBlock: Double? = nil
    @State private var blockTask: Task<Void, Never>?
    @State private var showP2BlockWindow: Bool = false
    @State private var didBlockThisRound: Bool = false
    @State private var p2BlockWindowTask: Task<Void, Never>?

    /// Baseball only: "Pitch..." then contact. Wii Sports derby feel.
    @State private var showPitchPhase: Bool = false
    @State private var committedQualityForPitch: Double? = nil
    @State private var pitchTask: Task<Void, Never>?

    @State private var myTimingThisRound: Int? = nil
    @State private var opponentTimingThisRound: Int? = nil
    @State private var waitingForOpponent: Bool = false

    /// Phase A: burst overlay when commit is perfect (scale + fade).
    @State private var perfectBurstProgress: CGFloat = 1

    private var roundLabel: String { mode.id.environmentRoundLabel }
    private var actionTitle: String { mode.id.environmentActionTitle }
    private var oppLabel: String { mode.id.opponentDisplayName }

    private var baseballSwingOutcome: BaseballDerbyCanvasView.SwingOutcome? {
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .homeRun }
        if f == mode.id.commitFeedbackGood { return .contact }
        return .out
    }

    private var footballReturnOutcome: KickReturnCanvasView.ReturnOutcome? {
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .touchdown }
        if f == mode.id.commitFeedbackGood { return .yards }
        return .stopped
    }

    private var tennisRallyOutcome: RallyAceCanvasView.RallyOutcome? {
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .ace }
        if f == mode.id.commitFeedbackGood { return .inCourt }
        return .outWide
    }

    private var volleyballSpikeOutcome: BeachVolleyballRallyCanvasView.SpikeOutcome? {
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .kill }
        if f == mode.id.commitFeedbackGood { return .point }
        return .blocked
    }

    private var gymnasticsRoutineOutcome: GymnasticsFloorRoutineCanvasView.RoutineOutcome? {
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .stuck }
        if f == mode.id.commitFeedbackGood { return .landed }
        return .deduct
    }

    private var hoopsShotOutcome: VeniceCourtCanvasView.ShotOutcome? {
        guard mode.id == .basketballHeadToHead || mode.id == .basketball3v3 else { return nil }
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .bucket }
        if f == mode.id.commitFeedbackGood { return .good }
        return .miss
    }

    private var soccerPenaltyOutcome: PenaltySpotCanvasView.PenaltyOutcome? {
        guard mode.id == .soccer else { return nil }
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .goal }
        if f == mode.id.commitFeedbackGood { return .onTarget }
        return .saved
    }

    private var golfHoleOutcome: ClosestToPinCanvasView.HoleOutcome? {
        guard mode.id == .golf else { return nil }
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .tapIn }
        if f == mode.id.commitFeedbackGood { return .onGreen }
        return .wide
    }

    private var brainBrawlDuelOutcome: BrainBrawlDuelCanvasView.DuelOutcome? {
        guard mode.id == .brainBrawl else { return nil }
        guard let f = commitFeedback else { return nil }
        if f == mode.id.commitFeedbackPerfect { return .correct }
        if f == mode.id.commitFeedbackGood { return .partial }
        return .wrong
    }

    var body: some View {
        ZStack {
            if !unrealRuntime.bIsUnrealReady {
                environmentGradient
            }
            VStack(spacing: 24) {
                environmentHeader
                roundIndicator
                scoreRow
                Spacer()
                if showContestWindow, (mode.id == .basketballHeadToHead || mode.id == .basketball3v3) {
                    contestPhaseView
                } else if showBlockWindow, mode.id == .karate {
                    blockPhaseView
                } else if mode.id == .baseball {
                    ZStack {
                        BaseballDerbyCanvasView(
                            accentColor: mode.accentColor,
                            showPitchPhase: showPitchPhase,
                            swingOutcome: baseballSwingOutcome
                        )
                        VStack(spacing: 12) {
                            if showPitchPhase {
                                Text("Pitch…")
                                    .font(.system(size: 18, weight: .black, design: .monospaced))
                                    .foregroundStyle(mode.accentColor)
                                    .accessibilityLabel("Pitch incoming")
                                    .accessibilityHint("Swing result will show after the pitch.")
                            } else if let feedback = commitFeedback {
                                Text(feedback)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                                    .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                    .scaleEffect(commitFeedbackScale)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                    .accessibilityLabel("Round result: \(feedback)")
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            Spacer()
                        }
                        .frame(height: 248)
                    }
                    controllerHintSection
                } else if mode.id == .football {
                    ZStack {
                        KickReturnCanvasView(
                            accentColor: mode.accentColor,
                            outcome: footballReturnOutcome
                        )
                        VStack(spacing: 12) {
                            if let feedback = commitFeedback {
                                Text(feedback)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                                    .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                    .scaleEffect(commitFeedbackScale)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                    .accessibilityLabel("Round result: \(feedback)")
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            Spacer()
                        }
                        .frame(height: 248)
                    }
                    controllerHintSection
                } else if mode.id == .tennis {
                    ZStack {
                        RallyAceCanvasView(
                            accentColor: mode.accentColor,
                            outcome: tennisRallyOutcome
                        )
                        VStack(spacing: 12) {
                            if let feedback = commitFeedback {
                                Text(feedback)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                                    .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                    .scaleEffect(commitFeedbackScale)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                    .accessibilityLabel("Round result: \(feedback)")
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            Spacer()
                        }
                        .frame(height: 248)
                    }
                    controllerHintSection
                } else if mode.id == .volleyball {
                    ZStack {
                        BeachVolleyballRallyCanvasView(
                            accentColor: mode.accentColor,
                            outcome: volleyballSpikeOutcome
                        )
                        VStack(spacing: 12) {
                            if let feedback = commitFeedback {
                                Text(feedback)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                                    .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                    .scaleEffect(commitFeedbackScale)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                    .accessibilityLabel("Round result: \(feedback)")
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            Spacer()
                        }
                        .frame(height: 248)
                    }
                    controllerHintSection
                } else if mode.id == .gymnastics {
                    ZStack {
                        GymnasticsFloorRoutineCanvasView(
                            accentColor: mode.accentColor,
                            outcome: gymnasticsRoutineOutcome
                        )
                        VStack(spacing: 12) {
                            if let feedback = commitFeedback {
                                Text(feedback)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                                    .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                    .scaleEffect(commitFeedbackScale)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                    .accessibilityLabel("Round result: \(feedback)")
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            Spacer()
                        }
                        .frame(height: 248)
                    }
                    controllerHintSection
                } else if mode.id == .basketballHeadToHead || mode.id == .basketball3v3 {
                    ZStack {
                        VeniceCourtCanvasView(
                            accentColor: mode.accentColor,
                            showContestWindow: showContestWindow,
                            contestDecided: contestDecided,
                            shotOutcome: hoopsShotOutcome
                        )
                        VStack(spacing: 12) {
                            if let feedback = commitFeedback {
                                Text(feedback)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                                    .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                    .scaleEffect(commitFeedbackScale)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                    .accessibilityLabel("Round result: \(feedback)")
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            Spacer()
                        }
                        .frame(height: 248)
                    }
                    controllerHintSection
                } else if mode.id == .soccer {
                    ZStack {
                        PenaltySpotCanvasView(
                            accentColor: mode.accentColor,
                            outcome: soccerPenaltyOutcome
                        )
                        VStack(spacing: 12) {
                            if let feedback = commitFeedback {
                                Text(feedback)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                                    .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                    .scaleEffect(commitFeedbackScale)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                    .accessibilityLabel("Round result: \(feedback)")
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            Spacer()
                        }
                        .frame(height: 248)
                    }
                    controllerHintSection
                } else if mode.id == .golf {
                    ZStack {
                        ClosestToPinCanvasView(
                            accentColor: mode.accentColor,
                            outcome: golfHoleOutcome
                        )
                        VStack(spacing: 12) {
                            if let feedback = commitFeedback {
                                Text(feedback)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                                    .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                    .scaleEffect(commitFeedbackScale)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                    .accessibilityLabel("Round result: \(feedback)")
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            Spacer()
                        }
                        .frame(height: 248)
                    }
                    controllerHintSection
                } else if mode.id == .brainBrawl {
                    VStack(spacing: 12) {
                        BrainBrawlDuelCanvasView(
                            accentColor: mode.accentColor,
                            outcome: brainBrawlDuelOutcome,
                            opponentLabel: oppLabel
                        )
                        if isLocalPlay && waitingForOpponent {
                            Text("Waiting for \(oppLabel)...")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Waiting for \(oppLabel)")
                                .accessibilityHint("Other player is committing their round")
                        } else if let feedback = commitFeedback {
                            Text(feedback)
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .red.opacity(0.95)))
                                .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                                .scaleEffect(commitFeedbackScale)
                                .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                                .accessibilityLabel("Round result: \(feedback)")
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(height: 248)
                    controllerHintSection
                } else if let feedback = commitFeedback {
                    Text(feedback)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : (feedback == mode.id.commitFeedbackGood ? Color.orange : .secondary))
                        .shadow(color: (feedback == mode.id.commitFeedbackPerfect ? mode.accentColor : .clear).opacity(0.5), radius: 8)
                        .scaleEffect(commitFeedbackScale)
                        .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                        .accessibilityLabel("Round result: \(feedback)")
                        .accessibilityAddTraits(.updatesFrequently)
                } else if isLocalPlay && waitingForOpponent {
                    Text("Waiting for \(oppLabel)...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Waiting for \(oppLabel)")
                        .accessibilityHint("Other player is committing their round")
                } else {
                    if mode.id == .karate {
                        KarateCanvasView(
                            accentColor: mode.accentColor,
                            isStriking: commitFeedback != nil,
                            isBlocked: blockDecided == true || (commitFeedback == mode.id.commitFeedbackMiss),
                            blockPhaseActive: showBlockWindow
                        )
                        controllerHintSection
                    } else {
                        controllerHintSection
                    }
                }
                if (mode.id == .basketballHeadToHead || mode.id == .basketball3v3), isLocalPlay, !iAmP1, showP2ContestWindow {
                    Button {
                        guard !didContestThisRound, let mp = multipeer else { return }
                        mp.send("CONTEST|\(round)")
                        didContestThisRound = true
                        showP2ContestWindow = false
                        p2ContestWindowTask?.cancel()
                        #if !targetEnvironment(simulator)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    } label: {
                        Text("Contest!")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().stroke(Color.orange, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(didContestThisRound)
                    .accessibilityLabel("Contest P1's shot")
                    .accessibilityHint("Reduces P1's shot quality for this round")
                }
                if mode.id == .karate, isLocalPlay, !iAmP1, showP2BlockWindow {
                    Button {
                        guard !didBlockThisRound, let mp = multipeer else { return }
                        mp.send("BLOCK|\(round)")
                        didBlockThisRound = true
                        showP2BlockWindow = false
                        p2BlockWindowTask?.cancel()
                        #if !targetEnvironment(simulator)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                    } label: {
                        Text("Block!")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().stroke(Color.red, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(didBlockThisRound)
                    .accessibilityLabel("Block P1's strike")
                    .accessibilityHint("Reduces P1's strike quality for this bout")
                }
                if !ControllerDiscoveryService.shared.hasPhysicalController {
                    Text("Tap the button below or use ✕ on the overlay")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(mode.accentColor.opacity(0.7))
                        .tracking(0.5)
                        .padding(.bottom, 4)
                }
                actionButton
            }
            .animation(.easeInOut(duration: 0.25), value: commitFeedback != nil)
            .padding(.bottom, 8)
            if ControllerDiscoveryService.shared.hasPhysicalController {
                controllerConnectedPill
            } else {
                PS2GamepadOverlay(
                    onFaceButton: handleArenaFaceButton(_:),
                    onDPad: { _ in },
                    onLeftStick: { _ in },
                    onRightStick: { _ in },
                    onCrossDown: canTapAction ? { commitRound() } : nil,
                    onCrossUp: nil,
                    accentColor: mode.accentColor,
                    isActive: canTapAction,
                    mobileOptimized: true
                )
                .allowsHitTesting(canTapAction)
            }
        }
        .onChange(of: multipeer?.lastReceivedMessage ?? "") { _, _ in
            guard let mp = multipeer, mp.lastReceivedRound == round else { return }
            if iAmP1 && mp.lastReceivedAction == "P2" {
                opponentTimingThisRound = mp.lastReceivedScore
                applyLocalPlayResult()
            } else if !iAmP1 && mp.lastReceivedAction == "P1" {
                opponentTimingThisRound = mp.lastReceivedScore
                if mode.id == .basketballHeadToHead || mode.id == .basketball3v3 {
                    didContestThisRound = false
                    showP2ContestWindow = true
                    p2ContestWindowTask?.cancel()
                    p2ContestWindowTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(800))
                        guard !Task.isCancelled else { return }
                        showP2ContestWindow = false
                    }
                } else if mode.id == .karate {
                    didBlockThisRound = false
                    showP2BlockWindow = true
                    p2BlockWindowTask?.cancel()
                    p2BlockWindowTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(800))
                        guard !Task.isCancelled else { return }
                        showP2BlockWindow = false
                    }
                }
            }
        }
        .alert("\(roundLabel) \(round)", isPresented: $showingRoundResult) {
            Button("Next") {
                nextRound()
            }
        } message: {
            if let r = roundResult {
                Text(alertMessage(p1: r.p1, p2: r.p2))
            }
        }
        .onDisappear { }
        .onPhysicalControllerCross(down: { if canTapAction { commitRound() } }, up: { })
        .overlay {
            if showTutorialOverlay {
                FirstTimeArenaTutorialOverlay(accentColor: mode.accentColor) {
                    showTutorialOverlay = false
                }
            }
        }
        .onAppear {
            if !FirstTimeArenaTutorialOverlay.hasSeen { showTutorialOverlay = true }
            if isLocalPlay, let mp = multipeer { hadPeerConnection = mp.isConnected }
        }
        .onChange(of: multipeer?.isConnected ?? false) { _, now in
            if isLocalPlay, hadPeerConnection, !now { showConnectionLostAlert = true }
            hadPeerConnection = now
        }
        .overlay {
            if commitFeedback == mode.id.commitFeedbackPerfect {
                perfectBurstOverlay
            }
        }
        .overlay {
            if showReadyPulse {
                readyPulseOverlay
            }
        }
        .alert("Connection lost", isPresented: $showConnectionLostAlert) {
            Button("Keep playing solo") {
                ignoreMultipeerAfterDisconnect = true
                waitingForOpponent = false
            }
            Button("Exit game", role: .destructive) { onExit() }
        } message: {
            Text("Your opponent disconnected. Keep playing vs CPU or exit to the arena.")
        }
    }

    @ViewBuilder
    private var environmentGradient: some View {
        if mode.id == .karate {
            KarateDojoArenaBackground(accentColor: mode.accentColor)
        } else if mode.id == .baseball {
            BaseballStadiumArenaBackground(accentColor: mode.accentColor)
        } else if mode.id == .football {
            FootballStadiumFieldBackground(accentColor: mode.accentColor)
        } else if mode.id == .tennis {
            BeachTennisCourtBackground(accentColor: mode.accentColor)
        } else if mode.id == .volleyball {
            BeachVolleyballArenaBackground(accentColor: mode.accentColor)
        } else if mode.id == .gymnastics {
            AcademyArenaGymnasticsBackground(accentColor: mode.accentColor)
        } else if mode.id == .basketballHeadToHead || mode.id == .basketball3v3 {
            VeniceBeachHoopsArenaBackground(accentColor: mode.accentColor)
        } else if mode.id == .soccer {
            PenaltyStadiumArenaBackground(accentColor: mode.accentColor)
        } else if mode.id == .golf {
            GolfLinksArenaBackground(accentColor: mode.accentColor)
        } else if mode.id == .brainBrawl {
            BrainBrawlAcademyBackground(accentColor: mode.accentColor)
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        mode.accentColor.opacity(0.18),
                        mode.id.environmentSecondaryColor.opacity(0.25),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
            }
        }
    }

    /// Shown when a physical controller is connected so virtual overlay is hidden (emulator-style handoff).
    private var controllerConnectedPill: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 12))
                Text(ControllerDiscoveryService.shared.controllerName ?? "Controller")
                    .font(.system(size: 11, weight: .semibold))
                Text("connected")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .padding(.bottom, 24)
        }
        .allowsHitTesting(false)
    }

    private var environmentHeader: some View {
        HStack {
            Button {
                onExit()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("EXIT")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(mode.environmentName)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(mode.accentColor)
                Text(mode.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var roundIndicator: some View {
        HStack(spacing: 6) {
            Text("\(roundLabel)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.5))
            Text("\(round)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("OF \(totalRounds)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .contentTransition(.numericText())
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: round)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(roundLabel) \(round) of \(totalRounds)")
    }

    private var scoreRow: some View {
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                Text("\(playerScore)")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: playerScore)
                Text("YOU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(mode.accentColor)
            }
            Text("\u{2014}")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.tertiary)
            VStack(spacing: 4) {
                Text("\(opponentScore)")
                    .font(.system(size: 44, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: opponentScore)
                Text(oppLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score: you \(playerScore), \(oppLabel) \(opponentScore)")
    }

    /// Head to Head only: "Contest?" then "Contested!" / "Clean look." NBA Street style.
    private var contestPhaseView: some View {
        Group {
            if let decided = contestDecided {
                Text(decided ? "Contested!" : "Clean look.")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(decided ? Color.orange : Theme.foundationGreen)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Text("Contest?")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(mode.accentColor.opacity(0.9))
            }
        }
        .animation(.easeOut(duration: 0.2), value: contestDecided)
        .accessibilityLabel(contestDecided == nil ? "Contest? Opponent may contest your shot." : (contestDecided == true ? "Contested. Shot was contested." : "Clean look. Shot was not contested."))
    }

    /// Karate only: "Block?" then "Blocked!" / "Clean hit." Storm × Matrix style.
    private var blockPhaseView: some View {
        Group {
            if let decided = blockDecided {
                Text(decided ? "Blocked!" : "Clean hit.")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(decided ? Color.red.opacity(0.95) : Theme.foundationGreen)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Text("Block?")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(mode.accentColor.opacity(0.9))
            }
        }
        .animation(.easeOut(duration: 0.2), value: blockDecided)
        .accessibilityLabel(blockDecided == nil ? "Block? Opponent may block your strike." : (blockDecided == true ? "Blocked. Strike was blocked." : "Clean hit. Strike was not blocked."))
    }

    /// No timing bar: press ✕ or tap to commit. Outcome from PRQ (creator vision).
    private var controllerHintSection: some View {
        VStack(spacing: 10) {
            Text(mode.id.environmentAtmosphere)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(mode.accentColor.opacity(0.9))
                .multilineTextAlignment(.center)
            Text("Press ✕ (Cross) or tap to \(actionTitle)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(mode.accentColor)
                .tracking(1)
            Text(mode.id.environmentDescription)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Press Cross or tap to commit. \(mode.id.environmentDescription)")
    }

    private func handleArenaFaceButton(_ button: PS2FaceButton) {
        guard button == .cross, canTapAction else { return }
        commitRound()
    }

    private var canTapAction: Bool {
        if showContestWindow || showBlockWindow || showPitchPhase { return false }
        if ignoreMultipeerAfterDisconnect { return !showingRoundResult }
        if !isLocalPlay { return !showingRoundResult }
        if waitingForOpponent { return false }
        if iAmP1 { return true }
        return opponentTimingThisRound != nil
    }

    private var actionButton: some View {
        Button {
            guard canTapAction else { return }
            withAnimation(.easeOut(duration: 0.08)) { actionButtonPressed = true }
            #if !targetEnvironment(simulator)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.1)) { actionButtonPressed = false }
                commitRound()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 18, weight: .semibold))
                Text(buttonActionTitle)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(2)
            }
            .foregroundStyle(canTapAction ? .black : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(buttonBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: mode.accentColor.opacity(0.4), radius: 12)
            .scaleEffect(actionButtonPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!canTapAction)
        .contentShape(Rectangle())
        .accessibilityLabel(actionTitle)
        .accessibilityHint(
            ControllerDiscoveryService.shared.hasPhysicalController
                ? commitPhaseHint
                : "Tap this button or use the virtual Cross button on the overlay. \(commitPhaseHint)"
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    private var buttonActionTitle: String {
        if !ignoreMultipeerAfterDisconnect && isLocalPlay && !iAmP1 && opponentTimingThisRound == nil { return "Wait for P1..." }
        return actionTitle
    }

    private var buttonBackgroundColor: Color {
        if !canTapAction { return mode.accentColor.opacity(0.5) }
        return mode.accentColor
    }

    /// True when player can commit and we're not in contest/block/pitch/waiting — show "ready" pulse.
    private var showReadyPulse: Bool {
        canTapAction && commitFeedback == nil && !showContestWindow && !showBlockWindow && !showPitchPhase && !waitingForOpponent
    }

    /// Phase A: radial burst on perfect commit for clearer feedback.
    private var perfectBurstOverlay: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [mode.accentColor.opacity(0.5), mode.accentColor.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 120
                )
            )
            .frame(width: 280, height: 280)
            .scaleEffect(0.3 + 1.7 * perfectBurstProgress)
            .opacity(0.6 * (1 - perfectBurstProgress))
            .allowsHitTesting(false)
            .onAppear {
                perfectBurstProgress = 0
                withAnimation(.easeOut(duration: 0.4)) { perfectBurstProgress = 1 }
            }
    }

    /// Phase A: subtle pulsing ring when ready to commit so the scene feels alive.
    private var readyPulseOverlay: some View {
        TimelineView(.animation(minimumInterval: 0.03)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = (1 + sin(t * 2.2)) / 2
            Circle()
                .stroke(mode.accentColor.opacity(0.15 + 0.2 * pulse), lineWidth: 2)
                .frame(width: 100, height: 100)
                .scaleEffect(0.92 + 0.12 * pulse)
        }
        .allowsHitTesting(false)
    }

    private var commitPhaseHint: String {
        if mode.id == .basketballHeadToHead || mode.id == .basketball3v3 { return "Shoot; opponent may contest. Use controller Cross or tap." }
        if mode.id == .basketballDunkContest { return "Commit your dunk for the judges. Use controller Cross or tap." }
        if mode.id == .karate { return "Strike; opponent may block. Use controller Cross or tap." }
        if mode.id == .baseball { return "Wait for the pitch, then swing. Use controller Cross or tap." }
        if mode.id == .football { return "Run the return; commit to break the tackle. Use controller Cross or tap." }
        if mode.id == .soccer { return "Shoot the penalty; keeper may save. Use controller Cross or tap." }
        if mode.id == .golf { return "Swing for the pin; closest to the pin wins the hole. Use controller Cross or tap." }
        if mode.id == .tennis { return "Serve, rally, or put the point away. Use controller Cross or tap." }
        if mode.id == .volleyball { return "Spike; opponent may block. Use controller Cross or tap." }
        if mode.id == .gymnastics { return "Execute the routine and stick the landing. Use controller Cross or tap." }
        if mode.id == .brainBrawl { return "Lock your answer; first correct wins the question. Use controller Cross or tap." }
        return "Commits the action for this round; use controller ✕ or tap"
    }

    /// Per-mode haptic for perfect commit (dunk/karate = heavy, golf/tennis = light, rest = medium).
    private func commitHapticStyleForPerfect() -> UIImpactFeedbackGenerator.FeedbackStyle {
        switch mode.id {
        case .basketballDunkContest, .karate, .gymnastics: return .heavy
        case .golf, .tennis, .volleyball: return .light
        default: return .medium
        }
    }

    /// Creator vision: no timing bar. Quality from PRQ only, in range 0.62–0.90 (PROJECT_FLOWS).
    private func qualityFromPRQ() -> Double {
        let prq = viewModel.effectiveMetrics.prqScore
        let normalized = min(100, max(0, prq)) / 100.0
        let base = 0.62 + normalized * 0.28
        let jitter = Double.random(in: -0.02...0.02)
        return min(0.90, max(0.62, base + jitter))
    }

    private func commitRound() {
        guard canTapAction else { return }
        let timingQuality = qualityFromPRQ()
        let perfect = mode.id.commitFeedbackPerfect
        let good = mode.id.commitFeedbackGood
        let miss = mode.id.commitFeedbackMiss
        let feedback = timingQuality >= 0.88 ? perfect : (timingQuality >= 0.72 ? good : miss)
        let soundQuality: GameplaySoundService.CommitFeedbackQuality = feedback == perfect ? .perfect : (feedback == good ? .good : .miss)
        if mode.id != .baseball {
            GameplaySoundService.playCommit(quality: soundQuality)
            commitFeedbackScale = 0.85
            withAnimation(.spring(response: 0.2)) { commitFeedback = feedback; commitFeedbackScale = 1.15 }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7).delay(0.12)) { commitFeedbackScale = 1.0 }
            #if !targetEnvironment(simulator)
            if feedback == perfect {
                let style = commitHapticStyleForPerfect()
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            } else if feedback == good { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            else { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            #endif
        }
        if isLocalPlay, !ignoreMultipeerAfterDisconnect, let mp = multipeer {
            let timingHundred = Int(min(100, max(0, timingQuality * 100)))
            myTimingThisRound = timingHundred
            let role = iAmP1 ? "P1" : "P2"
            mp.sendAction(role, score: timingHundred, round: round)
            if iAmP1 {
                waitingForOpponent = true
            } else {
                applyLocalPlayResult()
            }
        } else if mode.id == .basketballHeadToHead || mode.id == .basketball3v3 {
            committedQualityForContest = timingQuality
            showContestWindow = true
            contestDecided = nil
            contestTask?.cancel()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(720))
                withAnimation(.easeOut(duration: 0.2)) { commitFeedback = nil }
            }
            contestTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled, let quality = committedQualityForContest else { return }
                let contested = Double.random(in: 0..<1) < 0.35
                withAnimation(.easeOut(duration: 0.15)) { contestDecided = contested }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                let adjusted = quality * (contested ? 0.82 : 1.0)
                showContestWindow = false
                contestDecided = nil
                committedQualityForContest = nil
                contestTask = nil
                scoreRound(timingQuality: adjusted)
            }
        } else if mode.id == .karate {
            committedQualityForBlock = timingQuality
            showBlockWindow = true
            blockDecided = nil
            blockTask?.cancel()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(720))
                withAnimation(.easeOut(duration: 0.2)) { commitFeedback = nil }
            }
            blockTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled, let quality = committedQualityForBlock else { return }
                let blocked = Double.random(in: 0..<1) < 0.35
                withAnimation(.easeOut(duration: 0.15)) { blockDecided = blocked }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                let adjusted = quality * (blocked ? 0.82 : 1.0)
                showBlockWindow = false
                blockDecided = nil
                committedQualityForBlock = nil
                blockTask = nil
                scoreRound(timingQuality: adjusted)
            }
        } else if mode.id == .baseball {
            committedQualityForPitch = timingQuality
            showPitchPhase = true
            pitchTask?.cancel()
            pitchTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let quality = committedQualityForPitch else { return }
                let perfect = mode.id.commitFeedbackPerfect
                let good = mode.id.commitFeedbackGood
                let miss = mode.id.commitFeedbackMiss
                let feedback = quality >= 0.88 ? perfect : (quality >= 0.72 ? good : miss)
                let soundQuality: GameplaySoundService.CommitFeedbackQuality = feedback == perfect ? .perfect : (feedback == good ? .good : .miss)
                GameplaySoundService.playCommit(quality: soundQuality)
                commitFeedbackScale = 0.85
                withAnimation(.spring(response: 0.2)) { commitFeedback = feedback; commitFeedbackScale = 1.15 }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7).delay(0.12)) { commitFeedbackScale = 1.0 }
                #if !targetEnvironment(simulator)
                if feedback == perfect { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
                else if feedback == good { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                else { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
                #endif
                showPitchPhase = false
                committedQualityForPitch = nil
                pitchTask = nil
                scoreRound(timingQuality: quality)
                try? await Task.sleep(for: .milliseconds(720))
                withAnimation(.easeOut(duration: 0.2)) { commitFeedback = nil }
            }
        } else {
            scoreRound(timingQuality: timingQuality)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(720))
            if mode.id != .basketballHeadToHead && mode.id != .basketball3v3 && mode.id != .karate && mode.id != .baseball { withAnimation(.easeOut(duration: 0.2)) { commitFeedback = nil } }
        }
    }

    private func applyLocalPlayResult() {
        guard let myTiming = myTimingThisRound,
              let oppTiming = opponentTimingThisRound else { return }
        var p1Timing = iAmP1 ? myTiming : oppTiming
        let p2Timing = iAmP1 ? oppTiming : myTiming
        if (mode.id == .basketballHeadToHead || mode.id == .basketball3v3), !iAmP1, didContestThisRound {
            p1Timing = Int(Double(p1Timing) * 0.82)
        }
        if mode.id == .karate, !iAmP1, didBlockThisRound {
            p1Timing = Int(Double(p1Timing) * 0.82)
        }
        let p1WinsRound = p1Timing > p2Timing
        let p1Points = p1WinsRound ? 1 : 0
        let p2Points = 1 - p1Points
        roundScores.append((p1Points, p2Points))
        roundResult = (p1Points, p2Points)
        playerScore += p1Points
        opponentScore += p2Points
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.25)) { showingRoundResult = true }
        }
    }

    private func alertMessage(p1: Int, p2: Int) -> String {
        let won = p1 > p2
        switch mode.id {
        case .basketballHeadToHead:
            return won ? "Bucket. You \(p1), \(oppLabel) \(p2)." : "Missed. You \(p1), \(oppLabel) \(p2)."
        case .basketball3v3:
            return won ? "Bucket. Your squad \(p1), their squad \(p2)." : "Stopped. Your squad \(p1), their squad \(p2)."
        case .basketballDunkContest:
            return won ? "Dunk counted. Judges favor you this round." : "No score. Judges went the other way."
        case .karate:
            return won ? "Clean strike. You landed the point." : "Point to opponent. You took the hit."
        case .baseball:
            return won ? "Gone! You cleared the fence." : "Out. Pitcher got you this at-bat."
        case .football:
            return won ? "House call. You broke it." : "Stopped. Special teams held."
        case .soccer:
            return won ? "Goal! Keeper couldn’t reach it." : "Saved. Keeper read you."
        case .golf:
            return won ? "Closer. You won the hole." : "Opponent closer. You lost the hole."
        case .tennis:
            return won ? "Point yours. You \(p1), \(oppLabel) \(p2)." : "Point to opponent. You \(p1), \(oppLabel) \(p2)."
        case .volleyball:
            return won ? "Kill. You \(p1), \(oppLabel) \(p2)." : "Blocked. You \(p1), \(oppLabel) \(p2)."
        case .gymnastics:
            return won ? "Stuck. Judges gave you the routine." : "Deduction. Judges favored opponent."
        case .brainBrawl:
            return won ? "Correct! You got it first." : "AI answered first this time."
        }
    }

    /// Round win/loss from PRQ-derived quality (0.62–0.90). No timing bar; creator vision.
    private func scoreRound(timingQuality: Double = 0.5) {
        let baseChance = PRQ.successChanceFromPRQ(viewModel.effectiveMetrics.prqScore, for: mode.id)
        let skillFactor = 0.28 + 0.72 * timingQuality
        var chance = min(0.94, baseChance * skillFactor + (1 - skillFactor) * 0.15)
        let isClutch = (round == totalRounds && playerScore == opponentScore)
        if isClutch { chance = min(0.94, chance + 0.05) }
        let p1WinsRound = Double.random(in: 0..<1) < chance
        let p1Points = p1WinsRound ? 1 : 0
        let p2Points = 1 - p1Points
        roundScores.append((p1Points, p2Points))
        roundResult = (p1Points, p2Points)
        playerScore += p1Points
        opponentScore += p2Points
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.25)) { showingRoundResult = true }
        }
    }

    private func nextRound() {
        contestTask?.cancel()
        contestTask = nil
        p2ContestWindowTask?.cancel()
        p2ContestWindowTask = nil
        showContestWindow = false
        contestDecided = nil
        committedQualityForContest = nil
        showP2ContestWindow = false
        didContestThisRound = false
        blockTask?.cancel()
        blockTask = nil
        p2BlockWindowTask?.cancel()
        p2BlockWindowTask = nil
        showBlockWindow = false
        blockDecided = nil
        committedQualityForBlock = nil
        showP2BlockWindow = false
        didBlockThisRound = false
        pitchTask?.cancel()
        pitchTask = nil
        showPitchPhase = false
        committedQualityForPitch = nil
        roundResult = nil
        commitFeedback = nil
        myTimingThisRound = nil
        opponentTimingThisRound = nil
        waitingForOpponent = false
        if round >= totalRounds {
            finishGame()
        } else {
            round += 1
        }
    }

    private func finishGame() {
        _ = viewModel.effectiveMetrics.prqScore
        let won = playerScore > opponentScore
        let tied = playerScore == opponentScore
        let diff = playerScore - opponentScore
        let gain = PRQ.modeReward(mode: mode.id, won: won, tied: tied, combo: 0, criticals: 0, scoreDifferential: diff)
        let baseShards = 6 + totalRounds * 2
        let shards = max(8, min(40, baseShards + (playerScore * 3) + (won ? 12 : 0) + (diff > 0 ? diff * 2 : 0)))
        onGameEnd(playerScore, opponentScore, shards, gain, roundScores)
    }
}

// MARK: - Arena Unreal input scheme overlays (Hybrid `setUnrealReady` + `inputScheme`)

private struct FELArenaSwipeGolfInputOverlay: View {
    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "figure.golf")
                        .font(.title2)
                        .foregroundStyle(Color.cyan)
                    Text("SWIPE GOLF")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Text("Drag the arc to set power and shot shape. Release on the upswing — inputScheme swipeGolf (Unreal handshake).")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.45))
            .overlay(alignment: .top) { Divider().background(Color.white.opacity(0.2)) }
        }
        .allowsHitTesting(false)
    }
}

private struct FELArenaPenaltyKickInputOverlay: View {
    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "soccerball")
                        .font(.title2)
                        .foregroundStyle(Color.cyan)
                    Text("PENALTY KICK")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Text("Aim the reticle, then commit power — inputScheme penaltyKick. Matches active arena mode after setUnrealReady.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.45))
            .overlay(alignment: .top) { Divider().background(Color.white.opacity(0.2)) }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Environment copy (GameModeId) used by GenericArenaPlayView
// Round labels, action titles, round counts, and secondary colors are on GameModeId in GameMode.swift.

