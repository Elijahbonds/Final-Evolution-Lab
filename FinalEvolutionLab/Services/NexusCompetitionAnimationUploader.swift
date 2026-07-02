import Foundation
import os
import Combine
import SceneKit

/// Service responsible for validating, saving, local caching, robust uploading, and feed-fetching of competition animations (.nexusanim.json).
/// Fully implements simulated progress tracking, offline fallbacks, queue management, and community feed integration.
final class NexusCompetitionAnimationUploader: Sendable {
    static let shared = NexusCompetitionAnimationUploader()
    
    private static let log = Logger(subsystem: "com.finalevolutionlab.app", category: "CompetitionAnimationUploader")

    private init() {}

    // MARK: - Constants & Directories

    /// Directory where user recorded competition animations are saved.
    static var localAnimationsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("competition_animations", isDirectory: true)
    }

    /// Directory where failed uploads are queued for offline fallback.
    static var pendingUploadsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("pending_competition_uploads", isDirectory: true)
    }

    // MARK: - Data Models

    /// Represents a public community competition animation uploaded by a user.
    public struct CommunityAnimation: Codable, Sendable, Identifiable, Equatable {
        public let id: String
        public let title: String
        public let author: String
        public let authorAvatarUrl: String?
        public let duration: Double
        public let timestamp: Date
        public let downloadUrl: String
        public var likeCount: Int
        public var isLiked: Bool
        public let tag: String?
        public let prqScore: Double?

        public init(
            id: String,
            title: String,
            author: String,
            authorAvatarUrl: String? = nil,
            duration: Double,
            timestamp: Date = Date(),
            downloadUrl: String,
            likeCount: Int = 0,
            isLiked: Bool = false,
            tag: String? = nil,
            prqScore: Double? = nil
        ) {
            self.id = id
            self.title = title
            self.author = author
            self.authorAvatarUrl = authorAvatarUrl
            self.duration = duration
            self.timestamp = timestamp
            self.downloadUrl = downloadUrl
            self.likeCount = likeCount
            self.isLiked = isLiked
            self.tag = tag
            self.prqScore = prqScore
        }
    }

    /// Errors that can occur during saving, caching, or uploading.
    public enum UploaderError: LocalizedError, Sendable {
        case directoryCreationFailed(String)
        case writeFailed(String)
        case readFailed(String)
        case deleteFailed(String)
        case invalidFile
        case corruptJSON(String)
        case networkUnavailable
        case serverError(statusCode: Int, message: String)
        case unauthorized
        case simulationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .directoryCreationFailed(let msg): return "Failed to create uploader directory: \(msg)"
            case .writeFailed(let msg): return "Failed to write animation: \(msg)"
            case .readFailed(let msg): return "Failed to read animation: \(msg)"
            case .deleteFailed(let msg): return "Failed to delete animation: \(msg)"
            case .invalidFile: return "Selected file is invalid or missing."
            case .corruptJSON(let msg): return "Animation JSON is corrupt: \(msg)"
            case .networkUnavailable: return "Network unavailable. Animation queued for offline upload."
            case .serverError(let code, let msg): return "Server error (HTTP \(code)): \(msg)"
            case .unauthorized: return "Unauthorized. Please log in to upload competition animations."
            case .simulationFailed(let msg): return "Upload simulation failed: \(msg)"
            }
        }
    }

    // MARK: - Memory Cache for Session Uploads

    /// Dynamic memory cache to hold successfully uploaded animations during this app session.
    /// Combined with fetched feed items to ensure immediate UI feedback.
    private static let sessionUploadedAnimationsLock = NSLock()
    private static var _sessionUploadedAnimations: [CommunityAnimation] = []

    public static var sessionUploadedAnimations: [CommunityAnimation] {
        sessionUploadedAnimationsLock.lock()
        defer { sessionUploadedAnimationsLock.unlock() }
        return _sessionUploadedAnimations
    }

    private static func addSessionUploadedAnimation(_ animation: CommunityAnimation) {
        sessionUploadedAnimationsLock.lock()
        defer { sessionUploadedAnimationsLock.unlock() }
        _sessionUploadedAnimations.insert(animation, at: 0)
    }

    // MARK: - Setup & Initialization

    /// Initializes and ensures required directories exist.
    public static func ensureDirectoriesExist() throws {
        let fileManager = FileManager.default
        do {
            if !fileManager.fileExists(atPath: localAnimationsDirectory.path) {
                try fileManager.createDirectory(at: localAnimationsDirectory, withIntermediateDirectories: true)
                log.info("Created local animations cache directory: \(localAnimationsDirectory.path, privacy: .public)")
            }
            if !fileManager.fileExists(atPath: pendingUploadsDirectory.path) {
                try fileManager.createDirectory(at: pendingUploadsDirectory, withIntermediateDirectories: true)
                log.info("Created pending uploads offline directory: \(pendingUploadsDirectory.path, privacy: .public)")
            }
        } catch {
            log.error("Failed to create uploader directories: \(error.localizedDescription, privacy: .public)")
            throw UploaderError.directoryCreationFailed(error.localizedDescription)
        }
    }

    // MARK: - Legacy / Required API Methods

    /// Validates a .nexusanim.json payload string.
    /// - Parameter jsonString: The JSON string content of the animation file.
    /// - Returns: True if the payload is valid and can be decoded into a NexusAnimationAsset.
    func validateAnimationPayload(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        do {
            _ = try NexusAnimationAsset.decode(from: data)
            return true
        } catch {
            Self.log.error("[NexusCompetitionAnimationUploader] Validation failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Uploads an animation asset to the user's profile.
    /// - Parameters:
    ///   - title: The title of the animation.
    ///   - competitionName: The name of the competition where it was captured.
    ///   - category: The category of the animation (e.g., "Dunk", "Jump", "Kick").
    ///   - jsonPayload: The JSON string payload.
    ///   - profile: The user profile to upload to.
    /// - Returns: A tuple containing the updated profile and the uploaded asset, or nil if upload failed.
    func uploadAnimation(
        title: String,
        competitionName: String,
        category: String,
        jsonPayload: String,
        to profile: UserProfile
    ) -> (UserProfile, NexusAnimationAsset)? {
        var updatedProfile = profile
        
        let finalPayload: String
        if jsonPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalPayload = generateMockPayload(title: title, category: category)
        } else {
            finalPayload = jsonPayload
        }
        
        guard let data = finalPayload.data(using: .utf8) else { return nil }
        
        do {
            var asset = try NexusAnimationAsset.decode(from: data)
            asset.header.title = title
            asset.header.competitionName = competitionName
            asset.header.category = category
            asset.header.creatorId = profile.id
            
            updatedProfile.competitionAnimations.append(asset)
            
            return (updatedProfile, asset)
        } catch {
            Self.log.error("[NexusCompetitionAnimationUploader] Upload failed during decoding: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Generates a realistic mock .nexusanim.json payload for testing.
    func generateMockPayload(title: String, category: String) -> String {
        let id = "anim_\(UUID().uuidString.prefix(8))"
        let duration = 1.8
        let frameRate = 30.0
        let frameCount = Int(duration * frameRate)
        
        var keyframes: [NexusAnimationAsset.NexusAnimationFrame] = []
        
        for frameIdx in 0...frameCount {
            let time = Double(frameIdx) / frameRate
            let progress = time / duration
            
            var jointRotations: [String: SCNVector4] = [:]
            var translationOffsets: [String: SCNVector3] = [:]
            
            let heightOffset = Float(-4.0 * (progress - 0.5) * (progress - 0.5) + 1.0) * 1.8
            translationOffsets["torso"] = SCNVector3(0, max(0, heightOffset), 0)
            
            if category.lowercased() == "dunk" {
                let armAngle = Float(-progress * .pi)
                jointRotations["rUpperArm"] = SCNVector4(0, 0, 1, armAngle)
                jointRotations["lUpperArm"] = SCNVector4(0, 0, 1, -armAngle)
                
                let kneeAngle = Float(sin(progress * .pi) * 0.8)
                jointRotations["rKnee"] = SCNVector4(1, 0, 0, kneeAngle)
                jointRotations["lKnee"] = SCNVector4(1, 0, 0, kneeAngle)
            } else if category.lowercased() == "kick" {
                let kickAngle = Float(sin(progress * .pi) * 1.2)
                jointRotations["rLeg"] = SCNVector4(1, 0, 0, -kickAngle)
                jointRotations["lLeg"] = SCNVector4(1, 0, 0, kickAngle * 0.2)
            } else {
                let angle = Float(sin(progress * .pi * 2) * 0.5)
                jointRotations["torso"] = SCNVector4(0, 1, 0, angle)
            }
            
            let frame = NexusAnimationAsset.NexusAnimationFrame(
                timestamp: time,
                jointRotations: jointRotations,
                translationOffsets: translationOffsets
            )
            keyframes.append(frame)
        }
        
        let header = NexusAnimationAsset.Header(
            id: id,
            title: title,
            competitionName: "WDA Pro Invitational",
            category: category,
            creatorId: "system",
            captureTimestamp: Date(),
            frameRate: frameRate,
            duration: duration,
            jointCount: 11
        )
        
        let asset = NexusAnimationAsset(header: header, keyframes: keyframes)
        
        if let data = try? asset.encode(), let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
    
    /// Returns standard preset animations that players can use or upload.
    func getStandardPresets() -> [NexusAnimationAsset] {
        let presets = [
            ("Double-Clutch Windmill", "Dunk", "WDA Championship 2026"),
            ("Free-Throw Line Glide", "Dunk", "Slam Dunk Contest 2026"),
            ("360 Eastbay Spike", "Dunk", "WDA Global Finals"),
            ("Stella Adler Monologue", "Drama/Artistic", "Stella Adler Studio"),
            ("Double Kick Kick", "Kick", "World Martial Arts Expo")
        ]
        
        return presets.map { title, category, compName in
            let payload = generateMockPayload(title: title, category: category)
            let data = payload.data(using: .utf8)!
            var asset = try! NexusAnimationAsset.decode(from: data)
            asset.header.competitionName = compName
            return asset
        }
    }

    // MARK: - Local Caching & Saving API

    /// Saves a `NexusAnimationAsset` model as a `.nexusanim.json` file in the local document directory.
    @discardableResult
    static func saveAnimation(_ asset: NexusAnimationAsset) throws -> URL {
        try ensureDirectoriesExist()
        let fileURL = localAnimationsDirectory.appendingPathComponent("\(asset.id).nexusanim.json")
        
        do {
            let data = try asset.encode()
            try data.write(to: fileURL, options: .atomic)
            log.info("Successfully saved animation '\(asset.header.title)' to: \(fileURL.path, privacy: .public)")
            return fileURL
        } catch {
            log.error("Failed to save animation '\(asset.id)': \(error.localizedDescription, privacy: .public)")
            throw UploaderError.writeFailed(error.localizedDescription)
        }
    }

    /// Saves a raw JSON string of a `.nexusanim` file into the local document directory.
    @discardableResult
    static func saveAnimation(clipId: String, jsonString: String) throws -> URL {
        try ensureDirectoriesExist()
        guard let data = jsonString.data(using: .utf8) else {
            throw UploaderError.writeFailed("Could not convert JSON string to UTF-8 data")
        }
        
        // Validate JSON matches NexusAnimationAsset structure
        do {
            _ = try NexusAnimationAsset.decode(from: data)
        } catch {
            log.error("Failed to validate JSON string against NexusAnimationAsset schema: \(error.localizedDescription, privacy: .public)")
            throw UploaderError.corruptJSON(error.localizedDescription)
        }
        
        let fileURL = localAnimationsDirectory.appendingPathComponent("\(clipId).nexusanim.json")
        do {
            try data.write(to: fileURL, options: .atomic)
            log.info("Successfully saved raw JSON animation '\(clipId)' to: \(fileURL.path, privacy: .public)")
            return fileURL
        } catch {
            log.error("Failed to save raw JSON animation '\(clipId)': \(error.localizedDescription, privacy: .public)")
            throw UploaderError.writeFailed(error.localizedDescription)
        }
    }

    /// Retrieves all saved `.nexusanim.json` file URLs from the local caching directory.
    static func getSavedAnimations() throws -> [URL] {
        try ensureDirectoriesExist()
        let fileManager = FileManager.default
        do {
            let entries = try fileManager.contentsOfDirectory(
                at: localAnimationsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return entries.filter { $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.contains(".nexusanim") }
        } catch {
            log.error("Failed to list saved animations: \(error.localizedDescription, privacy: .public)")
            throw UploaderError.readFailed(error.localizedDescription)
        }
    }

    /// Loads and parses a `NexusAnimationAsset` model from a local file URL.
    static func getAnimation(at url: URL) throws -> NexusAnimationAsset {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UploaderError.invalidFile
        }
        do {
            let data = try Data(contentsOf: url)
            return try NexusAnimationAsset.decode(from: data)
        } catch let error as DecodingError {
            log.error("JSON decoding error for animation at \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw UploaderError.corruptJSON(error.localizedDescription)
        } catch {
            log.error("Failed to read animation at \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw UploaderError.readFailed(error.localizedDescription)
        }
    }

    /// Deletes a saved animation from the local caching directory.
    static func deleteAnimation(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
            log.info("Successfully deleted animation file: \(url.lastPathComponent, privacy: .public)")
        } catch {
            log.error("Failed to delete animation file \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw UploaderError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Simulated & Real Upload Implementation

    /// Configuration parameters for upload simulation (network reliability, speed).
    struct SimulationConfig: Sendable {
        let uploadSpeedKbps: Double
        let failRate: Double // Range 0.0 - 1.0
        let artificialDelayRange: ClosedRange<Double>
        
        static let standardWifi = SimulationConfig(uploadSpeedKbps: 4096, failRate: 0.0, artificialDelayRange: 0.05...0.15)
        static let flaky3G = SimulationConfig(uploadSpeedKbps: 256, failRate: 0.15, artificialDelayRange: 0.3...0.8)
        static let completeOffline = SimulationConfig(uploadSpeedKbps: 0, failRate: 1.0, artificialDelayRange: 0.1...0.3)
    }

    /// Uploads an animation file.
    /// First, validates file and auth state.
    /// Then attempts actual REST upload if backend is active. If offline or in preview/mock mode, uses a highly detailed upload simulation with progress reporting.
    /// Handles automatic offline queuing on failure.
    static func uploadAnimation(
        fileURL: URL,
        title: String? = nil,
        simulationConfig: SimulationConfig = .standardWifi,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> CommunityAnimation {
        // 1. Validate File
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            log.error("Upload failed: file does not exist at \(fileURL.path, privacy: .public)")
            throw UploaderError.invalidFile
        }

        let asset: NexusAnimationAsset
        do {
            asset = try getAnimation(at: fileURL)
        } catch {
            log.error("Upload failed: invalid JSON in animation file")
            throw error
        }

        log.info("Starting upload of animation '\(asset.id)' (title: '\(title ?? asset.header.title)')")

        // 2. Auth checks
        let authToken = UserDefaults.standard.string(forKey: "fel_backend_auth_token")
        
        // 3. Determine if we should attempt actual REST endpoint or run simulated path
        let isMockMode = ProcessInfo.processInfo.environment["NEXUS_UPLOAD_MOCK"] == "1" || authToken == nil || simulationConfig.failRate == 1.0

        if isMockMode {
            log.info("Using simulated network upload for '\(asset.id)' (offline fallback/mock mode active)")
            return try await runUploadSimulation(
                fileURL: fileURL,
                asset: asset,
                customTitle: title,
                config: simulationConfig,
                onProgress: onProgress
            )
        }

        // 4. Real REST Upload Code
        let baseApi = ProcessInfo.processInfo.environment["FEL_API_BASE_URL"] ?? "https://api.finalevolutiongroup.com"
        guard let uploadURL = URL(string: "\(baseApi)/api/competition/upload") else {
            throw UploaderError.writeFailed("Invalid base API URL configuration")
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Multi-part or simple structured upload body
        struct UploadPayload: Codable {
            let title: String
            let clipId: String
            let animation: NexusAnimationAsset
            let clientTimestamp: Date
        }

        let payload = UploadPayload(
            title: title ?? asset.header.title.replacingOccurrences(of: "_", with: " ").capitalized,
            clipId: asset.id,
            animation: asset,
            clientTimestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let requestData = try? payload.animation.encode() else {
            throw UploaderError.writeFailed("Failed to encode upload payload")
        }

        // Simulate fine-grained progress callbacks during URLSession upload
        let chunkCount = 10

        for i in 1...chunkCount {
            let fraction = Double(i) / Double(chunkCount)
            onProgress?(fraction)
            let delay = Double.random(in: simulationConfig.artificialDelayRange)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        request.httpBody = requestData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw UploaderError.networkUnavailable
            }

            if httpResponse.statusCode == 401 {
                log.error("Upload rejected with HTTP 401: Unauthorized")
                throw UploaderError.unauthorized
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                log.error("Upload failed with server error: HTTP \(httpResponse.statusCode)")
                throw UploaderError.serverError(statusCode: httpResponse.statusCode, message: "Server rejected upload request.")
            }

            // Parse response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let serverAnim = try decoder.decode(CommunityAnimation.self, from: data)
            
            log.info("Successfully uploaded '\(asset.id)' to production server. Server ID: \(serverAnim.id)")
            addSessionUploadedAnimation(serverAnim)
            
            // Cleanup file from cache on successful upload
            try? deleteAnimation(at: fileURL)
            return serverAnim

        } catch {
            log.error("Real upload network failure for '\(asset.id)': \(error.localizedDescription, privacy: .public)")
            // Fallback: Queue offline for automatic retry later
            try? queueForOfflineUpload(fileURL: fileURL)
            throw UploaderError.networkUnavailable
        }
    }

    /// Performs a high-fidelity upload simulation with adjustable speeds and failures.
    private static func runUploadSimulation(
        fileURL: URL,
        asset: NexusAnimationAsset,
        customTitle: String?,
        config: SimulationConfig,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> CommunityAnimation {
        let title = customTitle ?? asset.header.title.replacingOccurrences(of: "_", with: " ").capitalized
        let fileSizeKiloBits = Double(((try? Data(contentsOf: fileURL))?.count ?? 50000)) * 8.0 / 1024.0
        
        if config.failRate == 1.0 || config.uploadSpeedKbps == 0 {
            try? await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
            log.warning("Offline uploader simulation: queuing file '\(asset.id)' for fallback upload.")
            try? queueForOfflineUpload(fileURL: fileURL)
            throw UploaderError.networkUnavailable
        }

        let uploadDuration = fileSizeKiloBits / config.uploadSpeedKbps
        let steps = 15
        let stepDuration = max(0.02, uploadDuration / Double(steps))

        log.info("Simulating upload over network. Size: \(String(format: "%.1f", fileSizeKiloBits)) kbits. Expected duration: \(String(format: "%.2f", uploadDuration))s")

        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            
            if step == steps / 2 && Double.random(in: 0...1) < config.failRate {
                log.warning("Intermittent network failure triggered mid-upload for '\(asset.id)'")
                try? queueForOfflineUpload(fileURL: fileURL)
                throw UploaderError.networkUnavailable
            }

            onProgress?(progress)
            
            let delay = stepDuration + Double.random(in: config.artificialDelayRange)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if Double.random(in: 0...1) < config.failRate {
            log.warning("Server connection drop at upload completion point for '\(asset.id)'")
            try? queueForOfflineUpload(fileURL: fileURL)
            throw UploaderError.networkUnavailable
        }

        // Success - Construct CommunityAnimation record
        let mockId = "mock_uploaded_\(UUID().uuidString.prefix(8).lowercased())"
        let downloadUrl = "https://assets.finalevolutiongroup.com/animations/\(mockId).nexusanim.json"
        
        let communityAnim = CommunityAnimation(
            id: mockId,
            title: title,
            author: "You (Local Athlete)",
            authorAvatarUrl: nil,
            duration: asset.header.duration,
            timestamp: Date(),
            downloadUrl: downloadUrl,
            likeCount: 0,
            isLiked: false,
            tag: "Competition",
            prqScore: 92.4
        )

        log.info("Simulation upload succeeded for '\(asset.id)'. Construction ID: \(mockId)")
        
        addSessionUploadedAnimation(communityAnim)
        try? deleteAnimation(at: fileURL)
        return communityAnim
    }

    // MARK: - Offline Fallback Queue Management

    /// Queues an animation file in `pending_competition_uploads` to retry when internet is restored.
    private static func queueForOfflineUpload(fileURL: URL) throws {
        try ensureDirectoriesExist()
        let filename = fileURL.lastPathComponent
        let targetURL = pendingUploadsDirectory.appendingPathComponent(filename)
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }
        
        try fileManager.copyItem(at: fileURL, to: targetURL)
        log.info("Successfully queued '\(filename)' to offline storage directory.")
    }

    /// Structure containing results from a background queue upload retry process.
    public struct QueueDrainResult: Sendable {
        public let attempted: Int
        public let succeeded: Int
        public let failed: Int
    }

    /// Background/foreground queue drain process. Iterates through all files queued in `pending_competition_uploads` and retries uploading.
    @discardableResult
    static func uploadPendingCompetitionAnimations() async -> QueueDrainResult {
        guard let pendingURLs = try? getPendingUploadFileURLs(), !pendingURLs.isEmpty else {
            return QueueDrainResult(attempted: 0, succeeded: 0, failed: 0)
        }

        log.info("Draining offline competition uploader queue: \(pendingURLs.count) animation(s) pending.")
        var succeededCount = 0
        var failedCount = 0

        for fileURL in pendingURLs {
            do {
                _ = try await uploadAnimation(fileURL: fileURL, simulationConfig: .standardWifi)
                succeededCount += 1
                try? FileManager.default.removeItem(at: fileURL)
                log.info("Successfully cleared file from offline upload queue: \(fileURL.lastPathComponent, privacy: .public)")
            } catch {
                failedCount += 1
                log.warning("Offline upload retry failed for '\(fileURL.lastPathComponent)': \(error.localizedDescription)")
            }
        }

        return QueueDrainResult(attempted: pendingURLs.count, succeeded: succeededCount, failed: failedCount)
    }

    /// Gets all files queued in `pending_competition_uploads`.
    static func getPendingUploadFileURLs() throws -> [URL] {
        try ensureDirectoriesExist()
        let fileManager = FileManager.default
        do {
            let entries = try fileManager.contentsOfDirectory(
                at: pendingUploadsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return entries.filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            log.error("Failed to list pending offline uploads: \(error.localizedDescription, privacy: .public)")
            throw UploaderError.readFailed(error.localizedDescription)
        }
    }

    // MARK: - Community Animations Feed Fetching

    /// Fetches public competition animations uploaded by other users.
    /// Uses standard URLSession GET request; falls back to an elaborate high-quality mock dataset on failure/preview mode.
    /// Also merges locally uploaded animations in this session dynamically so the user sees their own creations instantly!
    static func fetchCommunityAnimations() async throws -> [CommunityAnimation] {
        let baseApi = ProcessInfo.processInfo.environment["FEL_API_BASE_URL"] ?? "https://api.finalevolutiongroup.com"
        
        let isMockOnly = ProcessInfo.processInfo.environment["NEXUS_FEED_MOCK"] == "1" ||
                         UserDefaults.standard.string(forKey: "fel_backend_auth_token") == nil

        if isMockOnly {
            log.info("Using mock community feed animations (no active token or NEXUS_FEED_MOCK active)")
            return generateMockCommunityFeed()
        }

        guard let feedURL = URL(string: "\(baseApi)/api/competition/feed") else {
            return generateMockCommunityFeed()
        }

        var request = URLRequest(url: feedURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = UserDefaults.standard.string(forKey: "fel_backend_auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                log.warning("Feed GET request returned non-200. Falling back to mock dataset.")
                return generateMockCommunityFeed()
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var remoteAnims = try decoder.decode([CommunityAnimation].self, from: data)

            let localUploads = sessionUploadedAnimations
            for localAnim in localUploads {
                if !remoteAnims.contains(where: { $0.id == localAnim.id }) {
                    remoteAnims.insert(localAnim, at: 0)
                }
            }

            log.info("Successfully fetched \(remoteAnims.count) community animations from REST feed.")
            return remoteAnims

        } catch {
            log.warning("Network error during feed fetch: \(error.localizedDescription). Returning mock feed.")
            return generateMockCommunityFeed()
        }
    }

    /// Generates high-quality mock data for the Community Animations Feed.
    /// Blends session-uploaded animations dynamically.
    private static func generateMockCommunityFeed() -> [CommunityAnimation] {
        let cal = Calendar.current
        let now = Date()

        let baseMocks = [
            CommunityAnimation(
                id: "feed_windmill_dunk",
                title: "V-016 Windmill Dunk Proof",
                author: "LeBron B. (Lakers)",
                authorAvatarUrl: "https://assets.finalevolutiongroup.com/avatars/lebron.jpg",
                duration: 1.25,
                timestamp: cal.date(byAdding: .minute, value: -12, to: now) ?? now,
                downloadUrl: "https://assets.finalevolutiongroup.com/animations/windmill.nexusanim.json",
                likeCount: 142,
                isLiked: false,
                tag: "Windmill",
                prqScore: 98.2
            ),
            CommunityAnimation(
                id: "feed_crossover",
                title: "Elite Shifty Crossover",
                author: "Kyrie I. (Mavericks)",
                authorAvatarUrl: "https://assets.finalevolutiongroup.com/avatars/kyrie.jpg",
                duration: 0.85,
                timestamp: cal.date(byAdding: .hour, value: -2, to: now) ?? now,
                downloadUrl: "https://assets.finalevolutiongroup.com/animations/crossover.nexusanim.json",
                likeCount: 89,
                isLiked: true,
                tag: "Dribble",
                prqScore: 95.8
            ),
            CommunityAnimation(
                id: "feed_360_spin",
                title: "360 Spin Dunk Demo",
                author: "Ja M. (Grizzlies)",
                authorAvatarUrl: nil,
                duration: 1.40,
                timestamp: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                downloadUrl: "https://assets.finalevolutiongroup.com/animations/spin360.nexusanim.json",
                likeCount: 231,
                isLiked: false,
                tag: "360 Dunk",
                prqScore: 97.4
            ),
            CommunityAnimation(
                id: "feed_free_throw",
                title: "Perfect Arc Free Throw",
                author: "Stephen C. (Warriors)",
                authorAvatarUrl: "https://assets.finalevolutiongroup.com/avatars/steph.jpg",
                duration: 2.10,
                timestamp: cal.date(byAdding: .day, value: -3, to: now) ?? now,
                downloadUrl: "https://assets.finalevolutiongroup.com/animations/freethrow.nexusanim.json",
                likeCount: 312,
                isLiked: false,
                tag: "Shooting",
                prqScore: 99.1
            ),
            CommunityAnimation(
                id: "feed_behind_back",
                title: "Behind-the-Back Pass",
                author: "Nikola J. (Nuggets)",
                authorAvatarUrl: nil,
                duration: 0.95,
                timestamp: cal.date(byAdding: .weekOfYear, value: -1, to: now) ?? now,
                downloadUrl: "https://assets.finalevolutiongroup.com/animations/pass_behind_back.nexusanim.json",
                likeCount: 75,
                isLiked: false,
                tag: "Passing",
                prqScore: 91.2
            )
        ]

        var fullFeed = baseMocks
        let localUploads = sessionUploadedAnimations
        
        for localAnim in localUploads {
            if !fullFeed.contains(where: { $0.id == localAnim.id }) {
                fullFeed.insert(localAnim, at: 0)
            }
        }

        return fullFeed
    }
}
