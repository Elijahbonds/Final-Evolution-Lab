import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

/// RC 1.0: mirrors `AFELBasketballPlayerController::GenerateAthletePerformanceJSON` cached from Unreal via `FelCoachPerformanceSnapshot`.
enum FELCoachPerformanceSnapshot {
    static let userDefaultsKey = "felLastCoachPerformanceJSON"

    struct Payload: Codable {
        let athleteName: String?
        let gearId: String?
        let allTimePeakZ: Double?
        let fatigueState: String?
    }

    static func cacheFromNotification(_ json: String) {
        UserDefaults.standard.set(json, forKey: userDefaultsKey)
    }

    static var cachedJSONString: String? {
        UserDefaults.standard.string(forKey: userDefaultsKey)
    }

    static func decodedPayload() -> Payload? {
        guard let s = cachedJSONString, let data = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    /// Only when trend is Fatigued and not Inconclusive/Unknown (server-quality gate in `GetJumpPerformanceTrend`).
    static var isFatigueDetected: Bool {
        decodedPayload()?.fatigueState == "Fatigued"
    }

    static func copyToPasteboardForShare() {
        let s = cachedJSONString ?? fallbackJSON()
        #if canImport(UIKit)
        UIPasteboard.general.string = s
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #endif
    }

    private static func fallbackJSON() -> String {
        "{\"athleteName\":\"Elijah Bonds\",\"gearId\":\"Base\",\"allTimePeakZ\":0,\"fatigueState\":\"Unknown\"}"
    }
}
