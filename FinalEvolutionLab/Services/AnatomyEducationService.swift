import Foundation
import Combine

@MainActor
final class AnatomyEducationService: ObservableObject {
    static let shared = AnatomyEducationService()
    
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
    
    func beginModule(moduleId: String) async throws -> String {
        let bodyPayload = ["module_id": moduleId]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyPayload)
        let request = try makeRequest(path: "/api/education/bio-digital/begin-module", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let receipt = json["completion_receipt"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        return receipt
    }
    
    func completeModule(moduleId: String, receipt: String) async throws {
        let bodyPayload = [
            "module_id": moduleId,
            "completion_receipt": receipt
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyPayload)
        let request = try makeRequest(path: "/api/education/bio-digital/complete-module", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }
    
    func getEligibility() async throws -> KinesiologyEligibility {
        let request = try makeRequest(path: "/api/education/kinesiology/eligibility", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(KinesiologyEligibility.self, from: data)
    }
    
    func claimCertificate() async throws -> CertificateClaimResult {
        let request = try makeRequest(path: "/api/education/kinesiology/certify", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(CertificateClaimResult.self, from: data)
    }
    
    func startFinalAssessment() async throws -> KinesiologyAssessmentSession {
        let request = try makeRequest(path: "/api/education/kinesiology/final-assessment/start", method: "POST")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(KinesiologyAssessmentSession.self, from: data)
    }
    
    func submitFinalAssessment(token: String, answers: [Int]) async throws -> KinesiologyAssessmentResult {
        let bodyPayload: [String: Any] = [
            "attempt_token": token,
            "answers": answers
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyPayload)
        let request = try makeRequest(path: "/api/education/kinesiology/final-assessment/submit", method: "POST", body: bodyData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
            throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        return try JSONDecoder().decode(KinesiologyAssessmentResult.self, from: data)
    }
    
    func solveKinesiologyCoursework() async throws {
        let correctAnswers: [String: [Int]] = [
            "kin_bio_1": [1, 1, 1, 1],
            "kin_mus_1": [1, 1, 1, 1],
            "kin_ms_1": [1, 1, 1, 1],
            "kin_inj_1": [0, 1, 1, 1],
            "kin_per_1": [1, 1, 1, 1],
            "kin_neu_1": [1, 0, 1, 1],
            "kin_rec_1": [2, 1, 1, 0],
            "kin_eth_1": [1, 1, 1, 1]
        ]
        
        for (lessonId, answers) in correctAnswers {
            // 1. Open the lesson
            let openRequest = try makeRequest(path: "/api/education/tracks/kinesiology/lesson/\(lessonId)/open", method: "POST")
            let (_, openRes) = try await URLSession.shared.data(for: openRequest)
            guard let openHttp = openRes as? HTTPURLResponse, openHttp.statusCode == 200 else {
                throw NSError(domain: "AnatomyEducationService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to open lesson \(lessonId)"])
            }
            
            // 2. Submit the quiz
            let bodyPayload = ["answers": answers]
            let bodyData = try JSONSerialization.data(withJSONObject: bodyPayload)
            let submitRequest = try makeRequest(path: "/api/education/tracks/kinesiology/lesson/\(lessonId)/submit", method: "POST", body: bodyData)
            let (data, submitRes) = try await URLSession.shared.data(for: submitRequest)
            guard let submitHttp = submitRes as? HTTPURLResponse, submitHttp.statusCode == 200 else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Status code for \(lessonId)"
                throw NSError(domain: "AnatomyEducationService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to submit lesson \(lessonId): \(errorMsg)"])
            }
        }
    }
}

// MARK: - Models

struct EligibilityCheck: Codable, Hashable {
    let met: Bool
    let detail: String
}

struct KinesiologyEligibility: Codable, Hashable {
    let allMet: Bool
    let checks: Checks

    struct Checks: Codable, Hashable {
        let courseworkCompleted: EligibilityCheck
        let bioDigitalModules: EligibilityCheck
        let prqThreshold: EligibilityCheck
        let finalAssessment: EligibilityCheck

        enum CodingKeys: String, CodingKey {
            case courseworkCompleted = "coursework_completed"
            case bioDigitalModules = "bio_digital_modules"
            case prqThreshold = "prq_threshold"
            case finalAssessment = "final_assessment"
        }
    }

    enum CodingKeys: String, CodingKey {
        case allMet = "all_met"
        case checks
    }
}

struct CertificateClaimResult: Codable, Hashable {
    let certificateId: String?
    let issuedAt: String?
    let credential: String?
    let xpEarned: Int?
    let alreadyIssued: Bool?

    enum CodingKeys: String, CodingKey {
        case certificateId = "certificate_id"
        case issuedAt = "issued_at"
        case credential
        case xpEarned = "xp_earned"
        case alreadyIssued = "already_issued"
    }
}

struct KinesiologyAssessmentQuestion: Codable, Identifiable, Hashable {
    var id: Int { index }
    let index: Int
    let q: String
    let options: [String]
}

struct KinesiologyAssessmentSession: Codable, Hashable {
    let attemptToken: String
    let id: String
    let title: String
    let questions: [KinesiologyAssessmentQuestion]
    let passThresholdPct: Int
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case attemptToken = "attempt_token"
        case id
        case title
        case questions
        case passThresholdPct = "pass_threshold_pct"
        case expiresAt = "expires_at"
    }
}

struct KinesiologyAssessmentResult: Codable, Hashable {
    let scorePct: Double
    let passed: Bool
    let correct: Int
    let total: Int
    let finalVerifiedReceipt: String?

    enum CodingKeys: String, CodingKey {
        case scorePct = "score_pct"
        case passed
        case correct
        case total
        case finalVerifiedReceipt = "final_verified_receipt"
    }
}
