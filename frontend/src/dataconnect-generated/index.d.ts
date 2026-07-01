import { ConnectorConfig, DataConnect, QueryRef, QueryPromise, ExecuteQueryOptions, MutationRef, MutationPromise } from 'firebase/data-connect';

export const connectorConfig: ConnectorConfig;

export type TimestampString = string;
export type UUIDString = string;
export type Int64String = string;
export type DateString = string;




export interface CardMarketListing_Key {
  id: UUIDString;
  __typename?: 'CardMarketListing_Key';
}

export interface ClaimCreatorCardOwnershipData {
  userOwnedCreatorCard_insert: UserOwnedCreatorCard_Key;
}

export interface ClaimCreatorCardOwnershipVariables {
  catalogCardId: string;
}

export interface ClaimRoyaltiesData {
  user_update?: User_Key | null;
  shardLedger_insert: ShardLedger_Key;
}

export interface ClaimRoyaltiesVariables {
  claimId: string;
  amount: number;
}

export interface CoachCritiqueRequest_Key {
  id: UUIDString;
  __typename?: 'CoachCritiqueRequest_Key';
}

export interface Comment_Key {
  id: UUIDString;
  __typename?: 'Comment_Key';
}

export interface CreateCardMarketListingData {
  cardMarketListing_insert: CardMarketListing_Key;
}

export interface CreateCardMarketListingVariables {
  catalogCardId: string;
  priceShards: number;
}

export interface CreateCommentData {
  comment_insert: Comment_Key;
}

export interface CreateCommentVariables {
  postId: UUIDString;
  content: string;
}

export interface CreateCreatorCardCatalogItemData {
  creatorCard_insert: CreatorCard_Key;
}

export interface CreateCreatorCardCatalogItemVariables {
  catalogCardId: string;
  displayName: string;
  rarityTier?: string | null;
}

export interface CreateCritiqueRequestWithEscrowData {
  shardLedger_insert: ShardLedger_Key;
  user_update?: User_Key | null;
  coachCritiqueRequest_insert: CoachCritiqueRequest_Key;
}

export interface CreateCritiqueRequestWithEscrowVariables {
  requestKey: string;
  exerciseName: string;
  notes?: string | null;
}

export interface CreatePostData {
  post_insert: Post_Key;
}

export interface CreatePostVariables {
  content: string;
  gameModeId?: string | null;
  trainingScore?: number | null;
  clipUrl?: string | null;
  feedSource?: string | null;
}

export interface CreatorCard_Key {
  id: UUIDString;
  __typename?: 'CreatorCard_Key';
}

export interface DeactivateCardMarketListingData {
  cardMarketListing_update?: CardMarketListing_Key | null;
}

export interface DeactivateCardMarketListingVariables {
  listingId: UUIDString;
}

export interface DeleteCommentData {
  comment_delete?: Comment_Key | null;
}

export interface DeleteCommentVariables {
  commentId: UUIDString;
}

export interface DeletePostData {
  post_delete?: Post_Key | null;
}

export interface DeletePostVariables {
  postId: UUIDString;
}

export interface ExecuteMarketplacePurchaseData {
  buyer_update?: User_Key | null;
  seller_update?: User_Key | null;
  revoke_ownership?: UserOwnedCreatorCard_Key | null;
  grant_ownership: UserOwnedCreatorCard_Key;
  deactivate_listing?: CardMarketListing_Key | null;
}

export interface ExecuteMarketplacePurchaseVariables {
  listingId: UUIDString;
  buyerId: UUIDString;
  sellerId: UUIDString;
  catalogCardId: string;
  buyerDeltaShards: number;
  sellerDeltaShards: number;
}

export interface ExecuteMarketplacePurchaseWithRoyaltyData {
  buyer_update?: User_Key | null;
  seller_update?: User_Key | null;
  creator_ledger_insert: ShardLedger_Key;
  creator_update?: User_Key | null;
  revoke_ownership?: UserOwnedCreatorCard_Key | null;
  grant_ownership: UserOwnedCreatorCard_Key;
  deactivate_listing?: CardMarketListing_Key | null;
}

export interface ExecuteMarketplacePurchaseWithRoyaltyVariables {
  listingId: UUIDString;
  buyerId: UUIDString;
  sellerId: UUIDString;
  catalogCardId: string;
  buyerDeltaShards: number;
  sellerDeltaShards: number;
  creatorId: UUIDString;
  royaltyShards: number;
}

