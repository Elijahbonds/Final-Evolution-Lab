const { queryRef, executeQuery, validateArgsWithOptions, mutationRef, executeMutation, validateArgs } = require('firebase/data-connect');

const connectorConfig = {
  connector: 'social',
  service: 'elijahbonds',
  location: 'us-east4'
};
exports.connectorConfig = connectorConfig;

const registerSignedInUserRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'RegisterSignedInUser', inputVars);
}
registerSignedInUserRef.operationName = 'RegisterSignedInUser';
exports.registerSignedInUserRef = registerSignedInUserRef;

exports.registerSignedInUser = function registerSignedInUser(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(registerSignedInUserRef(dcInstance, inputVars));
}
;

const updateMyTrainingProfileRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'UpdateMyTrainingProfile', inputVars);
}
updateMyTrainingProfileRef.operationName = 'UpdateMyTrainingProfile';
exports.updateMyTrainingProfileRef = updateMyTrainingProfileRef;

exports.updateMyTrainingProfile = function updateMyTrainingProfile(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(updateMyTrainingProfileRef(dcInstance, inputVars));
}
;

const createPostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreatePost', inputVars);
}
createPostRef.operationName = 'CreatePost';
exports.createPostRef = createPostRef;

exports.createPost = function createPost(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createPostRef(dcInstance, inputVars));
}
;

const createCommentRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateComment', inputVars);
}
createCommentRef.operationName = 'CreateComment';
exports.createCommentRef = createCommentRef;

exports.createComment = function createComment(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createCommentRef(dcInstance, inputVars));
}
;

const likePostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'LikePost', inputVars);
}
likePostRef.operationName = 'LikePost';
exports.likePostRef = likePostRef;

exports.likePost = function likePost(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(likePostRef(dcInstance, inputVars));
}
;

const unlikePostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'UnlikePost', inputVars);
}
unlikePostRef.operationName = 'UnlikePost';
exports.unlikePostRef = unlikePostRef;

exports.unlikePost = function unlikePost(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(unlikePostRef(dcInstance, inputVars));
}
;

const deletePostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'DeletePost', inputVars);
}
deletePostRef.operationName = 'DeletePost';
exports.deletePostRef = deletePostRef;

exports.deletePost = function deletePost(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(deletePostRef(dcInstance, inputVars));
}
;

const deleteCommentRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'DeleteComment', inputVars);
}
deleteCommentRef.operationName = 'DeleteComment';
exports.deleteCommentRef = deleteCommentRef;

exports.deleteComment = function deleteComment(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(deleteCommentRef(dcInstance, inputVars));
}
;

const spendEvolutionShardsRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'SpendEvolutionShards', inputVars);
}
spendEvolutionShardsRef.operationName = 'SpendEvolutionShards';
exports.spendEvolutionShardsRef = spendEvolutionShardsRef;

exports.spendEvolutionShards = function spendEvolutionShards(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(spendEvolutionShardsRef(dcInstance, inputVars));
}
;

const claimCreatorCardOwnershipRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'ClaimCreatorCardOwnership', inputVars);
}
claimCreatorCardOwnershipRef.operationName = 'ClaimCreatorCardOwnership';
exports.claimCreatorCardOwnershipRef = claimCreatorCardOwnershipRef;

exports.claimCreatorCardOwnership = function claimCreatorCardOwnership(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(claimCreatorCardOwnershipRef(dcInstance, inputVars));
}
;

const createCritiqueRequestWithEscrowRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateCritiqueRequestWithEscrow', inputVars);
}
createCritiqueRequestWithEscrowRef.operationName = 'CreateCritiqueRequestWithEscrow';
exports.createCritiqueRequestWithEscrowRef = createCritiqueRequestWithEscrowRef;

exports.createCritiqueRequestWithEscrow = function createCritiqueRequestWithEscrow(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createCritiqueRequestWithEscrowRef(dcInstance, inputVars));
}
;

const createCardMarketListingRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateCardMarketListing', inputVars);
}
createCardMarketListingRef.operationName = 'CreateCardMarketListing';
exports.createCardMarketListingRef = createCardMarketListingRef;

