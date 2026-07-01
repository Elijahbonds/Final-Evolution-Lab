import SwiftUI

struct GameModeSelectionView: View {
    let viewModel: LabViewModel
    @State private var appeared = false
    @State private var selectedMode: GameMode?
    @State private var showNeuralScan = false
    @State private var pendingMode: GameMode?
    @State private var sessionReadiness: Double = 50
    @State private var navigateToGame = false
    @State private var showMatchmaking = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                globalMatchmakingBanner

                ForEach(GameModeRegistry.sportCategories, id: \.rawValue) { category in
                    sportSection(category)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.deepBlack)
        .navigationDestination(isPresented: $navigateToGame) {
            if let mode = pendingMode {
                GameModeRouter(gameMode: mode, viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $showNeuralScan) {
            NeuralReadinessScanView { readiness in
                sessionReadiness = readiness
                viewModel.profile.metrics.neuralDrive = min(100, readiness)
                SaveSystem.saveProfile(viewModel.profile)
                showNeuralScan = false
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    await launchGame()
                }
            }
        }
        .sheet(isPresented: $showMatchmaking) {
            if let mode = pendingMode {
                MatchmakingView(viewModel: viewModel, gameMode: mode) { opponent, readiness in
                    sessionReadiness = readiness
                    showMatchmaking = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await launchGame()
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) { appeared = true }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SELECT MODE")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .tracking(4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)

            Text("Arena")
                .font(.system(size: 56, weight: .black))
                .italic()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

            // Active creator card pill
            if let active = viewModel.profile.activeCreatorCard,
               let card = CreatorCard.catalog.first(where: { $0.id == active.cardId }) {
                HStack(spacing: 6) {
                    Image(systemName: card.iconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(card.accentColor)
                    Text(card.title)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(card.accentColor)
                    Text("ACTIVE")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(card.accentColor.opacity(0.08))
                        .overlay(Capsule().stroke(card.accentColor.opacity(0.2), lineWidth: 0.5))
                )
                .opacity(appeared ? 1 : 0)
                .transition(.scale.combined(with: .opacity))
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("\(GameModeRegistry.all.count)")
                        .font(.system(.caption, design: .monospaced, weight: .black))
                        .foregroundStyle(Theme.brandCyan)
                    Text("MODES")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Circle()
                    .fill(.tertiary)
                    .frame(width: 3, height: 3)

                HStack(spacing: 4) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.brandCyan.opacity(0.7))
                    Text("MULTIPLAYER")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var globalMatchmakingBanner: some View {
        Button {
            if let mode = GameModeRegistry.all.first {
                pendingMode = mode
                showMatchmaking = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.brandCyan.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .symbolEffect(.pulse)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("GLOBAL ARENA")
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.white)

                    Text("Find opponents by PRQ tier")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(Theme.brandCyan.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.brandCyan)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.brandCyan.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func sportSection(_ category: GameMode.SportCategory) -> some View {
        let modes = GameModeRegistry.modes(for: category)
        let index = GameModeRegistry.sportCategories.firstIndex(of: category) ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(modes.first?.accentColor.opacity(0.3) ?? Theme.brandBlue.opacity(0.3))
                    .frame(width: 6, height: 6)

                Text(category.rawValue.uppercased())
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(3)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(modes.enumerated()), id: \.element.id) { modeIndex, mode in
                    GameModeCard(mode: mode) {
                        pendingMode = mode
                        if mode.id == .marketBrowse {
                            Task { await launchGame() }
                        } else {
                            showNeuralScan = true
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.5).delay(Double(index) * 0.1 + Double(modeIndex) * 0.06),
                        value: appeared
                    )
                }
            }
        }
    }

    @MainActor
    private func launchGame() async {
        // Load the NexusScene for this mode before navigating.
        // .marketBrowse is a store view, not a game session — skip the engine launch.
        if let mode = pendingMode, mode.id != .marketBrowse {
            try? await NexusEngine.shared.launchMode(
                mode.id,
                readiness: sessionReadiness,
                profile: viewModel.profile
            )
        }
        navigateToGame = true
    }
}

struct GameModeCard: View {
    let mode: GameMode
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var shimmer = false
    @State private var pulseRing = false
    @State private var orbRotation: Double = 0

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    // Icon with animated outer ring + inner glow
                    ZStack {
                        // Pulsing ambient glow
                        Circle()
                            .fill(mode.accentColor.opacity(pulseRing ? 0.18 : 0.06))
                            .frame(width: 52, height: 52)
                            .blur(radius: 6)
                            .animation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: pulseRing)

                        // Rotating dashed ring
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [mode.accentColor.opacity(0.55), .clear, mode.accentColor.opacity(0.3)],
                                    center: .center),
                                style: StrokeStyle(lineWidth: 1.2, dash: [3, 5]))
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(orbRotation))

                        // Solid icon background
                        Circle()
                            .fill(RadialGradient(
                                colors: [mode.accentColor.opacity(0.22), mode.accentColor.opacity(0.05)],
                                center: .center, startRadius: 2, endRadius: 22))
                            .frame(width: 42, height: 42)

                        Image(systemName: mode.iconName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(mode.accentColor)
                            .shadow(color: mode.accentColor.opacity(0.6), radius: 8)
                            .scaleEffect(isPressed ? 1.1 : 1.0)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        multiplayerBadge
                        // Arrow chevron — subtle directional cue
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(mode.accentColor.opacity(0.35))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.name.uppercased())
                        .font(.system(.subheadline, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(mode.subtitle)
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(mode.accentColor.opacity(0.8))
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                    Text(mode.environmentName)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.tertiary)

                if let hint = mode.hint {
                    Text(hint)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(mode.accentColor.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.cardBackground)

                    // Shimmer sweep when pressed
                    if shimmer {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(
                                colors: [.clear, mode.accentColor.opacity(0.12), .clear],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }

                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(
                            colors: [mode.accentColor.opacity(0.07), .clear, mode.accentColor.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))

                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    mode.accentColor.opacity(isPressed ? 0.6 : 0.18),
                                    mode.accentColor.opacity(0.06),
                                    mode.accentColor.opacity(isPressed ? 0.35 : 0.12)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isPressed ? 1.5 : 1)
                }
                .shadow(color: mode.accentColor.opacity(isPressed ? 0.22 : 0.06), radius: isPressed ? 16 : 5)
            )
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isPressed = pressing
                shimmer = pressing
            }
        }, perform: {})
        .onAppear {
            pulseRing = true
            withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
        }
    }

    private var multiplayerBadge: some View {
        Group {
            switch mode.multiplayerType {
            case .realtime:
                HStack(spacing: 3) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 7))
                    Text("LIVE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Theme.brandCyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Theme.brandCyan.opacity(0.1))
                .clipShape(Capsule())
            case .turnBased:
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 7))
                    Text("TURNS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            case .solo:
                EmptyView()
            }
        }
    }
}

extension GameMode: Hashable {
    nonisolated static func == (lhs: GameMode, rhs: GameMode) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