export interface GetCreatorCardCreatorData {
  creatorCards: ({
    id: UUIDString;
    creator?: {
      id: UUIDString;
      username: string;
    } & User_Key;
  } & CreatorCard_Key)[];
}

export interface GetCreatorCardCreatorVariables {
  catalogCardId: string;
}

export interface GetMyPrivateProfileData {
  users: ({
    id: UUIDString;
    username: string;
    email: string;
    profilePictureUrl?: string | null;
    avatarUrl?: string | null;
    topPRQScore?: number | null;
    evolutionShards: number;
    pendingRoyaltyShards: number;
    firebaseUid?: string | null;
  } & User_Key)[];
}

export interface GetPostWithThreadData {
  post?: {
    id: UUIDString;
    content: string;
    createdAt: TimestampString;
    gameModeId?: string | null;
    trainingScore?: number | null;
    clipUrl?: string | null;
    feedSource?: string | null;
    author: {
      id: UUIDString;
      username: string;
      profilePictureUrl?: string | null;
      avatarUrl?: string | null;
      topPRQScore?: number | null;
    } & User_Key;
    comments_on_post: ({
      id: UUIDString;
      content: string;
      createdAt: TimestampString;
      author: {
        id: UUIDString;
        username: string;
        profilePictureUrl?: string | null;
        avatarUrl?: string | null;
      } & User_Key;
    } & Comment_Key)[];
    postLikes_on_post: ({
      createdAt: TimestampString;
      user: {
        id: UUIDString;
        username: string;
      } & User_Key;
    })[];
  } & Post_Key;
}

export interface GetPostWithThreadVariables {
  postKey: Post_Key;
}

export interface GetUserByFirebaseUidData {
  users: ({
    id: UUIDString;
    username: string;
    profilePictureUrl?: string | null;
    avatarUrl?: string | null;
    topPRQScore?: number | null;
    evolutionShards: number;
    pendingRoyaltyShards: number;
    firebaseUid?: string | null;
  } & User_Key)[];
}

export interface GetUserProfileData {
  user?: {
    id: UUIDString;
    username: string;
    profilePictureUrl?: string | null;
    avatarUrl?: string | null;
    topPRQScore?: number | null;
    evolutionShards: number;
    pendingRoyaltyShards: number;
  } & User_Key;
  posts: ({
    id: UUIDString;
    content: string;
    createdAt: TimestampString;
    gameModeId?: string | null;
    trainingScore?: number | null;
    feedSource?: string | null;
  } & Post_Key)[];
}

export interface GetUserProfileVariables {
  userId: UUIDString;
}

export interface LikePostData {
  postLike_insert: PostLike_Key;
}

export interface LikePostVariables {
  postId: UUIDString;
}

export interface ListActiveCardMarketListingsData {
  cardMarketListings: ({
    id: UUIDString;
    catalogCardId: string;
    priceShards: number;
    listedAt: TimestampString;
    active: boolean;
    seller: {
      id: UUIDString;
      username: string;
      avatarUrl?: string | null;
    } & User_Key;
  } & CardMarketListing_Key)[];
}

export interface ListActiveCardMarketListingsVariables {
  limit?: number | null;
}

export interface ListCommentsForPostData {
  comments: ({
    id: UUIDString;
    content: string;
    createdAt: TimestampString;
    author: {
      id: UUIDString;
      username: string;
      profilePictureUrl?: string | null;
      avatarUrl?: string | null;
    } & User_Key;
  } & Comment_Key)[];
}

export interface ListCommentsForPostVariables {
  postId: UUIDString;
}

export interface ListCreatorCardsData {
  creatorCards: ({
    id: UUIDString;
    catalogCardId: string;
    displayName: string;
    rarityTier?: string | null;
    createdAt: TimestampString;
    creator?: {
      id: UUIDString;
      username: string;
    } & User_Key;
  } & CreatorCard_Key)[];
}

export interface ListCreatorCardsVariables {
  limit?: number | null;
}

