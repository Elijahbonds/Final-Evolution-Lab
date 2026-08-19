import Foundation

/// Consumer-facing copy — keeps engineer protocol ids in logs/C++ only.
enum FELPremiumCopy {
    // MARK: - Capability tiers (honest, friendly)

    enum Tier {
        static func practice(_ modeName: String) -> String { "Practice · \(modeName)" }
        static func earlyAccess(_ modeName: String) -> String { "Early Access · \(modeName)" }
        static func beta(_ modeName: String) -> String { "Beta · \(modeName)" }
        static func library(_ modeName: String) -> String { "Library · \(modeName)" }
    }

    // MARK: - Preview / early-access badges

    enum Preview {
        static let appLayer = "Early Access"
        static let arena = "Early Access · Arena"
        static let gameGenerator = "Early Access · Game Creator"
        static let nexus = "Early Access"
        static let nexusEducation = "Early Access · Learning Lab"
        static let sceneKitStub = "Early Access · 3D Preview"
        static let ide = "Early Access · Studio"
        static let ideV03 = "Early Access · Studio"
        static let inAppPlaytest = "Early Access · Playtest"
        static let geminiRest = "Early Access · AI Settings"
        static let firebaseOfflineNoKey = "Offline · Sign in for cloud sync"
        static let aiStudioConnectedFirebaseOffline = "AI Studio connected · Cloud sync offline"
        static let nexusOnly = "NEXUS Exclusive"
        static let systemScan = "Early Access · Body Scan"
        static let bioFuelStub = "Early Access · Nutrition"
        static let bioFuelScan = "Early Access · Meal Scan"
        static let economyStub = "Early Access · Rewards"
        static let communityFeed = "Early Access · Community"
        static let matchmakingStub = "Early Access · Matchmaking"
        static let vaultProfile = "Early Access · Profile"
        static let doorDashBridge = "Early Access · Meal Delivery"
        static let drawingTutorial = "Early Access · Tutorial"
        static let nexusFeed = "Early Access · Social Feed"
        static let cardMarket = "Early Access · Card Shop"
        static let streamingStub = "Early Access · Live Stream"
        static let toolChips = "Early Access · Agent Tools"
        static let education = "Early Access · Learning"
        static let coachLibrary = "Early Access · Coaching"
        static let nexusGenerate = "Early Access · Arena Builder"
        static let hlsDemo = "Early Access · Video Demo"
        static let generatedGameSpec = "Early Access · Custom Game"
        static let generatedFromScan = "Early Access · Scan to Play"
        static let simulatedPose = "Demo pose · Live scan coming soon"
        static let scanToGenerate = "Early Access · Scan to Play"
        static let proctoredDunkLobby = "Early Access · Proctored IRL Dunk"
        static let triumphCashEntry = "Preview · Triumph Cash Entry"
        static let triumphPaymentStub = "Preview · Payment UI Stub"
        static let proctoredZoomSession = "Preview · Proctored Zoom Session"
    }

    // MARK: - Connection / gameplay feedback

    enum Connection {
        static let sessionRequired = "Start a session to play"
        static let linkError = "Connection lost — try again"
        static let sceneError = "Something went wrong — try again"
        static let pulseFailed = "Move not registered — try again"
    }

    // MARK: - Gameplay HUD (consumer labels)

    enum HUD {
        static let readiness = "Readiness"
        static let readinessHint = "Double tap for readiness details"
    }

    // MARK: - Emulator / library shell

    enum Emulator {
        static let featuredModes = "Featured"
        static let modesAvailable = "Available now"
        static let startGame = "Start game"
        static let buildingGame = "Building your game…"
        static let scanToArena = "Turn your scan into a playable arena"
        static let describeToGame = "Describe a game — we build mode, venue, and rules from your words"
    }

    // MARK: - Session receipts (Dashboard)

    enum Receipt {
        static let savedLocally = "Saved on device · syncs when you sign in"
        static let awaitingAuth = "Sign in to sync scores"
        static let backendConnected = "Connected · Scores syncing"
        static let firebaseConnected = "Connected · Cloud sync on"
        static let livePost = "Syncing"
        static let savedQueue = "Saved locally"
        static let uploadPending = "Upload saved sessions"
        static let refreshQueue = "Refresh saved sessions"
    }

    // MARK: - AI Studio (Dashboard + panels)

