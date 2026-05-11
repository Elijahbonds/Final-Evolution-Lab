# Generated TypeScript README
This README will guide you through the process of using the generated JavaScript SDK package for the connector `social`. It will also provide examples on how to use your generated SDK to call your Data Connect queries and mutations.

***NOTE:** This README is generated alongside the generated SDK. If you make changes to this file, they will be overwritten when the SDK is regenerated.*

# Table of Contents
- [**Overview**](#generated-javascript-readme)
- [**Accessing the connector**](#accessing-the-connector)
  - [*Connecting to the local Emulator*](#connecting-to-the-local-emulator)
- [**Queries**](#queries)
  - [*ListRecentPosts*](#listrecentposts)
  - [*GetPostWithThread*](#getpostwiththread)
  - [*GetUserByFirebaseUid*](#getuserbyfirebaseuid)
  - [*GetMyPrivateProfile*](#getmyprivateprofile)
  - [*GetUserProfile*](#getuserprofile)
  - [*ListCommentsForPost*](#listcommentsforpost)
  - [*ListShardLedgerForUser*](#listshardledgerforuser)
  - [*ListCreatorCards*](#listcreatorcards)
  - [*ListActiveCardMarketListings*](#listactivecardmarketlistings)
- [**Mutations**](#mutations)
  - [*RegisterSignedInUser*](#registersignedinuser)
  - [*UpdateMyTrainingProfile*](#updatemytrainingprofile)
  - [*CreatePost*](#createpost)
  - [*CreateComment*](#createcomment)
  - [*LikePost*](#likepost)
  - [*UnlikePost*](#unlikepost)
  - [*DeletePost*](#deletepost)
  - [*DeleteComment*](#deletecomment)
  - [*SpendEvolutionShards*](#spendevolutionshards)
  - [*ClaimCreatorCardOwnership*](#claimcreatorcardownership)
  - [*CreateCritiqueRequestWithEscrow*](#createcritiquerequestwithescrow)
  - [*CreateCardMarketListing*](#createcardmarketlisting)
  - [*DeactivateCardMarketListing*](#deactivatecardmarketlisting)

# Accessing the connector
A connector is a collection of Queries and Mutations. One SDK is generated for each connector - this SDK is generated for the connector `social`. You can find more information about connectors in the [Data Connect documentation](https://firebase.google.com/docs/data-connect#how-does).

You can use this generated SDK by importing from the package `@dataconnect/generated` as shown below. Both CommonJS and ESM imports are supported.

You can also follow the instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#set-client).

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/generated';

const dataConnect = getDataConnect(connectorConfig);
```

## Connecting to the local Emulator
By default, the connector will connect to the production service.

To connect to the emulator, you can use the following code.
You can also follow the emulator instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#instrument-clients).

```typescript
import { connectDataConnectEmulator, getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/generated';

const dataConnect = getDataConnect(connectorConfig);
connectDataConnectEmulator(dataConnect, 'localhost', 9399);
```

After it's initialized, you can call your Data Connect [queries](#queries) and [mutations](#mutations) from your generated SDK.

# Queries

There are two ways to execute a Data Connect Query using the generated Web SDK:
- Using a Query Reference function, which returns a `QueryRef`
  - The `QueryRef` can be used as an argument to `executeQuery()`, which will execute the Query and return a `QueryPromise`
- Using an action shortcut function, which returns a `QueryPromise`
  - Calling the action shortcut function will execute the Query and return a `QueryPromise`

The following is true for both the action shortcut function and the `QueryRef` function:
- The `QueryPromise` returned will resolve to the result of the Query once it has finished executing
- If the Query accepts arguments, both the action shortcut function and the `QueryRef` function accept a single argument: an object that contains all the required variables (and the optional variables) for the Query
- Both functions can be called with or without passing in a `DataConnect` instance as an argument. If no `DataConnect` argument is passed in, then the generated SDK will call `getDataConnect(connectorConfig)` behind the scenes for you.

Below are examples of how to use the `social` connector's generated functions to execute each query. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-queries).

## ListRecentPosts
You can execute the `ListRecentPosts` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listRecentPosts(options?: ExecuteQueryOptions): QueryPromise<ListRecentPostsData, undefined>;

interface ListRecentPostsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<ListRecentPostsData, undefined>;
}
export const listRecentPostsRef: ListRecentPostsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listRecentPosts(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<ListRecentPostsData, undefined>;

interface ListRecentPostsRef {
  ...
  (dc: DataConnect): QueryRef<ListRecentPostsData, undefined>;
}
export const listRecentPostsRef: ListRecentPostsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listRecentPostsRef:
```typescript
const name = listRecentPostsRef.operationName;
console.log(name);
```

### Variables
The `ListRecentPosts` query has no variables.
### Return Type
Recall that executing the `ListRecentPosts` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListRecentPostsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
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
```
### Using `ListRecentPosts`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listRecentPosts } from '@dataconnect/generated';


// Call the `listRecentPosts()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listRecentPosts();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listRecentPosts(dataConnect);

console.log(data.posts);

// Or, you can use the `Promise` API.
listRecentPosts().then((response) => {
  const data = response.data;
  console.log(data.posts);
});
```

### Using `ListRecentPosts`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listRecentPostsRef } from '@dataconnect/generated';


// Call the `listRecentPostsRef()` function to get a reference to the query.
const ref = listRecentPostsRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listRecentPostsRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.posts);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.posts);
});
```

## GetPostWithThread
You can execute the `GetPostWithThread` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
getPostWithThread(vars: GetPostWithThreadVariables, options?: ExecuteQueryOptions): QueryPromise<GetPostWithThreadData, GetPostWithThreadVariables>;

interface GetPostWithThreadRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetPostWithThreadVariables): QueryRef<GetPostWithThreadData, GetPostWithThreadVariables>;
}
export const getPostWithThreadRef: GetPostWithThreadRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
getPostWithThread(dc: DataConnect, vars: GetPostWithThreadVariables, options?: ExecuteQueryOptions): QueryPromise<GetPostWithThreadData, GetPostWithThreadVariables>;

interface GetPostWithThreadRef {
  ...
  (dc: DataConnect, vars: GetPostWithThreadVariables): QueryRef<GetPostWithThreadData, GetPostWithThreadVariables>;
}
export const getPostWithThreadRef: GetPostWithThreadRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the getPostWithThreadRef:
```typescript
const name = getPostWithThreadRef.operationName;
console.log(name);
```

### Variables
The `GetPostWithThread` query requires an argument of type `GetPostWithThreadVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface GetPostWithThreadVariables {
  postKey: Post_Key;
}
```
### Return Type
Recall that executing the `GetPostWithThread` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `GetPostWithThreadData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
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
```
### Using `GetPostWithThread`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, getPostWithThread, GetPostWithThreadVariables } from '@dataconnect/generated';

// The `GetPostWithThread` query requires an argument of type `GetPostWithThreadVariables`:
const getPostWithThreadVars: GetPostWithThreadVariables = {
  postKey: ..., 
};

// Call the `getPostWithThread()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await getPostWithThread(getPostWithThreadVars);
// Variables can be defined inline as well.
const { data } = await getPostWithThread({ postKey: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await getPostWithThread(dataConnect, getPostWithThreadVars);

console.log(data.post);

// Or, you can use the `Promise` API.
getPostWithThread(getPostWithThreadVars).then((response) => {
  const data = response.data;
  console.log(data.post);
});
```

### Using `GetPostWithThread`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, getPostWithThreadRef, GetPostWithThreadVariables } from '@dataconnect/generated';

// The `GetPostWithThread` query requires an argument of type `GetPostWithThreadVariables`:
const getPostWithThreadVars: GetPostWithThreadVariables = {
  postKey: ..., 
};

// Call the `getPostWithThreadRef()` function to get a reference to the query.
const ref = getPostWithThreadRef(getPostWithThreadVars);
// Variables can be defined inline as well.
const ref = getPostWithThreadRef({ postKey: ..., });

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = getPostWithThreadRef(dataConnect, getPostWithThreadVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.post);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.post);
});
```

## GetUserByFirebaseUid
You can execute the `GetUserByFirebaseUid` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
getUserByFirebaseUid(options?: ExecuteQueryOptions): QueryPromise<GetUserByFirebaseUidData, undefined>;

interface GetUserByFirebaseUidRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<GetUserByFirebaseUidData, undefined>;
}
export const getUserByFirebaseUidRef: GetUserByFirebaseUidRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
getUserByFirebaseUid(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<GetUserByFirebaseUidData, undefined>;

interface GetUserByFirebaseUidRef {
  ...
  (dc: DataConnect): QueryRef<GetUserByFirebaseUidData, undefined>;
}
export const getUserByFirebaseUidRef: GetUserByFirebaseUidRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the getUserByFirebaseUidRef:
```typescript
const name = getUserByFirebaseUidRef.operationName;
console.log(name);
```

### Variables
The `GetUserByFirebaseUid` query has no variables.
### Return Type
Recall that executing the `GetUserByFirebaseUid` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `GetUserByFirebaseUidData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface GetUserByFirebaseUidData {
  users: ({
    id: UUIDString;
    username: string;
    profilePictureUrl?: string | null;
    avatarUrl?: string | null;
    topPRQScore?: number | null;
    evolutionShards: number;
    firebaseUid?: string | null;
  } & User_Key)[];
}
```
### Using `GetUserByFirebaseUid`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, getUserByFirebaseUid } from '@dataconnect/generated';


// Call the `getUserByFirebaseUid()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await getUserByFirebaseUid();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await getUserByFirebaseUid(dataConnect);

console.log(data.users);

// Or, you can use the `Promise` API.
getUserByFirebaseUid().then((response) => {
  const data = response.data;
  console.log(data.users);
});
```

### Using `GetUserByFirebaseUid`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, getUserByFirebaseUidRef } from '@dataconnect/generated';


// Call the `getUserByFirebaseUidRef()` function to get a reference to the query.
const ref = getUserByFirebaseUidRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = getUserByFirebaseUidRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.users);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.users);
});
```

## GetMyPrivateProfile
You can execute the `GetMyPrivateProfile` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
getMyPrivateProfile(options?: ExecuteQueryOptions): QueryPromise<GetMyPrivateProfileData, undefined>;

interface GetMyPrivateProfileRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (): QueryRef<GetMyPrivateProfileData, undefined>;
}
export const getMyPrivateProfileRef: GetMyPrivateProfileRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
getMyPrivateProfile(dc: DataConnect, options?: ExecuteQueryOptions): QueryPromise<GetMyPrivateProfileData, undefined>;

interface GetMyPrivateProfileRef {
  ...
  (dc: DataConnect): QueryRef<GetMyPrivateProfileData, undefined>;
}
export const getMyPrivateProfileRef: GetMyPrivateProfileRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the getMyPrivateProfileRef:
```typescript
const name = getMyPrivateProfileRef.operationName;
console.log(name);
```

### Variables
The `GetMyPrivateProfile` query has no variables.
### Return Type
Recall that executing the `GetMyPrivateProfile` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `GetMyPrivateProfileData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface GetMyPrivateProfileData {
  users: ({
    id: UUIDString;
    username: string;
    email: string;
    profilePictureUrl?: string | null;
    avatarUrl?: string | null;
    topPRQScore?: number | null;
    evolutionShards: number;
    firebaseUid?: string | null;
  } & User_Key)[];
}
```
### Using `GetMyPrivateProfile`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, getMyPrivateProfile } from '@dataconnect/generated';


// Call the `getMyPrivateProfile()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await getMyPrivateProfile();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await getMyPrivateProfile(dataConnect);

console.log(data.users);

// Or, you can use the `Promise` API.
getMyPrivateProfile().then((response) => {
  const data = response.data;
  console.log(data.users);
});
```

### Using `GetMyPrivateProfile`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, getMyPrivateProfileRef } from '@dataconnect/generated';


// Call the `getMyPrivateProfileRef()` function to get a reference to the query.
const ref = getMyPrivateProfileRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = getMyPrivateProfileRef(dataConnect);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.users);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.users);
});
```

## GetUserProfile
You can execute the `GetUserProfile` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
getUserProfile(vars: GetUserProfileVariables, options?: ExecuteQueryOptions): QueryPromise<GetUserProfileData, GetUserProfileVariables>;

interface GetUserProfileRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetUserProfileVariables): QueryRef<GetUserProfileData, GetUserProfileVariables>;
}
export const getUserProfileRef: GetUserProfileRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
getUserProfile(dc: DataConnect, vars: GetUserProfileVariables, options?: ExecuteQueryOptions): QueryPromise<GetUserProfileData, GetUserProfileVariables>;

interface GetUserProfileRef {
  ...
  (dc: DataConnect, vars: GetUserProfileVariables): QueryRef<GetUserProfileData, GetUserProfileVariables>;
}
export const getUserProfileRef: GetUserProfileRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the getUserProfileRef:
```typescript
const name = getUserProfileRef.operationName;
console.log(name);
```

### Variables
The `GetUserProfile` query requires an argument of type `GetUserProfileVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface GetUserProfileVariables {
  userId: UUIDString;
}
```
### Return Type
Recall that executing the `GetUserProfile` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `GetUserProfileData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface GetUserProfileData {
  user?: {
    id: UUIDString;
    username: string;
    profilePictureUrl?: string | null;
    avatarUrl?: string | null;
    topPRQScore?: number | null;
    evolutionShards: number;
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
```
### Using `GetUserProfile`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, getUserProfile, GetUserProfileVariables } from '@dataconnect/generated';

// The `GetUserProfile` query requires an argument of type `GetUserProfileVariables`:
const getUserProfileVars: GetUserProfileVariables = {
  userId: ..., 
};

// Call the `getUserProfile()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await getUserProfile(getUserProfileVars);
// Variables can be defined inline as well.
const { data } = await getUserProfile({ userId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await getUserProfile(dataConnect, getUserProfileVars);

console.log(data.user);
console.log(data.posts);

// Or, you can use the `Promise` API.
getUserProfile(getUserProfileVars).then((response) => {
  const data = response.data;
  console.log(data.user);
  console.log(data.posts);
});
```

### Using `GetUserProfile`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, getUserProfileRef, GetUserProfileVariables } from '@dataconnect/generated';

// The `GetUserProfile` query requires an argument of type `GetUserProfileVariables`:
const getUserProfileVars: GetUserProfileVariables = {
  userId: ..., 
};

// Call the `getUserProfileRef()` function to get a reference to the query.
const ref = getUserProfileRef(getUserProfileVars);
// Variables can be defined inline as well.
const ref = getUserProfileRef({ userId: ..., });

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = getUserProfileRef(dataConnect, getUserProfileVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.user);
console.log(data.posts);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.user);
  console.log(data.posts);
});
```

## ListCommentsForPost
You can execute the `ListCommentsForPost` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listCommentsForPost(vars: ListCommentsForPostVariables, options?: ExecuteQueryOptions): QueryPromise<ListCommentsForPostData, ListCommentsForPostVariables>;

interface ListCommentsForPostRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: ListCommentsForPostVariables): QueryRef<ListCommentsForPostData, ListCommentsForPostVariables>;
}
export const listCommentsForPostRef: ListCommentsForPostRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listCommentsForPost(dc: DataConnect, vars: ListCommentsForPostVariables, options?: ExecuteQueryOptions): QueryPromise<ListCommentsForPostData, ListCommentsForPostVariables>;

interface ListCommentsForPostRef {
  ...
  (dc: DataConnect, vars: ListCommentsForPostVariables): QueryRef<ListCommentsForPostData, ListCommentsForPostVariables>;
}
export const listCommentsForPostRef: ListCommentsForPostRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listCommentsForPostRef:
```typescript
const name = listCommentsForPostRef.operationName;
console.log(name);
```

### Variables
The `ListCommentsForPost` query requires an argument of type `ListCommentsForPostVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface ListCommentsForPostVariables {
  postId: UUIDString;
}
```
### Return Type
Recall that executing the `ListCommentsForPost` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListCommentsForPostData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
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
```
### Using `ListCommentsForPost`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listCommentsForPost, ListCommentsForPostVariables } from '@dataconnect/generated';

// The `ListCommentsForPost` query requires an argument of type `ListCommentsForPostVariables`:
const listCommentsForPostVars: ListCommentsForPostVariables = {
  postId: ..., 
};

// Call the `listCommentsForPost()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listCommentsForPost(listCommentsForPostVars);
// Variables can be defined inline as well.
const { data } = await listCommentsForPost({ postId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listCommentsForPost(dataConnect, listCommentsForPostVars);

console.log(data.comments);

// Or, you can use the `Promise` API.
listCommentsForPost(listCommentsForPostVars).then((response) => {
  const data = response.data;
  console.log(data.comments);
});
```

### Using `ListCommentsForPost`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listCommentsForPostRef, ListCommentsForPostVariables } from '@dataconnect/generated';

// The `ListCommentsForPost` query requires an argument of type `ListCommentsForPostVariables`:
const listCommentsForPostVars: ListCommentsForPostVariables = {
  postId: ..., 
};

// Call the `listCommentsForPostRef()` function to get a reference to the query.
const ref = listCommentsForPostRef(listCommentsForPostVars);
// Variables can be defined inline as well.
const ref = listCommentsForPostRef({ postId: ..., });

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listCommentsForPostRef(dataConnect, listCommentsForPostVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.comments);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.comments);
});
```

## ListShardLedgerForUser
You can execute the `ListShardLedgerForUser` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listShardLedgerForUser(vars?: ListShardLedgerForUserVariables, options?: ExecuteQueryOptions): QueryPromise<ListShardLedgerForUserData, ListShardLedgerForUserVariables>;

interface ListShardLedgerForUserRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars?: ListShardLedgerForUserVariables): QueryRef<ListShardLedgerForUserData, ListShardLedgerForUserVariables>;
}
export const listShardLedgerForUserRef: ListShardLedgerForUserRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listShardLedgerForUser(dc: DataConnect, vars?: ListShardLedgerForUserVariables, options?: ExecuteQueryOptions): QueryPromise<ListShardLedgerForUserData, ListShardLedgerForUserVariables>;

interface ListShardLedgerForUserRef {
  ...
  (dc: DataConnect, vars?: ListShardLedgerForUserVariables): QueryRef<ListShardLedgerForUserData, ListShardLedgerForUserVariables>;
}
export const listShardLedgerForUserRef: ListShardLedgerForUserRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listShardLedgerForUserRef:
```typescript
const name = listShardLedgerForUserRef.operationName;
console.log(name);
```

### Variables
The `ListShardLedgerForUser` query has an optional argument of type `ListShardLedgerForUserVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface ListShardLedgerForUserVariables {
  limit?: number | null;
}
```
### Return Type
Recall that executing the `ListShardLedgerForUser` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListShardLedgerForUserData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListShardLedgerForUserData {
  shardLedgers: ({
    id: UUIDString;
    deltaShards: number;
    reason: string;
    referenceId?: string | null;
    createdAt: TimestampString;
  } & ShardLedger_Key)[];
}
```
### Using `ListShardLedgerForUser`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listShardLedgerForUser, ListShardLedgerForUserVariables } from '@dataconnect/generated';

// The `ListShardLedgerForUser` query has an optional argument of type `ListShardLedgerForUserVariables`:
const listShardLedgerForUserVars: ListShardLedgerForUserVariables = {
  limit: ..., // optional
};

// Call the `listShardLedgerForUser()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listShardLedgerForUser(listShardLedgerForUserVars);
// Variables can be defined inline as well.
const { data } = await listShardLedgerForUser({ limit: ..., });
// Since all variables are optional for this query, you can omit the `ListShardLedgerForUserVariables` argument.
const { data } = await listShardLedgerForUser();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listShardLedgerForUser(dataConnect, listShardLedgerForUserVars);

console.log(data.shardLedgers);

// Or, you can use the `Promise` API.
listShardLedgerForUser(listShardLedgerForUserVars).then((response) => {
  const data = response.data;
  console.log(data.shardLedgers);
});
```

### Using `ListShardLedgerForUser`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listShardLedgerForUserRef, ListShardLedgerForUserVariables } from '@dataconnect/generated';

// The `ListShardLedgerForUser` query has an optional argument of type `ListShardLedgerForUserVariables`:
const listShardLedgerForUserVars: ListShardLedgerForUserVariables = {
  limit: ..., // optional
};

// Call the `listShardLedgerForUserRef()` function to get a reference to the query.
const ref = listShardLedgerForUserRef(listShardLedgerForUserVars);
// Variables can be defined inline as well.
const ref = listShardLedgerForUserRef({ limit: ..., });
// Since all variables are optional for this query, you can omit the `ListShardLedgerForUserVariables` argument.
const ref = listShardLedgerForUserRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listShardLedgerForUserRef(dataConnect, listShardLedgerForUserVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.shardLedgers);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.shardLedgers);
});
```

## ListCreatorCards
You can execute the `ListCreatorCards` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listCreatorCards(vars?: ListCreatorCardsVariables, options?: ExecuteQueryOptions): QueryPromise<ListCreatorCardsData, ListCreatorCardsVariables>;

interface ListCreatorCardsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars?: ListCreatorCardsVariables): QueryRef<ListCreatorCardsData, ListCreatorCardsVariables>;
}
export const listCreatorCardsRef: ListCreatorCardsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listCreatorCards(dc: DataConnect, vars?: ListCreatorCardsVariables, options?: ExecuteQueryOptions): QueryPromise<ListCreatorCardsData, ListCreatorCardsVariables>;

interface ListCreatorCardsRef {
  ...
  (dc: DataConnect, vars?: ListCreatorCardsVariables): QueryRef<ListCreatorCardsData, ListCreatorCardsVariables>;
}
export const listCreatorCardsRef: ListCreatorCardsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listCreatorCardsRef:
```typescript
const name = listCreatorCardsRef.operationName;
console.log(name);
```

### Variables
The `ListCreatorCards` query has an optional argument of type `ListCreatorCardsVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface ListCreatorCardsVariables {
  limit?: number | null;
}
```
### Return Type
Recall that executing the `ListCreatorCards` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListCreatorCardsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ListCreatorCardsData {
  creatorCards: ({
    id: UUIDString;
    catalogCardId: string;
    displayName: string;
    rarityTier?: string | null;
    createdAt: TimestampString;
  } & CreatorCard_Key)[];
}
```
### Using `ListCreatorCards`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listCreatorCards, ListCreatorCardsVariables } from '@dataconnect/generated';

// The `ListCreatorCards` query has an optional argument of type `ListCreatorCardsVariables`:
const listCreatorCardsVars: ListCreatorCardsVariables = {
  limit: ..., // optional
};

// Call the `listCreatorCards()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listCreatorCards(listCreatorCardsVars);
// Variables can be defined inline as well.
const { data } = await listCreatorCards({ limit: ..., });
// Since all variables are optional for this query, you can omit the `ListCreatorCardsVariables` argument.
const { data } = await listCreatorCards();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listCreatorCards(dataConnect, listCreatorCardsVars);

console.log(data.creatorCards);

// Or, you can use the `Promise` API.
listCreatorCards(listCreatorCardsVars).then((response) => {
  const data = response.data;
  console.log(data.creatorCards);
});
```

### Using `ListCreatorCards`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listCreatorCardsRef, ListCreatorCardsVariables } from '@dataconnect/generated';

// The `ListCreatorCards` query has an optional argument of type `ListCreatorCardsVariables`:
const listCreatorCardsVars: ListCreatorCardsVariables = {
  limit: ..., // optional
};

// Call the `listCreatorCardsRef()` function to get a reference to the query.
const ref = listCreatorCardsRef(listCreatorCardsVars);
// Variables can be defined inline as well.
const ref = listCreatorCardsRef({ limit: ..., });
// Since all variables are optional for this query, you can omit the `ListCreatorCardsVariables` argument.
const ref = listCreatorCardsRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listCreatorCardsRef(dataConnect, listCreatorCardsVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.creatorCards);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.creatorCards);
});
```

## ListActiveCardMarketListings
You can execute the `ListActiveCardMarketListings` query using the following action shortcut function, or by calling `executeQuery()` after calling the following `QueryRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
listActiveCardMarketListings(vars?: ListActiveCardMarketListingsVariables, options?: ExecuteQueryOptions): QueryPromise<ListActiveCardMarketListingsData, ListActiveCardMarketListingsVariables>;

interface ListActiveCardMarketListingsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars?: ListActiveCardMarketListingsVariables): QueryRef<ListActiveCardMarketListingsData, ListActiveCardMarketListingsVariables>;
}
export const listActiveCardMarketListingsRef: ListActiveCardMarketListingsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
listActiveCardMarketListings(dc: DataConnect, vars?: ListActiveCardMarketListingsVariables, options?: ExecuteQueryOptions): QueryPromise<ListActiveCardMarketListingsData, ListActiveCardMarketListingsVariables>;

interface ListActiveCardMarketListingsRef {
  ...
  (dc: DataConnect, vars?: ListActiveCardMarketListingsVariables): QueryRef<ListActiveCardMarketListingsData, ListActiveCardMarketListingsVariables>;
}
export const listActiveCardMarketListingsRef: ListActiveCardMarketListingsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the listActiveCardMarketListingsRef:
```typescript
const name = listActiveCardMarketListingsRef.operationName;
console.log(name);
```

### Variables
The `ListActiveCardMarketListings` query has an optional argument of type `ListActiveCardMarketListingsVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface ListActiveCardMarketListingsVariables {
  limit?: number | null;
}
```
### Return Type
Recall that executing the `ListActiveCardMarketListings` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ListActiveCardMarketListingsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
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
```
### Using `ListActiveCardMarketListings`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, listActiveCardMarketListings, ListActiveCardMarketListingsVariables } from '@dataconnect/generated';

// The `ListActiveCardMarketListings` query has an optional argument of type `ListActiveCardMarketListingsVariables`:
const listActiveCardMarketListingsVars: ListActiveCardMarketListingsVariables = {
  limit: ..., // optional
};

// Call the `listActiveCardMarketListings()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await listActiveCardMarketListings(listActiveCardMarketListingsVars);
// Variables can be defined inline as well.
const { data } = await listActiveCardMarketListings({ limit: ..., });
// Since all variables are optional for this query, you can omit the `ListActiveCardMarketListingsVariables` argument.
const { data } = await listActiveCardMarketListings();

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await listActiveCardMarketListings(dataConnect, listActiveCardMarketListingsVars);

console.log(data.cardMarketListings);

// Or, you can use the `Promise` API.
listActiveCardMarketListings(listActiveCardMarketListingsVars).then((response) => {
  const data = response.data;
  console.log(data.cardMarketListings);
});
```

### Using `ListActiveCardMarketListings`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, listActiveCardMarketListingsRef, ListActiveCardMarketListingsVariables } from '@dataconnect/generated';

// The `ListActiveCardMarketListings` query has an optional argument of type `ListActiveCardMarketListingsVariables`:
const listActiveCardMarketListingsVars: ListActiveCardMarketListingsVariables = {
  limit: ..., // optional
};

// Call the `listActiveCardMarketListingsRef()` function to get a reference to the query.
const ref = listActiveCardMarketListingsRef(listActiveCardMarketListingsVars);
// Variables can be defined inline as well.
const ref = listActiveCardMarketListingsRef({ limit: ..., });
// Since all variables are optional for this query, you can omit the `ListActiveCardMarketListingsVariables` argument.
const ref = listActiveCardMarketListingsRef();

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = listActiveCardMarketListingsRef(dataConnect, listActiveCardMarketListingsVars);

// Call `executeQuery()` on the reference to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeQuery(ref);

console.log(data.cardMarketListings);

// Or, you can use the `Promise` API.
executeQuery(ref).then((response) => {
  const data = response.data;
  console.log(data.cardMarketListings);
});
```

# Mutations

There are two ways to execute a Data Connect Mutation using the generated Web SDK:
- Using a Mutation Reference function, which returns a `MutationRef`
  - The `MutationRef` can be used as an argument to `executeMutation()`, which will execute the Mutation and return a `MutationPromise`
- Using an action shortcut function, which returns a `MutationPromise`
  - Calling the action shortcut function will execute the Mutation and return a `MutationPromise`

The following is true for both the action shortcut function and the `MutationRef` function:
- The `MutationPromise` returned will resolve to the result of the Mutation once it has finished executing
- If the Mutation accepts arguments, both the action shortcut function and the `MutationRef` function accept a single argument: an object that contains all the required variables (and the optional variables) for the Mutation
- Both functions can be called with or without passing in a `DataConnect` instance as an argument. If no `DataConnect` argument is passed in, then the generated SDK will call `getDataConnect(connectorConfig)` behind the scenes for you.

Below are examples of how to use the `social` connector's generated functions to execute each mutation. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-mutations).

## RegisterSignedInUser
You can execute the `RegisterSignedInUser` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
registerSignedInUser(vars: RegisterSignedInUserVariables): MutationPromise<RegisterSignedInUserData, RegisterSignedInUserVariables>;

interface RegisterSignedInUserRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: RegisterSignedInUserVariables): MutationRef<RegisterSignedInUserData, RegisterSignedInUserVariables>;
}
export const registerSignedInUserRef: RegisterSignedInUserRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
registerSignedInUser(dc: DataConnect, vars: RegisterSignedInUserVariables): MutationPromise<RegisterSignedInUserData, RegisterSignedInUserVariables>;

interface RegisterSignedInUserRef {
  ...
  (dc: DataConnect, vars: RegisterSignedInUserVariables): MutationRef<RegisterSignedInUserData, RegisterSignedInUserVariables>;
}
export const registerSignedInUserRef: RegisterSignedInUserRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the registerSignedInUserRef:
```typescript
const name = registerSignedInUserRef.operationName;
console.log(name);
```

### Variables
The `RegisterSignedInUser` mutation requires an argument of type `RegisterSignedInUserVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface RegisterSignedInUserVariables {
  username: string;
  email: string;
  profilePictureUrl?: string | null;
  avatarUrl?: string | null;
}
```
### Return Type
Recall that executing the `RegisterSignedInUser` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `RegisterSignedInUserData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface RegisterSignedInUserData {
  user_insert: User_Key;
}
```
### Using `RegisterSignedInUser`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, registerSignedInUser, RegisterSignedInUserVariables } from '@dataconnect/generated';

// The `RegisterSignedInUser` mutation requires an argument of type `RegisterSignedInUserVariables`:
const registerSignedInUserVars: RegisterSignedInUserVariables = {
  username: ..., 
  email: ..., 
  profilePictureUrl: ..., // optional
  avatarUrl: ..., // optional
};

// Call the `registerSignedInUser()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await registerSignedInUser(registerSignedInUserVars);
// Variables can be defined inline as well.
const { data } = await registerSignedInUser({ username: ..., email: ..., profilePictureUrl: ..., avatarUrl: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await registerSignedInUser(dataConnect, registerSignedInUserVars);

console.log(data.user_insert);

// Or, you can use the `Promise` API.
registerSignedInUser(registerSignedInUserVars).then((response) => {
  const data = response.data;
  console.log(data.user_insert);
});
```

### Using `RegisterSignedInUser`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, registerSignedInUserRef, RegisterSignedInUserVariables } from '@dataconnect/generated';

// The `RegisterSignedInUser` mutation requires an argument of type `RegisterSignedInUserVariables`:
const registerSignedInUserVars: RegisterSignedInUserVariables = {
  username: ..., 
  email: ..., 
  profilePictureUrl: ..., // optional
  avatarUrl: ..., // optional
};

// Call the `registerSignedInUserRef()` function to get a reference to the mutation.
const ref = registerSignedInUserRef(registerSignedInUserVars);
// Variables can be defined inline as well.
const ref = registerSignedInUserRef({ username: ..., email: ..., profilePictureUrl: ..., avatarUrl: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = registerSignedInUserRef(dataConnect, registerSignedInUserVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.user_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.user_insert);
});
```

## UpdateMyTrainingProfile
You can execute the `UpdateMyTrainingProfile` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updateMyTrainingProfile(vars: UpdateMyTrainingProfileVariables): MutationPromise<UpdateMyTrainingProfileData, UpdateMyTrainingProfileVariables>;

interface UpdateMyTrainingProfileRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateMyTrainingProfileVariables): MutationRef<UpdateMyTrainingProfileData, UpdateMyTrainingProfileVariables>;
}
export const updateMyTrainingProfileRef: UpdateMyTrainingProfileRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updateMyTrainingProfile(dc: DataConnect, vars: UpdateMyTrainingProfileVariables): MutationPromise<UpdateMyTrainingProfileData, UpdateMyTrainingProfileVariables>;

interface UpdateMyTrainingProfileRef {
  ...
  (dc: DataConnect, vars: UpdateMyTrainingProfileVariables): MutationRef<UpdateMyTrainingProfileData, UpdateMyTrainingProfileVariables>;
}
export const updateMyTrainingProfileRef: UpdateMyTrainingProfileRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updateMyTrainingProfileRef:
```typescript
const name = updateMyTrainingProfileRef.operationName;
console.log(name);
```

### Variables
The `UpdateMyTrainingProfile` mutation requires an argument of type `UpdateMyTrainingProfileVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdateMyTrainingProfileVariables {
  topPRQScore: number;
  avatarUrl?: string | null;
}
```
### Return Type
Recall that executing the `UpdateMyTrainingProfile` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdateMyTrainingProfileData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdateMyTrainingProfileData {
  user_update?: User_Key | null;
}
```
### Using `UpdateMyTrainingProfile`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updateMyTrainingProfile, UpdateMyTrainingProfileVariables } from '@dataconnect/generated';

// The `UpdateMyTrainingProfile` mutation requires an argument of type `UpdateMyTrainingProfileVariables`:
const updateMyTrainingProfileVars: UpdateMyTrainingProfileVariables = {
  topPRQScore: ..., 
  avatarUrl: ..., // optional
};

// Call the `updateMyTrainingProfile()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updateMyTrainingProfile(updateMyTrainingProfileVars);
// Variables can be defined inline as well.
const { data } = await updateMyTrainingProfile({ topPRQScore: ..., avatarUrl: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updateMyTrainingProfile(dataConnect, updateMyTrainingProfileVars);

console.log(data.user_update);

// Or, you can use the `Promise` API.
updateMyTrainingProfile(updateMyTrainingProfileVars).then((response) => {
  const data = response.data;
  console.log(data.user_update);
});
```

### Using `UpdateMyTrainingProfile`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updateMyTrainingProfileRef, UpdateMyTrainingProfileVariables } from '@dataconnect/generated';

// The `UpdateMyTrainingProfile` mutation requires an argument of type `UpdateMyTrainingProfileVariables`:
const updateMyTrainingProfileVars: UpdateMyTrainingProfileVariables = {
  topPRQScore: ..., 
  avatarUrl: ..., // optional
};

// Call the `updateMyTrainingProfileRef()` function to get a reference to the mutation.
const ref = updateMyTrainingProfileRef(updateMyTrainingProfileVars);
// Variables can be defined inline as well.
const ref = updateMyTrainingProfileRef({ topPRQScore: ..., avatarUrl: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updateMyTrainingProfileRef(dataConnect, updateMyTrainingProfileVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.user_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.user_update);
});
```

## CreatePost
You can execute the `CreatePost` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createPost(vars: CreatePostVariables): MutationPromise<CreatePostData, CreatePostVariables>;

interface CreatePostRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreatePostVariables): MutationRef<CreatePostData, CreatePostVariables>;
}
export const createPostRef: CreatePostRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createPost(dc: DataConnect, vars: CreatePostVariables): MutationPromise<CreatePostData, CreatePostVariables>;

interface CreatePostRef {
  ...
  (dc: DataConnect, vars: CreatePostVariables): MutationRef<CreatePostData, CreatePostVariables>;
}
export const createPostRef: CreatePostRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createPostRef:
```typescript
const name = createPostRef.operationName;
console.log(name);
```

### Variables
The `CreatePost` mutation requires an argument of type `CreatePostVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface CreatePostVariables {
  content: string;
  gameModeId?: string | null;
  trainingScore?: number | null;
  clipUrl?: string | null;
  feedSource?: string | null;
}
```
### Return Type
Recall that executing the `CreatePost` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreatePostData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreatePostData {
  post_insert: Post_Key;
}
```
### Using `CreatePost`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createPost, CreatePostVariables } from '@dataconnect/generated';

// The `CreatePost` mutation requires an argument of type `CreatePostVariables`:
const createPostVars: CreatePostVariables = {
  content: ..., 
  gameModeId: ..., // optional
  trainingScore: ..., // optional
  clipUrl: ..., // optional
  feedSource: ..., // optional
};

// Call the `createPost()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createPost(createPostVars);
// Variables can be defined inline as well.
const { data } = await createPost({ content: ..., gameModeId: ..., trainingScore: ..., clipUrl: ..., feedSource: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createPost(dataConnect, createPostVars);

console.log(data.post_insert);

// Or, you can use the `Promise` API.
createPost(createPostVars).then((response) => {
  const data = response.data;
  console.log(data.post_insert);
});
```

### Using `CreatePost`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createPostRef, CreatePostVariables } from '@dataconnect/generated';

// The `CreatePost` mutation requires an argument of type `CreatePostVariables`:
const createPostVars: CreatePostVariables = {
  content: ..., 
  gameModeId: ..., // optional
  trainingScore: ..., // optional
  clipUrl: ..., // optional
  feedSource: ..., // optional
};

// Call the `createPostRef()` function to get a reference to the mutation.
const ref = createPostRef(createPostVars);
// Variables can be defined inline as well.
const ref = createPostRef({ content: ..., gameModeId: ..., trainingScore: ..., clipUrl: ..., feedSource: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createPostRef(dataConnect, createPostVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.post_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.post_insert);
});
```

## CreateComment
You can execute the `CreateComment` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createComment(vars: CreateCommentVariables): MutationPromise<CreateCommentData, CreateCommentVariables>;

interface CreateCommentRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateCommentVariables): MutationRef<CreateCommentData, CreateCommentVariables>;
}
export const createCommentRef: CreateCommentRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createComment(dc: DataConnect, vars: CreateCommentVariables): MutationPromise<CreateCommentData, CreateCommentVariables>;

interface CreateCommentRef {
  ...
  (dc: DataConnect, vars: CreateCommentVariables): MutationRef<CreateCommentData, CreateCommentVariables>;
}
export const createCommentRef: CreateCommentRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createCommentRef:
```typescript
const name = createCommentRef.operationName;
console.log(name);
```

### Variables
The `CreateComment` mutation requires an argument of type `CreateCommentVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface CreateCommentVariables {
  postId: UUIDString;
  content: string;
}
```
### Return Type
Recall that executing the `CreateComment` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateCommentData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateCommentData {
  comment_insert: Comment_Key;
}
```
### Using `CreateComment`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createComment, CreateCommentVariables } from '@dataconnect/generated';

// The `CreateComment` mutation requires an argument of type `CreateCommentVariables`:
const createCommentVars: CreateCommentVariables = {
  postId: ..., 
  content: ..., 
};

// Call the `createComment()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createComment(createCommentVars);
// Variables can be defined inline as well.
const { data } = await createComment({ postId: ..., content: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createComment(dataConnect, createCommentVars);

console.log(data.comment_insert);

// Or, you can use the `Promise` API.
createComment(createCommentVars).then((response) => {
  const data = response.data;
  console.log(data.comment_insert);
});
```

### Using `CreateComment`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createCommentRef, CreateCommentVariables } from '@dataconnect/generated';

// The `CreateComment` mutation requires an argument of type `CreateCommentVariables`:
const createCommentVars: CreateCommentVariables = {
  postId: ..., 
  content: ..., 
};

// Call the `createCommentRef()` function to get a reference to the mutation.
const ref = createCommentRef(createCommentVars);
// Variables can be defined inline as well.
const ref = createCommentRef({ postId: ..., content: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createCommentRef(dataConnect, createCommentVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.comment_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.comment_insert);
});
```

## LikePost
You can execute the `LikePost` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
likePost(vars: LikePostVariables): MutationPromise<LikePostData, LikePostVariables>;

interface LikePostRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: LikePostVariables): MutationRef<LikePostData, LikePostVariables>;
}
export const likePostRef: LikePostRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
likePost(dc: DataConnect, vars: LikePostVariables): MutationPromise<LikePostData, LikePostVariables>;

interface LikePostRef {
  ...
  (dc: DataConnect, vars: LikePostVariables): MutationRef<LikePostData, LikePostVariables>;
}
export const likePostRef: LikePostRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the likePostRef:
```typescript
const name = likePostRef.operationName;
console.log(name);
```

### Variables
The `LikePost` mutation requires an argument of type `LikePostVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface LikePostVariables {
  postId: UUIDString;
}
```
### Return Type
Recall that executing the `LikePost` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `LikePostData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface LikePostData {
  postLike_insert: PostLike_Key;
}
```
### Using `LikePost`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, likePost, LikePostVariables } from '@dataconnect/generated';

// The `LikePost` mutation requires an argument of type `LikePostVariables`:
const likePostVars: LikePostVariables = {
  postId: ..., 
};

// Call the `likePost()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await likePost(likePostVars);
// Variables can be defined inline as well.
const { data } = await likePost({ postId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await likePost(dataConnect, likePostVars);

console.log(data.postLike_insert);

// Or, you can use the `Promise` API.
likePost(likePostVars).then((response) => {
  const data = response.data;
  console.log(data.postLike_insert);
});
```

### Using `LikePost`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, likePostRef, LikePostVariables } from '@dataconnect/generated';

// The `LikePost` mutation requires an argument of type `LikePostVariables`:
const likePostVars: LikePostVariables = {
  postId: ..., 
};

// Call the `likePostRef()` function to get a reference to the mutation.
const ref = likePostRef(likePostVars);
// Variables can be defined inline as well.
const ref = likePostRef({ postId: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = likePostRef(dataConnect, likePostVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.postLike_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.postLike_insert);
});
```

## UnlikePost
You can execute the `UnlikePost` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
unlikePost(vars: UnlikePostVariables): MutationPromise<UnlikePostData, UnlikePostVariables>;

interface UnlikePostRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UnlikePostVariables): MutationRef<UnlikePostData, UnlikePostVariables>;
}
export const unlikePostRef: UnlikePostRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
unlikePost(dc: DataConnect, vars: UnlikePostVariables): MutationPromise<UnlikePostData, UnlikePostVariables>;

interface UnlikePostRef {
  ...
  (dc: DataConnect, vars: UnlikePostVariables): MutationRef<UnlikePostData, UnlikePostVariables>;
}
export const unlikePostRef: UnlikePostRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the unlikePostRef:
```typescript
const name = unlikePostRef.operationName;
console.log(name);
```

### Variables
The `UnlikePost` mutation requires an argument of type `UnlikePostVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UnlikePostVariables {
  postId: UUIDString;
}
```
### Return Type
Recall that executing the `UnlikePost` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UnlikePostData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UnlikePostData {
  postLike_delete?: PostLike_Key | null;
}
```
### Using `UnlikePost`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, unlikePost, UnlikePostVariables } from '@dataconnect/generated';

// The `UnlikePost` mutation requires an argument of type `UnlikePostVariables`:
const unlikePostVars: UnlikePostVariables = {
  postId: ..., 
};

// Call the `unlikePost()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await unlikePost(unlikePostVars);
// Variables can be defined inline as well.
const { data } = await unlikePost({ postId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await unlikePost(dataConnect, unlikePostVars);

console.log(data.postLike_delete);

// Or, you can use the `Promise` API.
unlikePost(unlikePostVars).then((response) => {
  const data = response.data;
  console.log(data.postLike_delete);
});
```

### Using `UnlikePost`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, unlikePostRef, UnlikePostVariables } from '@dataconnect/generated';

// The `UnlikePost` mutation requires an argument of type `UnlikePostVariables`:
const unlikePostVars: UnlikePostVariables = {
  postId: ..., 
};

// Call the `unlikePostRef()` function to get a reference to the mutation.
const ref = unlikePostRef(unlikePostVars);
// Variables can be defined inline as well.
const ref = unlikePostRef({ postId: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = unlikePostRef(dataConnect, unlikePostVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.postLike_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.postLike_delete);
});
```

## DeletePost
You can execute the `DeletePost` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deletePost(vars: DeletePostVariables): MutationPromise<DeletePostData, DeletePostVariables>;

interface DeletePostRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeletePostVariables): MutationRef<DeletePostData, DeletePostVariables>;
}
export const deletePostRef: DeletePostRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deletePost(dc: DataConnect, vars: DeletePostVariables): MutationPromise<DeletePostData, DeletePostVariables>;

interface DeletePostRef {
  ...
  (dc: DataConnect, vars: DeletePostVariables): MutationRef<DeletePostData, DeletePostVariables>;
}
export const deletePostRef: DeletePostRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deletePostRef:
```typescript
const name = deletePostRef.operationName;
console.log(name);
```

### Variables
The `DeletePost` mutation requires an argument of type `DeletePostVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface DeletePostVariables {
  postId: UUIDString;
}
```
### Return Type
Recall that executing the `DeletePost` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeletePostData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeletePostData {
  post_delete?: Post_Key | null;
}
```
### Using `DeletePost`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deletePost, DeletePostVariables } from '@dataconnect/generated';

// The `DeletePost` mutation requires an argument of type `DeletePostVariables`:
const deletePostVars: DeletePostVariables = {
  postId: ..., 
};

// Call the `deletePost()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deletePost(deletePostVars);
// Variables can be defined inline as well.
const { data } = await deletePost({ postId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deletePost(dataConnect, deletePostVars);

console.log(data.post_delete);

// Or, you can use the `Promise` API.
deletePost(deletePostVars).then((response) => {
  const data = response.data;
  console.log(data.post_delete);
});
```

### Using `DeletePost`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deletePostRef, DeletePostVariables } from '@dataconnect/generated';

// The `DeletePost` mutation requires an argument of type `DeletePostVariables`:
const deletePostVars: DeletePostVariables = {
  postId: ..., 
};

// Call the `deletePostRef()` function to get a reference to the mutation.
const ref = deletePostRef(deletePostVars);
// Variables can be defined inline as well.
const ref = deletePostRef({ postId: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deletePostRef(dataConnect, deletePostVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.post_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.post_delete);
});
```

## DeleteComment
You can execute the `DeleteComment` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deleteComment(vars: DeleteCommentVariables): MutationPromise<DeleteCommentData, DeleteCommentVariables>;

interface DeleteCommentRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeleteCommentVariables): MutationRef<DeleteCommentData, DeleteCommentVariables>;
}
export const deleteCommentRef: DeleteCommentRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deleteComment(dc: DataConnect, vars: DeleteCommentVariables): MutationPromise<DeleteCommentData, DeleteCommentVariables>;

interface DeleteCommentRef {
  ...
  (dc: DataConnect, vars: DeleteCommentVariables): MutationRef<DeleteCommentData, DeleteCommentVariables>;
}
export const deleteCommentRef: DeleteCommentRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deleteCommentRef:
```typescript
const name = deleteCommentRef.operationName;
console.log(name);
```

### Variables
The `DeleteComment` mutation requires an argument of type `DeleteCommentVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface DeleteCommentVariables {
  commentId: UUIDString;
}
```
### Return Type
Recall that executing the `DeleteComment` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeleteCommentData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeleteCommentData {
  comment_delete?: Comment_Key | null;
}
```
### Using `DeleteComment`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deleteComment, DeleteCommentVariables } from '@dataconnect/generated';

// The `DeleteComment` mutation requires an argument of type `DeleteCommentVariables`:
const deleteCommentVars: DeleteCommentVariables = {
  commentId: ..., 
};

// Call the `deleteComment()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deleteComment(deleteCommentVars);
// Variables can be defined inline as well.
const { data } = await deleteComment({ commentId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deleteComment(dataConnect, deleteCommentVars);

console.log(data.comment_delete);

// Or, you can use the `Promise` API.
deleteComment(deleteCommentVars).then((response) => {
  const data = response.data;
  console.log(data.comment_delete);
});
```

### Using `DeleteComment`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deleteCommentRef, DeleteCommentVariables } from '@dataconnect/generated';

// The `DeleteComment` mutation requires an argument of type `DeleteCommentVariables`:
const deleteCommentVars: DeleteCommentVariables = {
  commentId: ..., 
};

// Call the `deleteCommentRef()` function to get a reference to the mutation.
const ref = deleteCommentRef(deleteCommentVars);
// Variables can be defined inline as well.
const ref = deleteCommentRef({ commentId: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deleteCommentRef(dataConnect, deleteCommentVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.comment_delete);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.comment_delete);
});
```

## SpendEvolutionShards
You can execute the `SpendEvolutionShards` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
spendEvolutionShards(vars: SpendEvolutionShardsVariables): MutationPromise<SpendEvolutionShardsData, SpendEvolutionShardsVariables>;

interface SpendEvolutionShardsRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: SpendEvolutionShardsVariables): MutationRef<SpendEvolutionShardsData, SpendEvolutionShardsVariables>;
}
export const spendEvolutionShardsRef: SpendEvolutionShardsRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
spendEvolutionShards(dc: DataConnect, vars: SpendEvolutionShardsVariables): MutationPromise<SpendEvolutionShardsData, SpendEvolutionShardsVariables>;

interface SpendEvolutionShardsRef {
  ...
  (dc: DataConnect, vars: SpendEvolutionShardsVariables): MutationRef<SpendEvolutionShardsData, SpendEvolutionShardsVariables>;
}
export const spendEvolutionShardsRef: SpendEvolutionShardsRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the spendEvolutionShardsRef:
```typescript
const name = spendEvolutionShardsRef.operationName;
console.log(name);
```

### Variables
The `SpendEvolutionShards` mutation requires an argument of type `SpendEvolutionShardsVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface SpendEvolutionShardsVariables {
  deltaShards: number;
  reason: string;
  referenceId?: string | null;
}
```
### Return Type
Recall that executing the `SpendEvolutionShards` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `SpendEvolutionShardsData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface SpendEvolutionShardsData {
  shardLedger_insert: ShardLedger_Key;
  user_update?: User_Key | null;
}
```
### Using `SpendEvolutionShards`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, spendEvolutionShards, SpendEvolutionShardsVariables } from '@dataconnect/generated';

// The `SpendEvolutionShards` mutation requires an argument of type `SpendEvolutionShardsVariables`:
const spendEvolutionShardsVars: SpendEvolutionShardsVariables = {
  deltaShards: ..., 
  reason: ..., 
  referenceId: ..., // optional
};

// Call the `spendEvolutionShards()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await spendEvolutionShards(spendEvolutionShardsVars);
// Variables can be defined inline as well.
const { data } = await spendEvolutionShards({ deltaShards: ..., reason: ..., referenceId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await spendEvolutionShards(dataConnect, spendEvolutionShardsVars);

console.log(data.shardLedger_insert);
console.log(data.user_update);

// Or, you can use the `Promise` API.
spendEvolutionShards(spendEvolutionShardsVars).then((response) => {
  const data = response.data;
  console.log(data.shardLedger_insert);
  console.log(data.user_update);
});
```

### Using `SpendEvolutionShards`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, spendEvolutionShardsRef, SpendEvolutionShardsVariables } from '@dataconnect/generated';

// The `SpendEvolutionShards` mutation requires an argument of type `SpendEvolutionShardsVariables`:
const spendEvolutionShardsVars: SpendEvolutionShardsVariables = {
  deltaShards: ..., 
  reason: ..., 
  referenceId: ..., // optional
};

// Call the `spendEvolutionShardsRef()` function to get a reference to the mutation.
const ref = spendEvolutionShardsRef(spendEvolutionShardsVars);
// Variables can be defined inline as well.
const ref = spendEvolutionShardsRef({ deltaShards: ..., reason: ..., referenceId: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = spendEvolutionShardsRef(dataConnect, spendEvolutionShardsVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.shardLedger_insert);
console.log(data.user_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.shardLedger_insert);
  console.log(data.user_update);
});
```

## ClaimCreatorCardOwnership
You can execute the `ClaimCreatorCardOwnership` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
claimCreatorCardOwnership(vars: ClaimCreatorCardOwnershipVariables): MutationPromise<ClaimCreatorCardOwnershipData, ClaimCreatorCardOwnershipVariables>;

interface ClaimCreatorCardOwnershipRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: ClaimCreatorCardOwnershipVariables): MutationRef<ClaimCreatorCardOwnershipData, ClaimCreatorCardOwnershipVariables>;
}
export const claimCreatorCardOwnershipRef: ClaimCreatorCardOwnershipRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
claimCreatorCardOwnership(dc: DataConnect, vars: ClaimCreatorCardOwnershipVariables): MutationPromise<ClaimCreatorCardOwnershipData, ClaimCreatorCardOwnershipVariables>;

interface ClaimCreatorCardOwnershipRef {
  ...
  (dc: DataConnect, vars: ClaimCreatorCardOwnershipVariables): MutationRef<ClaimCreatorCardOwnershipData, ClaimCreatorCardOwnershipVariables>;
}
export const claimCreatorCardOwnershipRef: ClaimCreatorCardOwnershipRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the claimCreatorCardOwnershipRef:
```typescript
const name = claimCreatorCardOwnershipRef.operationName;
console.log(name);
```

### Variables
The `ClaimCreatorCardOwnership` mutation requires an argument of type `ClaimCreatorCardOwnershipVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface ClaimCreatorCardOwnershipVariables {
  catalogCardId: string;
}
```
### Return Type
Recall that executing the `ClaimCreatorCardOwnership` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `ClaimCreatorCardOwnershipData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface ClaimCreatorCardOwnershipData {
  userOwnedCreatorCard_insert: UserOwnedCreatorCard_Key;
}
```
### Using `ClaimCreatorCardOwnership`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, claimCreatorCardOwnership, ClaimCreatorCardOwnershipVariables } from '@dataconnect/generated';

// The `ClaimCreatorCardOwnership` mutation requires an argument of type `ClaimCreatorCardOwnershipVariables`:
const claimCreatorCardOwnershipVars: ClaimCreatorCardOwnershipVariables = {
  catalogCardId: ..., 
};

// Call the `claimCreatorCardOwnership()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await claimCreatorCardOwnership(claimCreatorCardOwnershipVars);
// Variables can be defined inline as well.
const { data } = await claimCreatorCardOwnership({ catalogCardId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await claimCreatorCardOwnership(dataConnect, claimCreatorCardOwnershipVars);

console.log(data.userOwnedCreatorCard_insert);

// Or, you can use the `Promise` API.
claimCreatorCardOwnership(claimCreatorCardOwnershipVars).then((response) => {
  const data = response.data;
  console.log(data.userOwnedCreatorCard_insert);
});
```

### Using `ClaimCreatorCardOwnership`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, claimCreatorCardOwnershipRef, ClaimCreatorCardOwnershipVariables } from '@dataconnect/generated';

// The `ClaimCreatorCardOwnership` mutation requires an argument of type `ClaimCreatorCardOwnershipVariables`:
const claimCreatorCardOwnershipVars: ClaimCreatorCardOwnershipVariables = {
  catalogCardId: ..., 
};

// Call the `claimCreatorCardOwnershipRef()` function to get a reference to the mutation.
const ref = claimCreatorCardOwnershipRef(claimCreatorCardOwnershipVars);
// Variables can be defined inline as well.
const ref = claimCreatorCardOwnershipRef({ catalogCardId: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = claimCreatorCardOwnershipRef(dataConnect, claimCreatorCardOwnershipVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.userOwnedCreatorCard_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.userOwnedCreatorCard_insert);
});
```

## CreateCritiqueRequestWithEscrow
You can execute the `CreateCritiqueRequestWithEscrow` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createCritiqueRequestWithEscrow(vars: CreateCritiqueRequestWithEscrowVariables): MutationPromise<CreateCritiqueRequestWithEscrowData, CreateCritiqueRequestWithEscrowVariables>;

interface CreateCritiqueRequestWithEscrowRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateCritiqueRequestWithEscrowVariables): MutationRef<CreateCritiqueRequestWithEscrowData, CreateCritiqueRequestWithEscrowVariables>;
}
export const createCritiqueRequestWithEscrowRef: CreateCritiqueRequestWithEscrowRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createCritiqueRequestWithEscrow(dc: DataConnect, vars: CreateCritiqueRequestWithEscrowVariables): MutationPromise<CreateCritiqueRequestWithEscrowData, CreateCritiqueRequestWithEscrowVariables>;

interface CreateCritiqueRequestWithEscrowRef {
  ...
  (dc: DataConnect, vars: CreateCritiqueRequestWithEscrowVariables): MutationRef<CreateCritiqueRequestWithEscrowData, CreateCritiqueRequestWithEscrowVariables>;
}
export const createCritiqueRequestWithEscrowRef: CreateCritiqueRequestWithEscrowRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createCritiqueRequestWithEscrowRef:
```typescript
const name = createCritiqueRequestWithEscrowRef.operationName;
console.log(name);
```

### Variables
The `CreateCritiqueRequestWithEscrow` mutation requires an argument of type `CreateCritiqueRequestWithEscrowVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface CreateCritiqueRequestWithEscrowVariables {
  requestKey: string;
  exerciseName: string;
  notes?: string | null;
}
```
### Return Type
Recall that executing the `CreateCritiqueRequestWithEscrow` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateCritiqueRequestWithEscrowData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateCritiqueRequestWithEscrowData {
  shardLedger_insert: ShardLedger_Key;
  user_update?: User_Key | null;
  coachCritiqueRequest_insert: CoachCritiqueRequest_Key;
}
```
### Using `CreateCritiqueRequestWithEscrow`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createCritiqueRequestWithEscrow, CreateCritiqueRequestWithEscrowVariables } from '@dataconnect/generated';

// The `CreateCritiqueRequestWithEscrow` mutation requires an argument of type `CreateCritiqueRequestWithEscrowVariables`:
const createCritiqueRequestWithEscrowVars: CreateCritiqueRequestWithEscrowVariables = {
  requestKey: ..., 
  exerciseName: ..., 
  notes: ..., // optional
};

// Call the `createCritiqueRequestWithEscrow()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createCritiqueRequestWithEscrow(createCritiqueRequestWithEscrowVars);
// Variables can be defined inline as well.
const { data } = await createCritiqueRequestWithEscrow({ requestKey: ..., exerciseName: ..., notes: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createCritiqueRequestWithEscrow(dataConnect, createCritiqueRequestWithEscrowVars);

console.log(data.shardLedger_insert);
console.log(data.user_update);
console.log(data.coachCritiqueRequest_insert);

// Or, you can use the `Promise` API.
createCritiqueRequestWithEscrow(createCritiqueRequestWithEscrowVars).then((response) => {
  const data = response.data;
  console.log(data.shardLedger_insert);
  console.log(data.user_update);
  console.log(data.coachCritiqueRequest_insert);
});
```

### Using `CreateCritiqueRequestWithEscrow`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createCritiqueRequestWithEscrowRef, CreateCritiqueRequestWithEscrowVariables } from '@dataconnect/generated';

// The `CreateCritiqueRequestWithEscrow` mutation requires an argument of type `CreateCritiqueRequestWithEscrowVariables`:
const createCritiqueRequestWithEscrowVars: CreateCritiqueRequestWithEscrowVariables = {
  requestKey: ..., 
  exerciseName: ..., 
  notes: ..., // optional
};

// Call the `createCritiqueRequestWithEscrowRef()` function to get a reference to the mutation.
const ref = createCritiqueRequestWithEscrowRef(createCritiqueRequestWithEscrowVars);
// Variables can be defined inline as well.
const ref = createCritiqueRequestWithEscrowRef({ requestKey: ..., exerciseName: ..., notes: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createCritiqueRequestWithEscrowRef(dataConnect, createCritiqueRequestWithEscrowVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.shardLedger_insert);
console.log(data.user_update);
console.log(data.coachCritiqueRequest_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.shardLedger_insert);
  console.log(data.user_update);
  console.log(data.coachCritiqueRequest_insert);
});
```

## CreateCardMarketListing
You can execute the `CreateCardMarketListing` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
createCardMarketListing(vars: CreateCardMarketListingVariables): MutationPromise<CreateCardMarketListingData, CreateCardMarketListingVariables>;

interface CreateCardMarketListingRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateCardMarketListingVariables): MutationRef<CreateCardMarketListingData, CreateCardMarketListingVariables>;
}
export const createCardMarketListingRef: CreateCardMarketListingRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createCardMarketListing(dc: DataConnect, vars: CreateCardMarketListingVariables): MutationPromise<CreateCardMarketListingData, CreateCardMarketListingVariables>;

interface CreateCardMarketListingRef {
  ...
  (dc: DataConnect, vars: CreateCardMarketListingVariables): MutationRef<CreateCardMarketListingData, CreateCardMarketListingVariables>;
}
export const createCardMarketListingRef: CreateCardMarketListingRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createCardMarketListingRef:
```typescript
const name = createCardMarketListingRef.operationName;
console.log(name);
```

### Variables
The `CreateCardMarketListing` mutation requires an argument of type `CreateCardMarketListingVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface CreateCardMarketListingVariables {
  catalogCardId: string;
  priceShards: number;
}
```
### Return Type
Recall that executing the `CreateCardMarketListing` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateCardMarketListingData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateCardMarketListingData {
  cardMarketListing_insert: CardMarketListing_Key;
}
```
### Using `CreateCardMarketListing`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createCardMarketListing, CreateCardMarketListingVariables } from '@dataconnect/generated';

// The `CreateCardMarketListing` mutation requires an argument of type `CreateCardMarketListingVariables`:
const createCardMarketListingVars: CreateCardMarketListingVariables = {
  catalogCardId: ..., 
  priceShards: ..., 
};

// Call the `createCardMarketListing()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createCardMarketListing(createCardMarketListingVars);
// Variables can be defined inline as well.
const { data } = await createCardMarketListing({ catalogCardId: ..., priceShards: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createCardMarketListing(dataConnect, createCardMarketListingVars);

console.log(data.cardMarketListing_insert);

// Or, you can use the `Promise` API.
createCardMarketListing(createCardMarketListingVars).then((response) => {
  const data = response.data;
  console.log(data.cardMarketListing_insert);
});
```

### Using `CreateCardMarketListing`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createCardMarketListingRef, CreateCardMarketListingVariables } from '@dataconnect/generated';

// The `CreateCardMarketListing` mutation requires an argument of type `CreateCardMarketListingVariables`:
const createCardMarketListingVars: CreateCardMarketListingVariables = {
  catalogCardId: ..., 
  priceShards: ..., 
};

// Call the `createCardMarketListingRef()` function to get a reference to the mutation.
const ref = createCardMarketListingRef(createCardMarketListingVars);
// Variables can be defined inline as well.
const ref = createCardMarketListingRef({ catalogCardId: ..., priceShards: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createCardMarketListingRef(dataConnect, createCardMarketListingVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.cardMarketListing_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.cardMarketListing_insert);
});
```

## DeactivateCardMarketListing
You can execute the `DeactivateCardMarketListing` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
deactivateCardMarketListing(vars: DeactivateCardMarketListingVariables): MutationPromise<DeactivateCardMarketListingData, DeactivateCardMarketListingVariables>;

interface DeactivateCardMarketListingRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: DeactivateCardMarketListingVariables): MutationRef<DeactivateCardMarketListingData, DeactivateCardMarketListingVariables>;
}
export const deactivateCardMarketListingRef: DeactivateCardMarketListingRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
deactivateCardMarketListing(dc: DataConnect, vars: DeactivateCardMarketListingVariables): MutationPromise<DeactivateCardMarketListingData, DeactivateCardMarketListingVariables>;

interface DeactivateCardMarketListingRef {
  ...
  (dc: DataConnect, vars: DeactivateCardMarketListingVariables): MutationRef<DeactivateCardMarketListingData, DeactivateCardMarketListingVariables>;
}
export const deactivateCardMarketListingRef: DeactivateCardMarketListingRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the deactivateCardMarketListingRef:
```typescript
const name = deactivateCardMarketListingRef.operationName;
console.log(name);
```

### Variables
The `DeactivateCardMarketListing` mutation requires an argument of type `DeactivateCardMarketListingVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface DeactivateCardMarketListingVariables {
  listingId: UUIDString;
}
```
### Return Type
Recall that executing the `DeactivateCardMarketListing` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `DeactivateCardMarketListingData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface DeactivateCardMarketListingData {
  cardMarketListing_update?: CardMarketListing_Key | null;
}
```
### Using `DeactivateCardMarketListing`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, deactivateCardMarketListing, DeactivateCardMarketListingVariables } from '@dataconnect/generated';

// The `DeactivateCardMarketListing` mutation requires an argument of type `DeactivateCardMarketListingVariables`:
const deactivateCardMarketListingVars: DeactivateCardMarketListingVariables = {
  listingId: ..., 
};

// Call the `deactivateCardMarketListing()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deactivateCardMarketListing(deactivateCardMarketListingVars);
// Variables can be defined inline as well.
const { data } = await deactivateCardMarketListing({ listingId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await deactivateCardMarketListing(dataConnect, deactivateCardMarketListingVars);

console.log(data.cardMarketListing_update);

// Or, you can use the `Promise` API.
deactivateCardMarketListing(deactivateCardMarketListingVars).then((response) => {
  const data = response.data;
  console.log(data.cardMarketListing_update);
});
```

### Using `DeactivateCardMarketListing`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, deactivateCardMarketListingRef, DeactivateCardMarketListingVariables } from '@dataconnect/generated';

// The `DeactivateCardMarketListing` mutation requires an argument of type `DeactivateCardMarketListingVariables`:
const deactivateCardMarketListingVars: DeactivateCardMarketListingVariables = {
  listingId: ..., 
};

// Call the `deactivateCardMarketListingRef()` function to get a reference to the mutation.
const ref = deactivateCardMarketListingRef(deactivateCardMarketListingVars);
// Variables can be defined inline as well.
const ref = deactivateCardMarketListingRef({ listingId: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = deactivateCardMarketListingRef(dataConnect, deactivateCardMarketListingVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.cardMarketListing_update);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.cardMarketListing_update);
});
```

