import Foundation

// MARK: - Fuel the Freeway — Nutrition data model
// Photo-to-Shard: meal log with macros mapped to CNS/Fascia rewards.
// API hook ready for AI vision (Cursor/API) and Instacart export.

nonisolated struct FoodItem: Identifiable, Codable, Sendable {
    let id: String
    var name: String
    /// Grams or dominant unit
    var proteinGrams: Double
    /// Collagen-supporting (glycine/proline) or vitamin C–rich
    var fascialScore: Double
    /// Hydration / electrolytes (0...1)
    var hydrationScore: Double
    /// High leucine / structural repair
    var structuralRepair: Bool
    /// Collagen / vitamin C
    var fascialElasticity: Bool
    /// Hydration / electrolytes
    var signalVelocity: Bool
    /// Processed / inflammatory → triggers Congestion Alert
    var isInflammatory: Bool
    var loggedAt: Date

    /// Shard breakdown for this item (used when logging a meal).
    var shardRewards: [String: Int] {
        var out: [String: Int] = [:]
        if structuralRepair { out["Structural Repair"] = 5 }
        if fascialElasticity { out["Fascial Elasticity"] = 10 }
        if signalVelocity { out["Signal Velocity"] = 5 }
        return out
    }
}

nonisolated struct MealLogEntry: Identifiable, Codable, Sendable {
    let id: String
    var items: [FoodItem]
    var loggedAt: Date
    /// Set to true after user does a Movement Snack to clear congestion.
    var congestionCleared: Bool

    var totalShardsFromMeal: Int {
        var total = 0
        for item in items {
            total += item.shardRewards.values.reduce(0, +)
        }
        if congestionCleared { total += 5 }
        return total
    }

    var hasCongestion: Bool {
        items.contains { $0.isInflammatory }
    }
}

// MARK: - Cookbook (Vertical Velocity Kitchen)
// Fascial Hydration Broths, CNS Ignition Snacks; 3D Kitchen / Instacart placeholder.

nonisolated struct CookbookRecipe: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: RecipeCategory
    let ingredients: [String]
    let instructions: String
    /// For UI: which sling/line this supports (e.g. "Spiral Line", "Front Functional Line").
    let slingNote: String?
    /// Instacart/grocer list export — placeholder IDs for real API.
    var ingredientIdsForCart: [String] { ingredients.map { $0.lowercased().replacingOccurrences(of: " ", with: "_") } }

    enum RecipeCategory: String, Sendable, CaseIterable {
        case fascialHydration = "Fascial Hydration"
        case cnsIgnition = "CNS Ignition"
        case dstrkt = "Dstrkt Protocol"
    }
}

enum FuelCookbook {
    static let recipes: [CookbookRecipe] = [
        CookbookRecipe(
            id: "broth1",
            title: "Glycine-Proline Broth",
            subtitle: "Tensegrity support for the slings",
            category: .fascialHydration,
            ingredients: ["Bone broth", "Collagen powder", "Turmeric", "Black pepper", "Sea salt"],
            instructions: "Simmer bone broth with collagen until dissolved. Add turmeric, black pepper, and salt. Drink warm pre- or post-movement.",
            slingNote: "Spiral Line, Front Functional Line"
        ),
        CookbookRecipe(
            id: "broth2",
            title: "Electrolyte Replenish Broth",
            subtitle: "Signal velocity for the freeway",
            category: .fascialHydration,
            ingredients: ["Bone broth", "Coconut water", "Magnesium citrate", "Himalayan salt", "Lemon"],
            instructions: "Combine broth and coconut water. Stir in magnesium and salt. Finish with lemon. Use after intense CNS work.",
            slingNote: "Hydration supports whole-body conductivity"
        ),
        CookbookRecipe(
            id: "cns1",
            title: "Pre-Flight Ignition",
            subtitle: "Alpha-GPC & tyrosine focus",
            category: .cnsIgnition,
            ingredients: ["Eggs", "Grass-fed beef or salmon", "Leafy greens", "Olive oil"],
            instructions: "Eat 60–90 min before session. Prioritize choline (eggs) and tyrosine (protein) for neuro-transmission.",
            slingNote: nil
        ),
        CookbookRecipe(
            id: "cns2",
            title: "Neural Drive Bites",
            subtitle: "Pre-workout snack",
            category: .cnsIgnition,
            ingredients: ["Dark chocolate (85%+)", "Almonds", "Banana", "Sea salt"],
            instructions: "Small portion 30 min before training. Combines quick glucose with magnesium and minimal processing.",
            slingNote: nil
        ),
        CookbookRecipe(
            id: "dstrkt1",
            title: "Dstrkt Protocol — Game Day Fuel",
            subtitle: "Clean, pro-environment timing",
            category: .dstrkt,
            ingredients: ["Grass-fed steak or chicken", "Sweet potato", "Asparagus", "Avocado", "Bone broth"],
            instructions: "3–4 hours before competition. High protein, moderate carb, anti-inflammatory fats. Hydrate with broth.",
            slingNote: "Full systemic support for RFD"
        ),
    ]

    static func recipes(for category: CookbookRecipe.RecipeCategory) -> [CookbookRecipe] {
        recipes.filter { $0.category == category }
    }
}

// MARK: - Instacart / Grocer API placeholder
// One-click prep: export ingredient list to real-world cart.

enum InstacartExportService {
    /// Placeholder: in a full build, call Instacart/Whole Foods API to create a cart from ingredient list.
    /// - Parameter ingredientNames: e.g. ["Bone broth", "Collagen powder"]
    /// - Returns: URL to open app or web cart, or nil if not configured.
    static func exportToCart(ingredientNames: [String], mealPlanName: String?) -> URL? {
        // TODO: Integrate Instacart Partner API or deep link.
        // For now return nil; UI can show "Coming soon" or open a generic grocery list.
        _ = (ingredientNames, mealPlanName)
        return nil
    }

    /// Build a shareable or copyable grocery list string for the given recipe or meal plan.
    static func groceryListText(ingredientNames: [String], title: String?) -> String {
        let header = title.map { "\($0)\n" } ?? ""
        return header + ingredientNames.map { "• \($0)" }.joined(separator: "\n")
    }
}