export interface ListRecentPostsData {
  posts: ({
    id: UUIDString;
    content: string;
    createdAt: TimestampString;
    gameModeId?: string | null;
    trainingScore?: number | null;
    clipUrl?: string | null;
    feedSource?: string | null;
    author: {
      id: UUIDString;
      username: string;
      profilePictureUrl?: string | null;
      avatarUrl?: string | null;
      topPRQScore?: number | null;
    } & User_Key;
  } & Post_Key)[];
}

export interface ListShardLedgerForUserData {
  shardLedgers: ({
    id: UUIDString;
    deltaShards: number;
    reason: string;
    referenceId?: string | null;
    createdAt: TimestampString;
  } & ShardLedger_Key)[];
}

export interface ListShardLedgerForUserVariables {
  limit?: number | null;
}

export interface PostLike_Key {
  postId: UUIDString;
  userId: UUIDString;
  __typename?: 'PostLike_Key';
}

export interface Post_Key {
  id: UUIDString;
  __typename?: 'Post_Key';
}

export interface RegisterSignedInUserData {
  user_insert: User_Key;
}

export interface RegisterSignedInUserVariables {
  username: string;
  email: string;
  profilePictureUrl?: string | null;
  avatarUrl?: string | null;
}

export interface ShardLedger_Key {
  id: UUIDString;
  __typename?: 'ShardLedger_Key';
}

export interface SpendEvolutionShardsData {
  shardLedger_insert: ShardLedger_Key;
  user_update?: User_Key | null;
}

export interface SpendEvolutionShardsVariables {
  deltaShards: number;
  reason: string;
  referenceId?: string | null;
}

export interface UnlikePostData {
  postLike_delete?: PostLike_Key | null;
}

export interface UnlikePostVariables {
  postId: UUIDString;
}

export interface UpdateMyTrainingProfileData {
  user_update?: User_Key | null;
}

export interface UpdateMyTrainingProfileVariables {
  topPRQScore: number;
  avatarUrl?: string | null;
}

export interface UserOwnedCreatorCard_Key {
  userId: UUIDString;
  creatorCardId: UUIDString;
  __typename?: 'UserOwnedCreatorCard_Key';
}

export interface User_Key {
  id: UUIDString;
  __typename?: 'User_Key';
}

interface RegisterSignedInUserRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: RegisterSignedInUserVariables): MutationRef<RegisterSignedInUserData, RegisterSignedInUserVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: RegisterSignedInUserVariables): MutationRef<RegisterSignedInUserData, RegisterSignedInUserVariables>;
  operationName: string;
}
export const registerSignedInUserRef: RegisterSignedInUserRef;

export function registerSignedInUser(vars: RegisterSignedInUserVariables): MutationPromise<RegisterSignedInUserData, RegisterSignedInUserVariables>;
export function registerSignedInUser(dc: DataConnect, vars: RegisterSignedInUserVariables): MutationPromise<RegisterSignedInUserData, RegisterSignedInUserVariables>;

interface UpdateMyTrainingProfileRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateMyTrainingProfileVariables): MutationRef<UpdateMyTrainingProfileData, UpdateMyTrainingProfileVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdateMyTrainingProfileVariables): MutationRef<UpdateMyTrainingProfileData, UpdateMyTrainingProfileVariables>;
  operationName: string;
}
export const updateMyTrainingProfileRef: UpdateMyTrainingProfileRef;

export function updateMyTrainingProfile(vars: UpdateMyTrainingProfileVariables): MutationPromise<UpdateMyTrainingProfileData, UpdateMyTrainingProfileVariables>;
export function updateMyTrainingProfile(dc: DataConnect, vars: UpdateMyTrainingProfileVariables): MutationPromise<UpdateMyTrainingProfileData, UpdateMyTrainingProfileVariables>;

interface CreatePostRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreatePostVariables): MutationRef<CreatePostData, CreatePostVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: CreatePostVariables): MutationRef<CreatePostData, CreatePostVariables>;
  operationName: string;
}
export const createPostRef: CreatePostRef;

export function createPost(vars: CreatePostVariables): MutationPromise<CreatePostData, CreatePostVariables>;
export function createPost(dc: DataConnect, vars: CreatePostVariables): MutationPromise<CreatePostData, CreatePostVariables>;

interface CreateCommentRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateCommentVariables): MutationRef<CreateCommentData, CreateCommentVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: CreateCommentVariables): MutationRef<CreateCommentData, CreateCommentVariables>;
  operationName: string;
}
export const createCommentRef: CreateCommentRef;

