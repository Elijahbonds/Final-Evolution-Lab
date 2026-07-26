import Foundation

// SceneGen — authors every Nexus scene descriptor BY ENCODING THE REAL TYPES.
//
// The alternative is hand-writing JSON, and this repo already demonstrates
// where that leads: the single descriptor that existed before this tool used
// {"type":"skeleton",...} and {"x":..,"y":..}, while Swift's synthesized
// Codable expects {"skeleton":{...}} and a [x, y] array. It had never decoded,
// and nothing noticed because nothing loaded it.
//
// Generating from the types makes that class of drift impossible: if the model
// changes, this stops compiling.

func entities(for mode: GameModeId) -> [NexusEntity] {
    let cat = mode.avatarCategory
    let floor = NexusEntity(
        id: "floor_\(mode.rawValue)", name: "Floor",
        transform: NexusTransform(position: CGPoint(x: 0.5, y: 0.88), rotation: 0, scale: 1.0),
        components: [.surface(friction: 0.4)])
    let camera = NexusEntity(
        id: "camera_main", name: "Main Camera",
        transform: NexusTransform(position: CGPoint(x: 0.5, y: 0.5), rotation: 0, scale: 1.0),
        components: [.camera(zoom: 1.0, fov: 60)])
    func player(_ x: Double, amp: Double = 1.0) -> NexusEntity {
        NexusEntity(id: "player_\(mode.rawValue)", name: "Player",
            transform: NexusTransform(position: CGPoint(x: x, y: 0.72), rotation: 0, scale: 1.0),
            components: [.skeleton(category: cat, amplitude: CGFloat(amp)), .physics(mass: 80, restitution: 0.3)])
    }
    func opponent(_ id: String, _ x: Double, amp: Double = 0.85) -> NexusEntity {
        NexusEntity(id: id, name: "Opponent",
            transform: NexusTransform(position: CGPoint(x: x, y: 0.72), rotation: 0, scale: 1.0),
            components: [.skeleton(category: cat, amplitude: CGFloat(amp)), .physics(mass: 80, restitution: 0.3)])
    }
    func ball(_ symbol: String, _ hex: String, mass: Double, restitution: Double, scale: Double = 0.6) -> NexusEntity {
        NexusEntity(id: "ball", name: "Ball",
            transform: NexusTransform(position: CGPoint(x: 0.5, y: 0.55), rotation: 0, scale: CGFloat(scale)),
            components: [.sprite(systemImage: symbol, hexColor: hex), .physics(mass: mass, restitution: restitution)])
    }
    func trigger(_ id: String, _ x: Double, _ y: Double, _ event: String, r: Double = 0.04) -> NexusEntity {
        NexusEntity(id: id, name: "Trigger",
            transform: NexusTransform(position: CGPoint(x: x, y: y), rotation: 0, scale: 1.0),
            components: [.trigger(radius: CGFloat(r), eventName: event)])
    }

    switch mode {
    case .basketballHeadToHead, .basketballIRL:
        return [player(0.35), opponent("opponent_\(mode.rawValue)", 0.65),
                ball("basketball.fill", "#FF6B00", mass: 0.6, restitution: 0.8),
                trigger("hoop_left", 0.15, 0.30, "score_left"), trigger("hoop_right", 0.85, 0.30, "score_right"),
                floor, camera]
    case .basketballDunkContest:
        return [player(0.5), ball("basketball.fill", "#FF6B00", mass: 0.6, restitution: 0.8),
                trigger("rim", 0.5, 0.28, "dunk_scored", r: 0.05), floor, camera]
    case .basketball3v3, .courtCarnival:
        var e: [NexusEntity] = [player(0.30)]
        for i in 1...2 { e.append(opponent("ally_\(i)", 0.20 + Double(i) * 0.08, amp: 0.9)) }
        for i in 1...3 { e.append(opponent("foe_\(i)", 0.62 + Double(i) * 0.08)) }
        e += [ball("basketball.fill", "#FF6B00", mass: 0.6, restitution: 0.8),
              trigger("hoop_left", 0.15, 0.30, "score_left"), trigger("hoop_right", 0.85, 0.30, "score_right"),
              floor, camera]
        return e
    case .karate, .karateEndless:
        return [player(0.35), opponent("opponent_\(mode.rawValue)", 0.65),
                trigger("ring_out_left", 0.05, 0.72, "ring_out"), trigger("ring_out_right", 0.95, 0.72, "ring_out"),
                floor, camera]
    case .baseball:
        return [player(0.30), opponent("pitcher", 0.62),
                ball("baseball.fill", "#FFFFFF", mass: 0.145, restitution: 0.55, scale: 0.35),
                trigger("home_plate", 0.30, 0.86, "at_bat"), trigger("outfield", 0.85, 0.40, "home_run"),
                floor, camera]
    case .football:
        return [player(0.25), opponent("defender", 0.60),
                ball("football.fill", "#8B4513", mass: 0.43, restitution: 0.6, scale: 0.45),
                trigger("end_zone", 0.92, 0.72, "touchdown", r: 0.06), floor, camera]
    case .soccer:
        return [player(0.30), opponent("keeper", 0.86),
                ball("soccerball", "#FFFFFF", mass: 0.43, restitution: 0.75, scale: 0.45),
                trigger("goal", 0.93, 0.68, "goal", r: 0.07), floor, camera]
    case .tennis:
        return [player(0.20), opponent("opponent_tennis", 0.80),
                ball("tennisball.fill", "#D4FF00", mass: 0.058, restitution: 0.7, scale: 0.3),
                trigger("net", 0.5, 0.72, "net_fault", r: 0.03), floor, camera]
    case .volleyball:
        return [player(0.25), opponent("opponent_volleyball", 0.75),
                ball("volleyball.fill", "#FFD60A", mass: 0.27, restitution: 0.8, scale: 0.5),
                trigger("net", 0.5, 0.55, "net_touch", r: 0.03), floor, camera]
    case .golf:
        return [player(0.15),
                ball("golfball", "#FFFFFF", mass: 0.046, restitution: 0.5, scale: 0.22),
                trigger("hole", 0.88, 0.78, "hole_out", r: 0.02), floor, camera]
    case .gymnastics:
        return [player(0.5), trigger("landing_zone", 0.5, 0.84, "landing", r: 0.08), floor, camera]
    case .surfing, .skateboarding, .snowboarding:
        return [player(0.35), trigger("trick_zone", 0.6, 0.60, "trick_window", r: 0.10), floor, camera]
    case .brainBrawl, .whoSceneIt:
        return [player(0.5, amp: 0.4), opponent("opponent_\(mode.rawValue)", 0.75, amp: 0.4), floor, camera]
    case .marketBrowse:
        // A browsing surface: no avatar, no floor physics. Camera only.
        return [camera]
    }
}

func scene(for mode: GameModeId) -> NexusScene {
    var cfg = NexusPhysicsConfig()
    cfg.applyPRQ(50)
    return NexusScene(
        id: "\(mode.rawValue)_default",
        name: mode.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
        gameModeId: mode,
        entities: entities(for: mode),
        environment: NexusEnvironment.default(for: mode),
        physicsConfig: cfg)
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let enc = JSONEncoder()
enc.outputFormatting = [.prettyPrinted, .sortedKeys]
var n = 0
for mode in GameModeId.allCases {
    let data = try! enc.encode(scene(for: mode))
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(mode.rawValue).nexus.json")
    try! data.write(to: url)
    // round-trip immediately: a descriptor that cannot be read back is not a descriptor
    _ = try! JSONDecoder().decode(NexusScene.self, from: data)
    n += 1
}
print("generated + round-tripped \(n) scene descriptor(s) -> \(outDir)")
