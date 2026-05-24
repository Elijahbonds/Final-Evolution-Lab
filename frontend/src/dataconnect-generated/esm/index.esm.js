import { queryRef, executeQuery, validateArgsWithOptions, mutationRef, executeMutation, validateArgs } from 'firebase/data-connect';

export const connectorConfig = {
  connector: 'social',
  service: 'elijahbonds',
  location: 'us-east4'
};
export const registerSignedInUserRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'RegisterSignedInUser', inputVars);
}
registerSignedInUserRef.operationName = 'RegisterSignedInUser';

export function registerSignedInUser(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(registerSignedInUserRef(dcInstance, inputVars));
}

export const updateMyTrainingProfileRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'UpdateMyTrainingProfile', inputVars);
}
updateMyTrainingProfileRef.operationName = 'UpdateMyTrainingProfile';

export function updateMyTrainingProfile(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(updateMyTrainingProfileRef(dcInstance, inputVars));
}

export const createPostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreatePost', inputVars);
}
createPostRef.operationName = 'CreatePost';

export function createPost(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createPostRef(dcInstance, inputVars));
}

export const createCommentRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateComment', inputVars);
}
createCommentRef.operationName = 'CreateComment';

export function createComment(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createCommentRef(dcInstance, inputVars));
}

export const likePostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'LikePost', inputVars);
}
likePostRef.operationName = 'LikePost';

export function likePost(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(likePostRef(dcInstance, inputVars));
}

export const unlikePostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'UnlikePost', inputVars);
}
unlikePostRef.operationName = 'UnlikePost';

export function unlikePost(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(unlikePostRef(dcInstance, inputVars));
}

export const deletePostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'DeletePost', inputVars);
}
deletePostRef.operationName = 'DeletePost';

export function deletePost(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(deletePostRef(dcInstance, inputVars));
}

export const deleteCommentRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'DeleteComment', inputVars);
}
deleteCommentRef.operationName = 'DeleteComment';

export function deleteComment(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(deleteCommentRef(dcInstance, inputVars));
}

export const spendEvolutionShardsRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'SpendEvolutionShards', inputVars);
}
spendEvolutionShardsRef.operationName = 'SpendEvolutionShards';

export function spendEvolutionShards(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(spendEvolutionShardsRef(dcInstance, inputVars));
}

export const claimCreatorCardOwnershipRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'ClaimCreatorCardOwnership', inputVars);
}
claimCreatorCardOwnershipRef.operationName = 'ClaimCreatorCardOwnership';

export function claimCreatorCardOwnership(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(claimCreatorCardOwnershipRef(dcInstance, inputVars));
}

export const createCritiqueRequestWithEscrowRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateCritiqueRequestWithEscrow', inputVars);
}
createCritiqueRequestWithEscrowRef.operationName = 'CreateCritiqueRequestWithEscrow';

export function createCritiqueRequestWithEscrow(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createCritiqueRequestWithEscrowRef(dcInstance, inputVars));
}

export const createCardMarketListingRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateCardMarketListing', inputVars);
}
createCardMarketListingRef.operationName = 'CreateCardMarketListing';

export function createCardMarketListing(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createCardMarketListingRef(dcInstance, inputVars));
}

export const deactivateCardMarketListingRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'DeactivateCardMarketListing', inputVars);
}
deactivateCardMarketListingRef.operationName = 'DeactivateCardMarketListing';

export function deactivateCardMarketListing(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(deactivateCardMarketListingRef(dcInstance, inputVars));
}

export const listRecentPostsRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListRecentPosts');
}
listRecentPostsRef.operationName = 'ListRecentPosts';

export function listRecentPosts(dcOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrOptions, options, undefined,false, false);
  return executeQuery(listRecentPostsRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

export const getPostWithThreadRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'GetPostWithThread', inputVars);
}
getPostWithThreadRef.operationName = 'GetPostWithThread';

export function getPostWithThread(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, true);
  return executeQuery(getPostWithThreadRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

export const getUserByFirebaseUidRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'GetUserByFirebaseUid');
}
getUserByFirebaseUidRef.operationName = 'GetUserByFirebaseUid';

export function getUserByFirebaseUid(dcOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrOptions, options, undefined,false, false);
  return executeQuery(getUserByFirebaseUidRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

export const getMyPrivateProfileRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'GetMyPrivateProfile');
}
getMyPrivateProfileRef.operationName = 'GetMyPrivateProfile';

export function getMyPrivateProfile(dcOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrOptions, options, undefined,false, false);
  return executeQuery(getMyPrivateProfileRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

export const getUserProfileRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'GetUserProfile', inputVars);
}
getUserProfileRef.operationName = 'GetUserProfile';

export function getUserProfile(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, true);
  return executeQuery(getUserProfileRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

export const listCommentsForPostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListCommentsForPost', inputVars);
}
listCommentsForPostRef.operationName = 'ListCommentsForPost';

export function listCommentsForPost(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, true);
  return executeQuery(listCommentsForPostRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

export const listShardLedgerForUserRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListShardLedgerForUser', inputVars);
}
listShardLedgerForUserRef.operationName = 'ListShardLedgerForUser';

export function listShardLedgerForUser(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, false);
  return executeQuery(listShardLedgerForUserRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

export const listCreatorCardsRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListCreatorCards', inputVars);
}
listCreatorCardsRef.operationName = 'ListCreatorCards';

export function listCreatorCards(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, false);
  return executeQuery(listCreatorCardsRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

export const listActiveCardMarketListingsRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListActiveCardMarketListings', inputVars);
}
listActiveCardMarketListingsRef.operationName = 'ListActiveCardMarketListings';

export function listActiveCardMarketListings(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, false);
  return executeQuery(listActiveCardMarketListingsRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}

