import SwiftUI

// MARK: - GameModeRouter
// Central dispatch view: routes any GameModeId to the correct dedicated view.
// IMPORTANT: .marketBrowse routes to MarketBrowseView — NOT through game session flow.

struct GameModeRouter: View {
    let gameMode: GameMode
    let viewModel: LabViewModel
    let sessionReadiness: Double
    let generatorHudTheme: NexusGeneratorHudTheme?
    let onDismiss: () -> Void

    init(
        gameMode: GameMode,
        viewModel: LabViewModel,
        sessionReadiness: Double = 50,
        generatorHudTheme: NexusGeneratorHudTheme? = nil,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.gameMode = gameMode
        self.viewModel = viewModel
        self.sessionReadiness = sessionReadiness
        self.generatorHudTheme = generatorHudTheme
        self.onDismiss = onDismiss
    }

    @ViewBuilder
    var body: some View {
        routedView
            .onDisappear {
                // End the NexusEngine session when the game view is dismissed.
                // endSession() is a no-op if no session is live (e.g. .marketBrowse).
                NexusEngine.shared.endSession()
            }
    }

    @ViewBuilder
    private var routedView: some View {
        if gameMode.id.isIRLDunkContest {
            IRLDunkView(viewModel: viewModel, gameMode: gameMode)
        } else if gameMode.id == .marketBrowse {
            // Not a game session — no PRQ delta, no session receipt, no shards per round.
            MarketBrowseView(viewModel: viewModel)
        } else if gameMode.id == .brainBrawl {
            BrainBrawl2DView(
                viewModel: viewModel,
                gameMode: gameMode,
                onDismiss: onDismiss
            )
        } else {
            GamePlayView(
                viewModel: viewModel,
                gameMode: gameMode,
                sessionReadiness: sessionReadiness,
                generatorHudTheme: generatorHudTheme
            )
        }
    }
}
