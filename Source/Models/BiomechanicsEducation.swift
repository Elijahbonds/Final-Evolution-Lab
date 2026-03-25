// MARK: - Rate of Force Development (RFD) & Ground Reaction Force (GRF) — User Education
// Pop Force in the app is a composite index reflecting RFD and GRF efficiency.

import Foundation
import SwiftUI

/// User-facing education content for key biomechanical concepts.
enum BiomechanicsEducation {

    // MARK: - Rate of Force Development (RFD)

    static let rfdTitle = "Rate of Force Development (RFD)"
    static let rfdShortDefinition = "How quickly you can produce force from a standstill or after ground contact."
    static let rfdFullExplanation = """
        Rate of Force Development (RFD) is how fast your muscles and tendons build force from the moment you start pushing into the ground until peak force. In jumping and sprinting, a higher RFD means you reach peak force sooner, so you leave the ground faster and waste less time in contact.

        Why it matters:
        • Short ground-contact time (e.g. in pogos, bounds, sprints) demands high RFD.
        • Training with max-intent, low-rep efforts and reactive drills improves RFD.
        • Your Pop Force score in the Lab reflects how well your current movement uses RFD.
        """

    // MARK: - Ground Reaction Force (GRF)

    static let grfTitle = "Ground Reaction Force (GRF)"
    static let grfShortDefinition = "The force the ground exerts back on you when you push into it."
    static let grfFullExplanation = """
        Ground Reaction Force (GRF) is the force the ground pushes back on your body when you apply force into it. To jump higher or move faster, you want to maximize GRF in the right direction in a short time—so your body goes up (or forward) instead of wasting force sideways or into the floor.

        Why it matters:
        • Stiff ankles and a strong kinetic chain help you transfer force into the ground efficiently, increasing effective GRF.
        • Leaks in the chain (e.g. knee cave, soft ankles) reduce how much of your effort becomes useful GRF.
        • The Lab’s biomechanics audit and Pop Force score help you find and fix those leaks.
        """

    // MARK: - Pop Force (App Metric)

    static let popForceTitle = "Pop Force"
    static let popForceShortDefinition = "Your elastic reactivity and ground-contact efficiency—the combination of RFD and GRF in your jump."
    static let popForceFullExplanation = """
        Pop Force is Final Evolution Lab’s composite score for how well you use Rate of Force Development (RFD) and Ground Reaction Force (GRF) when you jump. It reflects:

        • How quickly you build force after touch-down (RFD).
        • How efficiently you direct that force into the ground (GRF) so you get maximum height or distance.

        Improving ankle stiffness, hip extension timing, and reactive strength (e.g. pogos, depth jumps) raises your Pop Force and your in-game performance in the Arena.
        """

    /// Single concept for list/grid display.
    struct Concept: Identifiable {
        let id: String
        let title: String
        let shortDefinition: String
        let fullExplanation: String
        let iconName: String
        let color: Color

        static let rfd = Concept(
            id: "rfd",
            title: rfdTitle,
            shortDefinition: rfdShortDefinition,
            fullExplanation: rfdFullExplanation,
            iconName: "bolt.fill",
            color: .orange
        )
        static let grf = Concept(
            id: "grf",
            title: grfTitle,
            shortDefinition: grfShortDefinition,
            fullExplanation: grfFullExplanation,
            iconName: "arrow.down.to.line",
            color: Theme.brandBlue
        )
        static let popForce = Concept(
            id: "pop_force",
            title: popForceTitle,
            shortDefinition: popForceShortDefinition,
            fullExplanation: popForceFullExplanation,
            iconName: "flame.fill",
            color: Theme.brandCyan
        )
        static let all: [Concept] = [.rfd, .grf, .popForce]
    }
}
