import SwiftUI

// MARK: - GameModeRouter
// Central dispatch view: routes any GameModeId to the correct dedicated view.
// IMPORTANT: non-game modules route to module views — NOT through game session flow.

struct GameModeRouter: View {
    let gameMode: GameMode
    let viewModel: LabViewModel

    @ViewBuilder
    var body: some View {
        routedView
            .onDisappear {
                // End the NexusEngine session when the game view is dismissed.
                // endSession() is a no-op if no session is live (e.g. non-game modules).
                NexusEngine.shared.endSession()
            }
    }

    @ViewBuilder
    private var routedView: some View {
        switch gameMode.id {
        case .basketballHeadToHead, .venicePickup:
            BasketballH2HGameView(viewModel: viewModel)
        case .basketball3v3:
            Basketball3v3GameView(viewModel: viewModel)
        case .basketballDunkContest3D:
            BasketballDunkGameView(viewModel: viewModel)
        case .basketballDunkContestIRL:
            IRLDunkView(viewModel: viewModel, gameMode: gameMode)
        case .karate:
            KarateGameView(viewModel: viewModel)
        case .karateEndless:
            KarateEndlessGameView(viewModel: viewModel)
        case .baseball:
            BaseballGameView(viewModel: viewModel, gameMode: gameMode)
        case .football:
            FootballGameView(viewModel: viewModel, gameMode: gameMode)
        case .soccer:
            SoccerGameView(viewModel: viewModel, gameMode: gameMode)
        case .golf:
            GolfGameView(viewModel: viewModel, gameMode: gameMode)
        case .tennis:
            TennisGameView(viewModel: viewModel, gameMode: gameMode)
        case .volleyball:
            VolleyballGameView(viewModel: viewModel, gameMode: gameMode)
        case .gymnastics:
            GymnasticsGameView(viewModel: viewModel, gameMode: gameMode)
        case .surfing:
            SurfingGameView(viewModel: viewModel, gameMode: gameMode)
        case .skateboarding:
            SkateboardingGameView(viewModel: viewModel, gameMode: gameMode)
        case .snowboarding:
            SnowboardingGameView(viewModel: viewModel, gameMode: gameMode)
        case .brainBrawl:
            BrainBrawlView(viewModel: viewModel, gameMode: gameMode)
        case .whoSceneIt:
            WhoSceneItView(viewModel: viewModel, gameMode: gameMode)
        case .courtCarnival:
            CourtCarnivalView(viewModel: viewModel, gameMode: gameMode)
        case .marketBrowse:
            // Not a game session — no PRQ delta, no session receipt, no shards per round.
            MarketBrowseView(viewModel: viewModel)
        case .movementLab:
            // Not a game session — education-only preview surfaced from the backend registry.
            EducationHubView(viewModel: viewModel)
        }
    }
}