exports.createCardMarketListing = function createCardMarketListing(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createCardMarketListingRef(dcInstance, inputVars));
}
;

const deactivateCardMarketListingRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'DeactivateCardMarketListing', inputVars);
}
deactivateCardMarketListingRef.operationName = 'DeactivateCardMarketListing';
exports.deactivateCardMarketListingRef = deactivateCardMarketListingRef;

exports.deactivateCardMarketListing = function deactivateCardMarketListing(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(deactivateCardMarketListingRef(dcInstance, inputVars));
}
;

const listRecentPostsRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListRecentPosts');
}
listRecentPostsRef.operationName = 'ListRecentPosts';
exports.listRecentPostsRef = listRecentPostsRef;

exports.listRecentPosts = function listRecentPosts(dcOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrOptions, options, undefined,false, false);
  return executeQuery(listRecentPostsRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const getPostWithThreadRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'GetPostWithThread', inputVars);
}
getPostWithThreadRef.operationName = 'GetPostWithThread';
exports.getPostWithThreadRef = getPostWithThreadRef;

exports.getPostWithThread = function getPostWithThread(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, true);
  return executeQuery(getPostWithThreadRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const getUserByFirebaseUidRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'GetUserByFirebaseUid');
}
getUserByFirebaseUidRef.operationName = 'GetUserByFirebaseUid';
exports.getUserByFirebaseUidRef = getUserByFirebaseUidRef;

exports.getUserByFirebaseUid = function getUserByFirebaseUid(dcOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrOptions, options, undefined,false, false);
  return executeQuery(getUserByFirebaseUidRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const getMyPrivateProfileRef = (dc) => {
  const { dc: dcInstance} = validateArgs(connectorConfig, dc, undefined);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'GetMyPrivateProfile');
}
getMyPrivateProfileRef.operationName = 'GetMyPrivateProfile';
exports.getMyPrivateProfileRef = getMyPrivateProfileRef;

exports.getMyPrivateProfile = function getMyPrivateProfile(dcOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrOptions, options, undefined,false, false);
  return executeQuery(getMyPrivateProfileRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const getUserProfileRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'GetUserProfile', inputVars);
}
getUserProfileRef.operationName = 'GetUserProfile';
exports.getUserProfileRef = getUserProfileRef;

exports.getUserProfile = function getUserProfile(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, true);
  return executeQuery(getUserProfileRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const listCommentsForPostRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListCommentsForPost', inputVars);
}
listCommentsForPostRef.operationName = 'ListCommentsForPost';
exports.listCommentsForPostRef = listCommentsForPostRef;

exports.listCommentsForPost = function listCommentsForPost(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, true);
  return executeQuery(listCommentsForPostRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const listShardLedgerForUserRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListShardLedgerForUser', inputVars);
}
listShardLedgerForUserRef.operationName = 'ListShardLedgerForUser';
exports.listShardLedgerForUserRef = listShardLedgerForUserRef;

exports.listShardLedgerForUser = function listShardLedgerForUser(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, false);
  return executeQuery(listShardLedgerForUserRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const listCreatorCardsRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListCreatorCards', inputVars);
}
listCreatorCardsRef.operationName = 'ListCreatorCards';
exports.listCreatorCardsRef = listCreatorCardsRef;

exports.listCreatorCards = function listCreatorCards(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, false);
  return executeQuery(listCreatorCardsRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;

const listActiveCardMarketListingsRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars);
  dcInstance._useGeneratedSdk();
  return queryRef(dcInstance, 'ListActiveCardMarketListings', inputVars);
}
listActiveCardMarketListingsRef.operationName = 'ListActiveCardMarketListings';
exports.listActiveCardMarketListingsRef = listActiveCardMarketListingsRef;

exports.listActiveCardMarketListings = function listActiveCardMarketListings(dcOrVars, varsOrOptions, options) {
  
  const { dc: dcInstance, vars: inputVars, options: inputOpts } = validateArgsWithOptions(connectorConfig, dcOrVars, varsOrOptions, options, true, false);
  return executeQuery(listActiveCardMarketListingsRef(dcInstance, inputVars), inputOpts && inputOpts.fetchPolicy);
}
;
