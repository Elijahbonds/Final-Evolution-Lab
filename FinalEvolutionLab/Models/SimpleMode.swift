import SwiftUI

private struct SimpleModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var simpleMode: Bool {
        get { self[SimpleModeKey.self] }
        set { self[SimpleModeKey.self] = newValue }
    }
}

struct SimpleModeLabels {
    static func neuralDrive(_ simple: Bool) -> String {
        simple ? "ENERGY LEVEL" : "NEURAL DRIVE"
    }

    static func prqScore(_ simple: Bool) -> String {
        simple ? "FITNESS SCORE" : "PRQ SCORE"
    }

    static func efficiency(_ simple: Bool) -> String {
        simple ? "WORKOUT QUALITY" : "EFFICIENCY"
    }

    static func readiness(_ simple: Bool) -> String {
        simple ? "BODY READINESS" : "READINESS"
    }

    static func evolutionShards(_ simple: Bool) -> String {
        simple ? "REWARD POINTS" : "SHARDS"
    }

    static func neuralEngine(_ simple: Bool) -> String {
        simple ? "Energy Level Online" : "Neural Engine Online"
    }

    static func verticalPotential(_ simple: Bool) -> String {
        simple ? "JUMP POWER" : "VERTICAL"
    }

    static func popForce(_ simple: Bool) -> String {
        simple ? "POWER SPEED" : "POP FORCE"
    }
}
