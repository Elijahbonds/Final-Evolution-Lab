import { ConnectorConfig, DataConnect, QueryRef, QueryPromise, ExecuteQueryOptions, MutationRef, MutationPromise } from 'firebase/data-connect';

export const connectorConfig: ConnectorConfig;

export type TimestampString = string;
export type UUIDString = string;
export type Int64String = string;
export type DateString = string;




export interface Comment_Key {
  id: UUIDString;
  __typename?: 'Comment_Key';
}

export interface CreateCommentData {
  comment_insert: Comment_Key;
}

export interface CreateCommentVariables {
  postId: UUIDString;
  authorId: UUIDString;
  content: string;
}

export interface CreatePostData {
  post_insert: Post_Key;
}

export interface CreatePostVariables {
  content: string;
  authorId: UUIDString;
  gameModeId?: string | null;
  trainingScore?: number | null;
  clipUrl?: string | null;
  feedSource?: string | null;
}

export interface DeleteCommentData {
  comment_delete?: Comment_Key | null;
}

export interface DeleteCommentVariables {
  commentKey: Comment_Key;
}

export interface DeletePostData {
  post_delete?: Post_Key | null;
}

export interface DeletePostVariables {
  postKey: Post_Key;
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
      email: string;
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
    email: string;
    profilePictureUrl?: string | null;
    avatarUrl?: string | null;
    topPRQScore?: number | null;
    firebaseUid?: string | null;
  } & User_Key)[];
}

export interface GetUserByFirebaseUidVariables {
  firebaseUid: string;
}

export interface GetUserProfileData {
  user?: {
    id: UUIDString;
    username: string;
    email: string;
    profilePictureUrl?: string | null;
    avatarUrl?: string | null;
    topPRQScore?: number | null;
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
  userId: UUIDString;
}

export interface LinkUserToFirebaseAuthData {
  user_update?: User_Key | null;
}

export interface LinkUserToFirebaseAuthVariables {
  userKey: User_Key;
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

export interface UnlikePostData {
  postLike_delete?: PostLike_Key | null;
}

export interface UnlikePostVariables {
  postId: UUIDString;
  userId: UUIDString;
}

export interface UpdateUserTrainingProfileData {
  user_update?: User_Key | null;
}

export interface UpdateUserTrainingProfileVariables {
  userKey: User_Key;
  topPRQScore: number;
  avatarUrl?: string | null;
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

interface LinkUserToFirebaseAuthRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: LinkUserToFirebaseAuthVariables): MutationRef<LinkUserToFirebaseAuthData, LinkUserToFirebaseAuthVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: LinkUserToFirebaseAuthVariables): MutationRef<LinkUserToFirebaseAuthData, LinkUserToFirebaseAuthVariables>;
  operationName: string;
}
export const linkUserToFirebaseAuthRef: LinkUserToFirebaseAuthRef;

export function linkUserToFirebaseAuth(vars: LinkUserToFirebaseAuthVariables): MutationPromise<LinkUserToFirebaseAuthData, LinkUserToFirebaseAuthVariables>;
export function linkUserToFirebaseAuth(dc: DataConnect, vars: LinkUserToFirebaseAuthVariables): MutationPromise<LinkUserToFirebaseAuthData, LinkUserToFirebaseAuthVariables>;

interface UpdateUserTrainingProfileRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateUserTrainingProfileVariables): MutationRef<UpdateUserTrainingProfileData, UpdateUserTrainingProfileVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: UpdateUserTrainingProfileVariables): MutationRef<UpdateUserTrainingProfileData, UpdateUserTrainingProfileVariables>;
  operationName: string;
}
export const updateUserTrainingProfileRef: UpdateUserTrainingProfileRef;

export function updateUserTrainingProfile(vars: UpdateUserTrainingProfileVariables): MutationPromise<UpdateUserTrainingProfileData, UpdateUserTrainingProfileVariables>;
export function updateUserTrainingProfile(dc: DataConnect, vars: UpdateUserTrainingProfileVariables): MutationPromise<UpdateUserTrainingProfileData, UpdateUserTrainingProfileVariables>;

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
  (vars: GetUserByFirebaseUidVariables): QueryRef<GetUserByFirebaseUidData, GetUserByFirebaseUidVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: GetUserByFirebaseUidVariables): QueryRef<GetUserByFirebaseUidData, GetUserByFirebaseUidVariables>;
  operationName: string;
}
export const getUserByFirebaseUidRef: GetUserByFirebaseUidRef;

export function getUserByFirebaseUid(vars: GetUserByFirebaseUidVariables, options?: ExecuteQueryOptions): QueryPromise<GetUserByFirebaseUidData, GetUserByFirebaseUidVariables>;
export function getUserByFirebaseUid(dc: DataConnect, vars: GetUserByFirebaseUidVariables, options?: ExecuteQueryOptions): QueryPromise<GetUserByFirebaseUidData, GetUserByFirebaseUidVariables>;

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

