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
  - [*GetUserProfile*](#getuserprofile)
  - [*ListCommentsForPost*](#listcommentsforpost)
- [**Mutations**](#mutations)
  - [*RegisterSignedInUser*](#registersignedinuser)
  - [*LinkUserToFirebaseAuth*](#linkusertofirebaseauth)
  - [*UpdateUserTrainingProfile*](#updateusertrainingprofile)
  - [*CreatePost*](#createpost)
  - [*CreateComment*](#createcomment)
  - [*LikePost*](#likepost)
  - [*UnlikePost*](#unlikepost)
  - [*DeletePost*](#deletepost)
  - [*DeleteComment*](#deletecomment)

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
getUserByFirebaseUid(vars: GetUserByFirebaseUidVariables, options?: ExecuteQueryOptions): QueryPromise<GetUserByFirebaseUidData, GetUserByFirebaseUidVariables>;

interface GetUserByFirebaseUidRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: GetUserByFirebaseUidVariables): QueryRef<GetUserByFirebaseUidData, GetUserByFirebaseUidVariables>;
}
export const getUserByFirebaseUidRef: GetUserByFirebaseUidRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `QueryRef` function.
```typescript
getUserByFirebaseUid(dc: DataConnect, vars: GetUserByFirebaseUidVariables, options?: ExecuteQueryOptions): QueryPromise<GetUserByFirebaseUidData, GetUserByFirebaseUidVariables>;

interface GetUserByFirebaseUidRef {
  ...
  (dc: DataConnect, vars: GetUserByFirebaseUidVariables): QueryRef<GetUserByFirebaseUidData, GetUserByFirebaseUidVariables>;
}
export const getUserByFirebaseUidRef: GetUserByFirebaseUidRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the getUserByFirebaseUidRef:
```typescript
const name = getUserByFirebaseUidRef.operationName;
console.log(name);
```

### Variables
The `GetUserByFirebaseUid` query requires an argument of type `GetUserByFirebaseUidVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface GetUserByFirebaseUidVariables {
  firebaseUid: string;
}
```
### Return Type
Recall that executing the `GetUserByFirebaseUid` query returns a `QueryPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `GetUserByFirebaseUidData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
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
```
### Using `GetUserByFirebaseUid`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, getUserByFirebaseUid, GetUserByFirebaseUidVariables } from '@dataconnect/generated';

// The `GetUserByFirebaseUid` query requires an argument of type `GetUserByFirebaseUidVariables`:
const getUserByFirebaseUidVars: GetUserByFirebaseUidVariables = {
  firebaseUid: ..., 
};

// Call the `getUserByFirebaseUid()` function to execute the query.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await getUserByFirebaseUid(getUserByFirebaseUidVars);
// Variables can be defined inline as well.
const { data } = await getUserByFirebaseUid({ firebaseUid: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await getUserByFirebaseUid(dataConnect, getUserByFirebaseUidVars);

console.log(data.users);

// Or, you can use the `Promise` API.
getUserByFirebaseUid(getUserByFirebaseUidVars).then((response) => {
  const data = response.data;
  console.log(data.users);
});
```

### Using `GetUserByFirebaseUid`'s `QueryRef` function

```typescript
import { getDataConnect, executeQuery } from 'firebase/data-connect';
import { connectorConfig, getUserByFirebaseUidRef, GetUserByFirebaseUidVariables } from '@dataconnect/generated';

// The `GetUserByFirebaseUid` query requires an argument of type `GetUserByFirebaseUidVariables`:
const getUserByFirebaseUidVars: GetUserByFirebaseUidVariables = {
  firebaseUid: ..., 
};

// Call the `getUserByFirebaseUidRef()` function to get a reference to the query.
const ref = getUserByFirebaseUidRef(getUserByFirebaseUidVars);
// Variables can be defined inline as well.
const ref = getUserByFirebaseUidRef({ firebaseUid: ..., });

// You can also pass in a `DataConnect` instance to the `QueryRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = getUserByFirebaseUidRef(dataConnect, getUserByFirebaseUidVars);

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

## LinkUserToFirebaseAuth
You can execute the `LinkUserToFirebaseAuth` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
linkUserToFirebaseAuth(vars: LinkUserToFirebaseAuthVariables): MutationPromise<LinkUserToFirebaseAuthData, LinkUserToFirebaseAuthVariables>;

interface LinkUserToFirebaseAuthRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: LinkUserToFirebaseAuthVariables): MutationRef<LinkUserToFirebaseAuthData, LinkUserToFirebaseAuthVariables>;
}
export const linkUserToFirebaseAuthRef: LinkUserToFirebaseAuthRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
linkUserToFirebaseAuth(dc: DataConnect, vars: LinkUserToFirebaseAuthVariables): MutationPromise<LinkUserToFirebaseAuthData, LinkUserToFirebaseAuthVariables>;

interface LinkUserToFirebaseAuthRef {
  ...
  (dc: DataConnect, vars: LinkUserToFirebaseAuthVariables): MutationRef<LinkUserToFirebaseAuthData, LinkUserToFirebaseAuthVariables>;
}
export const linkUserToFirebaseAuthRef: LinkUserToFirebaseAuthRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the linkUserToFirebaseAuthRef:
```typescript
const name = linkUserToFirebaseAuthRef.operationName;
console.log(name);
```

### Variables
The `LinkUserToFirebaseAuth` mutation requires an argument of type `LinkUserToFirebaseAuthVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface LinkUserToFirebaseAuthVariables {
  userKey: User_Key;
}
```
### Return Type
Recall that executing the `LinkUserToFirebaseAuth` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `LinkUserToFirebaseAuthData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface LinkUserToFirebaseAuthData {
  user_update?: User_Key | null;
}
```
### Using `LinkUserToFirebaseAuth`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, linkUserToFirebaseAuth, LinkUserToFirebaseAuthVariables } from '@dataconnect/generated';

// The `LinkUserToFirebaseAuth` mutation requires an argument of type `LinkUserToFirebaseAuthVariables`:
const linkUserToFirebaseAuthVars: LinkUserToFirebaseAuthVariables = {
  userKey: ..., 
};

// Call the `linkUserToFirebaseAuth()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await linkUserToFirebaseAuth(linkUserToFirebaseAuthVars);
// Variables can be defined inline as well.
const { data } = await linkUserToFirebaseAuth({ userKey: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await linkUserToFirebaseAuth(dataConnect, linkUserToFirebaseAuthVars);

console.log(data.user_update);

// Or, you can use the `Promise` API.
linkUserToFirebaseAuth(linkUserToFirebaseAuthVars).then((response) => {
  const data = response.data;
  console.log(data.user_update);
});
```

### Using `LinkUserToFirebaseAuth`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, linkUserToFirebaseAuthRef, LinkUserToFirebaseAuthVariables } from '@dataconnect/generated';

// The `LinkUserToFirebaseAuth` mutation requires an argument of type `LinkUserToFirebaseAuthVariables`:
const linkUserToFirebaseAuthVars: LinkUserToFirebaseAuthVariables = {
  userKey: ..., 
};

// Call the `linkUserToFirebaseAuthRef()` function to get a reference to the mutation.
const ref = linkUserToFirebaseAuthRef(linkUserToFirebaseAuthVars);
// Variables can be defined inline as well.
const ref = linkUserToFirebaseAuthRef({ userKey: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = linkUserToFirebaseAuthRef(dataConnect, linkUserToFirebaseAuthVars);

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

## UpdateUserTrainingProfile
You can execute the `UpdateUserTrainingProfile` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-generated/index.d.ts](./index.d.ts):
```typescript
updateUserTrainingProfile(vars: UpdateUserTrainingProfileVariables): MutationPromise<UpdateUserTrainingProfileData, UpdateUserTrainingProfileVariables>;

interface UpdateUserTrainingProfileRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: UpdateUserTrainingProfileVariables): MutationRef<UpdateUserTrainingProfileData, UpdateUserTrainingProfileVariables>;
}
export const updateUserTrainingProfileRef: UpdateUserTrainingProfileRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
updateUserTrainingProfile(dc: DataConnect, vars: UpdateUserTrainingProfileVariables): MutationPromise<UpdateUserTrainingProfileData, UpdateUserTrainingProfileVariables>;

interface UpdateUserTrainingProfileRef {
  ...
  (dc: DataConnect, vars: UpdateUserTrainingProfileVariables): MutationRef<UpdateUserTrainingProfileData, UpdateUserTrainingProfileVariables>;
}
export const updateUserTrainingProfileRef: UpdateUserTrainingProfileRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the updateUserTrainingProfileRef:
```typescript
const name = updateUserTrainingProfileRef.operationName;
console.log(name);
```

### Variables
The `UpdateUserTrainingProfile` mutation requires an argument of type `UpdateUserTrainingProfileVariables`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface UpdateUserTrainingProfileVariables {
  userKey: User_Key;
  topPRQScore: number;
  avatarUrl?: string | null;
}
```
### Return Type
Recall that executing the `UpdateUserTrainingProfile` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `UpdateUserTrainingProfileData`, which is defined in [dataconnect-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface UpdateUserTrainingProfileData {
  user_update?: User_Key | null;
}
```
### Using `UpdateUserTrainingProfile`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, updateUserTrainingProfile, UpdateUserTrainingProfileVariables } from '@dataconnect/generated';

// The `UpdateUserTrainingProfile` mutation requires an argument of type `UpdateUserTrainingProfileVariables`:
const updateUserTrainingProfileVars: UpdateUserTrainingProfileVariables = {
  userKey: ..., 
  topPRQScore: ..., 
  avatarUrl: ..., // optional
};

// Call the `updateUserTrainingProfile()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await updateUserTrainingProfile(updateUserTrainingProfileVars);
// Variables can be defined inline as well.
const { data } = await updateUserTrainingProfile({ userKey: ..., topPRQScore: ..., avatarUrl: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await updateUserTrainingProfile(dataConnect, updateUserTrainingProfileVars);

console.log(data.user_update);

// Or, you can use the `Promise` API.
updateUserTrainingProfile(updateUserTrainingProfileVars).then((response) => {
  const data = response.data;
  console.log(data.user_update);
});
```

### Using `UpdateUserTrainingProfile`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, updateUserTrainingProfileRef, UpdateUserTrainingProfileVariables } from '@dataconnect/generated';

// The `UpdateUserTrainingProfile` mutation requires an argument of type `UpdateUserTrainingProfileVariables`:
const updateUserTrainingProfileVars: UpdateUserTrainingProfileVariables = {
  userKey: ..., 
  topPRQScore: ..., 
  avatarUrl: ..., // optional
};

// Call the `updateUserTrainingProfileRef()` function to get a reference to the mutation.
const ref = updateUserTrainingProfileRef(updateUserTrainingProfileVars);
// Variables can be defined inline as well.
const ref = updateUserTrainingProfileRef({ userKey: ..., topPRQScore: ..., avatarUrl: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = updateUserTrainingProfileRef(dataConnect, updateUserTrainingProfileVars);

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
  authorId: UUIDString;
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
  authorId: ..., 
  gameModeId: ..., // optional
  trainingScore: ..., // optional
  clipUrl: ..., // optional
  feedSource: ..., // optional
};

// Call the `createPost()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createPost(createPostVars);
// Variables can be defined inline as well.
const { data } = await createPost({ content: ..., authorId: ..., gameModeId: ..., trainingScore: ..., clipUrl: ..., feedSource: ..., });

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
  authorId: ..., 
  gameModeId: ..., // optional
  trainingScore: ..., // optional
  clipUrl: ..., // optional
  feedSource: ..., // optional
};

// Call the `createPostRef()` function to get a reference to the mutation.
const ref = createPostRef(createPostVars);
// Variables can be defined inline as well.
const ref = createPostRef({ content: ..., authorId: ..., gameModeId: ..., trainingScore: ..., clipUrl: ..., feedSource: ..., });

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
  authorId: UUIDString;
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
  authorId: ..., 
  content: ..., 
};

// Call the `createComment()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createComment(createCommentVars);
// Variables can be defined inline as well.
const { data } = await createComment({ postId: ..., authorId: ..., content: ..., });

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
  authorId: ..., 
  content: ..., 
};

// Call the `createCommentRef()` function to get a reference to the mutation.
const ref = createCommentRef(createCommentVars);
// Variables can be defined inline as well.
const ref = createCommentRef({ postId: ..., authorId: ..., content: ..., });

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
  userId: UUIDString;
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
  userId: ..., 
};

// Call the `likePost()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await likePost(likePostVars);
// Variables can be defined inline as well.
const { data } = await likePost({ postId: ..., userId: ..., });

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
  userId: ..., 
};

// Call the `likePostRef()` function to get a reference to the mutation.
const ref = likePostRef(likePostVars);
// Variables can be defined inline as well.
const ref = likePostRef({ postId: ..., userId: ..., });

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
  userId: UUIDString;
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
  userId: ..., 
};

// Call the `unlikePost()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await unlikePost(unlikePostVars);
// Variables can be defined inline as well.
const { data } = await unlikePost({ postId: ..., userId: ..., });

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
  userId: ..., 
};

// Call the `unlikePostRef()` function to get a reference to the mutation.
const ref = unlikePostRef(unlikePostVars);
// Variables can be defined inline as well.
const ref = unlikePostRef({ postId: ..., userId: ..., });

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
  postKey: Post_Key;
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
  postKey: ..., 
};

// Call the `deletePost()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deletePost(deletePostVars);
// Variables can be defined inline as well.
const { data } = await deletePost({ postKey: ..., });

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
  postKey: ..., 
};

// Call the `deletePostRef()` function to get a reference to the mutation.
const ref = deletePostRef(deletePostVars);
// Variables can be defined inline as well.
const ref = deletePostRef({ postKey: ..., });

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
  commentKey: Comment_Key;
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
  commentKey: ..., 
};

// Call the `deleteComment()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await deleteComment(deleteCommentVars);
// Variables can be defined inline as well.
const { data } = await deleteComment({ commentKey: ..., });

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
  commentKey: ..., 
};

// Call the `deleteCommentRef()` function to get a reference to the mutation.
const ref = deleteCommentRef(deleteCommentVars);
// Variables can be defined inline as well.
const ref = deleteCommentRef({ commentKey: ..., });

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

