
import Foundation

import FirebaseCore
import FirebaseDataConnect
public extension DataConnect {

  static let socialConnector: SocialConnector = {

    let dc = DataConnect.dataConnect(connectorConfig: SocialConnector.connectorConfig, callerSDKType: .generated)
    return SocialConnector(dataConnect: dc)
  }()

}

public class SocialConnector {

  let dataConnect: DataConnect

  public static let connectorConfig = ConnectorConfig(serviceId: "elijahbonds", location: "us-east4", connector: "social")

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect

    // init operations 
    self.registerSignedInUserMutation = RegisterSignedInUserMutation(dataConnect: dataConnect)
    self.linkUserToFirebaseAuthMutation = LinkUserToFirebaseAuthMutation(dataConnect: dataConnect)
    self.updateUserTrainingProfileMutation = UpdateUserTrainingProfileMutation(dataConnect: dataConnect)
    self.createPostMutation = CreatePostMutation(dataConnect: dataConnect)
    self.createCommentMutation = CreateCommentMutation(dataConnect: dataConnect)
    self.likePostMutation = LikePostMutation(dataConnect: dataConnect)
    self.unlikePostMutation = UnlikePostMutation(dataConnect: dataConnect)
    self.deletePostMutation = DeletePostMutation(dataConnect: dataConnect)
    self.deleteCommentMutation = DeleteCommentMutation(dataConnect: dataConnect)
    self.listRecentPostsQuery = ListRecentPostsQuery(dataConnect: dataConnect)
    self.getPostWithThreadQuery = GetPostWithThreadQuery(dataConnect: dataConnect)
    self.getUserByFirebaseUidQuery = GetUserByFirebaseUidQuery(dataConnect: dataConnect)
    self.getUserProfileQuery = GetUserProfileQuery(dataConnect: dataConnect)
    self.listCommentsForPostQuery = ListCommentsForPostQuery(dataConnect: dataConnect)
    
  }

  public func useEmulator(host: String = DataConnect.EmulatorDefaults.host, port: Int = DataConnect.EmulatorDefaults.port) {
    self.dataConnect.useEmulator(host: host, port: port)
  }

  // MARK: Operations
public let registerSignedInUserMutation: RegisterSignedInUserMutation
public let linkUserToFirebaseAuthMutation: LinkUserToFirebaseAuthMutation
public let updateUserTrainingProfileMutation: UpdateUserTrainingProfileMutation
public let createPostMutation: CreatePostMutation
public let createCommentMutation: CreateCommentMutation
public let likePostMutation: LikePostMutation
public let unlikePostMutation: UnlikePostMutation
public let deletePostMutation: DeletePostMutation
public let deleteCommentMutation: DeleteCommentMutation
public let listRecentPostsQuery: ListRecentPostsQuery
public let getPostWithThreadQuery: GetPostWithThreadQuery
public let getUserByFirebaseUidQuery: GetUserByFirebaseUidQuery
public let getUserProfileQuery: GetUserProfileQuery
public let listCommentsForPostQuery: ListCommentsForPostQuery


}
