import SwiftUI

// MARK: - GameModeRouter
// Central dispatch view: routes any GameModeId to the correct dedicated view.
// IMPORTANT: .marketBrowse routes to MarketBrowseView — NOT through game session flow.

struct GameModeRouter: View {
    let gameMode: GameMode
    let viewModel: LabViewModel

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
        switch gameMode.id {
        case .basketballHeadToHead, .venicePickup:
            BasketballH2HGameView(viewModel: viewModel)
        case .basketball3v3:
            Basketball3v3GameView(viewModel: viewModel)
        case .basketballDunkContest3D:
            BasketballDunkGameView(viewModel: viewModel)
        case .basketballDunkContestIRL:
            IRLDunkView(viewModel: viewModel)
        case .karate:
            KarateGameView(viewModel: viewModel)
        case .karateEndless:
            KarateEndlessGameView(viewModel: viewModel)
        case .baseball:
            BaseballGameView(viewModel: viewModel)
        case .football:
            FootballGameView(viewModel: viewModel)
        case .soccer:
            SoccerGameView(viewModel: viewModel)
        case .golf:
            GolfGameView(viewModel: viewModel)
        case .tennis:
            TennisGameView(viewModel: viewModel)
        case .volleyball:
            VolleyballGameView(viewModel: viewModel)
        case .gymnastics:
            GymnasticsGameView(viewModel: viewModel)
        case .surfing:
            SurfingGameView(viewModel: viewModel)
        case .skateboarding:
            SkateboardingGameView(viewModel: viewModel)
        case .snowboarding:
            SnowboardingGameView(viewModel: viewModel)
        case .brainBrawl:
            BrainBrawlView(viewModel: viewModel)
        case .whoSceneIt:
            WhoSceneItView(viewModel: viewModel, gameMode: gameMode)
        case .courtCarnival:
            CourtCarnivalView(viewModel: viewModel, gameMode: gameMode)
        case .marketBrowse:
            // Not a game session — no PRQ delta, no session receipt, no shards per round.
            MarketBrowseView(viewModel: viewModel)
        }
    }
}
