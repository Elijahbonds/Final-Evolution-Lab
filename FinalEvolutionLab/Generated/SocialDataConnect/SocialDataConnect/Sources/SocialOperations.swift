import Foundation

import FirebaseCore
import FirebaseDataConnect




















// MARK: Common Enums

public enum OrderDirection: String, Codable, Sendable {
  case ASC = "ASC"
  case DESC = "DESC"
  }

public enum SearchQueryFormat: String, Codable, Sendable {
  case QUERY = "QUERY"
  case PLAIN = "PLAIN"
  case PHRASE = "PHRASE"
  case ADVANCED = "ADVANCED"
  }


// MARK: Connector Enums

// End enum definitions









public class RegisterSignedInUserMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "RegisterSignedInUser"

  public typealias Ref = MutationRef<RegisterSignedInUserMutation.Data,RegisterSignedInUserMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
username: String

  
        
        public var
email: String

  
        @OptionalVariable
        public var
profilePictureUrl: String?

  
        @OptionalVariable
        public var
avatarUrl: String?


    
    
    
    public init (
        
username: String
,
        
email: String

        
        
        ,
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        self.username = username
        self.email = email
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.username == rhs.username && 
              lhs.email == rhs.email && 
              lhs.profilePictureUrl == rhs.profilePictureUrl && 
              lhs.avatarUrl == rhs.avatarUrl
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(username)
  
  hasher.combine(email)
  
  hasher.combine(profilePictureUrl)
  
  hasher.combine(avatarUrl)
  
}

    enum CodingKeys: String, CodingKey {
      
      case username
      
      case email
      
      case profilePictureUrl
      
      case avatarUrl
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(username, forKey: .username, container: &container)
      
      
      
      try codecHelper.encode(email, forKey: .email, container: &container)
      
      
      if $profilePictureUrl.isSet { 
      try codecHelper.encode(profilePictureUrl, forKey: .profilePictureUrl, container: &container)
      }
      
      if $avatarUrl.isSet { 
      try codecHelper.encode(avatarUrl, forKey: .avatarUrl, container: &container)
      }
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
user_insert: UserKey

  }

  public func ref(
        
username: String
,
email: String

        
        ,
        _ optionalVars: ((inout RegisterSignedInUserMutation.Variables)->())? = nil
        ) -> MutationRef<RegisterSignedInUserMutation.Data,RegisterSignedInUserMutation.Variables>  {
        var variables = RegisterSignedInUserMutation.Variables(username:username,email:email)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "RegisterSignedInUser", variables: variables, resultsDataType:RegisterSignedInUserMutation.Data.self)
        return ref as MutationRef<RegisterSignedInUserMutation.Data,RegisterSignedInUserMutation.Variables>
   }

  @MainActor
   public func execute( 
        
username: String
,
email: String

        
        ,
        _ optionalVars: (@MainActor (inout RegisterSignedInUserMutation.Variables)->())? = nil
        ) async throws -> OperationResult<RegisterSignedInUserMutation.Data> {
        var variables = RegisterSignedInUserMutation.Variables(username:username,email:email)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "RegisterSignedInUser", variables: variables, resultsDataType:RegisterSignedInUserMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class UpdateMyTrainingProfileMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "UpdateMyTrainingProfile"

  public typealias Ref = MutationRef<UpdateMyTrainingProfileMutation.Data,UpdateMyTrainingProfileMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
topPRQScore: Double

  
        @OptionalVariable
        public var
avatarUrl: String?


    
    
    
    public init (
        
topPRQScore: Double

        
        
        ,
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        self.topPRQScore = topPRQScore
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.topPRQScore == rhs.topPRQScore && 
              lhs.avatarUrl == rhs.avatarUrl
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(topPRQScore)
  
  hasher.combine(avatarUrl)
  
}

    enum CodingKeys: String, CodingKey {
      
      case topPRQScore
      
      case avatarUrl
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(topPRQScore, forKey: .topPRQScore, container: &container)
      
      
      if $avatarUrl.isSet { 
      try codecHelper.encode(avatarUrl, forKey: .avatarUrl, container: &container)
      }
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
user_update: UserKey?

  }

  public func ref(
        
topPRQScore: Double

        
        ,
        _ optionalVars: ((inout UpdateMyTrainingProfileMutation.Variables)->())? = nil
        ) -> MutationRef<UpdateMyTrainingProfileMutation.Data,UpdateMyTrainingProfileMutation.Variables>  {
        var variables = UpdateMyTrainingProfileMutation.Variables(topPRQScore:topPRQScore)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "UpdateMyTrainingProfile", variables: variables, resultsDataType:UpdateMyTrainingProfileMutation.Data.self)
        return ref as MutationRef<UpdateMyTrainingProfileMutation.Data,UpdateMyTrainingProfileMutation.Variables>
   }

  @MainActor
   public func execute( 
        
topPRQScore: Double

        
        ,
        _ optionalVars: (@MainActor (inout UpdateMyTrainingProfileMutation.Variables)->())? = nil
        ) async throws -> OperationResult<UpdateMyTrainingProfileMutation.Data> {
        var variables = UpdateMyTrainingProfileMutation.Variables(topPRQScore:topPRQScore)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "UpdateMyTrainingProfile", variables: variables, resultsDataType:UpdateMyTrainingProfileMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class CreatePostMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "CreatePost"

  public typealias Ref = MutationRef<CreatePostMutation.Data,CreatePostMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
content: String

  
        @OptionalVariable
        public var
gameModeId: String?

  
        @OptionalVariable
        public var
trainingScore: Double?

  
        @OptionalVariable
        public var
clipUrl: String?

  
        @OptionalVariable
        public var
feedSource: String?


    
    
    
    public init (
        
content: String

        
        
        ,
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        self.content = content
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.content == rhs.content && 
              lhs.gameModeId == rhs.gameModeId && 
              lhs.trainingScore == rhs.trainingScore && 
              lhs.clipUrl == rhs.clipUrl && 
              lhs.feedSource == rhs.feedSource
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(content)
  
  hasher.combine(gameModeId)
  
  hasher.combine(trainingScore)
  
  hasher.combine(clipUrl)
  
  hasher.combine(feedSource)
  
}

    enum CodingKeys: String, CodingKey {
      
      case content
      
      case gameModeId
      
      case trainingScore
      
      case clipUrl
      
      case feedSource
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(content, forKey: .content, container: &container)
      
      
      if $gameModeId.isSet { 
      try codecHelper.encode(gameModeId, forKey: .gameModeId, container: &container)
      }
      
      if $trainingScore.isSet { 
      try codecHelper.encode(trainingScore, forKey: .trainingScore, container: &container)
      }
      
      if $clipUrl.isSet { 
      try codecHelper.encode(clipUrl, forKey: .clipUrl, container: &container)
      }
      
      if $feedSource.isSet { 
      try codecHelper.encode(feedSource, forKey: .feedSource, container: &container)
      }
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
post_insert: PostKey

  }

  public func ref(
        
content: String

        
        ,
        _ optionalVars: ((inout CreatePostMutation.Variables)->())? = nil
        ) -> MutationRef<CreatePostMutation.Data,CreatePostMutation.Variables>  {
        var variables = CreatePostMutation.Variables(content:content)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "CreatePost", variables: variables, resultsDataType:CreatePostMutation.Data.self)
        return ref as MutationRef<CreatePostMutation.Data,CreatePostMutation.Variables>
   }

  @MainActor
   public func execute( 
        
content: String

        
        ,
        _ optionalVars: (@MainActor (inout CreatePostMutation.Variables)->())? = nil
        ) async throws -> OperationResult<CreatePostMutation.Data> {
        var variables = CreatePostMutation.Variables(content:content)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "CreatePost", variables: variables, resultsDataType:CreatePostMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class CreateCommentMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "CreateComment"

  public typealias Ref = MutationRef<CreateCommentMutation.Data,CreateCommentMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
postId: UUID

  
        
        public var
content: String


    
    
    
    public init (
        
postId: UUID
,
        
content: String

        
        ) {
        self.postId = postId
        self.content = content
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postId == rhs.postId && 
              lhs.content == rhs.content
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postId)
  
  hasher.combine(content)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postId
      
      case content
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
      
      try codecHelper.encode(content, forKey: .content, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
comment_insert: CommentKey

  }

  public func ref(
        
postId: UUID
,
content: String

        ) -> MutationRef<CreateCommentMutation.Data,CreateCommentMutation.Variables>  {
        var variables = CreateCommentMutation.Variables(postId:postId,content:content)
        

        let ref = dataConnect.mutation(name: "CreateComment", variables: variables, resultsDataType:CreateCommentMutation.Data.self)
        return ref as MutationRef<CreateCommentMutation.Data,CreateCommentMutation.Variables>
   }

  @MainActor
   public func execute( 
        
postId: UUID
,
content: String

        ) async throws -> OperationResult<CreateCommentMutation.Data> {
        var variables = CreateCommentMutation.Variables(postId:postId,content:content)
        

        let ref = dataConnect.mutation(name: "CreateComment", variables: variables, resultsDataType:CreateCommentMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class LikePostMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "LikePost"

  public typealias Ref = MutationRef<LikePostMutation.Data,LikePostMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
postId: UUID


    
    
    
    public init (
        
postId: UUID

        
        ) {
        self.postId = postId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postId == rhs.postId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
postLike_insert: PostLikeKey

  }

  public func ref(
        
postId: UUID

        ) -> MutationRef<LikePostMutation.Data,LikePostMutation.Variables>  {
        var variables = LikePostMutation.Variables(postId:postId)
        

        let ref = dataConnect.mutation(name: "LikePost", variables: variables, resultsDataType:LikePostMutation.Data.self)
        return ref as MutationRef<LikePostMutation.Data,LikePostMutation.Variables>
   }

  @MainActor
   public func execute( 
        
postId: UUID

        ) async throws -> OperationResult<LikePostMutation.Data> {
        var variables = LikePostMutation.Variables(postId:postId)
        

        let ref = dataConnect.mutation(name: "LikePost", variables: variables, resultsDataType:LikePostMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class UnlikePostMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "UnlikePost"

  public typealias Ref = MutationRef<UnlikePostMutation.Data,UnlikePostMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
postId: UUID


    
    
    
    public init (
        
postId: UUID

        
        ) {
        self.postId = postId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postId == rhs.postId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
postLike_delete: PostLikeKey?

  }

  public func ref(
        
postId: UUID

        ) -> MutationRef<UnlikePostMutation.Data,UnlikePostMutation.Variables>  {
        var variables = UnlikePostMutation.Variables(postId:postId)
        

        let ref = dataConnect.mutation(name: "UnlikePost", variables: variables, resultsDataType:UnlikePostMutation.Data.self)
        return ref as MutationRef<UnlikePostMutation.Data,UnlikePostMutation.Variables>
   }

  @MainActor
   public func execute( 
        
postId: UUID

        ) async throws -> OperationResult<UnlikePostMutation.Data> {
        var variables = UnlikePostMutation.Variables(postId:postId)
        

        let ref = dataConnect.mutation(name: "UnlikePost", variables: variables, resultsDataType:UnlikePostMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class DeletePostMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "DeletePost"

  public typealias Ref = MutationRef<DeletePostMutation.Data,DeletePostMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
postId: UUID


    
    
    
    public init (
        
postId: UUID

        
        ) {
        self.postId = postId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postId == rhs.postId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
post_delete: PostKey?

  }

  public func ref(
        
postId: UUID

        ) -> MutationRef<DeletePostMutation.Data,DeletePostMutation.Variables>  {
        var variables = DeletePostMutation.Variables(postId:postId)
        

        let ref = dataConnect.mutation(name: "DeletePost", variables: variables, resultsDataType:DeletePostMutation.Data.self)
        return ref as MutationRef<DeletePostMutation.Data,DeletePostMutation.Variables>
   }

  @MainActor
   public func execute( 
        
postId: UUID

        ) async throws -> OperationResult<DeletePostMutation.Data> {
        var variables = DeletePostMutation.Variables(postId:postId)
        

        let ref = dataConnect.mutation(name: "DeletePost", variables: variables, resultsDataType:DeletePostMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class DeleteCommentMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "DeleteComment"

  public typealias Ref = MutationRef<DeleteCommentMutation.Data,DeleteCommentMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
commentId: UUID


    
    
    
    public init (
        
commentId: UUID

        
        ) {
        self.commentId = commentId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.commentId == rhs.commentId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(commentId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case commentId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(commentId, forKey: .commentId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
comment_delete: CommentKey?

  }

  public func ref(
        
commentId: UUID

        ) -> MutationRef<DeleteCommentMutation.Data,DeleteCommentMutation.Variables>  {
        var variables = DeleteCommentMutation.Variables(commentId:commentId)
        

        let ref = dataConnect.mutation(name: "DeleteComment", variables: variables, resultsDataType:DeleteCommentMutation.Data.self)
        return ref as MutationRef<DeleteCommentMutation.Data,DeleteCommentMutation.Variables>
   }

  @MainActor
   public func execute( 
        
commentId: UUID

        ) async throws -> OperationResult<DeleteCommentMutation.Data> {
        var variables = DeleteCommentMutation.Variables(commentId:commentId)
        

        let ref = dataConnect.mutation(name: "DeleteComment", variables: variables, resultsDataType:DeleteCommentMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class SpendEvolutionShardsMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "SpendEvolutionShards"

  public typealias Ref = MutationRef<SpendEvolutionShardsMutation.Data,SpendEvolutionShardsMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
deltaShards: Int

  
        
        public var
reason: String

  
        @OptionalVariable
        public var
referenceId: String?


    
    
    
    public init (
        
deltaShards: Int
,
        
reason: String

        
        
        ,
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        self.deltaShards = deltaShards
        self.reason = reason
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.deltaShards == rhs.deltaShards && 
              lhs.reason == rhs.reason && 
              lhs.referenceId == rhs.referenceId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(deltaShards)
  
  hasher.combine(reason)
  
  hasher.combine(referenceId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case deltaShards
      
      case reason
      
      case referenceId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(deltaShards, forKey: .deltaShards, container: &container)
      
      
      
      try codecHelper.encode(reason, forKey: .reason, container: &container)
      
      
      if $referenceId.isSet { 
      try codecHelper.encode(referenceId, forKey: .referenceId, container: &container)
      }
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
shardLedger_insert: ShardLedgerKey




public var 
user_update: UserKey?

  }

  public func ref(
        
deltaShards: Int
,
reason: String

        
        ,
        _ optionalVars: ((inout SpendEvolutionShardsMutation.Variables)->())? = nil
        ) -> MutationRef<SpendEvolutionShardsMutation.Data,SpendEvolutionShardsMutation.Variables>  {
        var variables = SpendEvolutionShardsMutation.Variables(deltaShards:deltaShards,reason:reason)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "SpendEvolutionShards", variables: variables, resultsDataType:SpendEvolutionShardsMutation.Data.self)
        return ref as MutationRef<SpendEvolutionShardsMutation.Data,SpendEvolutionShardsMutation.Variables>
   }

  @MainActor
   public func execute( 
        
deltaShards: Int
,
reason: String

        
        ,
        _ optionalVars: (@MainActor (inout SpendEvolutionShardsMutation.Variables)->())? = nil
        ) async throws -> OperationResult<SpendEvolutionShardsMutation.Data> {
        var variables = SpendEvolutionShardsMutation.Variables(deltaShards:deltaShards,reason:reason)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "SpendEvolutionShards", variables: variables, resultsDataType:SpendEvolutionShardsMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class ClaimCreatorCardOwnershipMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "ClaimCreatorCardOwnership"

  public typealias Ref = MutationRef<ClaimCreatorCardOwnershipMutation.Data,ClaimCreatorCardOwnershipMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
catalogCardId: String


    
    
    
    public init (
        
catalogCardId: String

        
        ) {
        self.catalogCardId = catalogCardId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.catalogCardId == rhs.catalogCardId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(catalogCardId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case catalogCardId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(catalogCardId, forKey: .catalogCardId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
userOwnedCreatorCard_insert: UserOwnedCreatorCardKey

  }

  public func ref(
        
catalogCardId: String

        ) -> MutationRef<ClaimCreatorCardOwnershipMutation.Data,ClaimCreatorCardOwnershipMutation.Variables>  {
        var variables = ClaimCreatorCardOwnershipMutation.Variables(catalogCardId:catalogCardId)
        

        let ref = dataConnect.mutation(name: "ClaimCreatorCardOwnership", variables: variables, resultsDataType:ClaimCreatorCardOwnershipMutation.Data.self)
        return ref as MutationRef<ClaimCreatorCardOwnershipMutation.Data,ClaimCreatorCardOwnershipMutation.Variables>
   }

  @MainActor
   public func execute( 
        
catalogCardId: String

        ) async throws -> OperationResult<ClaimCreatorCardOwnershipMutation.Data> {
        var variables = ClaimCreatorCardOwnershipMutation.Variables(catalogCardId:catalogCardId)
        

        let ref = dataConnect.mutation(name: "ClaimCreatorCardOwnership", variables: variables, resultsDataType:ClaimCreatorCardOwnershipMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class CreateCritiqueRequestWithEscrowMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "CreateCritiqueRequestWithEscrow"

  public typealias Ref = MutationRef<CreateCritiqueRequestWithEscrowMutation.Data,CreateCritiqueRequestWithEscrowMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
requestKey: String

  
        
        public var
exerciseName: String

  
        @OptionalVariable
        public var
notes: String?


    
    
    
    public init (
        
requestKey: String
,
        
exerciseName: String

        
        
        ,
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        self.requestKey = requestKey
        self.exerciseName = exerciseName
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.requestKey == rhs.requestKey && 
              lhs.exerciseName == rhs.exerciseName && 
              lhs.notes == rhs.notes
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(requestKey)
  
  hasher.combine(exerciseName)
  
  hasher.combine(notes)
  
}

    enum CodingKeys: String, CodingKey {
      
      case requestKey
      
      case exerciseName
      
      case notes
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(requestKey, forKey: .requestKey, container: &container)
      
      
      
      try codecHelper.encode(exerciseName, forKey: .exerciseName, container: &container)
      
      
      if $notes.isSet { 
      try codecHelper.encode(notes, forKey: .notes, container: &container)
      }
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
shardLedger_insert: ShardLedgerKey




public var 
user_update: UserKey?




public var 
coachCritiqueRequest_insert: CoachCritiqueRequestKey

  }

  public func ref(
        
requestKey: String
,
exerciseName: String

        
        ,
        _ optionalVars: ((inout CreateCritiqueRequestWithEscrowMutation.Variables)->())? = nil
        ) -> MutationRef<CreateCritiqueRequestWithEscrowMutation.Data,CreateCritiqueRequestWithEscrowMutation.Variables>  {
        var variables = CreateCritiqueRequestWithEscrowMutation.Variables(requestKey:requestKey,exerciseName:exerciseName)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "CreateCritiqueRequestWithEscrow", variables: variables, resultsDataType:CreateCritiqueRequestWithEscrowMutation.Data.self)
        return ref as MutationRef<CreateCritiqueRequestWithEscrowMutation.Data,CreateCritiqueRequestWithEscrowMutation.Variables>
   }

  @MainActor
   public func execute( 
        
requestKey: String
,
exerciseName: String

        
        ,
        _ optionalVars: (@MainActor (inout CreateCritiqueRequestWithEscrowMutation.Variables)->())? = nil
        ) async throws -> OperationResult<CreateCritiqueRequestWithEscrowMutation.Data> {
        var variables = CreateCritiqueRequestWithEscrowMutation.Variables(requestKey:requestKey,exerciseName:exerciseName)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "CreateCritiqueRequestWithEscrow", variables: variables, resultsDataType:CreateCritiqueRequestWithEscrowMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class CreateCardMarketListingMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "CreateCardMarketListing"

  public typealias Ref = MutationRef<CreateCardMarketListingMutation.Data,CreateCardMarketListingMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
catalogCardId: String

  
        
        public var
priceShards: Int


    
    
    
    public init (
        
catalogCardId: String
,
        
priceShards: Int

        
        ) {
        self.catalogCardId = catalogCardId
        self.priceShards = priceShards
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.catalogCardId == rhs.catalogCardId && 
              lhs.priceShards == rhs.priceShards
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(catalogCardId)
  
  hasher.combine(priceShards)
  
}

    enum CodingKeys: String, CodingKey {
      
      case catalogCardId
      
      case priceShards
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(catalogCardId, forKey: .catalogCardId, container: &container)
      
      
      
      try codecHelper.encode(priceShards, forKey: .priceShards, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
cardMarketListing_insert: CardMarketListingKey

  }

  public func ref(
        
catalogCardId: String
,
priceShards: Int

        ) -> MutationRef<CreateCardMarketListingMutation.Data,CreateCardMarketListingMutation.Variables>  {
        var variables = CreateCardMarketListingMutation.Variables(catalogCardId:catalogCardId,priceShards:priceShards)
        

        let ref = dataConnect.mutation(name: "CreateCardMarketListing", variables: variables, resultsDataType:CreateCardMarketListingMutation.Data.self)
        return ref as MutationRef<CreateCardMarketListingMutation.Data,CreateCardMarketListingMutation.Variables>
   }

  @MainActor
   public func execute( 
        
catalogCardId: String
,
priceShards: Int

        ) async throws -> OperationResult<CreateCardMarketListingMutation.Data> {
        var variables = CreateCardMarketListingMutation.Variables(catalogCardId:catalogCardId,priceShards:priceShards)
        

        let ref = dataConnect.mutation(name: "CreateCardMarketListing", variables: variables, resultsDataType:CreateCardMarketListingMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class DeactivateCardMarketListingMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "DeactivateCardMarketListing"

  public typealias Ref = MutationRef<DeactivateCardMarketListingMutation.Data,DeactivateCardMarketListingMutation.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
listingId: UUID


    
    
    
    public init (
        
listingId: UUID

        
        ) {
        self.listingId = listingId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.listingId == rhs.listingId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(listingId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case listingId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(listingId, forKey: .listingId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
cardMarketListing_update: CardMarketListingKey?

  }

  public func ref(
        
listingId: UUID

        ) -> MutationRef<DeactivateCardMarketListingMutation.Data,DeactivateCardMarketListingMutation.Variables>  {
        var variables = DeactivateCardMarketListingMutation.Variables(listingId:listingId)
        

        let ref = dataConnect.mutation(name: "DeactivateCardMarketListing", variables: variables, resultsDataType:DeactivateCardMarketListingMutation.Data.self)
        return ref as MutationRef<DeactivateCardMarketListingMutation.Data,DeactivateCardMarketListingMutation.Variables>
   }

  @MainActor
   public func execute( 
        
listingId: UUID

        ) async throws -> OperationResult<DeactivateCardMarketListingMutation.Data> {
        var variables = DeactivateCardMarketListingMutation.Variables(listingId:listingId)
        

        let ref = dataConnect.mutation(name: "DeactivateCardMarketListing", variables: variables, resultsDataType:DeactivateCardMarketListingMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class ListRecentPostsQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "ListRecentPosts"

  public typealias Ref = QueryRefObservation<ListRecentPostsQuery.Data,ListRecentPostsQuery.Variables>

  public struct Variables: OperationVariable {

    
    
  }

  public struct Data: Decodable, Sendable {




public struct Post: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
content: String



public var 
createdAt: Timestamp



public var 
gameModeId: String?



public var 
trainingScore: Double?



public var 
clipUrl: String?



public var 
feedSource: String?





public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String



public var 
profilePictureUrl: String?



public var 
avatarUrl: String?



public var 
topPRQScore: Double?


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
    case profilePictureUrl
    
    case avatarUrl
    
    case topPRQScore
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
    
    self.profilePictureUrl = try codecHelper.decode(String?.self, forKey: .profilePictureUrl, container: &container)
    
    
    
    self.avatarUrl = try codecHelper.decode(String?.self, forKey: .avatarUrl, container: &container)
    
    
    
    self.topPRQScore = try codecHelper.decode(Double?.self, forKey: .topPRQScore, container: &container)
    
    
  }
}
public var 
author: User


  
  public var postKey: PostKey {
    return PostKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: Post, rhs: Post) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case content
    
    case createdAt
    
    case gameModeId
    
    case trainingScore
    
    case clipUrl
    
    case feedSource
    
    case author
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.content = try codecHelper.decode(String.self, forKey: .content, container: &container)
    
    
    
    self.createdAt = try codecHelper.decode(Timestamp.self, forKey: .createdAt, container: &container)
    
    
    
    self.gameModeId = try codecHelper.decode(String?.self, forKey: .gameModeId, container: &container)
    
    
    
    self.trainingScore = try codecHelper.decode(Double?.self, forKey: .trainingScore, container: &container)
    
    
    
    self.clipUrl = try codecHelper.decode(String?.self, forKey: .clipUrl, container: &container)
    
    
    
    self.feedSource = try codecHelper.decode(String?.self, forKey: .feedSource, container: &container)
    
    
    
    self.author = try codecHelper.decode(User.self, forKey: .author, container: &container)
    
    
  }
}
public var 
posts: [Post]

  }

  public func ref(
        
        ) -> QueryRefObservation<ListRecentPostsQuery.Data,ListRecentPostsQuery.Variables>  {
        var variables = ListRecentPostsQuery.Variables()
        

        let ref = dataConnect.query(name: "ListRecentPosts", variables: variables, resultsDataType:ListRecentPostsQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<ListRecentPostsQuery.Data,ListRecentPostsQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
        ) async throws -> OperationResult<ListRecentPostsQuery.Data> {
        var variables = ListRecentPostsQuery.Variables()
        

        let ref = dataConnect.query(name: "ListRecentPosts", variables: variables, resultsDataType:ListRecentPostsQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<ListRecentPostsQuery.Data,ListRecentPostsQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}






public class GetPostWithThreadQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "GetPostWithThread"

  public typealias Ref = QueryRefObservation<GetPostWithThreadQuery.Data,GetPostWithThreadQuery.Variables>

  public struct Variables: OperationVariable {
  
        
  
        
        public var
postKey: PostKey


    
    
    
    public init (
        
postKey: PostKey

        
        ) {
        self.postKey = postKey
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postKey == rhs.postKey
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postKey)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postKey
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postKey, forKey: .postKey, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {




public struct Post: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
content: String



public var 
createdAt: Timestamp



public var 
gameModeId: String?



public var 
trainingScore: Double?



public var 
clipUrl: String?



public var 
feedSource: String?





public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String



public var 
profilePictureUrl: String?



public var 
avatarUrl: String?



public var 
topPRQScore: Double?


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
    case profilePictureUrl
    
    case avatarUrl
    
    case topPRQScore
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
    
    self.profilePictureUrl = try codecHelper.decode(String?.self, forKey: .profilePictureUrl, container: &container)
    
    
    
    self.avatarUrl = try codecHelper.decode(String?.self, forKey: .avatarUrl, container: &container)
    
    
    
    self.topPRQScore = try codecHelper.decode(Double?.self, forKey: .topPRQScore, container: &container)
    
    
  }
}
public var 
author: User





public struct Comment: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
content: String



public var 
createdAt: Timestamp





public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String



public var 
profilePictureUrl: String?



public var 
avatarUrl: String?


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
    case profilePictureUrl
    
    case avatarUrl
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
    
    self.profilePictureUrl = try codecHelper.decode(String?.self, forKey: .profilePictureUrl, container: &container)
    
    
    
    self.avatarUrl = try codecHelper.decode(String?.self, forKey: .avatarUrl, container: &container)
    
    
  }
}
public var 
author: User


  
  public var commentKey: CommentKey {
    return CommentKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: Comment, rhs: Comment) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case content
    
    case createdAt
    
    case author
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.content = try codecHelper.decode(String.self, forKey: .content, container: &container)
    
    
    
    self.createdAt = try codecHelper.decode(Timestamp.self, forKey: .createdAt, container: &container)
    
    
    
    self.author = try codecHelper.decode(User.self, forKey: .author, container: &container)
    
    
  }
}
public var 
comments_on_post: [Comment]





public struct PostLike: Decodable, Sendable  {
  


public var 
createdAt: Timestamp





public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
  }
}
public var 
user: User


  

  
  enum CodingKeys: String, CodingKey {
    
    case createdAt
    
    case user
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.createdAt = try codecHelper.decode(Timestamp.self, forKey: .createdAt, container: &container)
    
    
    
    self.user = try codecHelper.decode(User.self, forKey: .user, container: &container)
    
    
  }
}
public var 
postLikes_on_post: [PostLike]


  
  public var postKey: PostKey {
    return PostKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: Post, rhs: Post) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case content
    
    case createdAt
    
    case gameModeId
    
    case trainingScore
    
    case clipUrl
    
    case feedSource
    
    case author
    
    case comments_on_post
    
    case postLikes_on_post
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.content = try codecHelper.decode(String.self, forKey: .content, container: &container)
    
    
    
    self.createdAt = try codecHelper.decode(Timestamp.self, forKey: .createdAt, container: &container)
    
    
    
    self.gameModeId = try codecHelper.decode(String?.self, forKey: .gameModeId, container: &container)
    
    
    
    self.trainingScore = try codecHelper.decode(Double?.self, forKey: .trainingScore, container: &container)
    
    
    
    self.clipUrl = try codecHelper.decode(String?.self, forKey: .clipUrl, container: &container)
    
    
    
    self.feedSource = try codecHelper.decode(String?.self, forKey: .feedSource, container: &container)
    
    
    
    self.author = try codecHelper.decode(User.self, forKey: .author, container: &container)
    
    
    self.comments_on_post = try codecHelper.decode([Comment].self, forKey: .comments_on_post, container: &container)
    
    
    self.postLikes_on_post = try codecHelper.decode([PostLike].self, forKey: .postLikes_on_post, container: &container)
    
    
  }
}
public var 
post: Post?

  }

  public func ref(
        
postKey: PostKey

        ) -> QueryRefObservation<GetPostWithThreadQuery.Data,GetPostWithThreadQuery.Variables>  {
        var variables = GetPostWithThreadQuery.Variables(postKey:postKey)
        

        let ref = dataConnect.query(name: "GetPostWithThread", variables: variables, resultsDataType:GetPostWithThreadQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<GetPostWithThreadQuery.Data,GetPostWithThreadQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
postKey: PostKey

        ) async throws -> OperationResult<GetPostWithThreadQuery.Data> {
        var variables = GetPostWithThreadQuery.Variables(postKey:postKey)
        

        let ref = dataConnect.query(name: "GetPostWithThread", variables: variables, resultsDataType:GetPostWithThreadQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<GetPostWithThreadQuery.Data,GetPostWithThreadQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}






public class GetUserByFirebaseUidQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "GetUserByFirebaseUid"

  public typealias Ref = QueryRefObservation<GetUserByFirebaseUidQuery.Data,GetUserByFirebaseUidQuery.Variables>

  public struct Variables: OperationVariable {

    
    
  }

  public struct Data: Decodable, Sendable {




public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String



public var 
profilePictureUrl: String?



public var 
avatarUrl: String?



public var 
topPRQScore: Double?



public var 
evolutionShards: Int



public var 
firebaseUid: String?


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
    case profilePictureUrl
    
    case avatarUrl
    
    case topPRQScore
    
    case evolutionShards
    
    case firebaseUid
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
    
    self.profilePictureUrl = try codecHelper.decode(String?.self, forKey: .profilePictureUrl, container: &container)
    
    
    
    self.avatarUrl = try codecHelper.decode(String?.self, forKey: .avatarUrl, container: &container)
    
    
    
    self.topPRQScore = try codecHelper.decode(Double?.self, forKey: .topPRQScore, container: &container)
    
    
    
    self.evolutionShards = try codecHelper.decode(Int.self, forKey: .evolutionShards, container: &container)
    
    
    
    self.firebaseUid = try codecHelper.decode(String?.self, forKey: .firebaseUid, container: &container)
    
    
  }
}
public var 
users: [User]

  }

  public func ref(
        
        ) -> QueryRefObservation<GetUserByFirebaseUidQuery.Data,GetUserByFirebaseUidQuery.Variables>  {
        var variables = GetUserByFirebaseUidQuery.Variables()
        

        let ref = dataConnect.query(name: "GetUserByFirebaseUid", variables: variables, resultsDataType:GetUserByFirebaseUidQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<GetUserByFirebaseUidQuery.Data,GetUserByFirebaseUidQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
        ) async throws -> OperationResult<GetUserByFirebaseUidQuery.Data> {
        var variables = GetUserByFirebaseUidQuery.Variables()
        

        let ref = dataConnect.query(name: "GetUserByFirebaseUid", variables: variables, resultsDataType:GetUserByFirebaseUidQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<GetUserByFirebaseUidQuery.Data,GetUserByFirebaseUidQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}






public class GetMyPrivateProfileQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "GetMyPrivateProfile"

  public typealias Ref = QueryRefObservation<GetMyPrivateProfileQuery.Data,GetMyPrivateProfileQuery.Variables>

  public struct Variables: OperationVariable {

    
    
  }

  public struct Data: Decodable, Sendable {




public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String



public var 
email: String



public var 
profilePictureUrl: String?



public var 
avatarUrl: String?



public var 
topPRQScore: Double?



public var 
evolutionShards: Int



public var 
firebaseUid: String?


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
    case email
    
    case profilePictureUrl
    
    case avatarUrl
    
    case topPRQScore
    
    case evolutionShards
    
    case firebaseUid
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
    
    self.email = try codecHelper.decode(String.self, forKey: .email, container: &container)
    
    
    
    self.profilePictureUrl = try codecHelper.decode(String?.self, forKey: .profilePictureUrl, container: &container)
    
    
    
    self.avatarUrl = try codecHelper.decode(String?.self, forKey: .avatarUrl, container: &container)
    
    
    
    self.topPRQScore = try codecHelper.decode(Double?.self, forKey: .topPRQScore, container: &container)
    
    
    
    self.evolutionShards = try codecHelper.decode(Int.self, forKey: .evolutionShards, container: &container)
    
    
    
    self.firebaseUid = try codecHelper.decode(String?.self, forKey: .firebaseUid, container: &container)
    
    
  }
}
public var 
users: [User]

  }

  public func ref(
        
        ) -> QueryRefObservation<GetMyPrivateProfileQuery.Data,GetMyPrivateProfileQuery.Variables>  {
        var variables = GetMyPrivateProfileQuery.Variables()
        

        let ref = dataConnect.query(name: "GetMyPrivateProfile", variables: variables, resultsDataType:GetMyPrivateProfileQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<GetMyPrivateProfileQuery.Data,GetMyPrivateProfileQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
        ) async throws -> OperationResult<GetMyPrivateProfileQuery.Data> {
        var variables = GetMyPrivateProfileQuery.Variables()
        

        let ref = dataConnect.query(name: "GetMyPrivateProfile", variables: variables, resultsDataType:GetMyPrivateProfileQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<GetMyPrivateProfileQuery.Data,GetMyPrivateProfileQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}






public class GetUserProfileQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "GetUserProfile"

  public typealias Ref = QueryRefObservation<GetUserProfileQuery.Data,GetUserProfileQuery.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
userId: UUID


    
    
    
    public init (
        
userId: UUID

        
        ) {
        self.userId = userId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.userId == rhs.userId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(userId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case userId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(userId, forKey: .userId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {




public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String



public var 
profilePictureUrl: String?



public var 
avatarUrl: String?



public var 
topPRQScore: Double?



public var 
evolutionShards: Int


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
    case profilePictureUrl
    
    case avatarUrl
    
    case topPRQScore
    
    case evolutionShards
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
    
    self.profilePictureUrl = try codecHelper.decode(String?.self, forKey: .profilePictureUrl, container: &container)
    
    
    
    self.avatarUrl = try codecHelper.decode(String?.self, forKey: .avatarUrl, container: &container)
    
    
    
    self.topPRQScore = try codecHelper.decode(Double?.self, forKey: .topPRQScore, container: &container)
    
    
    
    self.evolutionShards = try codecHelper.decode(Int.self, forKey: .evolutionShards, container: &container)
    
    
  }
}
public var 
user: User?





public struct Post: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
content: String



public var 
createdAt: Timestamp



public var 
gameModeId: String?



public var 
trainingScore: Double?



public var 
feedSource: String?


  
  public var postKey: PostKey {
    return PostKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: Post, rhs: Post) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case content
    
    case createdAt
    
    case gameModeId
    
    case trainingScore
    
    case feedSource
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.content = try codecHelper.decode(String.self, forKey: .content, container: &container)
    
    
    
    self.createdAt = try codecHelper.decode(Timestamp.self, forKey: .createdAt, container: &container)
    
    
    
    self.gameModeId = try codecHelper.decode(String?.self, forKey: .gameModeId, container: &container)
    
    
    
    self.trainingScore = try codecHelper.decode(Double?.self, forKey: .trainingScore, container: &container)
    
    
    
    self.feedSource = try codecHelper.decode(String?.self, forKey: .feedSource, container: &container)
    
    
  }
}
public var 
posts: [Post]

  }

  public func ref(
        
userId: UUID

        ) -> QueryRefObservation<GetUserProfileQuery.Data,GetUserProfileQuery.Variables>  {
        var variables = GetUserProfileQuery.Variables(userId:userId)
        

        let ref = dataConnect.query(name: "GetUserProfile", variables: variables, resultsDataType:GetUserProfileQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<GetUserProfileQuery.Data,GetUserProfileQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
userId: UUID

        ) async throws -> OperationResult<GetUserProfileQuery.Data> {
        var variables = GetUserProfileQuery.Variables(userId:userId)
        

        let ref = dataConnect.query(name: "GetUserProfile", variables: variables, resultsDataType:GetUserProfileQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<GetUserProfileQuery.Data,GetUserProfileQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}






public class ListCommentsForPostQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "ListCommentsForPost"

  public typealias Ref = QueryRefObservation<ListCommentsForPostQuery.Data,ListCommentsForPostQuery.Variables>

  public struct Variables: OperationVariable {
  
        
        public var
postId: UUID


    
    
    
    public init (
        
postId: UUID

        
        ) {
        self.postId = postId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postId == rhs.postId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {




public struct Comment: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
content: String



public var 
createdAt: Timestamp





public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String



public var 
profilePictureUrl: String?



public var 
avatarUrl: String?


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
    case profilePictureUrl
    
    case avatarUrl
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
    
    self.profilePictureUrl = try codecHelper.decode(String?.self, forKey: .profilePictureUrl, container: &container)
    
    
    
    self.avatarUrl = try codecHelper.decode(String?.self, forKey: .avatarUrl, container: &container)
    
    
  }
}
public var 
author: User


  
  public var commentKey: CommentKey {
    return CommentKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: Comment, rhs: Comment) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case content
    
    case createdAt
    
    case author
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.content = try codecHelper.decode(String.self, forKey: .content, container: &container)
    
    
    
    self.createdAt = try codecHelper.decode(Timestamp.self, forKey: .createdAt, container: &container)
    
    
    
    self.author = try codecHelper.decode(User.self, forKey: .author, container: &container)
    
    
  }
}
public var 
comments: [Comment]

  }

  public func ref(
        
postId: UUID

        ) -> QueryRefObservation<ListCommentsForPostQuery.Data,ListCommentsForPostQuery.Variables>  {
        var variables = ListCommentsForPostQuery.Variables(postId:postId)
        

        let ref = dataConnect.query(name: "ListCommentsForPost", variables: variables, resultsDataType:ListCommentsForPostQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<ListCommentsForPostQuery.Data,ListCommentsForPostQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
postId: UUID

        ) async throws -> OperationResult<ListCommentsForPostQuery.Data> {
        var variables = ListCommentsForPostQuery.Variables(postId:postId)
        

        let ref = dataConnect.query(name: "ListCommentsForPost", variables: variables, resultsDataType:ListCommentsForPostQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<ListCommentsForPostQuery.Data,ListCommentsForPostQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}






public class ListShardLedgerForUserQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "ListShardLedgerForUser"

  public typealias Ref = QueryRefObservation<ListShardLedgerForUserQuery.Data,ListShardLedgerForUserQuery.Variables>

  public struct Variables: OperationVariable {
  
        @OptionalVariable
        public var
limit: Int?


    
    
    
    public init (
        
        
        
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.limit == rhs.limit
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(limit)
  
}

    enum CodingKeys: String, CodingKey {
      
      case limit
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      if $limit.isSet { 
      try codecHelper.encode(limit, forKey: .limit, container: &container)
      }
      
    }

  }

  public struct Data: Decodable, Sendable {




public struct ShardLedger: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
deltaShards: Int



public var 
reason: String



public var 
referenceId: String?



public var 
createdAt: Timestamp


  
  public var shardLedgerKey: ShardLedgerKey {
    return ShardLedgerKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: ShardLedger, rhs: ShardLedger) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case deltaShards
    
    case reason
    
    case referenceId
    
    case createdAt
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.deltaShards = try codecHelper.decode(Int.self, forKey: .deltaShards, container: &container)
    
    
    
    self.reason = try codecHelper.decode(String.self, forKey: .reason, container: &container)
    
    
    
    self.referenceId = try codecHelper.decode(String?.self, forKey: .referenceId, container: &container)
    
    
    
    self.createdAt = try codecHelper.decode(Timestamp.self, forKey: .createdAt, container: &container)
    
    
  }
}
public var 
shardLedgers: [ShardLedger]

  }

  public func ref(
        
        
        
        _ optionalVars: ((inout ListShardLedgerForUserQuery.Variables)->())? = nil
        ) -> QueryRefObservation<ListShardLedgerForUserQuery.Data,ListShardLedgerForUserQuery.Variables>  {
        var variables = ListShardLedgerForUserQuery.Variables()
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.query(name: "ListShardLedgerForUser", variables: variables, resultsDataType:ListShardLedgerForUserQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<ListShardLedgerForUserQuery.Data,ListShardLedgerForUserQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
        
        
        _ optionalVars: (@MainActor (inout ListShardLedgerForUserQuery.Variables)->())? = nil
        ) async throws -> OperationResult<ListShardLedgerForUserQuery.Data> {
        var variables = ListShardLedgerForUserQuery.Variables()
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.query(name: "ListShardLedgerForUser", variables: variables, resultsDataType:ListShardLedgerForUserQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<ListShardLedgerForUserQuery.Data,ListShardLedgerForUserQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}






public class ListCreatorCardsQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "ListCreatorCards"

  public typealias Ref = QueryRefObservation<ListCreatorCardsQuery.Data,ListCreatorCardsQuery.Variables>

  public struct Variables: OperationVariable {
  
        @OptionalVariable
        public var
limit: Int?


    
    
    
    public init (
        
        
        
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.limit == rhs.limit
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(limit)
  
}

    enum CodingKeys: String, CodingKey {
      
      case limit
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      if $limit.isSet { 
      try codecHelper.encode(limit, forKey: .limit, container: &container)
      }
      
    }

  }

  public struct Data: Decodable, Sendable {




public struct CreatorCard: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
catalogCardId: String



public var 
displayName: String



public var 
rarityTier: String?



public var 
createdAt: Timestamp


  
  public var creatorCardKey: CreatorCardKey {
    return CreatorCardKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: CreatorCard, rhs: CreatorCard) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case catalogCardId
    
    case displayName
    
    case rarityTier
    
    case createdAt
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.catalogCardId = try codecHelper.decode(String.self, forKey: .catalogCardId, container: &container)
    
    
    
    self.displayName = try codecHelper.decode(String.self, forKey: .displayName, container: &container)
    
    
    
    self.rarityTier = try codecHelper.decode(String?.self, forKey: .rarityTier, container: &container)
    
    
    
    self.createdAt = try codecHelper.decode(Timestamp.self, forKey: .createdAt, container: &container)
    
    
  }
}
public var 
creatorCards: [CreatorCard]

  }

  public func ref(
        
        
        
        _ optionalVars: ((inout ListCreatorCardsQuery.Variables)->())? = nil
        ) -> QueryRefObservation<ListCreatorCardsQuery.Data,ListCreatorCardsQuery.Variables>  {
        var variables = ListCreatorCardsQuery.Variables()
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.query(name: "ListCreatorCards", variables: variables, resultsDataType:ListCreatorCardsQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<ListCreatorCardsQuery.Data,ListCreatorCardsQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
        
        
        _ optionalVars: (@MainActor (inout ListCreatorCardsQuery.Variables)->())? = nil
        ) async throws -> OperationResult<ListCreatorCardsQuery.Data> {
        var variables = ListCreatorCardsQuery.Variables()
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.query(name: "ListCreatorCards", variables: variables, resultsDataType:ListCreatorCardsQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<ListCreatorCardsQuery.Data,ListCreatorCardsQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}






public class ListActiveCardMarketListingsQuery{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "ListActiveCardMarketListings"

  public typealias Ref = QueryRefObservation<ListActiveCardMarketListingsQuery.Data,ListActiveCardMarketListingsQuery.Variables>

  public struct Variables: OperationVariable {
  
        @OptionalVariable
        public var
limit: Int?


    
    
    
    public init (
        
        
        
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.limit == rhs.limit
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(limit)
  
}

    enum CodingKeys: String, CodingKey {
      
      case limit
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      if $limit.isSet { 
      try codecHelper.encode(limit, forKey: .limit, container: &container)
      }
      
    }

  }

  public struct Data: Decodable, Sendable {




public struct CardMarketListing: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
catalogCardId: String



public var 
priceShards: Int



public var 
listedAt: Timestamp



public var 
active: Bool





public struct User: Decodable, Sendable ,Hashable, Equatable, Identifiable {
  


public var 
id: UUID



public var 
username: String



public var 
avatarUrl: String?


  
  public var userKey: UserKey {
    return UserKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: User, rhs: User) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case username
    
    case avatarUrl
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.username = try codecHelper.decode(String.self, forKey: .username, container: &container)
    
    
    
    self.avatarUrl = try codecHelper.decode(String?.self, forKey: .avatarUrl, container: &container)
    
    
  }
}
public var 
seller: User


  
  public var cardMarketListingKey: CardMarketListingKey {
    return CardMarketListingKey(
      
      id: id
    )
  }

  
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(id)
  
}
public static func == (lhs: CardMarketListing, rhs: CardMarketListing) -> Bool {
    
    return lhs.id == rhs.id 
        
  }

  

  
  enum CodingKeys: String, CodingKey {
    
    case id
    
    case catalogCardId
    
    case priceShards
    
    case listedAt
    
    case active
    
    case seller
    
  }

  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    
    
    self.id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
    
    
    
    self.catalogCardId = try codecHelper.decode(String.self, forKey: .catalogCardId, container: &container)
    
    
    
    self.priceShards = try codecHelper.decode(Int.self, forKey: .priceShards, container: &container)
    
    
    
    self.listedAt = try codecHelper.decode(Timestamp.self, forKey: .listedAt, container: &container)
    
    
    
    self.active = try codecHelper.decode(Bool.self, forKey: .active, container: &container)
    
    
    
    self.seller = try codecHelper.decode(User.self, forKey: .seller, container: &container)
    
    
  }
}
public var 
cardMarketListings: [CardMarketListing]

  }

  public func ref(
        
        
        
        _ optionalVars: ((inout ListActiveCardMarketListingsQuery.Variables)->())? = nil
        ) -> QueryRefObservation<ListActiveCardMarketListingsQuery.Data,ListActiveCardMarketListingsQuery.Variables>  {
        var variables = ListActiveCardMarketListingsQuery.Variables()
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.query(name: "ListActiveCardMarketListings", variables: variables, resultsDataType:ListActiveCardMarketListingsQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<ListActiveCardMarketListingsQuery.Data,ListActiveCardMarketListingsQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
        
        
        _ optionalVars: (@MainActor (inout ListActiveCardMarketListingsQuery.Variables)->())? = nil
        ) async throws -> OperationResult<ListActiveCardMarketListingsQuery.Data> {
        var variables = ListActiveCardMarketListingsQuery.Variables()
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.query(name: "ListActiveCardMarketListings", variables: variables, resultsDataType:ListActiveCardMarketListingsQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<ListActiveCardMarketListingsQuery.Data,ListActiveCardMarketListingsQuery.Variables>
        return try await refCast.execute(fetchPolicy: fetchPolicy)
        
   }
}


