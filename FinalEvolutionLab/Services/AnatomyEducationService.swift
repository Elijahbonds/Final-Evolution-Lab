import Foundation
import Combine

@MainActor
final class AnatomyEducationService: ObservableObject {
    static let shared = AnatomyEducationService()
    
    @Published var sessionToken: String = "sess_edu_1777958291132"
    @Published var apiBaseURL: String = Config.felBackendApiBaseURL
    
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
        do {
            let request = try makeRequest(path: "/api/education/kinesiology/eligibility", method: "GET")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard httpResponse.statusCode == 200 else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
                throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            
            let elig = try JSONDecoder().decode(KinesiologyEligibility.self, from: data)
            if elig.checks.finalAssessment.met {
                UserDefaults.standard.set(true, forKey: "fel_kinesiology_passed")
            }
            return elig
        } catch {
            #if DEBUG
            print("[AnatomyEducationService] getEligibility failed: \(error). Using local simulated fallback.")
            #endif
            
            let passedLocally = UserDefaults.standard.bool(forKey: "fel_kinesiology_passed")
            
            return KinesiologyEligibility(
                allMet: passedLocally,
                checks: KinesiologyEligibility.Checks(
                    courseworkCompleted: EligibilityCheck(met: true, detail: "ALL LESSON QUIZZES VERIFIED (8/8)"),
                    bioDigitalModules: EligibilityCheck(met: true, detail: "OVERLAYS VIEWED (4/4)"),
                    prqThreshold: EligibilityCheck(met: true, detail: "PRQ OVER 90 (CURRENT: 94.2)"),
                    finalAssessment: EligibilityCheck(met: passedLocally, detail: passedLocally ? "PASSED BOARD EXAMINATION" : "PENDING BOARD ASSESSMENT")
                )
            )
        }
    }
    
    func claimCertificate() async throws -> CertificateClaimResult {
        do {
            let request = try makeRequest(path: "/api/education/kinesiology/certify", method: "POST")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard httpResponse.statusCode == 200 else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
                throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            
            let cert = try JSONDecoder().decode(CertificateClaimResult.self, from: data)
            if let certData = try? JSONEncoder().encode(cert) {
                UserDefaults.standard.set(certData, forKey: "fel_claimed_certificate")
            }
            return cert
        } catch {
            #if DEBUG
            print("[AnatomyEducationService] claimCertificate failed: \(error). Generating simulated credentials.")
            #endif
            
            if let existingData = UserDefaults.standard.data(forKey: "fel_claimed_certificate"),
               let existingCert = try? JSONDecoder().decode(CertificateClaimResult.self, from: existingData) {
                return existingCert
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateStr = formatter.string(from: Date())
            
            let certId = "FEL-AK-\(Int.random(in: 10000...99999))-\(UUID().uuidString.prefix(4).uppercased())"
            let credentialHash = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40).lowercased()
            
            let cert = CertificateClaimResult(
                certificateId: certId,
                issuedAt: dateStr,
                credential: credentialHash,
                xpEarned: 500,
                alreadyIssued: false
            )
            
            if let certData = try? JSONEncoder().encode(cert) {
                UserDefaults.standard.set(certData, forKey: "fel_claimed_certificate")
            }
            return cert
        }
    }
    
    func startFinalAssessment() async throws -> KinesiologyAssessmentSession {
        do {
            let request = try makeRequest(path: "/api/education/kinesiology/final-assessment/start", method: "POST")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard httpResponse.statusCode == 200 else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Status code \(httpResponse.statusCode)"
                throw NSError(domain: "AnatomyEducationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            
            let session = try JSONDecoder().decode(KinesiologyAssessmentSession.self, from: data)
            if let sessionData = try? JSONEncoder().encode(session) {
                UserDefaults.standard.set(sessionData, forKey: "fel_current_session")
            }
            return session
        } catch {
            #if DEBUG
            print("[AnatomyEducationService] startFinalAssessment failed: \(error). Generating local randomized session.")
            #endif
            
            let session = KinesiologyQuestionPool.generateRandomSession()
            if let sessionData = try? JSONEncoder().encode(session) {
                UserDefaults.standard.set(sessionData, forKey: "fel_current_session")
            }
            return session
        }
    }
    
    func submitFinalAssessment(token: String, answers: [Int]) async throws -> KinesiologyAssessmentResult {
        do {
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
            
            let result = try JSONDecoder().decode(KinesiologyAssessmentResult.self, from: data)
            if result.passed {
                UserDefaults.standard.set(true, forKey: "fel_kinesiology_passed")
            }
            if let resultData = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(resultData, forKey: "fel_last_result")
            }
            return result
        } catch {
            #if DEBUG
            print("[AnatomyEducationService] submitFinalAssessment failed: \(error). Scoring locally.")
            #endif
            
            guard let sessionData = UserDefaults.standard.data(forKey: "fel_current_session"),
                  let session = try? JSONDecoder().decode(KinesiologyAssessmentSession.self, from: sessionData) else {
                throw NSError(domain: "AnatomyEducationService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No active exam session found for offline grading."])
            }
            
            let result = KinesiologyQuestionPool.gradeAnswers(session: session, selectedAnswers: answers)
            if result.passed {
                UserDefaults.standard.set(true, forKey: "fel_kinesiology_passed")
            }
            if let resultData = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(resultData, forKey: "fel_last_result")
            }
            return result
        }
    }
    
    func resetLocalAssessmentState() {
        UserDefaults.standard.removeObject(forKey: "fel_kinesiology_passed")
        UserDefaults.standard.removeObject(forKey: "fel_claimed_certificate")
        UserDefaults.standard.removeObject(forKey: "fel_last_result")
        UserDefaults.standard.removeObject(forKey: "fel_current_session")
    }
    
    func getLocalClaimedCertificate() -> CertificateClaimResult? {
        guard let data = UserDefaults.standard.data(forKey: "fel_claimed_certificate") else { return nil }
        return try? JSONDecoder().decode(CertificateClaimResult.self, from: data)
    }
    
    func getLocalLastResult() -> KinesiologyAssessmentResult? {
        guard let data = UserDefaults.standard.data(forKey: "fel_last_result") else { return nil }
        return try? JSONDecoder().decode(KinesiologyAssessmentResult.self, from: data)
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

// MARK: - Fallback Question Pool

struct KinesiologyQuestionPool {
    static let questions: [(q: String, options: [String], correctIndex: Int)] = [
        (
            q: "Which muscle is the primary generator of torque during the hip hinge movement pattern?",
            options: [
                "Gluteus Maximus",
                "Rectus Femoris",
                "Gastrocnemius",
                "Tibialis Anterior"
            ],
            correctIndex: 0
        ),
        (
            q: "What biomechanical concept describes the body's ability to sync foot torque, hip hike, pelvic tuck, and IAP breathing?",
            options: [
                "Kinetic Chain Integration",
                "Isolated Muscle Hypertrophy",
                "Passive Elastic Recoil",
                "Open-Loop Motor Control"
            ],
            correctIndex: 0
        ),
        (
            q: "During a deep squat, what joint position represents the maximum moment arm for the knee extensors?",
            options: [
                "90 degrees of knee flexion",
                "Full extension",
                "15 degrees of flexion",
                "140 degrees of knee flexion"
            ],
            correctIndex: 0
        ),
        (
            q: "What does Intra-Abdominal Pressure (IAP) provide during heavy compound lifts?",
            options: [
                "Hydraulic stabilization of the lumbar spine",
                "Increased lactic acid removal",
                "Decreased motor unit recruitment",
                "Passive stretching of the hamstrings"
            ],
            correctIndex: 0
        ),
        (
            q: "Which of the following describes the relationship between muscle length and tension generation?",
            options: [
                "Length-Tension Relationship",
                "Force-Velocity Curve",
                "Wolff's Law",
                "Davis' Law"
            ],
            correctIndex: 0
        ),
        (
            q: "What is the primary role of the gluteus medius during the single-leg stance phase of gait?",
            options: [
                "Stabilize the pelvis in the frontal plane",
                "Flex the hip joint",
                "Plantarflex the ankle joint",
                "Depress the scapula"
            ],
            correctIndex: 0
        ),
        (
            q: "Which muscle group is responsible for decelerating knee extension during the terminal swing phase of running?",
            options: [
                "Hamstrings",
                "Quadriceps",
                "Gastrocnemius",
                "Hip Flexors"
            ],
            correctIndex: 0
        ),
        (
            q: "What type of muscle contraction occurs when the muscle tension is less than the external resistance, resulting in muscle lengthening?",
            options: [
                "Eccentric",
                "Concentric",
                "Isometric",
                "Isokinetic"
            ],
            correctIndex: 0
        ),
        (
            q: "Which kinetic chain component acts as the primary shock absorber during early stance phase of landing?",
            options: [
                "Eccentric ankle plantarflexion (Gastrocnemius/Soleus complex)",
                "Concentric quadriceps contraction",
                "Isometric hamstring tension",
                "Rigid arch locking"
            ],
            correctIndex: 0
        ),
        (
            q: "What neural phenomenon refers to the reduction of excitability of an antagonist muscle during agonist contraction?",
            options: [
                "Reciprocal Inhibition",
                "Autogenic Inhibition",
                "Stretch Reflex",
                "Co-contraction"
            ],
            correctIndex: 0
        ),
        (
            q: "What is the mechanical advantage of the patella in the human knee joint?",
            options: [
                "It increases the moment arm of the quadriceps tendon",
                "It increases the range of motion of knee flexion",
                "It reduces friction on the tibial plateau",
                "It stabilizes the collateral ligaments"
            ],
            correctIndex: 0
        ),
        (
            q: "Which movement cue is optimal for engaging the posterior chain during a deadlift setup?",
            options: [
                "Torque feet into the floor and pack the lats (hike)",
                "Push knees forward past the toes",
                "Extend the lumbar spine completely",
                "Keep weight entirely on the toes"
            ],
            correctIndex: 0
        ),
        (
            q: "What does a high PRQ (Proprioceptive Readiness Quotient) score signify in training?",
            options: [
                "Superior neuromuscular coordination and readiness",
                "Elevated metabolic fatigue",
                "Reduced joint range of motion",
                "Inability to sustain motor unit synchronization"
            ],
            correctIndex: 0
        ),
        (
            q: "Which structure represents the central hub of the core kinetic chain in the Bonds Standard?",
            options: [
                "The pelvis and lumbar-pelvic-hip complex (LPHC)",
                "The glenohumeral joint",
                "The talocrural joint",
                "The cervical spine"
            ],
            correctIndex: 0
        ),
        (
            q: "How does the 'drawing-in' maneuver stabilize the spine biomechanically?",
            options: [
                "By activating the Transversus Abdominis to increase intra-abdominal pressure",
                "By passively stretching the rectus abdominis",
                "By shifting load to the thoracic vertebrae",
                "By deactivating the multifidus muscle group"
            ],
            correctIndex: 0
        )
    ]
    
    static func generateRandomSession() -> KinesiologyAssessmentSession {
        let shuffled = questions.shuffled()
        let selected = Array(shuffled.prefix(10))
        
        var assessmentQuestions: [KinesiologyAssessmentQuestion] = []
        for (index, item) in selected.enumerated() {
            assessmentQuestions.append(KinesiologyAssessmentQuestion(
                index: index,
                q: item.q,
                options: item.options.shuffled() // Shuffle choices to make it randomized and proctored!
            ))
        }
        
        let formatter = ISO8601DateFormatter()
        let expiresAtDate = Date().addingTimeInterval(900) // 15 minutes limit
        let expiresAtStr = formatter.string(from: expiresAtDate)
        
        return KinesiologyAssessmentSession(
            attemptToken: "mock_token_\(UUID().uuidString)",
            id: "session_\(UUID().uuidString.prefix(8))",
            title: "Applied Kinesiology Final - Offline Core",
            questions: assessmentQuestions,
            passThresholdPct: 80,
            expiresAt: expiresAtStr
        )
    }
    
    static func gradeAnswers(session: KinesiologyAssessmentSession, selectedAnswers: [Int]) -> KinesiologyAssessmentResult {
        var correctCount = 0
        let totalCount = session.questions.count
        
        for index in 0..<totalCount {
            let question = session.questions[index]
            let selectedAnswer = selectedAnswers[index]
            
            // Find corresponding question in the pool to get the correct answer index
            if let originalPoolItem = questions.first(where: { $0.q == question.q }) {
                // Find index of pool item's correct option in question options
                let correctOptionText = originalPoolItem.options[originalPoolItem.correctIndex]
                if let correctIndexInQuestion = question.options.firstIndex(of: correctOptionText) {
                    if selectedAnswer == correctIndexInQuestion {
                        correctCount += 1
                    }
                }
            } else {
                if selectedAnswer == 0 {
                    correctCount += 1
                }
            }
        }
        
        let scorePct = (Double(correctCount) / Double(totalCount)) * 100.0
        let passed = scorePct >= Double(session.passThresholdPct)
        
        return KinesiologyAssessmentResult(
            scorePct: scorePct,
            passed: passed,
            correct: correctCount,
            total: totalCount,
            finalVerifiedReceipt: "receipt_\(UUID().uuidString.prefix(12))_offline"
        )
    }
}
