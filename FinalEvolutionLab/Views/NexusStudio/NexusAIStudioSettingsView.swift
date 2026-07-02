import SwiftUI

/// AI Studio settings panel — API key (Keychain), model picker, Gemini ping test.
struct NexusAIStudioSettingsView: View {
    @State private var config = NexusAIStudioConfigService.shared
    @State private var showKey = false
    @State private var statusMessage: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statusCard
                apiKeySection
                modelSection
                testSection
                usageNote
            }
            .padding(16)
        }
        .background(Theme.deepBlack)
        .onAppear {
            config.refreshKeyPresence()
            if config.hasStoredKey {
                config.apiKeyDraft = "••••••••"
            }
        }
    }

    private var header: some View {
        NexusStudioPanelHeader(
            title: "Creative AI",
            accent: Theme.elitePurple,
            previewLabel: FELPremiumCopy.Preview.geminiRest,
            subtitle: "Connect Google AI Studio for smarter game creation. Your key stays on this device; offline mode uses built-in templates."
        )
    }

    private var statusCard: some View {
        NexusStudioConnectionPill(
            tone: config.connectionStatus.pillTone,
            title: config.connectionStatus.pillTitle,
            detail: config.lastPingMessage ?? config.connectionStatus.pillDetail(config: config)
        )
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NexusStudioSectionTitle(title: "API key")

            HStack(spacing: 8) {
                Group {
                    if showKey {
                        TextField("AIza…", text: $config.apiKeyDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("AIza…", text: $config.apiKeyDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .textFieldStyle(NexusStudioDarkTextFieldStyle())

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.brandCyan)
                        .padding(10)
                        .background(Circle().fill(Theme.brandCyan.opacity(0.12)))
                }
            }
            .accessibilityIdentifier("NexusAIStudioAPIKeyField")

            HStack(spacing: 10) {
                Button("Save key") {
                    saveKey()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandCyan)
                .disabled(isSaving)
                .accessibilityIdentifier("NexusAIStudioSaveKeyButton")

                if config.hasStoredKey {
                    Button("Remove") {
                        clearKey()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.orange)
                }
            }

            if let statusMessage {
                NexusStudioStatusPill(
                    message: statusMessage,
                    isError: statusMessage.localizedCaseInsensitiveContains("fail")
                )
            }
        }
        .nexusStudioCard()
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NexusStudioSectionTitle(title: "Model")

            Picker("Gemini model", selection: $config.selectedModel) {
                ForEach(NexusAIStudioConfigService.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.brandCyan)
            .accessibilityIdentifier("NexusAIStudioModelPicker")
        }
        .nexusStudioCard()
    }

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NexusStudioSectionTitle(title: "Test connection")

            Button {
                Task { await config.pingGemini() }
            } label: {
                HStack(spacing: 8) {
                    if config.connectionStatus == .checking {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    Text(config.connectionStatus == .checking ? "Testing…" : "Test connection")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.elitePurple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(config.connectionStatus == .checking)
            .accessibilityIdentifier("NexusAIStudioPingButton")
        }
        .nexusStudioCard()
    }

    private var usageNote: some View {
        Text("Play and Game Generator use this connection for AI-assisted creation. Without a key, NEXUS uses built-in game templates.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func saveKey() {
        isSaving = true
        statusMessage = nil
        defer { isSaving = false }

        if config.apiKeyDraft == "••••••••" {
            statusMessage = "Enter a new key to replace the stored value."
            return
        }

        do {
            try config.saveAPIKeyFromDraft()
            statusMessage = "API key saved to Keychain."
            FelToastCenter.shared.show("AI Studio key saved", isError: false)
        } catch {
            statusMessage = error.localizedDescription
            FelToastCenter.shared.show(error.localizedDescription, isError: true)
        }
    }

    private func clearKey() {
        config.clearStoredKey()
        statusMessage = "Keychain entry cleared."
    }
}

#if DEBUG
#Preview {
    NexusAIStudioSettingsView()
        .preferredColorScheme(.dark)
}
#endif