export function createComment(vars: CreateCommentVariables): MutationPromise<CreateCommentData, CreateCommentVariables>;
export function createComment(dc: DataConnect, vars: CreateCommentVariables): MutationPromise<CreateCommentData, CreateCommentVariables>;

interface LikePostRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: LikePostVariables): MutationRef<LikePostData, LikePostVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: LikePostVariables): MutationRef<LikePostData, LikePostVariables>;
  operationName: string;
}
export const likePostRef: LikePostRef;

export function likePost(vars: LikePostVariables): MutationPromise<LikePostData, LikePostVariables>;
export function likePost(dc: DataConnect, vars: LikePostVariables): MutationPromise<LikePostData, LikePostVariables>;

interface UnlikePostRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UnlikePostVariables): MutationRef<UnlikePostData, UnlikePostVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UnlikePostVariables): MutationRef<UnlikePostData, UnlikePostVariables>;
  operationName: string;
}
export const unlikePostRef: UnlikePostRef;

export function unlikePost(vars: UnlikePostVariables): MutationPromise<UnlikePostData, UnlikePostVariables>;
export function unlikePost(dc: DataConnect, vars: UnlikePostVariables): MutationPromise<UnlikePostData, UnlikePostVariables>;

interface DeletePostRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeletePostVariables): MutationRef<DeletePostData, DeletePostVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: DeletePostVariables): MutationRef<DeletePostData, DeletePostVariables>;
  operationName: string;
}
export const deletePostRef: DeletePostRef;

export function deletePost(vars: DeletePostVariables): MutationPromise<DeletePostData, DeletePostVariables>;
export function deletePost(dc: DataConnect, vars: DeletePostVariables): MutationPromise<DeletePostData, DeletePostVariables>;

interface DeleteCommentRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteCommentVariables): MutationRef<DeleteCommentData, DeleteCommentVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: DeleteCommentVariables): MutationRef<DeleteCommentData, DeleteCommentVariables>;
  operationName: string;
}
export const deleteCommentRef: DeleteCommentRef;

export function deleteComment(vars: DeleteCommentVariables): MutationPromise<DeleteCommentData, DeleteCommentVariables>;
export function deleteComment(dc: DataConnect, vars: DeleteCommentVariables): MutationPromise<DeleteCommentData, DeleteCommentVariables>;

interface SpendEvolutionShardsRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: SpendEvolutionShardsVariables): MutationRef<SpendEvolutionShardsData, SpendEvolutionShardsVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: SpendEvolutionShardsVariables): MutationRef<SpendEvolutionShardsData, SpendEvolutionShardsVariables>;
  operationName: string;
}
export const spendEvolutionShardsRef: SpendEvolutionShardsRef;

export function spendEvolutionShards(vars: SpendEvolutionShardsVariables): MutationPromise<SpendEvolutionShardsData, SpendEvolutionShardsVariables>;
export function spendEvolutionShards(dc: DataConnect, vars: SpendEvolutionShardsVariables): MutationPromise<SpendEvolutionShardsData, SpendEvolutionShardsVariables>;

interface ClaimCreatorCardOwnershipRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: ClaimCreatorCardOwnershipVariables): MutationRef<ClaimCreatorCardOwnershipData, ClaimCreatorCardOwnershipVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: ClaimCreatorCardOwnershipVariables): MutationRef<ClaimCreatorCardOwnershipData, ClaimCreatorCardOwnershipVariables>;
  operationName: string;
}
export const claimCreatorCardOwnershipRef: ClaimCreatorCardOwnershipRef;

export function claimCreatorCardOwnership(vars: ClaimCreatorCardOwnershipVariables): MutationPromise<ClaimCreatorCardOwnershipData, ClaimCreatorCardOwnershipVariables>;
export function claimCreatorCardOwnership(dc: DataConnect, vars: ClaimCreatorCardOwnershipVariables): MutationPromise<ClaimCreatorCardOwnershipData, ClaimCreatorCardOwnershipVariables>;

interface CreateCritiqueRequestWithEscrowRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateCritiqueRequestWithEscrowVariables): MutationRef<CreateCritiqueRequestWithEscrowData, CreateCritiqueRequestWithEscrowVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: CreateCritiqueRequestWithEscrowVariables): MutationRef<CreateCritiqueRequestWithEscrowData, CreateCritiqueRequestWithEscrowVariables>;
  operationName: string;
}
export const createCritiqueRequestWithEscrowRef: CreateCritiqueRequestWithEscrowRef;

