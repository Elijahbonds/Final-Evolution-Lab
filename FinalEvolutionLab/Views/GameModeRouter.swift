import SwiftUI

// MARK: - GameModeRouter
// Central dispatch view: special native destinations first; NEXUS runtime modes fall back to GamePlayView.
// IMPORTANT: .marketBrowse routes to MarketBrowseView — NOT through game session flow.

struct GameModeRouter: View {
    let gameMode: GameMode
    let viewModel: LabViewModel
    var sessionReadiness: Double = 50
    var generatorHudTheme: NexusGeneratorHudTheme? = nil
    var skipMatchLobbyForScreenshotHarness: Bool = false
    var onDismiss: () -> Void = {}

    @ViewBuilder
    var body: some View {
        routedView
    }

    @ViewBuilder
    private var routedView: some View {
        switch gameMode.id {
        case .basketballDunkContestIRL:
            IRLDunkView(viewModel: viewModel, gameMode: gameMode)
        case .brainBrawl:
            BrainBrawl2DView(viewModel: viewModel, gameMode: gameMode, onDismiss: onDismiss)
        case .marketBrowse:
            // Not a game session — no PRQ delta, no session receipt, no shards per round.
            MarketBrowseView(viewModel: viewModel)
        default:
            GamePlayView(
                viewModel: viewModel,
                gameMode: gameMode,
                sessionReadiness: sessionReadiness,
                generatorHudTheme: generatorHudTheme,
                skipMatchLobbyForScreenshotHarness: skipMatchLobbyForScreenshotHarness
            )
        }
    }
}
