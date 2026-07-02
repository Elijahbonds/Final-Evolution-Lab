import SwiftUI

struct NexusAgentChatView: View {
    @Bindable private var coordinator = NEXUSAgentCoordinator.shared
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            composer
        }
        .background(Theme.deepBlack)
        .navigationTitle("NEXUS Agent")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Backend", selection: $coordinator.backend) {
                        ForEach(NEXUSAgentLLMBackend.allCases, id: \.self) { backend in
                            Text(backend.label).tag(backend)
                        }
                    }
                    Button("Clear chat", role: .destructive) {
                        coordinator.clearChat()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("NEXUS AGENT")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.neonGreen)
                    .tracking(2)
                Spacer()
                FELPreviewLabel(text: "PREVIEW")
            }

            Text("Cursor-like control · whitelisted tools · honest ship labels")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                chip(coordinator.backend.label, icon: "cpu")
                chip(NEXUSAgentService.resolvedRepoRootPath(), icon: "folder")
                Button {
                    NEXUSCursorBridge.copyRepoRootToPasteboard()
                    NEXUSCursorBridge.openCursorRepoURL()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("Open in Cursor")
                    }
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.neonGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.neonGreen.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            toolChipBar
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }

    private var toolChipBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("WHITELISTED TOOLS")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                FELPreviewLabel(text: FELPremiumCopy.Preview.toolChips)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(NEXUSAgentToolName.mcpSurfaceTools, id: \.rawValue) { tool in
                        toolChipButton(tool: tool, label: tool.displayTitle, arguments: defaultArgs(for: tool))
                    }
                    ForEach(Array(NEXUSAgentToolName.quickRunChips.enumerated()), id: \.offset) { _, entry in
                        toolChipButton(tool: entry.tool, label: entry.label, arguments: entry.arguments)
                    }
                }
            }
        }
    }

    private func toolChipButton(tool: NEXUSAgentToolName, label: String, arguments: [String: Any]) -> some View {
        Button {
            Task { await coordinator.runQuickTool(tool, arguments: arguments) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Theme.brandCyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.brandCyan.opacity(0.1))
            .overlay(Capsule().stroke(Theme.brandCyan.opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(coordinator.isProcessing)
    }

    private func defaultArgs(for tool: NEXUSAgentToolName) -> [String: Any] {
        switch tool {
        case .playtest:
            return ["mode_id": GameModeId.basketballDunkContest3D.rawValue]
        case .buildGate:
            return ["target": "validate_only"]
        default:
            return [:]
        }
    }

    private func chip(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(coordinator.messages.filter { $0.role != .system }) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onChange(of: coordinator.messages.count) { _, _ in
                if let last = coordinator.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: NEXUSAgentMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Theme.brandBlue.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        case .assistant:
            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        case .tool:
            toolResultCard(message)
        case .system:
            EmptyView()
        }
    }

    private func toolResultCard(_ message: NEXUSAgentMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(Theme.neonGreen)
                Text(message.toolName ?? "tool")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.neonGreen)
                Spacer()
            }

            Text(message.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            if let json = message.toolResultJSON {
                Text(json)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(Theme.neonGreen.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.neonGreen.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask NEXUS Agent…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .focused($inputFocused)
                .disabled(coordinator.isProcessing)

            Button {
                let text = draft
                draft = ""
                inputFocused = false
                Task { await coordinator.send(userText: text) }
            } label: {
                Image(systemName: coordinator.isProcessing ? "hourglass" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.white.opacity(0.2)
                        : Theme.neonGreen)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.isProcessing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.6))
    }
}

#Preview {
    NavigationStack {
        NexusAgentChatView()
    }
    .preferredColorScheme(.dark)
}