export function createCritiqueRequestWithEscrow(vars: CreateCritiqueRequestWithEscrowVariables): MutationPromise<CreateCritiqueRequestWithEscrowData, CreateCritiqueRequestWithEscrowVariables>;
export function createCritiqueRequestWithEscrow(dc: DataConnect, vars: CreateCritiqueRequestWithEscrowVariables): MutationPromise<CreateCritiqueRequestWithEscrowData, CreateCritiqueRequestWithEscrowVariables>;

interface CreateCardMarketListingRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateCardMarketListingVariables): MutationRef<CreateCardMarketListingData, CreateCardMarketListingVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: CreateCardMarketListingVariables): MutationRef<CreateCardMarketListingData, CreateCardMarketListingVariables>;
  operationName: string;
}
export const createCardMarketListingRef: CreateCardMarketListingRef;

export function createCardMarketListing(vars: CreateCardMarketListingVariables): MutationPromise<CreateCardMarketListingData, CreateCardMarketListingVariables>;
export function createCardMarketListing(dc: DataConnect, vars: CreateCardMarketListingVariables): MutationPromise<CreateCardMarketListingData, CreateCardMarketListingVariables>;

interface DeactivateCardMarketListingRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeactivateCardMarketListingVariables): MutationRef<DeactivateCardMarketListingData, DeactivateCardMarketListingVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: DeactivateCardMarketListingVariables): MutationRef<DeactivateCardMarketListingData, DeactivateCardMarketListingVariables>;
  operationName: string;
}
export const deactivateCardMarketListingRef: DeactivateCardMarketListingRef;

export function deactivateCardMarketListing(vars: DeactivateCardMarketListingVariables): MutationPromise<DeactivateCardMarketListingData, DeactivateCardMarketListingVariables>;
export function deactivateCardMarketListing(dc: DataConnect, vars: DeactivateCardMarketListingVariables): MutationPromise<DeactivateCardMarketListingData, DeactivateCardMarketListingVariables>;

interface ExecuteMarketplacePurchaseRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: ExecuteMarketplacePurchaseVariables): MutationRef<ExecuteMarketplacePurchaseData, ExecuteMarketplacePurchaseVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: ExecuteMarketplacePurchaseVariables): MutationRef<ExecuteMarketplacePurchaseData, ExecuteMarketplacePurchaseVariables>;
  operationName: string;
}
export const executeMarketplacePurchaseRef: ExecuteMarketplacePurchaseRef;

export function executeMarketplacePurchase(vars: ExecuteMarketplacePurchaseVariables): MutationPromise<ExecuteMarketplacePurchaseData, ExecuteMarketplacePurchaseVariables>;
export function executeMarketplacePurchase(dc: DataConnect, vars: ExecuteMarketplacePurchaseVariables): MutationPromise<ExecuteMarketplacePurchaseData, ExecuteMarketplacePurchaseVariables>;

interface CreateCreatorCardCatalogItemRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateCreatorCardCatalogItemVariables): MutationRef<CreateCreatorCardCatalogItemData, CreateCreatorCardCatalogItemVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: CreateCreatorCardCatalogItemVariables): MutationRef<CreateCreatorCardCatalogItemData, CreateCreatorCardCatalogItemVariables>;
  operationName: string;
}
export const createCreatorCardCatalogItemRef: CreateCreatorCardCatalogItemRef;

export function createCreatorCardCatalogItem(vars: CreateCreatorCardCatalogItemVariables): MutationPromise<CreateCreatorCardCatalogItemData, CreateCreatorCardCatalogItemVariables>;
export function createCreatorCardCatalogItem(dc: DataConnect, vars: CreateCreatorCardCatalogItemVariables): MutationPromise<CreateCreatorCardCatalogItemData, CreateCreatorCardCatalogItemVariables>;

