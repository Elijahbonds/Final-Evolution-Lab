import Foundation
import UIKit

/// Fuel the Freeway — meal photo → Gemini vision → macro flags for Evolution Shards (Swift ↔ Unreal economy parity via `ShardReward` / C++ `FELShardRewardTable`).
enum FELFuelPhotoShardService {
    /// Same semantics as `MealScanSheet` / Abstract: four booleans from one vision pass.
    struct MealShardAIResult: Sendable {
        let structuralRepair: Bool
        let fascialElasticity: Bool
        let signalVelocity: Bool
        let inflammatoryDetected: Bool
        let rawResponse: String
    }

    private static let mealAnalysisPrompt = """
    You are analyzing a meal photo for an athlete nutrition app (Fuel the Freeway). Reply with ONLY four words on one line, space-separated: yes or no for each.
    Order: 1) Structural Repair (high protein/leucine: meat, eggs, dairy, legumes) 2) Fascial Elasticity (collagen/vitamin C: bone broth, citrus, leafy greens, berries) 3) Signal Velocity (hydration/electrolytes: water, coconut water, fruits, vegetables) 4) Inflammatory (highly processed, sugary, or inflammatory foods).
    Example: yes no yes no
    """

    /// Calls Gemini vision (`generateContentWithImage`); does not mutate profile — caller applies `ShardReward.forMealLog` / `LabViewModel.applyMealLogRewards`.
    static func analyzeMealImage(_ image: UIImage) async throws -> MealShardAIResult {
        let jpeg = image.jpegData(compressionQuality: 0.7) ?? Data()
        let base64 = jpeg.base64EncodedString()
        let response = try await GeminiService.shared.generateContentWithImage(
            prompt: Self.mealAnalysisPrompt,
            imageBase64: base64,
            mimeType: "image/jpeg"
        )
        let parsed = parseGeminiMealResponse(response)
        return MealShardAIResult(
            structuralRepair: parsed.structural,
            fascialElasticity: parsed.fascial,
            signalVelocity: parsed.signal,
            inflammatoryDetected: parsed.inflammatory,
            rawResponse: response
        )
    }

    private static func parseGeminiMealResponse(_ text: String) -> (structural: Bool, fascial: Bool, signal: Bool, inflammatory: Bool) {
        let lower = text.lowercased()
        let tokens = lower.split(separator: " ").map(String.init)
        func isYes(_ s: String) -> Bool { s == "yes" || s.hasPrefix("y") }
        let a = tokens.count > 0 ? isYes(tokens[0]) : false
        let b = tokens.count > 1 ? isYes(tokens[1]) : false
        let c = tokens.count > 2 ? isYes(tokens[2]) : false
        let d = tokens.count > 3 ? isYes(tokens[3]) : false
        return (a, b, c, d)
    }
}
