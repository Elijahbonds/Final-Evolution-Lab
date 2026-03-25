import SwiftUI
import MultipeerConnectivity

/// Local play lobby: Host or Join a game over Multipeer, pick mode, then start Arena.
struct LocalPlayLobbyView: View {
    let multipeer: MultipeerService
    let onStartGame: (GameMode, Bool) -> Void
    let onDismiss: () -> Void

    @State private var isHost = true
    @State private var selectedMode: GameMode?
    @State private var hostingGameId: String?
    @State private var browsingGameId: String?

    private var modes: [GameMode] { GameModeRegistry.all }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        roleToggle
                        if selectedMode == nil {
                            modePicker
                        } else if let mode = selectedMode {
                            connectionSection(mode: mode)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Local Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        multipeer.stop()
                        onDismiss()
                    }
                    .foregroundStyle(Theme.brandBlue)
                }
            }
            .onDisappear {
                if hostingGameId == nil && browsingGameId == nil {
                    multipeer.stop()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOCAL PLAY")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
                .tracking(4)
            Text("Play with someone on the same Wi‑Fi. Host creates a game; the other joins.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var roleToggle: some View {
        HStack(spacing: 12) {
            Button {
                multipeer.stop()
                hostingGameId = nil
                browsingGameId = nil
                selectedMode = nil
                isHost = true
            } label: {
                Text("Host")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(isHost ? .black : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isHost ? Theme.brandCyan : Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Host")
            .accessibilityHint("Create a game for others to join on the same Wi‑Fi")

            Button {
                multipeer.stop()
                hostingGameId = nil
                browsingGameId = nil
                selectedMode = nil
                isHost = false
            } label: {
                Text("Join")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(!isHost ? .black : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(!isHost ? Theme.brandCyan : Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Join")
            .accessibilityHint("Find and join a game on the same Wi‑Fi")
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose mode")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 8) {
                ForEach(modes, id: \.id.id) { mode in
                    Button {
                        selectedMode = mode
                        if isHost {
                            multipeer.startHosting(gameId: mode.id.rawValue)
                            hostingGameId = mode.id.rawValue
                        } else {
                            multipeer.startBrowsing(gameId: mode.id.rawValue)
                            browsingGameId = mode.id.rawValue
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(mode.accentColor)
                                .frame(width: 44, height: 44)
                                .background(mode.accentColor.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text(mode.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func connectionSection(mode: GameMode) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: mode.iconName)
                    .foregroundStyle(mode.accentColor)
                Text(mode.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Change") {
                    multipeer.stop()
                    hostingGameId = nil
                    browsingGameId = nil
                    selectedMode = nil
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.brandCyan)
            }
            .padding(12)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if isHost {
                hostWaitingView(mode: mode)
            } else {
                joinBrowseView(mode: mode)
            }
        }
    }

    private func hostWaitingView(mode: GameMode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if multipeer.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.checkmark")
                        .foregroundStyle(Theme.brandCyan)
                    Text("\(multipeer.connectedPeerName) connected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.brandCyan.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    onStartGame(mode, true)
                    onDismiss()
                } label: {
                    Text("Start Game")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.brandCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Theme.brandCyan)
                    Text("Waiting for player...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func joinBrowseView(mode: GameMode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if multipeer.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill.checkmark")
                        .foregroundStyle(Theme.brandCyan)
                    Text("Connected to \(multipeer.connectedPeerName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.brandCyan.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    onStartGame(mode, false)
                    onDismiss()
                } label: {
                    Text("Start Game")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.brandCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else {
                Text("Nearby games")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                if multipeer.discoveredPeers.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(Theme.brandCyan)
                        Text("Searching...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ForEach(multipeer.discoveredPeers) { peer in
                        Button {
                            multipeer.invite(peer: peer.peerId)
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(Theme.brandCyan)
                                Text(peer.peerId.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                if let g = peer.gameId, let m = GameModeRegistry.all.first(where: { $0.id.rawValue == g }) {
                                    Text(m.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Join")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.brandCyan)
                            }
                            .padding(12)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