interface ExecuteMarketplacePurchaseWithRoyaltyRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: ExecuteMarketplacePurchaseWithRoyaltyVariables): MutationRef<ExecuteMarketplacePurchaseWithRoyaltyData, ExecuteMarketplacePurchaseWithRoyaltyVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: ExecuteMarketplacePurchaseWithRoyaltyVariables): MutationRef<ExecuteMarketplacePurchaseWithRoyaltyData, ExecuteMarketplacePurchaseWithRoyaltyVariables>;
  operationName: string;
}
export const executeMarketplacePurchaseWithRoyaltyRef: ExecuteMarketplacePurchaseWithRoyaltyRef;

export function executeMarketplacePurchaseWithRoyalty(vars: ExecuteMarketplacePurchaseWithRoyaltyVariables): MutationPromise<ExecuteMarketplacePurchaseWithRoyaltyData, ExecuteMarketplacePurchaseWithRoyaltyVariables>;
export function executeMarketplacePurchaseWithRoyalty(dc: DataConnect, vars: ExecuteMarketplacePurchaseWithRoyaltyVariables): MutationPromise<ExecuteMarketplacePurchaseWithRoyaltyData, ExecuteMarketplacePurchaseWithRoyaltyVariables>;

interface ClaimRoyaltiesRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: ClaimRoyaltiesVariables): MutationRef<ClaimRoyaltiesData, ClaimRoyaltiesVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: ClaimRoyaltiesVariables): MutationRef<ClaimRoyaltiesData, ClaimRoyaltiesVariables>;
  operationName: string;
}
export const claimRoyaltiesRef: ClaimRoyaltiesRef;

export function claimRoyalties(vars: ClaimRoyaltiesVariables): MutationPromise<ClaimRoyaltiesData, ClaimRoyaltiesVariables>;
export function claimRoyalties(dc: DataConnect, vars: ClaimRoyaltiesVariables): MutationPromise<ClaimRoyaltiesData, ClaimRoyaltiesVariables>;

interface ListRecentPostsRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListRecentPostsData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<ListRecentPostsData, undefined>;
  operationName: string;
}
export const listRecentPostsRef: ListRecentPostsRef;

export function listRecentPosts(options?: ExecuteQueryOptions): QueryPromise<ListRecentPostsData, undefined>;
export function listRecentPosts(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListRecentPostsData, undefined>;

interface GetPostWithThreadRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetPostWithThreadVariables): QueryRef<GetPostWithThreadData, GetPostWithThreadVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: GetPostWithThreadVariables): QueryRef<GetPostWithThreadData, GetPostWithThreadVariables>;
  operationName: string;
}
export const getPostWithThreadRef: GetPostWithThreadRef;

export function getPostWithThread(vars: GetPostWithThreadVariables, options?: ExecuteQueryOptions): QueryPromise<GetPostWithThreadData, GetPostWithThreadVariables>;
export function getPostWithThread(dc: DataConnect, vars: GetPostWithThreadVariables, options?: ExecuteQueryOptions): QueryPromise<GetPostWithThreadData, GetPostWithThreadVariables>;

interface GetUserByFirebaseUidRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<GetUserByFirebaseUidData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<GetUserByFirebaseUidData, undefined>;
  operationName: string;
}
export const getUserByFirebaseUidRef: GetUserByFirebaseUidRef;

export function getUserByFirebaseUid(options?: ExecuteQueryOptions): QueryPromise<GetUserByFirebaseUidData, undefined>;
export function getUserByFirebaseUid(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<GetUserByFirebaseUidData, undefined>;

interface GetMyPrivateProfileRef {
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<GetMyPrivateProfileData, undefined>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect): QueryRef<GetMyPrivateProfileData, undefined>;
  operationName: string;
}
export const getMyPrivateProfileRef: GetMyPrivateProfileRef;

export function getMyPrivateProfile(options?: ExecuteQueryOptions): QueryPromise<GetMyPrivateProfileData, undefined>;
export function getMyPrivateProfile(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<GetMyPrivateProfileData, undefined>;

interface GetUserProfileRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetUserProfileVariables): QueryRef<GetUserProfileData, GetUserProfileVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: GetUserProfileVariables): QueryRef<GetUserProfileData, GetUserProfileVariables>;
  operationName: string;
}
export const getUserProfileRef: GetUserProfileRef;

export function getUserProfile(vars: GetUserProfileVariables, options?: ExecuteQueryOptions): QueryPromise<GetUserProfileData, GetUserProfileVariables>;
export function getUserProfile(dc: DataConnect, vars: GetUserProfileVariables, options?: ExecuteQueryOptions): QueryPromise<GetUserProfileData, GetUserProfileVariables>;

