import Foundation
import QuartzCore

nonisolated enum ModifierState: String, Sendable {
    case none
    case style
    case power
    case special

    var label: String {
        switch self {
        case .none: return "STANDARD"
        case .style: return "STYLE"
        case .power: return "POWER"
        case .special: return "SPECIAL"
        }
    }

    var scoreScale: Double {
        switch self {
        case .none: return 1.0
        case .style: return 1.3
        case .power: return 1.45
        case .special: return 2.0
        }
    }
}

nonisolated struct DirectionalTrick: Sendable, Identifiable {
    let id: String
    let name: String
    let displayName: String
    let direction: ComboDirection
    let modifier: ModifierState
    let basePoints: Int
    let riskFactor: Double
    let animationKey: String

    static let dunkTricks: [DirectionalTrick] = [
        DirectionalTrick(id: "windmill_std", name: "Windmill", displayName: "WINDMILL!", direction: .up, modifier: .none, basePoints: 8, riskFactor: 1.0, animationKey: "dunk_windmill"),
        DirectionalTrick(id: "360_std", name: "360 Dunk", displayName: "360!", direction: .right, modifier: .none, basePoints: 10, riskFactor: 1.2, animationKey: "dunk_360"),
        DirectionalTrick(id: "tomahawk_std", name: "Tomahawk", displayName: "TOMAHAWK!", direction: .left, modifier: .none, basePoints: 7, riskFactor: 0.9, animationKey: "dunk_tomahawk"),
        DirectionalTrick(id: "btl_std", name: "Between the Legs", displayName: "BETWEEN THE LEGS!", direction: .down, modifier: .none, basePoints: 9, riskFactor: 1.1, animationKey: "dunk_btl"),
        DirectionalTrick(id: "reverse_std", name: "Reverse Jam", displayName: "REVERSE!", direction: .neutral, modifier: .none, basePoints: 6, riskFactor: 0.8, animationKey: "dunk_reverse"),
        DirectionalTrick(id: "flashy_windmill", name: "Flashy Windmill", displayName: "FLASHY WINDMILL!", direction: .up, modifier: .style, basePoints: 12, riskFactor: 1.3, animationKey: "dunk_flashy_windmill"),
        DirectionalTrick(id: "flashy_360", name: "720 Spin", displayName: "720!", direction: .right, modifier: .style, basePoints: 15, riskFactor: 1.5, animationKey: "dunk_720"),
        DirectionalTrick(id: "flashy_btl", name: "Double Pump BTL", displayName: "DOUBLE PUMP!", direction: .down, modifier: .style, basePoints: 14, riskFactor: 1.4, animationKey: "dunk_double_pump"),
        DirectionalTrick(id: "flashy_hawk", name: "Corkscrew Tomahawk", displayName: "CORKSCREW!", direction: .left, modifier: .style, basePoints: 13, riskFactor: 1.35, animationKey: "dunk_corkscrew"),
        DirectionalTrick(id: "power_windmill", name: "Gorilla Windmill", displayName: "GORILLA!", direction: .up, modifier: .power, basePoints: 14, riskFactor: 1.4, animationKey: "dunk_gorilla"),
        DirectionalTrick(id: "power_slam", name: "Backboard Breaker", displayName: "BACKBOARD BREAKER!", direction: .down, modifier: .power, basePoints: 16, riskFactor: 1.6, animationKey: "dunk_breaker"),
        DirectionalTrick(id: "power_tomahawk", name: "War Hammer", displayName: "WAR HAMMER!", direction: .left, modifier: .power, basePoints: 15, riskFactor: 1.5, animationKey: "dunk_warhammer"),
        DirectionalTrick(id: "power_360", name: "Freight Train 360", displayName: "FREIGHT TRAIN!", direction: .right, modifier: .power, basePoints: 17, riskFactor: 1.7, animationKey: "dunk_freight"),
        DirectionalTrick(id: "sig_freeThrow", name: "Free Throw Line", displayName: "FREE THROW LINE!", direction: .up, modifier: .special, basePoints: 25, riskFactor: 2.0, animationKey: "dunk_freethrow"),
        DirectionalTrick(id: "sig_eastbay", name: "Eastbay Windmill", displayName: "EASTBAY!", direction: .down, modifier: .special, basePoints: 28, riskFactor: 2.2, animationKey: "dunk_eastbay"),
        DirectionalTrick(id: "sig_elbowHang", name: "Elbow Hang", displayName: "ELBOW HANG!", direction: .left, modifier: .special, basePoints: 22, riskFactor: 1.9, animationKey: "dunk_elbow"),
        DirectionalTrick(id: "sig_doubleClutch", name: "Double Clutch 720", displayName: "DOUBLE CLUTCH 720!", direction: .right, modifier: .special, basePoints: 30, riskFactor: 2.5, animationKey: "dunk_dc720"),
    ]

    static let combatTricks: [DirectionalTrick] = [
        DirectionalTrick(id: "punch_std", name: "Jab Cross", displayName: "JAB CROSS!", direction: .up, modifier: .none, basePoints: 6, riskFactor: 0.8, animationKey: "combat_jab"),
        DirectionalTrick(id: "kick_std", name: "Roundhouse", displayName: "ROUNDHOUSE!", direction: .right, modifier: .none, basePoints: 8, riskFactor: 1.0, animationKey: "combat_roundhouse"),
        DirectionalTrick(id: "sweep_std", name: "Leg Sweep", displayName: "SWEEP!", direction: .down, modifier: .none, basePoints: 7, riskFactor: 0.9, animationKey: "combat_sweep"),
        DirectionalTrick(id: "elbow_std", name: "Spinning Elbow", displayName: "SPINNING ELBOW!", direction: .left, modifier: .none, basePoints: 9, riskFactor: 1.1, animationKey: "combat_elbow"),
        DirectionalTrick(id: "counter_std", name: "Counter Strike", displayName: "COUNTER!", direction: .neutral, modifier: .none, basePoints: 10, riskFactor: 1.2, animationKey: "combat_counter"),
        DirectionalTrick(id: "style_vortex", name: "Vortex Strike", displayName: "VORTEX!", direction: .up, modifier: .style, basePoints: 14, riskFactor: 1.4, animationKey: "combat_rasengan"),
        DirectionalTrick(id: "style_barrage", name: "Iron Barrage", displayName: "IRON BARRAGE!", direction: .down, modifier: .style, basePoints: 16, riskFactor: 1.5, animationKey: "combat_barrage"),
        DirectionalTrick(id: "style_surge", name: "Surge Drive", displayName: "SURGE!", direction: .left, modifier: .style, basePoints: 15, riskFactor: 1.45, animationKey: "combat_chidori"),
        DirectionalTrick(id: "power_smash", name: "Earth Shatter", displayName: "EARTH SHATTER!", direction: .down, modifier: .power, basePoints: 18, riskFactor: 1.7, animationKey: "combat_shatter"),
        DirectionalTrick(id: "power_rush", name: "Berserker Rush", displayName: "BERSERKER!", direction: .up, modifier: .power, basePoints: 17, riskFactor: 1.6, animationKey: "combat_berserker"),
        DirectionalTrick(id: "sig_gate", name: "Final Gate Protocol", displayName: "FINAL GATE!", direction: .up, modifier: .special, basePoints: 30, riskFactor: 2.5, animationKey: "combat_gate"),
        DirectionalTrick(id: "sig_shadow", name: "Phantom Echo Finisher", displayName: "PHANTOM ECHO!", direction: .down, modifier: .special, basePoints: 28, riskFactor: 2.2, animationKey: "combat_shadow"),
    ]

    /// Board / precision extreme-sports tricks (skate/snow/surf/gymnastics).
    /// Previously these modes fell through to `dunkTricks`, so landing a trick
    /// flashed basketball names ("WINDMILL!", "360!") — content bleed-through.
    /// Same direction × modifier grid so `resolve` always finds a match.
    static let boardTricks: [DirectionalTrick] = [
        DirectionalTrick(id: "board_ollie", name: "Ollie", displayName: "OLLIE!", direction: .up, modifier: .none, basePoints: 6, riskFactor: 0.8, animationKey: "board_ollie"),
        DirectionalTrick(id: "board_shuv", name: "Pop Shuv-It", displayName: "SHUV-IT!", direction: .right, modifier: .none, basePoints: 8, riskFactor: 1.0, animationKey: "board_shuvit"),
        DirectionalTrick(id: "board_grind", name: "50-50 Grind", displayName: "GRIND!", direction: .left, modifier: .none, basePoints: 7, riskFactor: 0.9, animationKey: "board_grind"),
        DirectionalTrick(id: "board_kickflip", name: "Kickflip", displayName: "KICKFLIP!", direction: .down, modifier: .none, basePoints: 9, riskFactor: 1.1, animationKey: "board_kickflip"),
        DirectionalTrick(id: "board_carve", name: "Carve", displayName: "CARVE!", direction: .neutral, modifier: .none, basePoints: 6, riskFactor: 0.8, animationKey: "board_carve"),
        DirectionalTrick(id: "board_stylemethod", name: "Method Air", displayName: "METHOD AIR!", direction: .up, modifier: .style, basePoints: 13, riskFactor: 1.3, animationKey: "board_method"),
        DirectionalTrick(id: "board_style360", name: "360 Spin", displayName: "360 SPIN!", direction: .right, modifier: .style, basePoints: 15, riskFactor: 1.5, animationKey: "board_spin360"),
        DirectionalTrick(id: "board_stylegrab", name: "Indy Grab", displayName: "INDY GRAB!", direction: .down, modifier: .style, basePoints: 14, riskFactor: 1.4, animationKey: "board_indy"),
        DirectionalTrick(id: "board_styleboard", name: "Boardslide", displayName: "BOARDSLIDE!", direction: .left, modifier: .style, basePoints: 13, riskFactor: 1.35, animationKey: "board_boardslide"),
        DirectionalTrick(id: "board_powerbig", name: "Big Air", displayName: "BIG AIR!", direction: .up, modifier: .power, basePoints: 14, riskFactor: 1.4, animationKey: "board_bigair"),
        DirectionalTrick(id: "board_powerslam", name: "Backflip", displayName: "BACKFLIP!", direction: .down, modifier: .power, basePoints: 16, riskFactor: 1.6, animationKey: "board_backflip"),
        DirectionalTrick(id: "board_powerrail", name: "Rail Slide", displayName: "RAIL SLIDE!", direction: .left, modifier: .power, basePoints: 15, riskFactor: 1.5, animationKey: "board_rail"),
        DirectionalTrick(id: "board_power900", name: "900 Spin", displayName: "900!", direction: .right, modifier: .power, basePoints: 17, riskFactor: 1.7, animationKey: "board_900"),
        DirectionalTrick(id: "board_sigmctwist", name: "McTwist", displayName: "MCTWIST!", direction: .up, modifier: .special, basePoints: 25, riskFactor: 2.0, animationKey: "board_mctwist"),
        DirectionalTrick(id: "board_sig1080", name: "1080", displayName: "1080!", direction: .down, modifier: .special, basePoints: 28, riskFactor: 2.2, animationKey: "board_1080"),
        DirectionalTrick(id: "board_sighandplant", name: "Handplant", displayName: "HANDPLANT!", direction: .left, modifier: .special, basePoints: 22, riskFactor: 1.9, animationKey: "board_handplant"),
        DirectionalTrick(id: "board_sigdoublecork", name: "Double Cork", displayName: "DOUBLE CORK!", direction: .right, modifier: .special, basePoints: 30, riskFactor: 2.5, animationKey: "board_doublecork"),
    ]

    static func resolve(direction: ComboDirection, modifier: ModifierState, mode: GameModeId) -> DirectionalTrick {
        let pool: [DirectionalTrick]
        switch mode {
        case .karate, .karateEndless:
            pool = combatTricks
        case .skateboarding, .snowboarding, .surfing, .gymnastics:
            pool = boardTricks
        default:
            pool = dunkTricks
        }
        let filtered = pool.filter { $0.direction == direction && $0.modifier == modifier }
        if let match = filtered.first { return match }
        let fallback = pool.filter { $0.direction == direction }
        return fallback.first ?? pool[0]
    }
}

