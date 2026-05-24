import Foundation
import Combine

@MainActor
final class BioFuelService: ObservableObject {
    static let shared = BioFuelService()
    
    @Published var sessionToken: String = "sess_edu_1777958291132"
    @Published var apiBaseURL: String = "http://localhost:8000"
    
    private init() {}
    
    private func makeRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(apiBaseURL)\(path)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }
    
    // MARK: - API Calls
    
    func getTodayProgress() async throws -> BioFuelToday {
        let request = try makeRequest(path: "/api/biofuel/today", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(BioFuelToday.self, from: data)
    }
    
    func getNeuroCues() async throws -> BioFuelCuesResponse {
        let request = try makeRequest(path: "/api/biofuel/cues", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(BioFuelCuesResponse.self, from: data)
    }
    
    func scanMeal(model: String, base64Image: String, hint: String?) async throws -> BioFuelScanResult {
        var payload: [String: Any] = [
            "model": model,
            "image_base64": base64Image
        ]
        if let hint = hint, !hint.isEmpty {
            payload["hint"] = hint
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(path: "/api/biofuel/scan", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(BioFuelScanResult.self, from: data)
    }
    
    func confirmScan(scanId: String) async throws -> BioFuelConfirmResult {
        let payload = ["scan_id": scanId]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(path: "/api/biofuel/scan/confirm", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(BioFuelConfirmResult.self, from: data)
    }
    
    func getRecipes(intent: String? = nil) async throws -> BioFuelRecipesList {
        var path = "/api/biofuel/recipes"
        if let intent = intent, !intent.isEmpty {
            path += "?intent=\(intent)"
        }
        
        let request = try makeRequest(path: path, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(BioFuelRecipesList.self, from: data)
    }
    
    func getRecipeDetail(id: String) async throws -> BioFuelRecipeDetail {
        let request = try makeRequest(path: "/api/biofuel/recipes/\(id)", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(BioFuelRecipeDetail.self, from: data)
    }
    
    func instacartCart(recipeId: String) async throws -> InstacartCartResult {
        let payload = ["recipe_id": recipeId]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(path: "/api/biofuel/instacart-cart", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(InstacartCartResult.self, from: data)
    }
    
    func doordashSearch(intent: String? = nil, maxCalories: Int? = nil, minProtein: Int? = nil) async throws -> DoorDashSearchResult {
        var payload: [String: Any] = [:]
        if let intent = intent, !intent.isEmpty {
            payload["intent"] = intent
        }
        if let maxCalories = maxCalories {
            payload["max_calories"] = maxCalories
        }
        if let minProtein = minProtein {
            payload["min_protein_g"] = minProtein
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(path: "/api/biofuel/doordash-search", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(DoorDashSearchResult.self, from: data)
    }
    
    func logManualMeal(label: String, calories: Int, protein: Int, carbs: Int, fats: Int, source: String = "manual") async throws -> BioFuelLogResult {
        let payload: [String: Any] = [
            "title": label,
            "calories": calories,
            "protein_g": protein,
            "carbs_g": carbs,
            "fats_g": fats,
            "source": source
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(path: "/api/biofuel/log", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "BioFuelService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(BioFuelLogResult.self, from: data)
    }
}

// MARK: - Codable Data Models

struct BioFuelMacros: Codable {
    let calories: Int
    let protein_g: Int
    let carbs_g: Int
    let fats_g: Int
    let hydration_ml: Int?
}

struct BioFuelEntry: Codable, Identifiable {
    var id: String {
        return _id ?? UUID().uuidString
    }
    let _id: String?
    let title: String
    let calories: Int
    let protein_g: Int
    let carbs_g: Int
    let fats_g: Int
    let hydration_ml: Int?
    let source: String
    let logged_at: String?
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case title
        case calories
        case protein_g
        case carbs_g
        case fats_g
        case hydration_ml
        case source
        case logged_at
    }
}

struct BioFuelToday: Codable {
    let day: String
    let weight_kg: Double
    let intent: String
    let intent_label: String
    let target: BioFuelMacros
    let consumed: BioFuelMacros
    let remaining: BioFuelMacros
    let pct: BioFuelMacros
    let entries: [BioFuelEntry]
    let targets_confidence: String?
    let weight_kg_source: String?
    let assumption_note: String?
}

struct BioFuelCue: Codable, Identifiable {
    var id: String {
        return _id ?? UUID().uuidString
    }
    let _id: String?
    let tone: String
    let icon: String
    let title: String
    let message: String
    let action_label: String?
    let action: String?
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case tone
        case icon
        case title
        case message
        case action_label
        case action
    }
}

struct BioFuelCuesResponse: Codable {
    let day: String
    let tone: String
    let cues: [BioFuelCue]
}

struct BioFuelScanResult: Codable {
    let scan_id: String
    let day: String
    let source: String
    let model_used: String
    let title: String
    let confidence: String
    let macros: BioFuelMacros
    let description: String
    let pending_confirmation: Bool
    let nutri_shards_potential: Int
    let allergy_diet_warnings: [String]?
    let allergy_diet_violation: Bool?
}

struct BioFuelConfirmResult: Codable {
    let ok: Bool
    let nutri_shards_awarded: Int?
    let scan_id: String
    let pending_confirmation: Bool
    let already_confirmed: Bool?
}

struct BioFuelIntent: Codable, Identifiable {
    var id: String
    let label: String
}

struct BioFuelRecipesList: Codable {
    let intents: [BioFuelIntent]
    let nutrition_filters_active: Bool
    let recipes: [BioFuelRecipeSummary]
}

struct BioFuelRecipeSummary: Codable, Identifiable {
    let id: String
    let title: String
    let intent: String
    let intent_label: String
    let duration_min: Int
    let macros: BioFuelMacros
    let summary: String
    let viz_palette: [String]
}

struct BioFuelIngredient: Codable, Hashable {
    let name: String
    let qty: String
}

struct BioFuelRecipeDetail: Codable, Identifiable {
    let id: String
    let title: String
    let intent: String
    let intent_label: String
    let duration_min: Int
    let macros: BioFuelMacros
    let micros: [String: Double]?
    let summary: String
    let ingredients: [BioFuelIngredient]
    let steps: [String]
    let viz_palette: [String]
}

struct InstacartCartResult: Codable {
    let recipe_id: String
    let recipe_title: String
    let deep_link: String
    let fallback_url: String
    let items: [String]
    let note: String
    let policy_note: String
}

struct DoorDashMatch: Codable, Identifiable {
    let id: String
    let intent: String
    let name: String
    let restaurant: String
    let macros: BioFuelMacros
    let city_query: String
    let price_approx_usd: Double
    let deep_link: String
}

struct DoorDashSearchResult: Codable {
    let intent: String
    let intent_label: String
    let remaining_today: BioFuelMacros
    let min_protein_g: Int
    let max_calories: Int
    let matches: [DoorDashMatch]
    let no_safe_matches: Bool
    let nutrition_filters_active: Bool
    let note: String
    let policy_note: String
}

struct BioFuelLogResult: Codable {
    let ok: Bool
    let day: String
    let deduped: Bool?
}
