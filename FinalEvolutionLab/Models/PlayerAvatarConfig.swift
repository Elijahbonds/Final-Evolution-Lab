import Foundation

// MARK: — Face Preset

/// Face geometry preset for the player's UE5 avatar.
/// `.elijahBonds` uses the dedicated `MESHY_elijah_bonds_athlete` model — the primary personal model.
/// All other presets fall back to generated meshes via Meshy text-to-3D with the supplied prompt.
nonisolated enum FacePreset: String, Codable, Sendable, CaseIterable {
    case elijahBonds     = "elijah_bonds"
    case chiseledAthlete = "chiseled_athletic"
    case roundAthlete    = "round_athletic"
    case sharpElite      = "sharp_elite"
    case naturalYouth    = "natural_youth"
    case squareJaw       = "square_jaw"

    var displayName: String {
        switch self {
        case .elijahBonds:      return "EB Model"
        case .chiseledAthlete:  return "Chiseled"
        case .roundAthlete:     return "Round"
        case .sharpElite:       return "Sharp"
        case .naturalYouth:     return "Natural"
        case .squareJaw:        return "Square Jaw"
        }
    }

    var meshySlotId: String { "MESHY_face_\(rawValue)" }
    var isPersonalModel: Bool { self == .elijahBonds }

    /// Meshy text-to-3D generation prompt for this face. Used when importing into UE5.
    var meshyGenerationPrompt: String {
        switch self {
        case .elijahBonds:
            return "Athletic Black male face, chiseled jawline, defined cheekbones, clean fade haircut, confident neutral expression, game-ready low-poly head mesh, stylized realism, PS3-era quality, young adult, no background."
        case .chiseledAthlete:
            return "Athletic male face, strong chiseled jawline, defined cheekbones, symmetrical sharp features, game-ready low-poly, stylized realism, neutral expression, no background."
        case .roundAthlete:
            return "Athletic male face, soft round features, wide eyes, approachable, game-ready low-poly, stylized realism, neutral expression, no background."
        case .sharpElite:
            return "Athletic male face, sharp angular features, high cheekbones, piercing focused gaze, elite athlete look, game-ready low-poly, stylized realism, no background."
        case .naturalYouth:
            return "Athletic male face, natural proportions, fresh young adult look, game-ready low-poly, stylized realism, neutral expression, no background."
        case .squareJaw:
            return "Athletic male face, strong square jaw, broad face, power athlete look, game-ready low-poly, stylized realism, neutral expression, no background."
        }
    }
}

// MARK: — Skin Tone

nonisolated enum PlayerSkinTone: String, Codable, Sendable, CaseIterable {
    case tone1 = "#FDDBB4"
    case tone2 = "#E8B88A"
    case tone3 = "#C68642"
    case tone4 = "#8D5524"
    case tone5 = "#4A2912"
    case tone6 = "#2C1A0E"

    var displayName: String {
        switch self {
        case .tone1: return "Fair"
        case .tone2: return "Light"
        case .tone3: return "Medium"
        case .tone4: return "Tan"
        case .tone5: return "Deep Brown"
        case .tone6: return "Deep"
        }
    }
    var hexValue: String { rawValue }
}

// MARK: — Hair

nonisolated enum PlayerHairStyle: String, Codable, Sendable, CaseIterable {
    case fade, taper, braids, afro, buzz, bald, waves, caesar, dreads, mohawk, long
    var displayName: String { rawValue.capitalized }
}

// MARK: — Outfit

nonisolated enum PlayerOutfitTier: String, Codable, Sendable {
    case standard   = "standard"
    case developing = "developing"
    case flight     = "flight"
    case elite      = "elite"

    var requiredPRQ: Double {
        switch self {
        case .standard:   return 0
        case .developing: return 50
        case .flight:     return 70
        case .elite:      return 85
        }
    }
    var displayName: String { rawValue.capitalized }
    var defaultJerseyHex: String {
        switch self {
        case .standard:   return "#00E5FF"
        case .developing: return "#00B4D8"
        case .flight:     return "#00F5FF"
        case .elite:      return "#8B5CF6"
        }
    }
}

nonisolated enum PlayerShoeStyle: String, Codable, Sendable, CaseIterable {
    case basketball, hiTop, running, training, skateboard, cleats
    var displayName: String { rawValue == "hiTop" ? "Hi-Top" : rawValue.capitalized }
}

nonisolated enum PlayerAccessory: String, Codable, Sendable, CaseIterable {
    case headband, wristband, chain, glasses, armband, kneeSleeve
    var displayName: String { rawValue == "kneeSleeve" ? "Knee Sleeve" : rawValue.capitalized }
}

// MARK: — PlayerAvatarConfig