nonisolated struct QTEApexWindow: Sendable {
    static let windowDuration: Double = 0.4
    static let perfectThreshold: Double = 0.08
    static let greatThreshold: Double = 0.15
    static let goodThreshold: Double = 0.25

    let windowStart: Double
    let windowEnd: Double
    let targetTime: Double

    init(startTime: Double) {
        self.windowStart = startTime
        self.windowEnd = startTime + Self.windowDuration
        self.targetTime = startTime + Self.windowDuration * 0.5
    }

    func grade(inputTime: Double) -> QTEGrade {
        guard inputTime >= windowStart && inputTime <= windowEnd else { return .miss }
        let delta = abs(inputTime - targetTime)
        if delta <= Self.perfectThreshold { return .perfect }
        if delta <= Self.greatThreshold { return .great }
        if delta <= Self.goodThreshold { return .good }
        return .ok
    }
}

nonisolated enum QTEGrade: String, Sendable {
    case perfect = "PERFECT"
    case great = "GREAT"
    case good = "GOOD"
    case ok = "OK"
    case miss = "MISS"

    var multiplier: Double {
        switch self {
        case .perfect: return 2.0
        case .great: return 1.5
        case .good: return 1.2
        case .ok: return 1.0
        case .miss: return 0.3
        }
    }

    var triggersSlowMo: Bool {
        self == .perfect || self == .great
    }
}

