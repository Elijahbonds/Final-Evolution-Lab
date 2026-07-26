
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
    self.updateMyTrainingProfileMutation = UpdateMyTrainingProfileMutation(dataConnect: dataConnect)
    self.createPostMutation = CreatePostMutation(dataConnect: dataConnect)
    self.createCommentMutation = CreateCommentMutation(dataConnect: dataConnect)
    self.likePostMutation = LikePostMutation(dataConnect: dataConnect)
    self.unlikePostMutation = UnlikePostMutation(dataConnect: dataConnect)
    self.deletePostMutation = DeletePostMutation(dataConnect: dataConnect)
    self.deleteCommentMutation = DeleteCommentMutation(dataConnect: dataConnect)
    self.spendEvolutionShardsMutation = SpendEvolutionShardsMutation(dataConnect: dataConnect)
    self.claimCreatorCardOwnershipMutation = ClaimCreatorCardOwnershipMutation(dataConnect: dataConnect)
    self.createCritiqueRequestWithEscrowMutation = CreateCritiqueRequestWithEscrowMutation(dataConnect: dataConnect)
    self.createCardMarketListingMutation = CreateCardMarketListingMutation(dataConnect: dataConnect)
    self.deactivateCardMarketListingMutation = DeactivateCardMarketListingMutation(dataConnect: dataConnect)
    self.executeMarketplacePurchaseMutation = ExecuteMarketplacePurchaseMutation(dataConnect: dataConnect)
    self.createCreatorCardCatalogItemMutation = CreateCreatorCardCatalogItemMutation(dataConnect: dataConnect)
    self.executeMarketplacePurchaseWithRoyaltyMutation = ExecuteMarketplacePurchaseWithRoyaltyMutation(dataConnect: dataConnect)
    self.claimRoyaltiesMutation = ClaimRoyaltiesMutation(dataConnect: dataConnect)
    self.listRecentPostsQuery = ListRecentPostsQuery(dataConnect: dataConnect)
    self.getPostWithThreadQuery = GetPostWithThreadQuery(dataConnect: dataConnect)
    self.getUserByFirebaseUidQuery = GetUserByFirebaseUidQuery(dataConnect: dataConnect)
    self.getMyPrivateProfileQuery = GetMyPrivateProfileQuery(dataConnect: dataConnect)
    self.getUserProfileQuery = GetUserProfileQuery(dataConnect: dataConnect)
    self.listCommentsForPostQuery = ListCommentsForPostQuery(dataConnect: dataConnect)
    self.listShardLedgerForUserQuery = ListShardLedgerForUserQuery(dataConnect: dataConnect)
    self.listCreatorCardsQuery = ListCreatorCardsQuery(dataConnect: dataConnect)
    self.listActiveCardMarketListingsQuery = ListActiveCardMarketListingsQuery(dataConnect: dataConnect)
    self.getCreatorCardCreatorQuery = GetCreatorCardCreatorQuery(dataConnect: dataConnect)
    
  }

  public func useEmulator(host: String = DataConnect.EmulatorDefaults.host, port: Int = DataConnect.EmulatorDefaults.port) {
    self.dataConnect.useEmulator(host: host, port: port)
  }

  // MARK: Operations
public let registerSignedInUserMutation: RegisterSignedInUserMutation
public let updateMyTrainingProfileMutation: UpdateMyTrainingProfileMutation
public let createPostMutation: CreatePostMutation
public let createCommentMutation: CreateCommentMutation
public let likePostMutation: LikePostMutation
public let unlikePostMutation: UnlikePostMutation
public let deletePostMutation: DeletePostMutation
public let deleteCommentMutation: DeleteCommentMutation
public let spendEvolutionShardsMutation: SpendEvolutionShardsMutation
public let claimCreatorCardOwnershipMutation: ClaimCreatorCardOwnershipMutation
public let createCritiqueRequestWithEscrowMutation: CreateCritiqueRequestWithEscrowMutation
public let createCardMarketListingMutation: CreateCardMarketListingMutation
public let deactivateCardMarketListingMutation: DeactivateCardMarketListingMutation
public let executeMarketplacePurchaseMutation: ExecuteMarketplacePurchaseMutation
public let createCreatorCardCatalogItemMutation: CreateCreatorCardCatalogItemMutation
public let executeMarketplacePurchaseWithRoyaltyMutation: ExecuteMarketplacePurchaseWithRoyaltyMutation
public let claimRoyaltiesMutation: ClaimRoyaltiesMutation
public let listRecentPostsQuery: ListRecentPostsQuery
public let getPostWithThreadQuery: GetPostWithThreadQuery
public let getUserByFirebaseUidQuery: GetUserByFirebaseUidQuery
public let getMyPrivateProfileQuery: GetMyPrivateProfileQuery
public let getUserProfileQuery: GetUserProfileQuery
public let listCommentsForPostQuery: ListCommentsForPostQuery
public let listShardLedgerForUserQuery: ListShardLedgerForUserQuery
public let listCreatorCardsQuery: ListCreatorCardsQuery
public let listActiveCardMarketListingsQuery: ListActiveCardMarketListingsQuery
public let getCreatorCardCreatorQuery: GetCreatorCardCreatorQuery


}