    enum AIStudio {
        static let connected = "AI Studio · Connected"
        static let testing = "AI Studio · Checking connection"
        static let templateFallback = "AI Studio · Using built-in templates"
        static let keyNotTested = "AI Studio · Key saved (not tested)"
        static let connectedDetail = "Connected · Game creator ready"
        static let offlineDetail = "Add an API key in Settings to enable AI creation"
        static func connectedStatus(model: String, source: String) -> String {
            "Connected · \(model) · \(source)"
        }
        static let offlineStatus = "Offline · Add API key in Settings"
    }

    // MARK: - Firebase (Dashboard)

    enum Firebase {
        static let live = "Cloud sync · Live"
        static let preview = "Cloud sync · Offline preview"
        static let unavailable = "Cloud sync · Not configured"
        static let disabledEnv = "Cloud sync · Disabled in this build"
        static let disabledCompile = "Cloud sync · Not included in this build"
        static let disabled = "Cloud sync · Disabled"
    }

    // MARK: - Generator metadata (UI display only)

    static func generatorTierLabel(_ tier: String) -> String {
        switch tier {
        case "template_mvp":
            return "Built-in templates"
        case "ai_studio_assisted", "gemini_assisted":
            return "AI-assisted design"
        case "template_ai_studio_partial", "template_gemini_partial":
            return "Templates + AI hints"
        default:
            return tier.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Maps C++ / adapter preview_label strings to consumer copy.
    static func humanizePreviewLabel(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Preview.generatedGameSpec }
        if trimmed.hasPrefix("PREVIEW · ") {
            let suffix = String(trimmed.dropFirst("PREVIEW · ".count))
            switch suffix.uppercased() {
            case "GENERATED GAME SPEC", "GENERATED GAME SPEC · NOT SEELE FULL SYNTHESIS":
                return Preview.generatedGameSpec
            case "NEXUS GAME GENERATOR":
                return Preview.gameGenerator
            case "NEXUS ARENA":
                return Preview.arena
            case "GEMINI REST":
                return Preview.geminiRest
            case "IN-APP PLAYTEST":
                return Preview.inAppPlaytest
            case "NEXUS STUDIO IDE V0.3", "IDE V0.3":
                return Preview.ideV03
            case "LOCAL QUEUE ONLY":
                return Receipt.savedLocally
            case "FIREBASE OFFLINE", "FIREBASE OFFLINE · NO AI STUDIO KEY":
                return Preview.firebaseOfflineNoKey
            case "TOOL CHIPS":
                return Preview.toolChips
            default:
                if suffix.contains(" · NOT SEELE") {
                    return Preview.generatedGameSpec
                }
                return Tier.earlyAccess(suffix.capitalized)
            }
        }
        return trimmed
    }

    /// Maps fel.* command errors to player-facing feedback (dev logs keep raw strings).
    static func humanizeCommandError(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("fel.sport.pulse") { return Connection.pulseFailed }
        if lower.contains("failed") || lower.hasPrefix("fel.") {
            return Connection.sceneError
        }
        return raw
    }

    /// Maps C++ outcome-sport `last_action` ids to HUD copy (not fel.* command names).
    static func humanizeOutcomeSportAction(_ raw: String) -> String {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty { return raw }
        switch key {
        case "light_strike": return "Light strike"
        case "heavy_strike": return "Heavy strike"
        case "block": return "Block"
        case "counter": return "Counter"
        case "three_pointer": return "3-pointer"
        case "two_pointer", "layup": return "Layup"
        case "home_run": return "Home run"
        case "strikeout": return "Strikeout"
        case "touchdown": return "Touchdown"
        case "field_goal": return "Field goal"
        case "turnover": return "Turnover"
        case "penalty", "penalty_shot": return "Penalty kick"
        case "putt": return "Putt"
        case "ace", "ace_serve": return "Ace"
        case "bunt": return "Bunt"
        case "deliver_cue": return "Deliver Cue"
        case "project_voice": return "Project Voice"
        case "hold_frame": return "Hold Frame"
        case "acting_drill": return "Acting Drill"
        case "performance_challenge": return "Performance Challenge"
        case "camera_angle": return "Camera Angle"
        default:
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Court Carnival pad ids from C++ — not shown as snake_case in HUD.
    static func humanizeCarnivalPad(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "trick_shot": return "Trick shot"
        case "rhythm_board": return "Rhythm board"
        case "atw_landmark": return "Landmark"
        case "hot_potato": return "Hot potato"
        default: return humanizeOutcomeSportAction(raw)
        }
    }
}
