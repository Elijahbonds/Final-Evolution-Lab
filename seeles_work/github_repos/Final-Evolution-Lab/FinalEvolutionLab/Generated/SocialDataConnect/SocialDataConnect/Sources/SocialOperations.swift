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






public class LinkUserToFirebaseAuthMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "LinkUserToFirebaseAuth"

  public typealias Ref = MutationRef<LinkUserToFirebaseAuthMutation.Data,LinkUserToFirebaseAuthMutation.Variables>

  public struct Variables: OperationVariable {
  
        
  
        
        public var
userKey: UserKey


    
    
    
    public init (
        
userKey: UserKey

        
        ) {
        self.userKey = userKey
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.userKey == rhs.userKey
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(userKey)
  
}

    enum CodingKeys: String, CodingKey {
      
      case userKey
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(userKey, forKey: .userKey, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
user_update: UserKey?

  }

  public func ref(
        
userKey: UserKey

        ) -> MutationRef<LinkUserToFirebaseAuthMutation.Data,LinkUserToFirebaseAuthMutation.Variables>  {
        var variables = LinkUserToFirebaseAuthMutation.Variables(userKey:userKey)
        

        let ref = dataConnect.mutation(name: "LinkUserToFirebaseAuth", variables: variables, resultsDataType:LinkUserToFirebaseAuthMutation.Data.self)
        return ref as MutationRef<LinkUserToFirebaseAuthMutation.Data,LinkUserToFirebaseAuthMutation.Variables>
   }

  @MainActor
   public func execute( 
        
userKey: UserKey

        ) async throws -> OperationResult<LinkUserToFirebaseAuthMutation.Data> {
        var variables = LinkUserToFirebaseAuthMutation.Variables(userKey:userKey)
        

        let ref = dataConnect.mutation(name: "LinkUserToFirebaseAuth", variables: variables, resultsDataType:LinkUserToFirebaseAuthMutation.Data.self)
        
        return try await ref.execute()
        
   }
}






public class UpdateUserTrainingProfileMutation{

  let dataConnect: DataConnect

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public static let OperationName = "UpdateUserTrainingProfile"

  public typealias Ref = MutationRef<UpdateUserTrainingProfileMutation.Data,UpdateUserTrainingProfileMutation.Variables>

  public struct Variables: OperationVariable {
  
        
  
        
        public var
userKey: UserKey

  
        
        public var
topPRQScore: Double

  
        @OptionalVariable
        public var
avatarUrl: String?


    
    
    
    public init (
        
userKey: UserKey
,
        
topPRQScore: Double

        
        
        ,
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        self.userKey = userKey
        self.topPRQScore = topPRQScore
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.userKey == rhs.userKey && 
              lhs.topPRQScore == rhs.topPRQScore && 
              lhs.avatarUrl == rhs.avatarUrl
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(userKey)
  
  hasher.combine(topPRQScore)
  
  hasher.combine(avatarUrl)
  
}

    enum CodingKeys: String, CodingKey {
      
      case userKey
      
      case topPRQScore
      
      case avatarUrl
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(userKey, forKey: .userKey, container: &container)
      
      
      
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
        
userKey: UserKey
,
topPRQScore: Double

        
        ,
        _ optionalVars: ((inout UpdateUserTrainingProfileMutation.Variables)->())? = nil
        ) -> MutationRef<UpdateUserTrainingProfileMutation.Data,UpdateUserTrainingProfileMutation.Variables>  {
        var variables = UpdateUserTrainingProfileMutation.Variables(userKey:userKey,topPRQScore:topPRQScore)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "UpdateUserTrainingProfile", variables: variables, resultsDataType:UpdateUserTrainingProfileMutation.Data.self)
        return ref as MutationRef<UpdateUserTrainingProfileMutation.Data,UpdateUserTrainingProfileMutation.Variables>
   }

  @MainActor
   public func execute( 
        
userKey: UserKey
,
topPRQScore: Double

        
        ,
        _ optionalVars: (@MainActor (inout UpdateUserTrainingProfileMutation.Variables)->())? = nil
        ) async throws -> OperationResult<UpdateUserTrainingProfileMutation.Data> {
        var variables = UpdateUserTrainingProfileMutation.Variables(userKey:userKey,topPRQScore:topPRQScore)
        
        if let optionalVars {
            optionalVars(&variables)
        }
        

        let ref = dataConnect.mutation(name: "UpdateUserTrainingProfile", variables: variables, resultsDataType:UpdateUserTrainingProfileMutation.Data.self)
        
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

  
        
        public var
authorId: UUID

  
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
        
authorId: UUID

        
        
        ,
        _ optionalVars: ((inout Variables)->())? = nil
        ) {
        self.content = content
        self.authorId = authorId
        

        
        if let optionalVars {
            optionalVars(&self)
        }
        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.content == rhs.content && 
              lhs.authorId == rhs.authorId && 
              lhs.gameModeId == rhs.gameModeId && 
              lhs.trainingScore == rhs.trainingScore && 
              lhs.clipUrl == rhs.clipUrl && 
              lhs.feedSource == rhs.feedSource
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(content)
  
  hasher.combine(authorId)
  
  hasher.combine(gameModeId)
  
  hasher.combine(trainingScore)
  
  hasher.combine(clipUrl)
  
  hasher.combine(feedSource)
  
}

    enum CodingKeys: String, CodingKey {
      
      case content
      
      case authorId
      
      case gameModeId
      
      case trainingScore
      
      case clipUrl
      
      case feedSource
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(content, forKey: .content, container: &container)
      
      
      
      try codecHelper.encode(authorId, forKey: .authorId, container: &container)
      
      
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
authorId: UUID

        
        ,
        _ optionalVars: ((inout CreatePostMutation.Variables)->())? = nil
        ) -> MutationRef<CreatePostMutation.Data,CreatePostMutation.Variables>  {
        var variables = CreatePostMutation.Variables(content:content,authorId:authorId)
        
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
authorId: UUID

        
        ,
        _ optionalVars: (@MainActor (inout CreatePostMutation.Variables)->())? = nil
        ) async throws -> OperationResult<CreatePostMutation.Data> {
        var variables = CreatePostMutation.Variables(content:content,authorId:authorId)
        
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
authorId: UUID

  
        
        public var
content: String


    
    
    
    public init (
        
postId: UUID
,
        
authorId: UUID
,
        
content: String

        
        ) {
        self.postId = postId
        self.authorId = authorId
        self.content = content
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postId == rhs.postId && 
              lhs.authorId == rhs.authorId && 
              lhs.content == rhs.content
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postId)
  
  hasher.combine(authorId)
  
  hasher.combine(content)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postId
      
      case authorId
      
      case content
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
      
      try codecHelper.encode(authorId, forKey: .authorId, container: &container)
      
      
      
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
authorId: UUID
,
content: String

        ) -> MutationRef<CreateCommentMutation.Data,CreateCommentMutation.Variables>  {
        var variables = CreateCommentMutation.Variables(postId:postId,authorId:authorId,content:content)
        

        let ref = dataConnect.mutation(name: "CreateComment", variables: variables, resultsDataType:CreateCommentMutation.Data.self)
        return ref as MutationRef<CreateCommentMutation.Data,CreateCommentMutation.Variables>
   }

  @MainActor
   public func execute( 
        
postId: UUID
,
authorId: UUID
,
content: String

        ) async throws -> OperationResult<CreateCommentMutation.Data> {
        var variables = CreateCommentMutation.Variables(postId:postId,authorId:authorId,content:content)
        

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

  
        
        public var
userId: UUID


    
    
    
    public init (
        
postId: UUID
,
        
userId: UUID

        
        ) {
        self.postId = postId
        self.userId = userId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postId == rhs.postId && 
              lhs.userId == rhs.userId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postId)
  
  hasher.combine(userId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postId
      
      case userId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
      
      try codecHelper.encode(userId, forKey: .userId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
postLike_insert: PostLikeKey

  }

  public func ref(
        
postId: UUID
,
userId: UUID

        ) -> MutationRef<LikePostMutation.Data,LikePostMutation.Variables>  {
        var variables = LikePostMutation.Variables(postId:postId,userId:userId)
        

        let ref = dataConnect.mutation(name: "LikePost", variables: variables, resultsDataType:LikePostMutation.Data.self)
        return ref as MutationRef<LikePostMutation.Data,LikePostMutation.Variables>
   }

  @MainActor
   public func execute( 
        
postId: UUID
,
userId: UUID

        ) async throws -> OperationResult<LikePostMutation.Data> {
        var variables = LikePostMutation.Variables(postId:postId,userId:userId)
        

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

  
        
        public var
userId: UUID


    
    
    
    public init (
        
postId: UUID
,
        
userId: UUID

        
        ) {
        self.postId = postId
        self.userId = userId
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.postId == rhs.postId && 
              lhs.userId == rhs.userId
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(postId)
  
  hasher.combine(userId)
  
}

    enum CodingKeys: String, CodingKey {
      
      case postId
      
      case userId
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(postId, forKey: .postId, container: &container)
      
      
      
      try codecHelper.encode(userId, forKey: .userId, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
postLike_delete: PostLikeKey?

  }

  public func ref(
        
postId: UUID
,
userId: UUID

        ) -> MutationRef<UnlikePostMutation.Data,UnlikePostMutation.Variables>  {
        var variables = UnlikePostMutation.Variables(postId:postId,userId:userId)
        

        let ref = dataConnect.mutation(name: "UnlikePost", variables: variables, resultsDataType:UnlikePostMutation.Data.self)
        return ref as MutationRef<UnlikePostMutation.Data,UnlikePostMutation.Variables>
   }

  @MainActor
   public func execute( 
        
postId: UUID
,
userId: UUID

        ) async throws -> OperationResult<UnlikePostMutation.Data> {
        var variables = UnlikePostMutation.Variables(postId:postId,userId:userId)
        

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



public var 
post_delete: PostKey?

  }

  public func ref(
        
postKey: PostKey

        ) -> MutationRef<DeletePostMutation.Data,DeletePostMutation.Variables>  {
        var variables = DeletePostMutation.Variables(postKey:postKey)
        

        let ref = dataConnect.mutation(name: "DeletePost", variables: variables, resultsDataType:DeletePostMutation.Data.self)
        return ref as MutationRef<DeletePostMutation.Data,DeletePostMutation.Variables>
   }

  @MainActor
   public func execute( 
        
postKey: PostKey

        ) async throws -> OperationResult<DeletePostMutation.Data> {
        var variables = DeletePostMutation.Variables(postKey:postKey)
        

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
commentKey: CommentKey


    
    
    
    public init (
        
commentKey: CommentKey

        
        ) {
        self.commentKey = commentKey
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.commentKey == rhs.commentKey
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(commentKey)
  
}

    enum CodingKeys: String, CodingKey {
      
      case commentKey
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(commentKey, forKey: .commentKey, container: &container)
      
      
    }

  }

  public struct Data: Decodable, Sendable {



public var 
comment_delete: CommentKey?

  }

  public func ref(
        
commentKey: CommentKey

        ) -> MutationRef<DeleteCommentMutation.Data,DeleteCommentMutation.Variables>  {
        var variables = DeleteCommentMutation.Variables(commentKey:commentKey)
        

        let ref = dataConnect.mutation(name: "DeleteComment", variables: variables, resultsDataType:DeleteCommentMutation.Data.self)
        return ref as MutationRef<DeleteCommentMutation.Data,DeleteCommentMutation.Variables>
   }

  @MainActor
   public func execute( 
        
commentKey: CommentKey

        ) async throws -> OperationResult<DeleteCommentMutation.Data> {
        var variables = DeleteCommentMutation.Variables(commentKey:commentKey)
        

        let ref = dataConnect.mutation(name: "DeleteComment", variables: variables, resultsDataType:DeleteCommentMutation.Data.self)
        
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
email: String



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
    
    case email
    
    case profilePictureUrl
    
    case avatarUrl
    
    case topPRQScore
    
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
  
        
        public var
firebaseUid: String


    
    
    
    public init (
        
firebaseUid: String

        
        ) {
        self.firebaseUid = firebaseUid
        

        
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      
        return lhs.firebaseUid == rhs.firebaseUid
              
    }

    
public func hash(into hasher: inout Hasher) {
  
  hasher.combine(firebaseUid)
  
}

    enum CodingKeys: String, CodingKey {
      
      case firebaseUid
      
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()
      
      
      try codecHelper.encode(firebaseUid, forKey: .firebaseUid, container: &container)
      
      
    }

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
    
    
    
    self.firebaseUid = try codecHelper.decode(String?.self, forKey: .firebaseUid, container: &container)
    
    
  }
}
public var 
users: [User]

  }

  public func ref(
        
firebaseUid: String

        ) -> QueryRefObservation<GetUserByFirebaseUidQuery.Data,GetUserByFirebaseUidQuery.Variables>  {
        var variables = GetUserByFirebaseUidQuery.Variables(firebaseUid:firebaseUid)
        

        let ref = dataConnect.query(name: "GetUserByFirebaseUid", variables: variables, resultsDataType:GetUserByFirebaseUidQuery.Data.self, publisher: .observableMacro)
        return ref as! QueryRefObservation<GetUserByFirebaseUidQuery.Data,GetUserByFirebaseUidQuery.Variables>
   }

  @MainActor
   public func execute( fetchPolicy: QueryFetchPolicy = .preferCache,  
        
firebaseUid: String

        ) async throws -> OperationResult<GetUserByFirebaseUidQuery.Data> {
        var variables = GetUserByFirebaseUidQuery.Variables(firebaseUid:firebaseUid)
        

        let ref = dataConnect.query(name: "GetUserByFirebaseUid", variables: variables, resultsDataType:GetUserByFirebaseUidQuery.Data.self, publisher: .observableMacro)
        
        let refCast = ref as! QueryRefObservation<GetUserByFirebaseUidQuery.Data,GetUserByFirebaseUidQuery.Variables>
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
email: String



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
    
    case email
    
    case profilePictureUrl
    
    case avatarUrl
    
    case topPRQScore
    
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