/// Unified player avatar configuration.
/// Merges PRQ-derived body proportions + full appearance customization + Meshy 3D model reference.
/// This is the single source of truth for what the player looks like in Nexus Engine gameplay.
nonisolated struct PlayerAvatarConfig: Codable, Sendable, Identifiable {
    var id: String { userId }

    // Identity
    var userId: String
    var displayName: String

    // Body (PRQ-derived — set from scan, not user-editable)
    var heightScale: Double
    var weightScale: Double
    var limbLength: Double

    // Face
    var facePreset: FacePreset

    // Appearance
    var skinTone: PlayerSkinTone
    var hairStyle: PlayerHairStyle
    var hairColorHex: String

    // Outfit
    var outfitTier: PlayerOutfitTier
    var jerseyColorHex: String
    var shortsColorHex: String
    var shoeStyle: PlayerShoeStyle
    var shoeColorHex: String
    var accessories: [PlayerAccessory]

    // Aura / glow (PRQ-derived)
    var auraColorR: Double
    var auraColorG: Double
    var auraColorB: Double
    var trailIntensity: Double

    // Meshy 3D model reference
    /// Primary asset slot. "MESHY_elijah_bonds_athlete" for personal model; "MESHY_athlete_base_skeleton" for generated.
    var meshyAthleteSlotId: String
    var usePersonalModel: Bool
}

// MARK: — Factory methods

extension PlayerAvatarConfig {

    /// Build a `PlayerAvatarConfig` from a completed system scan. PRQ determines outfit tier and aura.
    static func fromScan(_ scan: SystemScanResult, userId: String, displayName: String) -> PlayerAvatarConfig {
        let prq = scan.prqScore
        let sc  = scan.avatarConfig

        let tier: PlayerOutfitTier
        switch prq {
        case 85...: tier = .elite
        case 70..<85: tier = .flight
        case 50..<70: tier = .developing
        default: tier = .standard
        }

        return PlayerAvatarConfig(
            userId: userId,
            displayName: displayName,
            heightScale: sc.heightScale,
            weightScale: sc.weightScale,
            limbLength: sc.limbLength,
            facePreset: .elijahBonds,
            skinTone: .tone4,
            hairStyle: .fade,
            hairColorHex: "#1A1A1A",
            outfitTier: tier,
            jerseyColorHex: tier.defaultJerseyHex,
            shortsColorHex: "#1A1A24",
            shoeStyle: .basketball,
            shoeColorHex: "#FFFFFF",
            accessories: [],
            auraColorR: sc.auraColorR,
            auraColorG: sc.auraColorG,
            auraColorB: sc.auraColorB,
            trailIntensity: sc.trailIntensity,
            meshyAthleteSlotId: "MESHY_elijah_bonds_athlete",
            usePersonalModel: true
        )
    }

    static func makeDefault(userId: String, displayName: String) -> PlayerAvatarConfig {
        PlayerAvatarConfig(
            userId: userId,
            displayName: displayName,
            heightScale: 1.0,
            weightScale: 1.0,
            limbLength: 1.0,
            facePreset: .elijahBonds,
            skinTone: .tone4,
            hairStyle: .fade,
            hairColorHex: "#1A1A1A",
            outfitTier: .standard,
            jerseyColorHex: "#00E5FF",
            shortsColorHex: "#1A1A24",
            shoeStyle: .basketball,
            shoeColorHex: "#FFFFFF",
            accessories: [],
            auraColorR: 0,
            auraColorG: 0.83,
            auraColorB: 1.0,
            trailIntensity: 0.3,
            meshyAthleteSlotId: "MESHY_elijah_bonds_athlete",
            usePersonalModel: true
        )
    }

    /// Full JSON payload delivered to Unreal via `receiveAvatarAppearanceJSON:`.
    func toUnrealPayload() -> [String: Any] {
        [
            "type": "avatar_appearance",
            "userId": userId,
            "usePersonalModel": usePersonalModel,
            "meshyAthleteSlotId": meshyAthleteSlotId,
            "meshyFaceSlotId": facePreset.meshySlotId,
            "nexusBlueprintClass": usePersonalModel ? "BP_PlayerAvatar_Personal" : "BP_PlayerAvatar_Base",
            "bodyScale": [
                "heightScale": heightScale,
                "weightScale": weightScale,
                "limbLength": limbLength
            ],
            "appearance": [
                "facePreset": facePreset.rawValue,
                "skinTone": skinTone.hexValue,
                "hairStyle": hairStyle.rawValue,
                "hairColor": hairColorHex
            ],
            "outfit": [
                "tier": outfitTier.rawValue,
                "jerseyColor": jerseyColorHex,
                "shortsColor": shortsColorHex,
                "shoeStyle": shoeStyle.rawValue,
                "shoeColor": shoeColorHex,
                "accessories": accessories.map(\.rawValue)
            ],
            "aura": [
                "r": auraColorR,
                "g": auraColorG,
                "b": auraColorB,
                "trailIntensity": trailIntensity
            ]
        ]
    }
}
