import Foundation
import Testing
@testable import FinalEvolutionLab

/// Universal control mechanic: every sport plays on the ArenaPad
/// (joystick + d-pad + buttons); only quiz/party/rhythm/camera modes keep
/// native touch. This is the product spec — views must follow it.
struct ControlSchemeTests {

    @Test func allSportsUseTheArenaPad() {
        let padSports: [GameModeId] = [
            .basketballHeadToHead, .venicePickup, .basketball3v3,
            .basketballDunkContest3D, .karate, .karateEndless,
            .baseball, .football, .soccer, .golf, .tennis, .volleyball,
        ]
        for mode in padSports {
            #expect(mode.usesArenaPad, "\(mode.rawValue) must use the ArenaPad")
        }
    }

    @Test func quizPartyRhythmAndCameraKeepNativeTouch() {
        let touchModes: [GameModeId] = [
            .brainBrawl, .whoSceneIt, .courtCarnival,
            .gymnastics, .surfing, .skateboarding, .snowboarding,
            .basketballDunkContestIRL, .marketBrowse,
        ]
        for mode in touchModes {
            #expect(!mode.usesArenaPad, "\(mode.rawValue) keeps native touch controls")
        }
    }

    @Test func classificationCoversEveryMode() {
        // No mode may be unclassified — the switch above is exhaustive by
        // construction, but this pins the split if cases are added.
        let pad = GameModeId.allCases.filter(\.usesArenaPad).count
        let touch = GameModeId.allCases.filter { !$0.usesArenaPad }.count
        #expect(pad == 12)
        #expect(touch == 9)
        #expect(pad + touch == GameModeId.allCases.count)
    }
}
