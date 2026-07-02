import Foundation

/// Canonical template prompts for all 18 playable arena modes (excludes `market_browse`).
enum NexusGameGeneratorTemplates {
    struct Template: Identifiable, Sendable {
        let id: String
        let title: String
        let subtitle: String
        let prompt: String
        let category: String
    }

    static let featuredIds: Set<String> = [
        "basketball_dunk",
        "karate_endless",
        "court_carnival",
        "brain_brawl",
    ]

    static let all: [Template] = [
        Template(
            id: "basketball_h2h",
            title: "Head to Head",
            subtitle: "Venice 1v1",
            prompt: "Head to head basketball pickup game on Venice beach court",
            category: "Basketball"
        ),
        Template(
            id: "basketball_dunk",
            title: "Dunk Contest",
            subtitle: "Venice beach showdown",
            prompt: "Hard basketball dunk contest on Venice beach court with orange hoops",
            category: "Basketball"
        ),
        Template(
            id: "basketball_3v3",
            title: "3v3 Streetball",
            subtitle: "Venice street run",
            prompt: "Intense 3v3 streetball on Venice beach court",
            category: "Basketball"
        ),
        Template(
            id: "karate_h2h",
            title: "Karate 1v1",
            subtitle: "Zen dojo duel",
            prompt: "Karate sparring match in zen dojo — competitive difficulty",
            category: "Combat"
        ),
        Template(
            id: "karate_endless",
            title: "Karate Endless",
            subtitle: "Wave survival dojo",
            prompt: "Karate endless wave challenge in zen dojo — intense difficulty",
            category: "Combat"
        ),
        Template(
            id: "baseball",
            title: "Home Run Derby",
            subtitle: "Park slugfest",
            prompt: "Home run derby at the baseball park — hard difficulty",
            category: "Field"
        ),
        Template(
            id: "football",
            title: "Kick Return",
            subtitle: "Gridiron stadium",
            prompt: "Kick return challenge at gridiron stadium — elite difficulty",
            category: "Field"
        ),
        Template(
            id: "soccer",
            title: "Penalty Shootout",
            subtitle: "Stadium spot kicks",
            prompt: "Penalty shootout at soccer stadium — normal difficulty",
            category: "Field"
        ),
        Template(
            id: "golf",
            title: "Closest to Pin",
            subtitle: "Links course",
            prompt: "Closest to pin golf challenge on links course — casual difficulty",
            category: "Precision"
        ),
        Template(
            id: "tennis",
            title: "Rally Ace",
            subtitle: "Court rally",
            prompt: "Tennis rally ace match on hard court — competitive difficulty",
            category: "Precision"
        ),
        Template(
            id: "volleyball",
            title: "Sand Rally",
            subtitle: "Beach sand court",
            prompt: "Volleyball sand court rally match — normal difficulty",
            category: "Precision"
        ),
        Template(
            id: "gymnastics",
            title: "Floor Routine",
            subtitle: "Training floor",
            prompt: "Gymnastics floor routine on training floor — hard difficulty",
            category: "Academy"
        ),
        Template(
            id: "surfing",
            title: "Surf Break",
            subtitle: "Venice surf line",
            prompt: "Surfing rhythm session at Venice surf break — casual difficulty",
            category: "Board"
        ),
        Template(
            id: "skateboarding",
            title: "Skate Park",
            subtitle: "Street lines",
            prompt: "Skateboard trick lines at skate park — normal difficulty",
            category: "Board"
        ),
        Template(
            id: "snowboarding",
            title: "Mountain Slope",
            subtitle: "Halfpipe run",
            prompt: "Snowboarding halfpipe run on mountain slope — intense difficulty",
            category: "Board"
        ),
        Template(
            id: "brain_brawl",
            title: "Brain Brawl",
            subtitle: "Neuro trivia arena",
            prompt: "Brain brawl trivia quiz in neuro arena — hard difficulty",
            category: "Academy"
        ),
        Template(
            id: "who_scene_it",
            title: "Who Scene It",
            subtitle: "Film quiz night",
            prompt: "Who scene it film quiz party in neuro arena — casual difficulty",
            category: "Party"
        ),
        Template(
            id: "court_carnival",
            title: "Court Carnival",
            subtitle: "Trick-shot party",
            prompt: "Court carnival party mode with trick shot pads on Venice court",
            category: "Party"
        ),
    ]

    static var featured: [Template] {
        all.filter { featuredIds.contains($0.id) }
    }

    static var browseAll: [Template] {
        all.filter { !featuredIds.contains($0.id) }
    }

    static func template(forModeId modeId: String) -> Template? {
        all.first { $0.id == modeId }
    }

    /// Registry-backed venue + capability for template gallery cards.
    static func registryMode(for template: Template) -> GameMode? {
        GameModeRegistry.playableMode(forRegistryId: template.id)
    }
}
