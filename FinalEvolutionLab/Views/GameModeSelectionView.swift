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
                GamePlayView(viewModel: viewModel, gameMode: mode, sessionReadiness: sessionReadiness)
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
                    navigateToGame = true
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
                        navigateToGame = true
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

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("11")
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
                        showNeuralScan = true
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
}

struct GameModeCard: View {
    let mode: GameMode
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var shimmer = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [mode.accentColor.opacity(0.2), mode.accentColor.opacity(0.05)],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 22
                                )
                            )
                            .frame(width: 42, height: 42)

                        Image(systemName: mode.iconName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(mode.accentColor)
                            .shadow(color: mode.accentColor.opacity(0.4), radius: 6)
                    }

                    Spacer()

                    multiplayerBadge
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

                HStack(spacing: 5) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 8))
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 8))
                    Text("Controller / Swipe")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.secondary)

                Text(mode.id.gameplayDNA)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(mode.accentColor.opacity(0.55))
                    .lineLimit(2)

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

                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [mode.accentColor.opacity(0.06), .clear, mode.accentColor.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    mode.accentColor.opacity(isPressed ? 0.5 : 0.15),
                                    mode.accentColor.opacity(0.05),
                                    mode.accentColor.opacity(isPressed ? 0.3 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: mode.accentColor.opacity(isPressed ? 0.15 : 0.05), radius: isPressed ? 12 : 4)
            )
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isPressed = pressing }
        }, perform: {})
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
    static func == (lhs: GameMode, rhs: GameMode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
