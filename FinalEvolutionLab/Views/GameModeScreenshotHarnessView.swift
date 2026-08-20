import SwiftUI

/// PR / docs-only: launch app with argument `-ScreenshotHarness` to capture Arena grid + every ``GameMode`` destination without stepping through multiplayer lobby.
struct GameModeScreenshotHarnessView: View {
    @State private var viewModel = LabViewModel()
    @State private var modeIndex = 0
    /// 0 = full Arena mode grid, 1 = GamePlay chrome for selected mode.
    @State private var section = 0

    private var modes: [GameMode] { GameModeRegistry.all }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sectionPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                if section == 0 {
                    GameModeSelectionView(viewModel: viewModel)
                } else {
                    gameplayHarnessColumn
                }
            }
            .background(Theme.deepBlack)
            .navigationTitle("Screenshot Harness")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var sectionPicker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("Arena grid") {
                    section = 0
                }
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(section == 0 ? Theme.brandCyan : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(section == 0 ? Theme.brandCyan.opacity(0.15) : Color.white.opacity(0.06))
                .clipShape(Capsule())
                .accessibilityIdentifier("ScreenshotHarnessArenaGrid")

                Button("Gameplay") {
                    section = 1
                }
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(section == 1 ? Theme.brandCyan : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(section == 1 ? Theme.brandCyan.opacity(0.15) : Color.white.opacity(0.06))
                .clipShape(Capsule())
                .accessibilityIdentifier("ScreenshotHarnessGameplay")
            }

            if section == 1 {
                VStack(spacing: 6) {
                    Text(modes[modeIndex].name)
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("ScreenshotHarnessModeTitle")

                    Text(modes[modeIndex].id.rawValue)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("ScreenshotHarnessModeId")

                    HStack(spacing: 16) {
                        Button("Previous mode") {
                            modeIndex = (modeIndex - 1 + modes.count) % modes.count
                        }
                        .accessibilityIdentifier("ScreenshotHarnessPrev")

                        Text("\(modeIndex + 1) / \(modes.count)")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                            .accessibilityIdentifier("ScreenshotHarnessCounter")

                        Button("Next mode") {
                            modeIndex = (modeIndex + 1) % modes.count
                        }
                        .accessibilityIdentifier("ScreenshotHarnessNext")
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var gameplayHarnessColumn: some View {
        GameModeRouter(
            viewModel: viewModel,
            gameMode: modes[modeIndex],
            sessionReadiness: 72,
            skipMatchLobbyForScreenshotHarness: true
        )
        .id(modes[modeIndex].id)
    }
}

