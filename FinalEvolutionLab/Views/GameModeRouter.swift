import SwiftUI

// MARK: - GameModeRouter
// Central dispatch view: routes any GameModeId to the correct dedicated view.
// When UnityFramework is loaded, game modes render inside Unity for full 3D environments.
// SwiftUI Canvas implementations serve as fallback when Unity is not yet available.
// IMPORTANT: .marketBrowse routes to MarketBrowseView — NOT through game session flow.

struct GameModeRouter: View {
    let gameMode: GameMode
    let viewModel: LabViewModel

    @State private var unityManager = UnityManager.shared

    @ViewBuilder
    var body: some View {
        routedView
            .onDisappear {
                NexusEngine.shared.endSession()
            }
    }

    @ViewBuilder
    private var routedView: some View {
        if unityManager.isUnityLoaded, let unityMode = gameMode.id.unityMode {
            // Unity runtime is active — send game mode config and display the Unity view.
            UnityContainerView(mode: unityMode)
                .onAppear { sendGameModeToUnity(unityMode) }
        } else {
            swiftUIFallback
        }
    }

    // Sends game mode identifier to Unity so the C# side can load the correct scene.
    private func sendGameModeToUnity(_ mode: UnityMode) {
        unityManager.sendMessageToGO("GameModeReceiver", method: "OnGameMode", message: mode.rawValue)
    }

    @ViewBuilder
    private var swiftUIFallback: some View {
        switch gameMode.id {
        case .basketballHeadToHead:
            BasketballH2HGameView(viewModel: viewModel)
        case .basketball3v3:
            Basketball3v3GameView(viewModel: viewModel)
        case .basketballDunkContest:
            BasketballDunkGameView(viewModel: viewModel)
        case .basketballIRL:
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

// MARK: - GameModeId → UnityMode mapping

private extension GameModeId {
    var unityMode: UnityMode? {
        switch self {
        case .basketballDunkContest:  return .basketballDunkContest
        case .basketball3v3:          return .basketball3v3
        case .basketballHeadToHead:   return .basketballHeadToHead
        case .basketballIRL:          return .basketballIRL
        case .karate:                 return .karate
        case .karateEndless:          return .karateEndless
        case .baseball:               return .baseball
        case .football:               return .football
        case .soccer:                 return .soccer
        case .golf:                   return .golf
        case .tennis:                 return .tennis
        case .volleyball:             return .volleyball
        case .gymnastics:             return .gymnastics
        case .surfing:                return .surfing
        case .skateboarding:          return .skateboarding
        case .snowboarding:           return .snowboarding
        case .brainBrawl:             return .brainBrawl
        case .whoSceneIt:             return .whoSceneIt
        case .courtCarnival:          return .courtCarnival
        // marketBrowse is a shop UI, never routed through Unity
        case .marketBrowse:           return nil
        }
    }
}
