import Foundation

/// Posts gameplay notifications consumed by ``GameSceneHostView`` for event-triggered scenic camera cuts.
enum FELGameplayEventBus {
    static func postScored() {
        NotificationCenter.default.post(name: .felGameplayScored, object: nil)
    }

    static func postBuzzIn() {
        NotificationCenter.default.post(name: .felGameplayBuzzIn, object: nil)
    }

    static func postPenalty() {
        NotificationCenter.default.post(name: .felGameplayPenalty, object: nil)
    }

    static func postKarateBlock() {
        NotificationCenter.default.post(name: .felGameplayKarateBlock, object: nil)
    }

    static func postWaveCompleted() {
        NotificationCenter.default.post(name: .felGameplayWaveCompleted, object: nil)
    }

    /// Opponent H2H turn — scenic broadcast cut + opponent avatar focus in ``GameSceneHostView``.
    static func postOpponentScored() {
        NotificationCenter.default.post(name: .felGameplayOpponentScored, object: nil)
    }

    /// Dunk contest judging moment — score-card reveal VFX (``FELVFXTemplates``)
    /// + announcer sting/duck (``FELAudioDirector``) in ``GameSceneHostView``.
    static func postJudgeReveal(scores: [Int]) {
        NotificationCenter.default.post(name: .felGameplayJudgeReveal,
                                        object: nil,
                                        userInfo: ["scores": scores])
    }
}

extension Notification.Name {
    static let felGameplayScored = Notification.Name("FELGameplayScored")
    static let felGameplayBuzzIn = Notification.Name("FELGameplayBuzzIn")
    static let felGameplayPenalty = Notification.Name("FELGameplayPenalty")
    static let felGameplayKarateBlock = Notification.Name("FELGameplayKarateBlock")
    static let felGameplayWaveCompleted = Notification.Name("FELGameplayWaveCompleted")
    static let felGameplayOpponentScored = Notification.Name("FELGameplayOpponentScored")
    static let felGameplayJudgeReveal = Notification.Name("FELGameplayJudgeReveal")
}
