import SwiftUI

// MARK: - Arena venue routing (ARENAS UI ↔ environments)

/// Maps high-level venues to `GameModeRegistry` / `GameModeId` for a single “dashboard → Arena” handoff.
enum VenueManager {
    enum Venue: String, CaseIterable, Sendable {
        case veniceBeach
        case dojo
        case stadiumDiamond
        case stadiumField
        case stadiumPitch
        case golfGreen
        case beachCourt
        case academyArena

        var environmentName: String {
            switch self {
            case .veniceBeach: return "Venice Beach Court"
            case .dojo: return "Dojo Arena"
            case .stadiumDiamond: return "Stadium Diamond"
            case .stadiumField: return "Stadium Field"
            case .stadiumPitch: return "Stadium Pitch"
            case .golfGreen: return "Golf Green"
            case .beachCourt: return "Beach Court"
            case .academyArena: return "Arena"
            }
        }

        /// Default mode to open when jumping in from a hub tile.
        var defaultModeId: GameModeId {
            switch self {
            case .veniceBeach: return .basketballHeadToHead
            case .dojo: return .karate
            case .stadiumDiamond: return .baseball
            case .stadiumField: return .football
            case .stadiumPitch: return .soccer
            case .golfGreen: return .golf
            case .beachCourt: return .volleyball
            case .academyArena: return .gymnastics
            }
        }
    }

    /// Switch to Arena tab and preselect a mode for the next `ArenaView` appear.
    @MainActor
    static func openVenue(_ venue: Venue, viewModel: LabViewModel, selectedTab: Binding<AppTab>) {
        viewModel.preselectedArenaModeId = venue.defaultModeId
        selectedTab.wrappedValue = .arena
        PRQManager.shared.sync(from: viewModel)
    }

    @MainActor
    static func openMode(_ modeId: GameModeId, viewModel: LabViewModel, selectedTab: Binding<AppTab>) {
        viewModel.preselectedArenaModeId = modeId
        selectedTab.wrappedValue = .arena
        PRQManager.shared.sync(from: viewModel)
    }

    /// Venice: hoops vs dunk lab redirect (dunk uses Lab full-screen flow).
    @MainActor
    static func openDunkContestLab(viewModel: LabViewModel, selectedTab: Binding<AppTab>) {
        viewModel.openDunkOnNextLabAppearance = true
        selectedTab.wrappedValue = .lab
        PRQManager.shared.sync(from: viewModel)
    }
}