interface ListCommentsForPostRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: ListCommentsForPostVariables): QueryRef<ListCommentsForPostData, ListCommentsForPostVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: ListCommentsForPostVariables): QueryRef<ListCommentsForPostData, ListCommentsForPostVariables>;
  operationName: string;
}
export const listCommentsForPostRef: ListCommentsForPostRef;

export function listCommentsForPost(vars: ListCommentsForPostVariables, options?: ExecuteQueryOptions): QueryPromise<ListCommentsForPostData, ListCommentsForPostVariables>;
export function listCommentsForPost(dc: DataConnect, vars: ListCommentsForPostVariables, options?: ExecuteQueryOptions): QueryPromise<ListCommentsForPostData, ListCommentsForPostVariables>;

interface ListShardLedgerForUserRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars?: ListShardLedgerForUserVariables): QueryRef<ListShardLedgerForUserData, ListShardLedgerForUserVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars?: ListShardLedgerForUserVariables): QueryRef<ListShardLedgerForUserData, ListShardLedgerForUserVariables>;
  operationName: string;
}
export const listShardLedgerForUserRef: ListShardLedgerForUserRef;

export function listShardLedgerForUser(vars?: ListShardLedgerForUserVariables, options?: ExecuteQueryOptions): QueryPromise<ListShardLedgerForUserData, ListShardLedgerForUserVariables>;
export function listShardLedgerForUser(dc: DataConnect, vars?: ListShardLedgerForUserVariables, options?: ExecuteQueryOptions): QueryPromise<ListShardLedgerForUserData, ListShardLedgerForUserVariables>;

interface ListCreatorCardsRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars?: ListCreatorCardsVariables): QueryRef<ListCreatorCardsData, ListCreatorCardsVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars?: ListCreatorCardsVariables): QueryRef<ListCreatorCardsData, ListCreatorCardsVariables>;
  operationName: string;
}
export const listCreatorCardsRef: ListCreatorCardsRef;

export function listCreatorCards(vars?: ListCreatorCardsVariables, options?: ExecuteQueryOptions): QueryPromise<ListCreatorCardsData, ListCreatorCardsVariables>;
export function listCreatorCards(dc: DataConnect, vars?: ListCreatorCardsVariables, options?: ExecuteQueryOptions): QueryPromise<ListCreatorCardsData, ListCreatorCardsVariables>;

interface ListActiveCardMarketListingsRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars?: ListActiveCardMarketListingsVariables): QueryRef<ListActiveCardMarketListingsData, ListActiveCardMarketListingsVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars?: ListActiveCardMarketListingsVariables): QueryRef<ListActiveCardMarketListingsData, ListActiveCardMarketListingsVariables>;
  operationName: string;
}
export const listActiveCardMarketListingsRef: ListActiveCardMarketListingsRef;

export function listActiveCardMarketListings(vars?: ListActiveCardMarketListingsVariables, options?: ExecuteQueryOptions): QueryPromise<ListActiveCardMarketListingsData, ListActiveCardMarketListingsVariables>;
export function listActiveCardMarketListings(dc: DataConnect, vars?: ListActiveCardMarketListingsVariables, options?: ExecuteQueryOptions): QueryPromise<ListActiveCardMarketListingsData, ListActiveCardMarketListingsVariables>;

interface GetCreatorCardCreatorRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetCreatorCardCreatorVariables): QueryRef<GetCreatorCardCreatorData, GetCreatorCardCreatorVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: GetCreatorCardCreatorVariables): QueryRef<GetCreatorCardCreatorData, GetCreatorCardCreatorVariables>;
  operationName: string;
}
export const getCreatorCardCreatorRef: GetCreatorCardCreatorRef;

export function getCreatorCardCreator(vars: GetCreatorCardCreatorVariables, options?: ExecuteQueryOptions): QueryPromise<GetCreatorCardCreatorData, GetCreatorCardCreatorVariables>;
export function getCreatorCardCreator(dc: DataConnect, vars: GetCreatorCardCreatorVariables, options?: ExecuteQueryOptions): QueryPromise<GetCreatorCardCreatorData, GetCreatorCardCreatorVariables>;

