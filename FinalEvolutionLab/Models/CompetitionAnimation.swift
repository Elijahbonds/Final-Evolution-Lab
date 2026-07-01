import Foundation
import SwiftUI

/// Represents a captured keyframe animation asset uploaded from a real athletic competition.
struct CompetitionAnimation: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var title: String
    var competitionName: String
    var category: String // e.g., "Dunk", "Jump", "Kick"
    var keyframePayload: String // JSON payload of .nexusanim.json
    var uploadedAt: Date

    init(id: String, title: String, competitionName: String, category: String, keyframePayload: String, uploadedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.competitionName = competitionName
        self.category = category
        self.keyframePayload = keyframePayload
        self.uploadedAt = uploadedAt
    }
}

/// Represents a custom Creator Card minted from an uploaded competition animation.
struct MintedCreatorCard: Codable, Sendable, Identifiable {
    var id: String
    var animationId: String
    var title: String
    var description: String
    var costShards: Int
    var masterclassUrl: String
    var royaltyEarnings: Int
    var totalSales: Int
    var mintedAt: Date
    var statsBoost: PerformanceMetrics

    init(
        id: String,
        animationId: String,
        title: String,
        description: String,
        costShards: Int,
        masterclassUrl: String,
        royaltyEarnings: Int = 0,
        totalSales: Int = 0,
        mintedAt: Date = Date(),
        statsBoost: PerformanceMetrics
    ) {
        self.id = id
        self.animationId = animationId
        self.title = title
        self.description = description
        self.costShards = costShards
        self.masterclassUrl = masterclassUrl
        self.royaltyEarnings = royaltyEarnings
        self.totalSales = totalSales
        self.mintedAt = mintedAt
        self.statsBoost = statsBoost
    }
}

/// Parsed structure of the .nexusanim.json payload.
struct AnimationPayload: Codable, Sendable {
    var format: String
    var version: String
    var metadata: AnimationMetadata
    var keyframes: [AnimationKeyframe]

    init(format: String = "nexusanim", version: String = "1.0", metadata: AnimationMetadata, keyframes: [AnimationKeyframe]) {
        self.format = format
        self.version = version
        self.metadata = metadata
        self.keyframes = keyframes
    }
}

struct AnimationMetadata: Codable, Sendable {
    var title: String
    var category: String
    var duration: Double

    init(title: String, category: String, duration: Double) {
        self.title = title
        self.category = category
        self.duration = duration
    }
}

struct AnimationKeyframe: Codable, Sendable {
    var time: Double
    var pose: String?
    var jointAngles: [String: Double] // e.g., ["rUpperArm_z": -3.0, "lLeg_x": -0.6, ...]

    init(time: Double, pose: String? = nil, jointAngles: [String: Double]) {
        self.time = time
        self.pose = pose
        self.jointAngles = jointAngles
    }
}
