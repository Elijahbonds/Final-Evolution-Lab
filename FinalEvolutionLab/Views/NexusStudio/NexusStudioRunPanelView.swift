import SwiftUI

struct NexusStudioRunPanelView: View {
    @State private var selectedModeId: GameModeId
    @State private var readiness: Double
    @State private var artifactSummary = NexusPlaytestArtifactReader.loadSummary()
    @State private var generatedGames: [NexusGeneratedGameEntry] = []
    @State private var selectedGeneratedPath: String?
    @State private var statusMessage: String?
    @State private var aiStudio = NexusAIStudioConfigService.shared
    @State private var generatePrompt = ""
    @State private var isGenerating = false
    @State private var engine = NexusGameplayEngine()

    init(initialModeId: GameModeId? = nil, initialReadiness: Double = 75, initialGeneratedPath: String? = nil) {
        _selectedModeId = State(initialValue: initialModeId ?? .basketballDunkContest3D)
        _readiness = State(initialValue: initialReadiness)
        _selectedGeneratedPath = State(initialValue: initialGeneratedPath)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                aiStudioStatusCard
                studioGenerateCard
                generatedGamesCard
                modePicker
                playtestButton
                artifactCard
            }
            .padding(16)
        }
        .background(Theme.deepBlack)
        .onAppear {
            aiStudio.refreshKeyPresence()
            refreshAll()
        }
    }

    private var aiStudioStatusCard: some View {
        HStack(alignment: .center, spacing: 10) {
            NexusStudioConnectionPill(
                tone: aiStudio.connectionStatus.pillTone,
                title: aiStudio.connectionStatus.pillTitle,
                detail: aiStudio.connectionStatus.pillDetail(config: aiStudio)
            )
            Button {
                NexusStudioCoordinator.shared.openAIStudioSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.brandCyan)
                    .padding(8)
                    .background(Circle().fill(Theme.brandCyan.opacity(0.12)))
            }
            .accessibilityIdentifier("NexusStudioRunAISettingsButton")
        }
        .accessibilityIdentifier("NexusStudioRunAIStatusCard")
    }

    private var studioGenerateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            NexusStudioSectionTitle(title: "Create a game")

            TextField(
                "Describe a mode — e.g. hard karate endless with dojo venue",
                text: $generatePrompt,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textFieldStyle(NexusStudioDarkTextFieldStyle())
            .accessibilityIdentifier("NexusStudioRunGeneratePrompt")

            Button {
                generateInStudio()
            } label: {
                HStack(spacing: 8) {
                    if isGenerating { ProgressView().tint(.black) }
                    Image(systemName: "wand.and.stars")
                    Text(isGenerating ? "Creating…" : "Create game")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.brandCyan)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(generatePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            .accessibilityIdentifier("NexusStudioRunGenerateButton")
        }
        .nexusStudioCard()
    }

    private func generateInStudio() {
        let trimmed = generatePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isGenerating = true
        statusMessage = FELPremiumCopy.Emulator.buildingGame

        Task { @MainActor in
            defer { isGenerating = false }

            if !engine.isLinked {
                engine.bootstrapForCreativeCommands(readiness: readiness)
            }

            let includeArena = trimmed.localizedCaseInsensitiveContains("arena")
                || trimmed.localizedCaseInsensitiveContains("court")
                || trimmed.localizedCaseInsensitiveContains("venue")
                || trimmed.localizedCaseInsensitiveContains("stadium")
                || trimmed.localizedCaseInsensitiveContains("dojo")

            let result = await engine.generateGame(
                trimmed,
                includeArena: includeArena,
                startSession: true,
                forceTemplate: false,
                aiStudio: aiStudio
            )

            if result.success, let spec = result.spec {
                readiness = NexusGeneratedGameEntry.readiness(for: spec.difficultyTier)
                if let parsed = GameModeId(rawValue: spec.modeId) {
                    selectedModeId = parsed
                }
                if let path = engine.exportGeneratedSpecToSandbox(spec) {
                    selectedGeneratedPath = path
                    statusMessage = "Generated \(spec.displayName) → sandbox/\(path)"
                    refreshGeneratedGames()
                    FelToastCenter.shared.show("Generated: \(spec.displayName)", isError: false)
                } else {
                    statusMessage = "Generated \(spec.displayName) — sandbox export failed"
                }
            } else {
                statusMessage = result.errorMessage ?? "Generation failed"
                FelToastCenter.shared.show(statusMessage ?? "Generation failed", isError: true)
            }
        }
    }

    private var header: some View {
        NexusStudioPanelHeader(
            title: "Play on device",
            accent: Theme.neonGreen,
            previewLabel: FELPremiumCopy.Preview.inAppPlaytest,
            subtitle: "Launch a generated game or quick-play mode on this device. Mac playtest results appear here after running a local test on your Mac."
        )
    }

    private var generatedGamesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NexusStudioSectionTitle(title: "Your games")
                Spacer()
                Button("Refresh") { refreshGeneratedGames() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.brandCyan)
            }

            if generatedGames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No games exported yet.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Create a mode in Arena, then open it here to play on device.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(generatedGames.prefix(6)) { entry in
                    Button {
                        applyGeneratedEntry(entry)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedGeneratedPath == entry.relativePath ? "checkmark.circle.fill" : "gamecontroller")
                                .foregroundStyle(selectedGeneratedPath == entry.relativePath ? Theme.neonGreen : Theme.elitePurple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    if let mode = GameModeRegistry.playableMode(forRegistryId: entry.modeId) {
                                        NexusBuilderCapabilityBadge(tier: mode.nexusCapabilityTier)
                                    }
                                    Text("\(entry.modeId) · \(entry.difficultyTier)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Text(entry.venueToken.isEmpty ? "default venue" : entry.venueToken)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedGeneratedPath == entry.relativePath ? Theme.neonGreen.opacity(0.12) : Color.white.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }

                if selectedGeneratedPath != nil {
                    Button {
                        playSelectedGeneratedGame()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                            Text("Play selected game")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.elitePurple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .nexusStudioCard()
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            NexusStudioSectionTitle(title: "Quick play")

            Picker("Mode", selection: $selectedModeId) {
                ForEach(GameModeRegistry.nexusSprintModes) { mode in
                    Text(mode.name).tag(mode.id)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.brandCyan)
            .onChange(of: selectedModeId) { _, _ in
                selectedGeneratedPath = nil
            }

            HStack {
                Text("Intensity")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Slider(value: $readiness, in: 0...100, step: 5)
                    .tint(Theme.neonGreen)
                Text("\(Int(readiness))")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.neonGreen)
                    .frame(width: 28)
            }
        }
        .nexusStudioCard()
    }

    private var playtestButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                launchPlaytest(modeId: selectedModeId, readiness: readiness, label: nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Play on device")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.neonGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let statusMessage {
                NexusStudioStatusPill(
                    message: statusMessage,
                    isError: statusMessage.localizedCaseInsensitiveContains("fail")
                        || statusMessage.localizedCaseInsensitiveContains("error")
                )
            }
        }
    }

    private var artifactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                NexusStudioSectionTitle(title: "Latest Mac test")
                Spacer()
                Button("Refresh") { refreshArtifact() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.brandCyan)
            }

            if artifactSummary.exists {
                summaryRow("Status", artifactSummary.overallStatus.uppercased(), color: artifactSummary.overallStatus == "pass" ? Theme.neonGreen : .orange)
                if let modeId = artifactSummary.modeId {
                    summaryRow("Mode", modeId)
                }
                if let venue = artifactSummary.venue {
                    summaryRow("Venue", venue)
                }
                if let fps = artifactSummary.runtimeFPS {
                    summaryRow("FPS", String(format: "%.1f", fps))
                }
                if let tris = artifactSummary.triangleCount {
                    summaryRow("Triangles", "\(tris)")
                }
                if let generated = artifactSummary.generatedAt {
                    summaryRow("Generated", generated)
                }
                Text(artifactSummary.rawPath)
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .lineLimit(2)
            } else {
                Text("No Mac playtest results yet. Run a local test on your Mac to see performance details here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .nexusStudioCard()
    }

    private func summaryRow(_ label: String, _ value: String, color: Color = .white) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
        }
    }

    private func applyGeneratedEntry(_ entry: NexusGeneratedGameEntry) {
        selectedGeneratedPath = entry.relativePath
        if let parsed = GameModeId(rawValue: entry.modeId) {
            selectedModeId = parsed
        }
        readiness = entry.readinessEstimate
        statusMessage = "Loaded \(entry.displayName) from sandbox."
    }

    private func playSelectedGeneratedGame() {
        guard let path = selectedGeneratedPath,
              let entry = generatedGames.first(where: { $0.relativePath == path }),
              let mode = GameModeRegistry.playableMode(forRegistryId: entry.modeId)
        else {
            statusMessage = "Select a generated spec first."
            return
        }

        launchPlaytest(modeId: mode.id, readiness: entry.readinessEstimate, label: entry.displayName)
    }

    private func launchPlaytest(modeId: GameModeId, readiness: Double, label: String?) {
        guard let mode = GameModeRegistry.all.first(where: { $0.id == modeId }) else {
            statusMessage = "Mode not in registry."
            return
        }

        NotificationCenter.default.post(
            name: .nexusAgentLaunchMode,
            object: nil,
            userInfo: [
                "mode_id": modeId.rawValue,
                "mode_name": mode.name,
                "readiness": readiness,
            ]
        )
        let prefix = label ?? mode.name
        statusMessage = "Launching \(prefix)…"
        FelToastCenter.shared.show("Playtest: \(prefix)", isError: false)
    }

    private func refreshAll() {
        refreshArtifact()
        refreshGeneratedGames()
    }

    private func refreshGeneratedGames() {
        NexusStudioWorkspaceService.shared.bootstrap()
        generatedGames = NexusStudioWorkspaceService.shared.listGeneratedGameSpecs()

        if let path = selectedGeneratedPath,
           !generatedGames.contains(where: { $0.relativePath == path }) {
            selectedGeneratedPath = nil
        } else if let path = selectedGeneratedPath,
                  let entry = generatedGames.first(where: { $0.relativePath == path }) {
            applyGeneratedEntry(entry)
        }
    }

    private func refreshArtifact() {
        artifactSummary = NexusPlaytestArtifactReader.loadSummary()
    }
}

#if DEBUG
#Preview {
    NexusStudioRunPanelView()
        .preferredColorScheme(.dark)
}
#endif
