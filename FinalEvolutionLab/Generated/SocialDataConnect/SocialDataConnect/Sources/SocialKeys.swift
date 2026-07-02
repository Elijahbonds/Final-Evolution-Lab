import Foundation

import FirebaseCore
import FirebaseDataConnect




public struct CardMarketListingKey {
  
  public private(set) var id: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  id
    
  }
}

extension CardMarketListingKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(id, forKey: .id, container: &container)
      
      
    }
}

extension CardMarketListingKey : Equatable {
  public static func == (lhs: CardMarketListingKey, rhs: CardMarketListingKey) -> Bool {
    
    if lhs.id != rhs.id {
      return false
    }
    
    return true
  }
}

extension CardMarketListingKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.id)
    
  }
}

extension CardMarketListingKey : Sendable {}



public struct CoachCritiqueRequestKey {
  
  public private(set) var id: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  id
    
  }
}

extension CoachCritiqueRequestKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(id, forKey: .id, container: &container)
      
      
    }
}

extension CoachCritiqueRequestKey : Equatable {
  public static func == (lhs: CoachCritiqueRequestKey, rhs: CoachCritiqueRequestKey) -> Bool {
    
    if lhs.id != rhs.id {
      return false
    }
    
    return true
  }
}

extension CoachCritiqueRequestKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.id)
    
  }
}

extension CoachCritiqueRequestKey : Sendable {}



public struct CommentKey {
  
  public private(set) var id: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  id
    
  }
}

extension CommentKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(id, forKey: .id, container: &container)
      
      
    }
}

extension CommentKey : Equatable {
  public static func == (lhs: CommentKey, rhs: CommentKey) -> Bool {
    
    if lhs.id != rhs.id {
      return false
    }
    
    return true
  }
}

extension CommentKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.id)
    
  }
}

extension CommentKey : Sendable {}



public struct CreatorCardKey {
  
  public private(set) var id: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  id
    
  }
}

extension CreatorCardKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(id, forKey: .id, container: &container)
      
      
    }
}

extension CreatorCardKey : Equatable {
  public static func == (lhs: CreatorCardKey, rhs: CreatorCardKey) -> Bool {
    
    if lhs.id != rhs.id {
      return false
    }
    
    return true
  }
}

extension CreatorCardKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.id)
    
  }
}

extension CreatorCardKey : Sendable {}



public struct PostLikeKey {
  
  public private(set) var postId: UUID
  
  public private(set) var userId: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  postId
    
    case  userId
    
  }
}

extension PostLikeKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.postId = try codecHelper.decode(UUID.self, forKey: .postId, container: &container)
    
    self.userId = try codecHelper.decode(UUID.self, forKey: .userId, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
      
      try codecHelper.encode(userId, forKey: .userId, container: &container)
      
      
    }
}

extension PostLikeKey : Equatable {
  public static func == (lhs: PostLikeKey, rhs: PostLikeKey) -> Bool {
    
    if lhs.postId != rhs.postId {
      return false
    }
    
    if lhs.userId != rhs.userId {
      return false
    }
    
    return true
  }
}

extension PostLikeKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.postId)
    
    hasher.combine(self.userId)
    
  }
}

extension PostLikeKey : Sendable {}



public struct PostKey {
  
  public private(set) var id: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  id
    
  }
}

extension PostKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(id, forKey: .id, container: &container)
      
      
    }
}

extension PostKey : Equatable {
  public static func == (lhs: PostKey, rhs: PostKey) -> Bool {
    
    if lhs.id != rhs.id {
      return false
    }
    
    return true
  }
}

extension PostKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.id)
    
  }
}

extension PostKey : Sendable {}



public struct ShardLedgerKey {
  
  public private(set) var id: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  id
    
  }
}

extension ShardLedgerKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(id, forKey: .id, container: &container)
      
      
    }
}

extension ShardLedgerKey : Equatable {
  public static func == (lhs: ShardLedgerKey, rhs: ShardLedgerKey) -> Bool {
    
    if lhs.id != rhs.id {
      return false
    }
    
    return true
  }
}

extension ShardLedgerKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.id)
    
  }
}

extension ShardLedgerKey : Sendable {}



public struct UserOwnedCreatorCardKey {
  
  public private(set) var userId: UUID
  
  public private(set) var creatorCardId: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  userId
    
    case  creatorCardId
    
  }
}

extension UserOwnedCreatorCardKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.userId = try codecHelper.decode(UUID.self, forKey: .userId, container: &container)
    
    self.creatorCardId = try codecHelper.decode(UUID.self, forKey: .creatorCardId, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(userId, forKey: .userId, container: &container)
      
      
      
      try codecHelper.encode(creatorCardId, forKey: .creatorCardId, container: &container)
      
      
    }
}

extension UserOwnedCreatorCardKey : Equatable {
  public static func == (lhs: UserOwnedCreatorCardKey, rhs: UserOwnedCreatorCardKey) -> Bool {
    
    if lhs.userId != rhs.userId {
      return false
    }
    
    if lhs.creatorCardId != rhs.creatorCardId {
      return false
    }
    
    return true
  }
}

extension UserOwnedCreatorCardKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.userId)
    
    hasher.combine(self.creatorCardId)
    
  }
}

extension UserOwnedCreatorCardKey : Sendable {}



public struct UserKey {
  
  public private(set) var id: UUID
  

  enum CodingKeys: String, CodingKey {
    
    case  id
    
  }
}

extension UserKey : Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
  }

  public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(id, forKey: .id, container: &container)
      
      
    }
}

extension UserKey : Equatable {
  public static func == (lhs: UserKey, rhs: UserKey) -> Bool {
    
    if lhs.id != rhs.id {
      return false
    }
    
    return true
  }
}

extension UserKey : Hashable {
  public func hash(into hasher: inout Hasher) {
    
    hasher.combine(self.id)
    
  }
}

extension UserKey : Sendable {}


