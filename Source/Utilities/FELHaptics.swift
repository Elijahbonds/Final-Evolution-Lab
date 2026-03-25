import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Vertical Velocity Academy — penultimate stride phases (sync with `UFELInputManager::PlayPushTwelveClinicalHaptic` / Unreal `BeatPhaseMod3`).
enum FELPenultimateStridePhase: Int, Sendable, CaseIterable {
    case push = 0
    case beatOne = 1
    case beatTwo = 2

    static func clamped(_ raw: Int) -> Self {
        let m = ((raw % 3) + 3) % 3
        return Self(rawValue: m) ?? .push
    }
}

/// Physical “reward” feedback for Unreal session import / Neuro-Mechanic milestones.
enum FELHaptics {
    /// Medium impact when `felUnrealSessionResultsReady` fires or an orphaned session is merged.
    static func sessionRewardImpact() {
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred(intensity: 0.95)
        #endif
    }

    /// "Delete the Fear" launch splash — four beats over ~1.2s to mask Unreal `WarmUpForBioSync` / arena precache during cold open.
    static func deleteTheFearLaunchHeartbeat() {
        #if canImport(UIKit)
        let light = UIImpactFeedbackGenerator(style: .light)
        let medium = UIImpactFeedbackGenerator(style: .medium)
        light.prepare()
        light.impactOccurred(intensity: 0.72)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            medium.prepare()
            medium.impactOccurred(intensity: 0.82)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
            light.impactOccurred(intensity: 0.58)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.96) {
            medium.impactOccurred(intensity: 0.76)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.18) {
            light.impactOccurred(intensity: 0.48)
        }
        #endif
    }

    /// Bio-Sync complete (`felBioSyncComplete`) — readiness snapshot written for Unreal Lab handoff.
    static func bioSyncCompleteSuccess() {
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
        #endif
    }

    /// Unreal `FELNativeBridge` — Academy terminal, module completion, match end; 4 = Perfect dunk (legacy), 5 = Perfect strike, 6 = motion-warp "thud".
    static func unrealUINotificationFeedback(kind: Int) {
        #if canImport(UIKit)
        switch kind {
        case 4:
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            heavy.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
                let rigid = UIImpactFeedbackGenerator(style: .rigid)
                rigid.prepare()
                rigid.impactOccurred(intensity: 0.92)
            }
        case 5:
            let rigid = UIImpactFeedbackGenerator(style: .rigid)
            rigid.prepare()
            rigid.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                let med = UIImpactFeedbackGenerator(style: .medium)
                med.prepare()
                med.impactOccurred(intensity: 0.78)
            }
        case 6:
            // Motion-warp apex: sharp physical "thud" (Bonds Bounce takeoff contact).
            let rigid = UIImpactFeedbackGenerator(style: .rigid)
            rigid.prepare()
            rigid.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.018) {
                let heavy = UIImpactFeedbackGenerator(style: .heavy)
                heavy.prepare()
                heavy.impactOccurred(intensity: 1.0)
            }
        case 7:
            // Bonds Apex — Sonic Flare at jump apex (Niagara) — short dynamic burst (ProMotion-safe).
            let soft = UIImpactFeedbackGenerator(style: .soft)
            soft.prepare()
            soft.impactOccurred(intensity: 0.88)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.028) {
                let light = UIImpactFeedbackGenerator(style: .light)
                light.prepare()
                light.impactOccurred(intensity: 0.72)
            }
        default:
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
        }
        #endif
    }

    /// Push 1, 2 — Bonds Standard haptics from Unreal `UFELRhythmicCueingWidget` / `felPenultimateStrideRhythm` (iOS Taptic Engine).
    static func pushPenultimateStrideClinical(phase: FELPenultimateStridePhase) {
        #if canImport(UIKit)
        switch phase {
        case .push:
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            heavy.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                let med = UIImpactFeedbackGenerator(style: .medium)
                med.prepare()
                med.impactOccurred(intensity: 0.72)
            }
        case .beatOne, .beatTwo:
            let rigid = UIImpactFeedbackGenerator(style: .rigid)
            rigid.prepare()
            rigid.impactOccurred(intensity: phase == .beatOne ? 0.88 : 0.95)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.022) {
                let light = UIImpactFeedbackGenerator(style: .light)
                light.prepare()
                light.impactOccurred(intensity: 0.55)
            }
        }
        #endif
    }
}
