import { ConnectorConfig, DataConnect, MutationRef, MutationPromise } from 'firebase/data-connect';

export const connectorConfig: ConnectorConfig;

export type TimestampString = string;
export type UUIDString = string;
export type Int64String = string;
export type DateString = string;




export interface AppendShardLedgerData {
  shardLedger_insert: ShardLedger_Key;
  user_update?: User_Key | null;
}

export interface AppendShardLedgerVariables {
  targetFirebaseUid: string;
  deltaShards: number;
  reason: string;
  referenceId?: string | null;
}

export interface CardMarketListing_Key {
  id: UUIDString;
  __typename?: 'CardMarketListing_Key';
}

export interface CoachCritiqueRequest_Key {
  id: UUIDString;
  __typename?: 'CoachCritiqueRequest_Key';
}

export interface Comment_Key {
  id: UUIDString;
  __typename?: 'Comment_Key';
}

export interface CreateCreatorCardCatalogItemData {
  creatorCard_insert: CreatorCard_Key;
}

export interface CreateCreatorCardCatalogItemVariables {
  catalogCardId: string;
  displayName: string;
  rarityTier?: string | null;
}

export interface CreatorCard_Key {
  id: UUIDString;
  __typename?: 'CreatorCard_Key';
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

export interface ShardLedger_Key {
  id: UUIDString;
  __typename?: 'ShardLedger_Key';
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

interface AppendShardLedgerRef {
  /* Allow users to create refs without passing in DataConnect */
  (vars: AppendShardLedgerVariables): MutationRef<AppendShardLedgerData, AppendShardLedgerVariables>;
  /* Allow users to pass in custom DataConnect instances */
  (dc: DataConnect, vars: AppendShardLedgerVariables): MutationRef<AppendShardLedgerData, AppendShardLedgerVariables>;
  operationName: string;
}
export const appendShardLedgerRef: AppendShardLedgerRef;

export function appendShardLedger(vars: AppendShardLedgerVariables): MutationPromise<AppendShardLedgerData, AppendShardLedgerVariables>;
export function appendShardLedger(dc: DataConnect, vars: AppendShardLedgerVariables): MutationPromise<AppendShardLedgerData, AppendShardLedgerVariables>;

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

