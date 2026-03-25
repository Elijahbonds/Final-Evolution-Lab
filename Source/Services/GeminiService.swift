import Foundation
import Observation

// MARK: - Gemini API (Google AI) — REST client for Xcode
// Use for Photo-to-Shard meal analysis, chat, or any generateContent. Get an API key: https://aistudio.google.com/apikey

/// Lightweight Gemini REST client. API key from Info.plist (GEMINI_API_KEY) or environment.
@Observable
@MainActor
final class GeminiService {
    static let shared = GeminiService()

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-1.5-flash"

    /// Set via configure(apiKey:) or read from Bundle/ProcessInfo. Never commit real keys.
    private(set) var apiKey: String?

    var isConfigured: Bool { apiKey != nil && !(apiKey?.isEmpty ?? true) }

    private init() {
        apiKey = Self.readAPIKeyFromEnvironment()
    }

    /// Call once at app launch (e.g. from App delegate or first view). Prefer loading from a secure config.
    func configure(apiKey: String?) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? apiKey : nil
    }

    /// Generate text from a prompt. Use for chat, analysis, or after parsing image + prompt for Photo-to-Shard.
    func generateContent(prompt: String) async throws -> String {
        guard let apiKey else {
            throw GeminiError.missingAPIKey
        }
        return try await Self.generateContentREST(prompt: prompt, apiKey: apiKey)
    }

    /// Stateless Gemini `generateContent` — safe from `Task.detached` so MainActor / SwiftUI never blocks on I/O (~16.7 ms frame budget).
    nonisolated static func generateContentREST(prompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.4,
                "maxOutputTokens": 1024,
            ] as [String: Any],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        if http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let errMsg = (message?["message"] as? String) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(errMsg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String
        guard let text else {
            throw GeminiError.noContent
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Analyze an image (e.g. meal photo) with a prompt. Pass image as base64-encoded JPEG/PNG data.
    func generateContentWithImage(prompt: String, imageBase64: String, mimeType: String = "image/jpeg") async throws -> String {
        guard let apiKey else {
            throw GeminiError.missingAPIKey
        }
        let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [
                    ["text": prompt],
                    [
                        "inline_data": [
                            "mime_type": mimeType,
                            "data": imageBase64
                        ]
                    ]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1024,
            ] as [String : Any]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        if http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let errMsg = (message?["message"] as? String) ?? "HTTP \(http.statusCode)"
            throw GeminiError.apiError(errMsg)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String
        guard let text else {
            throw GeminiError.noContent
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readAPIKeyFromEnvironment() -> String? {
        FELAppConfig.geminiAPIKey
    }
}

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case noContent
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key not set. Add GEMINI_API_KEY to Info.plist or call GeminiService.shared.configure(apiKey:)."
        case .invalidResponse:
            return "Invalid response from Gemini API."
        case .noContent:
            return "No content in Gemini response."
        case .apiError(let msg):
            return "Gemini API error: \(msg)"
        }
    }
}