nonisolated struct SignatureComboEngine: Sendable {
    static let maxChainLength: Int = 6
    static let chainWindowSeconds: Double = 0.5
    static let styleLandingWindowSeconds: Double = 0.35
    static let comboDecayPerSecond: Double = 0.8

    let chain: [DirectionalTrick]
    let chainStartTime: Double
    let lastInputTime: Double
    let totalStylePoints: Int
    let comboMultiplier: Double
    let apexWindow: QTEApexWindow?
    let lastQTEGrade: QTEGrade?

    init() {
        self.chain = []
        self.chainStartTime = 0
        self.lastInputTime = 0
        self.totalStylePoints = 0
        self.comboMultiplier = 1.0
        self.apexWindow = nil
        self.lastQTEGrade = nil
    }

    private init(
        chain: [DirectionalTrick],
        chainStartTime: Double,
        lastInputTime: Double,
        totalStylePoints: Int,
        comboMultiplier: Double,
        apexWindow: QTEApexWindow?,
        lastQTEGrade: QTEGrade?
    ) {
        self.chain = chain
        self.chainStartTime = chainStartTime
        self.lastInputTime = lastInputTime
        self.totalStylePoints = totalStylePoints
        self.comboMultiplier = comboMultiplier
        self.apexWindow = apexWindow
        self.lastQTEGrade = lastQTEGrade
    }

    var chainLength: Int { chain.count }
    var isActive: Bool { !chain.isEmpty }

    var chainLabel: String {
        chain.map { $0.displayName }.joined(separator: " > ")
    }

    func addTrick(_ trick: DirectionalTrick, at time: Double) -> SignatureComboEngine {
        let isNewChain = chain.isEmpty || (time - lastInputTime) > Self.chainWindowSeconds
        var newChain = isNewChain ? [trick] : chain + [trick]
        if newChain.count > Self.maxChainLength {
            newChain = Array(newChain.suffix(Self.maxChainLength))
        }

        let isBranch = chain.last.map { $0.id != trick.id } ?? false
        let branchBonus: Double = isBranch ? 0.25 : 0.1
        let newMultiplier = isNewChain ? 1.0 + branchBonus : min(4.0, comboMultiplier + branchBonus)

        let rawPoints = Int(Double(trick.basePoints) * newMultiplier * trick.riskFactor)
        let newTotal = isNewChain ? rawPoints : totalStylePoints + rawPoints

        return SignatureComboEngine(
            chain: newChain,
            chainStartTime: isNewChain ? time : chainStartTime,
            lastInputTime: time,
            totalStylePoints: newTotal,
            comboMultiplier: newMultiplier,
            apexWindow: apexWindow,
            lastQTEGrade: lastQTEGrade
        )
    }

    func startApexQTE(at time: Double) -> SignatureComboEngine {
        let window = QTEApexWindow(startTime: time)
        return SignatureComboEngine(
            chain: chain,
            chainStartTime: chainStartTime,
            lastInputTime: lastInputTime,
            totalStylePoints: totalStylePoints,
            comboMultiplier: comboMultiplier,
            apexWindow: window,
            lastQTEGrade: lastQTEGrade
        )
    }

    func resolveApexQTE(inputTime: Double) -> SignatureComboEngine {
        guard let window = apexWindow else { return self }
        let grade = window.grade(inputTime: inputTime)
        let bonusPoints = Int(Double(totalStylePoints) * (grade.multiplier - 1.0))
        return SignatureComboEngine(
            chain: chain,
            chainStartTime: chainStartTime,
            lastInputTime: inputTime,
            totalStylePoints: totalStylePoints + max(0, bonusPoints),
            comboMultiplier: comboMultiplier * grade.multiplier,
            apexWindow: nil,
            lastQTEGrade: grade
        )
    }

    func styleLanding(at time: Double) -> (engine: SignatureComboEngine, bonus: Int) {
        let landingBonus = Int(Double(totalStylePoints) * 0.3)
        let boosted = SignatureComboEngine(
            chain: chain,
            chainStartTime: chainStartTime,
            lastInputTime: time,
            totalStylePoints: totalStylePoints + landingBonus,
            comboMultiplier: comboMultiplier + 0.5,
            apexWindow: nil,
            lastQTEGrade: lastQTEGrade
        )
        return (boosted, landingBonus)
    }

    func reset() -> SignatureComboEngine {
        SignatureComboEngine()
    }

    func finalScore(prqNormalized: Double, neuralBurst: Bool) -> Int {
        let prqBonus = 1.0 + prqNormalized * 0.3
        let burstBonus: Double = neuralBurst ? 1.2 : 1.0
        return Int(Double(totalStylePoints) * prqBonus * burstBonus)
    }
}

// MARK: - ComboChain
// Tracks consecutive-trick score multiplier system (separate from SignatureComboEngine).
// A chain stays alive when tricks are performed within 3 seconds of each other;
// breaking that window resets the chain to length 1 at the new trick.

nonisolated struct ComboChain: Sendable {
    var chainLength: Int = 0
    var lastTrickTime: CFTimeInterval = 0

    var multiplier: Double {
        guard chainLength > 0 else { return 1.0 }
        return min(pow(1.1, Double(chainLength)), 5.0)
    }

    mutating func recordTrick(at time: CFTimeInterval) {
        if chainLength == 0 || (time - lastTrickTime) <= 3.0 {
            chainLength += 1
        } else {
            chainLength = 1
        }
        lastTrickTime = time
    }

    mutating func resetChain() {
        chainLength = 0
        lastTrickTime = 0
    }
}
