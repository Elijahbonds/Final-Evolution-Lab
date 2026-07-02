import Foundation
import SwiftUI

nonisolated struct CreatorLink: Sendable {
    enum LinkType: String, Sendable { case masterclass, imdb, product, website, youtube, instagram, spotify, gallery, tiktok, twitter, podcast }
    let type: LinkType
    let label: String
    let url: String
}

nonisolated struct CreatorCard: Identifiable, Sendable {
    let id: String
    let creatorName: String
    let title: String
    let description: String
    let costShards: Int
    let iconName: String
    let accentColor: Color
    let metricsBoost: PerformanceMetrics
    let movementSignature: MovementSignature
    let masterclassURL: String?
    let productURL: String?
    let imdbURL: String?
    /// Artists / DJs — surfaced in IP showcase.
    let spotifyURL: String?
    /// Visual artists — surfaced in IP showcase.
    let artGalleryURL: String?
    let socialURL: String?
    let creatorBio: String?
    let showcaseTagline: String
    let showcaseHighlights: [String]
    let miniBio: String
    let links: [CreatorLink]
    let meshAssetId: String?
    let usesCatalogPlaceholderPreview: Bool

    init(
        id: String,
        creatorName: String,
        title: String,
        description: String,
        costShards: Int,
        iconName: String,
        accentColor: Color,
        metricsBoost: PerformanceMetrics,
        movementSignature: MovementSignature,
        masterclassURL: String? = nil,
        productURL: String? = nil,
        imdbURL: String? = nil,
        spotifyURL: String? = nil,
        artGalleryURL: String? = nil,
        socialURL: String? = nil,
        creatorBio: String? = nil,
        showcaseTagline: String = "",
        showcaseHighlights: [String] = [],
        miniBio: String = "",
        links: [CreatorLink] = [],
        meshAssetId: String? = nil,
        usesCatalogPlaceholderPreview: Bool = false
    ) {
        self.id = id
        self.creatorName = creatorName
        self.title = title
        self.description = description
        self.costShards = costShards
        self.iconName = iconName
        self.accentColor = accentColor
        self.metricsBoost = metricsBoost
        self.movementSignature = movementSignature
        self.masterclassURL = masterclassURL
        self.productURL = productURL
        self.imdbURL = imdbURL
        self.spotifyURL = spotifyURL
        self.artGalleryURL = artGalleryURL
        self.socialURL = socialURL
        self.creatorBio = creatorBio
        self.showcaseTagline = showcaseTagline
        self.showcaseHighlights = showcaseHighlights
        self.miniBio = miniBio
        self.links = links
        self.meshAssetId = meshAssetId
        self.usesCatalogPlaceholderPreview = usesCatalogPlaceholderPreview
    }

    var resolvedShowcaseTagline: String {
        showcaseTagline.isEmpty ? description : showcaseTagline
    }

    var resolvedMiniBio: String {
        if !miniBio.isEmpty { return miniBio }
        return creatorBio ?? description
    }

    var resolvedShowcaseHighlights: [String] {
        if !showcaseHighlights.isEmpty { return showcaseHighlights }
        return [description]
    }

    var resolvedLinks: [CreatorLink] {
        if !links.isEmpty { return links }
        var out: [CreatorLink] = []
        if let url = masterclassURL {
            out.append(CreatorLink(type: .masterclass, label: "\(creatorName) Masterclass", url: url))
        }
        if let url = productURL {
            out.append(CreatorLink(type: .product, label: "\(title) Product", url: url))
        }
        if let url = imdbURL {
            out.append(CreatorLink(type: .imdb, label: "IMDb", url: url))
        }
        if let url = spotifyURL {
            out.append(CreatorLink(type: .spotify, label: "\(creatorName) on Spotify", url: url))
        }
        if let url = artGalleryURL {
            out.append(CreatorLink(type: .gallery, label: "\(creatorName) Gallery", url: url))
        }
        if let url = socialURL {
            out.append(CreatorLink(type: .instagram, label: creatorName, url: url))
        }
        return out
    }

    @MainActor static func card(forId id: String) -> CreatorCard? {
        catalog.first { $0.id == id }
    }

    @MainActor static func activeCard(for profile: UserProfile) -> CreatorCard? {
        guard let state = profile.activeCreatorCard else { return nil }
        return card(forId: state.cardId)
    }

    @MainActor static var catalog: [CreatorCard] = [
        CreatorCard(
            id: "amir_smith",
            creatorName: "Amir Smith",
            title: "Amir Smith Signature",
            description: "Elite guard footwork and explosive first step. +14 PRQ, +22 Vertical, +12 Neural Drive.",
            costShards: 800,
            iconName: "figure.run.treadmill",
            accentColor: Color(red: 0.1, green: 0.7, blue: 1.0),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 12,
                prqScore: 14,
                readinessScore: 8,
                verticalPotential: 22,
                neuralDrive: 12,
                currentOutfit: "amir_smith"
            ),
            movementSignature: MovementSignature(
                style: .explosive,
                jumpApex: 1.4,
                hangTimeFactor: 1.5,
                firstStepBurst: 1.6,
                limbEmission: 0.65,
                trailColor: Color(red: 0.1, green: 0.7, blue: 1.0)
            ),
            showcaseTagline: "First step is a weapon. Let the data prove it.",
            showcaseHighlights: [
                "14-year pro career at elite guard position",
                "Patented 3-step deceleration-acceleration cycle",
                "Venice Beach open run champion · 3 consecutive seasons",
                "Meshy athlete scan: MESHY_amir_smith_athlete",
                "Training philosophy: slow is smooth, smooth is fast"
            ],
            miniBio: "Amir Smith is an elite guard with 14 years of professional experience and a reputation for the most explosive first step in the game. He trains at Venice Beach and uses data-driven movement analysis to coach the next generation of guards.",
            links: [
                CreatorLink(type: .product, label: "Amir Smith Training Program", url: "https://amirsmith.training"),
                CreatorLink(type: .instagram, label: "@amirsmithhoops", url: "https://instagram.com/amirsmithhoops"),
                CreatorLink(type: .youtube, label: "Amir Smith Movement Lab", url: "https://youtube.com/@amirsmith")
            ],
            usesCatalogPlaceholderPreview: true
        ),
        CreatorCard(
            id: "coach_v_elite",
            creatorName: "Coach V",
            title: "Coach V Elite Card",
            description: "Unlock Coach V's elite movement data. +15 PRQ, +20 Vertical, +10 Neural Drive.",
            costShards: 500,
            iconName: "crown.fill",
            accentColor: .yellow,
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 10,
                prqScore: 15,
                readinessScore: 5,
                verticalPotential: 20,
                neuralDrive: 10,
                currentOutfit: "coach_v"
            ),
            movementSignature: MovementSignature(
                style: .explosive,
                jumpApex: 1.3,
                hangTimeFactor: 1.4,
                firstStepBurst: 1.2,
                limbEmission: 0.5,
                trailColor: .yellow
            ),
            productURL: "https://finalevolutiongroup.com/products/coach-v-elite",
            imdbURL: "https://www.imdb.com/title/tt0468569/",
            creatorBio: "Elite performance coach · movement science · Creator Card IP showcase."
        ),
        CreatorCard(
            id: "bonds_bounce",
            creatorName: "Elijah Bonds",
            title: "Bonds Bounce Blueprint",
            description: "The vertical jump architecture. +12 PRQ, +25 Vertical, +8 Efficiency.",
            costShards: 750,
            iconName: "bolt.trianglebadge.exclamationmark.fill",
            accentColor: Color(red: 0.95, green: 0.49, blue: 0.15),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 8,
                prqScore: 12,
                readinessScore: 5,
                verticalPotential: 25,
                neuralDrive: 8,
                currentOutfit: "bonds_bounce"
            ),
            movementSignature: MovementSignature(
                style: .vertical,
                jumpApex: 1.5,
                hangTimeFactor: 1.6,
                firstStepBurst: 1.0,
                limbEmission: 0.6,
                trailColor: Color(red: 0.95, green: 0.49, blue: 0.15)
            ),
            masterclassURL: "https://finalevolutiongroup.com/masterclass/bonds-bounce",
            productURL: "https://finalevolutiongroup.com/products/bonds-bounce",
            socialURL: "https://finalevolutiongroup.com",
            showcaseTagline: "Vertical architecture built on PRQ science.",
            showcaseHighlights: [
                "Founder of Final Evolution Lab · NEXUS athlete evolution",
                "Bonds Standard methodology · drawing-in + V-stance stack",
                "PRQ-driven vertical jump prescriptions",
                "Venice Beach flight lab origin story"
            ],
            miniBio: "Founder of Final Evolution Lab — vertical architecture, PRQ science, and NEXUS athlete evolution.",
            usesCatalogPlaceholderPreview: true
        ),
        CreatorCard(
            id: "flight_lab",
            creatorName: "Flight Lab",
            title: "Flight Lab Pro Card",
            description: "Advanced flight mechanics data. +10 PRQ, +18 Vertical, +15 Neural Drive.",
            costShards: 600,
            iconName: "airplane.departure",
            accentColor: Color(red: 0, green: 0.95, blue: 0.9),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 5,
                prqScore: 10,
                readinessScore: 8,
                verticalPotential: 18,
                neuralDrive: 15,
                currentOutfit: "flight_lab"
            ),
            movementSignature: MovementSignature(
                style: .fluid,
                jumpApex: 1.2,
                hangTimeFactor: 1.8,
                firstStepBurst: 1.1,
                limbEmission: 0.7,
                trailColor: Color(red: 0, green: 0.95, blue: 0.9)
            )
        ),
        CreatorCard(
            id: "neural_max",
            creatorName: "Neural Max",
            title: "Neural Max Override",
            description: "Peak CNS recruitment protocols. +8 PRQ, +12 Vertical, +25 Neural Drive.",
            costShards: 400,
            iconName: "brain.head.profile.fill",
            accentColor: Color(red: 0.6, green: 0.2, blue: 1.0),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 5,
                prqScore: 8,
                readinessScore: 10,
                verticalPotential: 12,
                neuralDrive: 25,
                currentOutfit: "neural_max"
            ),
            movementSignature: MovementSignature(
                style: .neural,
                jumpApex: 1.1,
                hangTimeFactor: 1.2,
                firstStepBurst: 1.5,
                limbEmission: 0.9,
                trailColor: Color(red: 0.6, green: 0.2, blue: 1.0)
            )
        ),
        CreatorCard(
            id: "scene_directors_cut",
            creatorName: "Director Stella",
            title: "Director's Cut Monologue",
            description: "Stella Adler's dramatic monologue drill. Practice vocal range and emotional pacing. +15 PRQ, +20 Neural Drive.",
            costShards: 550,
            iconName: "film.fill",
            accentColor: .purple,
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 8,
                prqScore: 15,
                readinessScore: 5,
                verticalPotential: 10,
                neuralDrive: 20,
                currentOutfit: "directors_cut"
            ),
            movementSignature: MovementSignature(
                style: .fluid,
                jumpApex: 1.1,
                hangTimeFactor: 1.2,
                firstStepBurst: 1.0,
                limbEmission: 0.4,
                trailColor: .purple
            )
        ),
        CreatorCard(
            id: "scene_method_acting",
            creatorName: "Method Master",
            title: "Method Acting Dialogue Drill",
            description: "A deep character immersion exercise focusing on subtext and emotional memory. +10 PRQ, +15 Readiness.",
            costShards: 450,
            iconName: "theatermasks.fill",
            accentColor: .red,
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 12,
                prqScore: 10,
                readinessScore: 15,
                verticalPotential: 5,
                neuralDrive: 12,
                currentOutfit: "method_acting"
            ),
            movementSignature: MovementSignature(
                style: .neural,
                jumpApex: 1.0,
                hangTimeFactor: 1.1,
                firstStepBurst: 1.3,
                limbEmission: 0.5,
                trailColor: .red
            )
        ),
        CreatorCard(
            id: "scene_action_sequence",
            creatorName: "Stunt Director Jack",
            title: "Action Sequence Cue",
            description: "High-intensity physical blocking and spatial awareness challenge. +12 PRQ, +25 Vertical.",
            costShards: 650,
            iconName: "bolt.fill",
            accentColor: .orange,
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 6,
                prqScore: 12,
                readinessScore: 8,
                verticalPotential: 25,
                neuralDrive: 10,
                currentOutfit: "action_sequence"
            ),
            movementSignature: MovementSignature(
                style: .explosive,
                jumpApex: 1.4,
                hangTimeFactor: 1.3,
                firstStepBurst: 1.5,
                limbEmission: 0.8,
                trailColor: .orange
            )
        ),
        CreatorCard(
            id: "tyler_currie_flight",
            creatorName: "Tyler Currie",
            title: "Currie Flight Mechanics",
            description: "Reactive jump mechanics and hang-time control. +11 PRQ, +20 Vertical.",
            costShards: 550,
            iconName: "airplane",
            accentColor: Color(red: 0.35, green: 0.85, blue: 0.95),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 7, prqScore: 11, readinessScore: 8,
                verticalPotential: 20, neuralDrive: 10, currentOutfit: "tyler_currie"
            ),
            movementSignature: MovementSignature(
                style: .fluid, jumpApex: 1.35, hangTimeFactor: 1.5,
                firstStepBurst: 1.05, limbEmission: 0.55,
                trailColor: Color(red: 0.35, green: 0.85, blue: 0.95)
            ),
            masterclassURL: "https://finalevolutiongroup.com/masterclass/tyler-currie",
            showcaseTagline: "Hang time is a skill — train the reactive window.",
            miniBio: "Flight mechanics coach — reactive plyometrics and contest hang-time packages.",
            usesCatalogPlaceholderPreview: true
        ),
        CreatorCard(
            id: "chris_staples_highlights",
            creatorName: "Chris Staples",
            title: "Staples Highlight Reel",
            description: "Showtime dunk sequencing and crowd-energy cues. +10 PRQ, +18 Vertical.",
            costShards: 500,
            iconName: "play.rectangle.fill",
            accentColor: Color(red: 1.0, green: 0.78, blue: 0.2),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 5, prqScore: 10, readinessScore: 7,
                verticalPotential: 18, neuralDrive: 14, currentOutfit: "chris_staples"
            ),
            movementSignature: MovementSignature(
                style: .explosive, jumpApex: 1.38, hangTimeFactor: 1.42,
                firstStepBurst: 1.2, limbEmission: 0.7,
                trailColor: Color(red: 1.0, green: 0.78, blue: 0.2)
            ),
            artGalleryURL: "https://finalevolutiongroup.com/gallery/chris-staples",
            socialURL: "https://youtube.com",
            showcaseHighlights: [
                "Showtime dunk sequencing for contest energy",
                "Crowd-read finish packages",
                "Visual highlight reel archive"
            ],
            miniBio: "Highlight creator — showtime sequences, crowd reads, and contest presentation.",
            usesCatalogPlaceholderPreview: true
        ),
        CreatorCard(
            id: "andrew_mcfly_parkour",
            creatorName: "Andrew McFly",
            title: "McFly Parkour Flow",
            description: "First-step burst and spatial awareness. +9 PRQ, +16 Neural Drive.",
            costShards: 480,
            iconName: "figure.run",
            accentColor: Color(red: 0.55, green: 0.95, blue: 0.35),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 9, prqScore: 9, readinessScore: 10,
                verticalPotential: 14, neuralDrive: 16, currentOutfit: "andrew_mcfly"
            ),
            movementSignature: MovementSignature(
                style: .explosive, jumpApex: 1.2, hangTimeFactor: 1.25,
                firstStepBurst: 1.45, limbEmission: 0.5,
                trailColor: Color(red: 0.55, green: 0.95, blue: 0.35)
            ),
            artGalleryURL: "https://finalevolutiongroup.com/gallery/andrew-mcfly",
            creatorBio: "Parkour flow specialist — first-step burst, wall approaches, and spatial reads.",
            miniBio: "Parkour flow specialist — first-step burst, wall approaches, and spatial reads.",
            usesCatalogPlaceholderPreview: true
        ),
        CreatorCard(
            id: "ty2_skills_lab",
            creatorName: "Ty2.0",
            title: "Ty2.0 Skills Lab",
            description: "Handle-to-hang combo drills. +10 PRQ, +15 Vertical, +12 Neural.",
            costShards: 520,
            iconName: "basketball.fill",
            accentColor: Color(red: 0.95, green: 0.35, blue: 0.55),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 6, prqScore: 10, readinessScore: 8,
                verticalPotential: 15, neuralDrive: 12, currentOutfit: "ty2_skills"
            ),
            movementSignature: MovementSignature(
                style: .fluid, jumpApex: 1.25, hangTimeFactor: 1.35,
                firstStepBurst: 1.25, limbEmission: 0.6,
                trailColor: Color(red: 0.95, green: 0.35, blue: 0.55)
            ),
            masterclassURL: "https://finalevolutiongroup.com/masterclass/ty2",
            spotifyURL: "https://open.spotify.com/artist/ty2skills",
            miniBio: "Skills lab creator — handle-to-hang combos, game-speed footwork, and DJ sets.",
            usesCatalogPlaceholderPreview: true
        ),
        CreatorCard(
            id: "baller_bree_court",
            creatorName: "Baller Bree",
            title: "Baller Bree Court Presence",
            description: "Women's game footwork and finish packages. +11 PRQ, +14 Vertical.",
            costShards: 500,
            iconName: "figure.female",
            accentColor: Color(red: 0.85, green: 0.45, blue: 0.95),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 8, prqScore: 11, readinessScore: 9,
                verticalPotential: 14, neuralDrive: 11, currentOutfit: "baller_bree"
            ),
            movementSignature: MovementSignature(
                style: .fluid, jumpApex: 1.22, hangTimeFactor: 1.3,
                firstStepBurst: 1.18, limbEmission: 0.55,
                trailColor: Color(red: 0.85, green: 0.45, blue: 0.95)
            ),
            spotifyURL: "https://open.spotify.com/artist/ballerbree",
            socialURL: "https://instagram.com",
            miniBio: "Women's basketball creator — court presence, footwork packages, and finish craft.",
            usesCatalogPlaceholderPreview: true
        ),
        CreatorCard(
            id: "bald_barbie_strength",
            creatorName: "Bald Barbie",
            title: "Bald Barbie Strength Arc",
            description: "Strength-to-flight transfer and core stability. +8 PRQ, +12 Readiness.",
            costShards: 450,
            iconName: "dumbbell.fill",
            accentColor: Color(red: 0.98, green: 0.55, blue: 0.75),
            metricsBoost: PerformanceMetrics(
                efficiencyScore: 10, prqScore: 8, readinessScore: 12,
                verticalPotential: 12, neuralDrive: 9, currentOutfit: "bald_barbie"
            ),
            movementSignature: MovementSignature(
                style: .standard, jumpApex: 1.15, hangTimeFactor: 1.2,
                firstStepBurst: 1.1, limbEmission: 0.45,
                trailColor: Color(red: 0.98, green: 0.55, blue: 0.75)
            ),
            productURL: "https://finalevolutiongroup.com/products/bald-barbie",
            miniBio: "Strength and mobility creator — core stability, hinge patterns, and flight transfer.",
            usesCatalogPlaceholderPreview: true
        ),
    ]

    /// Encoded in each card’s QR. Optional ``athleteId`` scopes the active equipped card for sharing.
    func qrPayload(includeAthleteId athleteId: String?) -> String {
        var s = "https://finalevolutiongroup.com/creator-card/\(id)"
        if let raw = athleteId?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
           let enc = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            s += "?athlete=\(enc)"
        }
        return s
    }
}

nonisolated struct MovementSignature: Sendable {
    let style: MovementStyle
    let jumpApex: Double
    let hangTimeFactor: Double
    let firstStepBurst: Double
    let limbEmission: Double
    let trailColor: Color
}

nonisolated enum MovementStyle: String, Sendable {
    case explosive
    case vertical
    case fluid
    case neural
    case standard

    var animationSpeed: Double {
        switch self {
        case .explosive: 0.8
        case .vertical: 1.0
        case .fluid: 1.2
        case .neural: 0.7
        case .standard: 1.0
        }
    }
}
