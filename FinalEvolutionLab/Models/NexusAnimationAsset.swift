import Foundation
import SceneKit

// MARK: - SceneKit Codable Extensions

extension SCNVector3: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        // Try decoding as an array of Floats first
        if var container = try? decoder.unkeyedContainer() {
            let x = try container.decode(Float.self)
            let y = try container.decode(Float.self)
            let z = try container.decode(Float.self)
            self.init(x, y, z)
            return
        }
        
        // Fallback to dictionary format
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Float.self, forKey: .x)
        let y = try container.decode(Float.self, forKey: .y)
        let z = try container.decode(Float.self, forKey: .z)
        self.init(x, y, z)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
    }
    
    private enum CodingKeys: String, CodingKey {
        case x, y, z
    }
}

extension SCNVector4: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        // Try decoding as an array of Floats first
        if var container = try? decoder.unkeyedContainer() {
            let x = try container.decode(Float.self)
            let y = try container.decode(Float.self)
            let z = try container.decode(Float.self)
            let w = try container.decode(Float.self)
            self.init(x, y, z, w)
            return
        }
        
        // Fallback to dictionary format
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Float.self, forKey: .x)
        let y = try container.decode(Float.self, forKey: .y)
        let z = try container.decode(Float.self, forKey: .z)
        let w = try container.decode(Float.self, forKey: .w)
        self.init(x, y, z, w)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(z, forKey: .z)
        try container.encode(w, forKey: .w)
    }
    
    private enum CodingKeys: String, CodingKey {
        case x, y, z, w
    }
}

// MARK: - NexusAnimationAsset

nonisolated struct NexusAnimationAsset: Codable, Sendable, Identifiable {
    public typealias Keyframe = NexusAnimationFrame
    
    var id: String { header.id }
    
    var header: Header
    var keyframes: [NexusAnimationFrame]
    
    nonisolated struct Header: Codable, Sendable {
        var id: String
        var title: String
        var competitionName: String
        var category: String
        var creatorId: String
        var captureTimestamp: Date
        var frameRate: Double
        var duration: Double
        var jointCount: Int
        
        var movementType: String { category }
        
        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case competitionName
            case category
            case sport
            case creatorId
            case captureTimestamp
            case frameRate
            case duration
            case jointCount
        }
        
        nonisolated init(
            id: String,
            title: String,
            competitionName: String,
            category: String,
            creatorId: String,
            captureTimestamp: Date,
            frameRate: Double,
            duration: Double,
            jointCount: Int
        ) {
            self.id = id
            self.title = title
            self.competitionName = competitionName
            self.category = category
            self.creatorId = creatorId
            self.captureTimestamp = captureTimestamp
            self.frameRate = frameRate
            self.duration = duration
            self.jointCount = jointCount
        }
        
        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            competitionName = try container.decode(String.self, forKey: .competitionName)
            
            // Backward compatibility: support category falling back to sport or default
            category = try container.decodeIfPresent(String.self, forKey: .category)
                ?? container.decodeIfPresent(String.self, forKey: .sport)
                ?? "General"
                
            creatorId = try container.decode(String.self, forKey: .creatorId)
            
            // Handle date decoding robustly (Double timestamp, ISO8601 string, or Date)
            if let dateDouble = try? container.decode(Double.self, forKey: .captureTimestamp) {
                captureTimestamp = Date(timeIntervalSince1970: dateDouble)
            } else if let dateString = try? container.decode(String.self, forKey: .captureTimestamp) {
                let formatter = ISO8601DateFormatter()
                captureTimestamp = formatter.date(from: dateString) ?? Date()
            } else {
                captureTimestamp = (try? container.decode(Date.self, forKey: .captureTimestamp)) ?? Date()
            }
            
            frameRate = try container.decode(Double.self, forKey: .frameRate)
            duration = try container.decode(Double.self, forKey: .duration)
            jointCount = try container.decode(Int.self, forKey: .jointCount)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encode(competitionName, forKey: .competitionName)
            try container.encode(category, forKey: .category)
            try container.encode(creatorId, forKey: .creatorId)
            try container.encode(captureTimestamp, forKey: .captureTimestamp)
            try container.encode(frameRate, forKey: .frameRate)
            try container.encode(duration, forKey: .duration)
            try container.encode(jointCount, forKey: .jointCount)
        }
    }
    
    nonisolated struct NexusAnimationFrame: Codable, Sendable {
        var timestamp: Double
        var jointRotations: [String: SCNVector4]
        var translationOffsets: [String: SCNVector3]
        
        private enum CodingKeys: String, CodingKey {
            case timestamp
            case jointRotations
            case translationOffsets
        }
        
        nonisolated init(
            timestamp: Double,
            jointRotations: [String: SCNVector4],
            translationOffsets: [String: SCNVector3]
        ) {
            self.timestamp = timestamp
            self.jointRotations = jointRotations
            self.translationOffsets = translationOffsets
        }
        
        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            timestamp = try container.decode(Double.self, forKey: .timestamp)
            jointRotations = (try? container.decode([String: SCNVector4].self, forKey: .jointRotations)) ?? [:]
            translationOffsets = (try? container.decode([String: SCNVector3].self, forKey: .translationOffsets)) ?? [:]
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(jointRotations, forKey: .jointRotations)
            try container.encode(translationOffsets, forKey: .translationOffsets)
        }
    }
}

extension NexusAnimationAsset {
    /// Deserializes a `NexusAnimationAsset` from a JSON Data object.
    static func decode(from data: Data) throws -> NexusAnimationAsset {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let doubleVal = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: doubleVal)
            }
            if let stringVal = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: stringVal) {
                    return date
                }
            }
            return try Date(from: decoder)
        }
        return try decoder.decode(NexusAnimationAsset.self, from: data)
    }
    
    /// Serializes a `NexusAnimationAsset` to JSON Data.
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(self)
    }
}
