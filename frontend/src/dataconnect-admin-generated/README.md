# Generated TypeScript README
This README will guide you through the process of using the generated JavaScript SDK package for the connector `admin`. It will also provide examples on how to use your generated SDK to call your Data Connect queries and mutations.

***NOTE:** This README is generated alongside the generated SDK. If you make changes to this file, they will be overwritten when the SDK is regenerated.*

# Table of Contents
- [**Overview**](#generated-javascript-readme)
- [**Accessing the connector**](#accessing-the-connector)
  - [*Connecting to the local Emulator*](#connecting-to-the-local-emulator)
- [**Queries**](#queries)
- [**Mutations**](#mutations)
  - [*AppendShardLedger*](#appendshardledger)
  - [*CreateCreatorCardCatalogItem*](#createcreatorcardcatalogitem)

# Accessing the connector
A connector is a collection of Queries and Mutations. One SDK is generated for each connector - this SDK is generated for the connector `admin`. You can find more information about connectors in the [Data Connect documentation](https://firebase.google.com/docs/data-connect#how-does).

You can use this generated SDK by importing from the package `@dataconnect/admin-generated` as shown below. Both CommonJS and ESM imports are supported.

You can also follow the instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#set-client).

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/admin-generated';

const dataConnect = getDataConnect(connectorConfig);
```

## Connecting to the local Emulator
By default, the connector will connect to the production service.

To connect to the emulator, you can use the following code.
You can also follow the emulator instructions from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#instrument-clients).

```typescript
import { connectDataConnectEmulator, getDataConnect } from 'firebase/data-connect';
import { connectorConfig } from '@dataconnect/admin-generated';

const dataConnect = getDataConnect(connectorConfig);
connectDataConnectEmulator(dataConnect, 'localhost', 9399);
```

After it's initialized, you can call your Data Connect [queries](#queries) and [mutations](#mutations) from your generated SDK.

# Queries

No queries were generated for the `admin` connector.

If you want to learn more about how to use queries in Data Connect, you can follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-queries).

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

Below are examples of how to use the `admin` connector's generated functions to execute each mutation. You can also follow the examples from the [Data Connect documentation](https://firebase.google.com/docs/data-connect/web-sdk#using-mutations).

## AppendShardLedger
You can execute the `AppendShardLedger` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-admin-generated/index.d.ts](./index.d.ts):
```typescript
appendShardLedger(vars: AppendShardLedgerVariables): MutationPromise<AppendShardLedgerData, AppendShardLedgerVariables>;

interface AppendShardLedgerRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: AppendShardLedgerVariables): MutationRef<AppendShardLedgerData, AppendShardLedgerVariables>;
}
export const appendShardLedgerRef: AppendShardLedgerRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
appendShardLedger(dc: DataConnect, vars: AppendShardLedgerVariables): MutationPromise<AppendShardLedgerData, AppendShardLedgerVariables>;

interface AppendShardLedgerRef {
  ...
  (dc: DataConnect, vars: AppendShardLedgerVariables): MutationRef<AppendShardLedgerData, AppendShardLedgerVariables>;
}
export const appendShardLedgerRef: AppendShardLedgerRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the appendShardLedgerRef:
```typescript
const name = appendShardLedgerRef.operationName;
console.log(name);
```

### Variables
The `AppendShardLedger` mutation requires an argument of type `AppendShardLedgerVariables`, which is defined in [dataconnect-admin-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface AppendShardLedgerVariables {
  targetFirebaseUid: string;
  deltaShards: number;
  reason: string;
  referenceId?: string | null;
}
```
### Return Type
Recall that executing the `AppendShardLedger` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `AppendShardLedgerData`, which is defined in [dataconnect-admin-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface AppendShardLedgerData {
  shardLedger_insert: ShardLedger_Key;
  user_update?: User_Key | null;
}
```
### Using `AppendShardLedger`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, appendShardLedger, AppendShardLedgerVariables } from '@dataconnect/admin-generated';

// The `AppendShardLedger` mutation requires an argument of type `AppendShardLedgerVariables`:
const appendShardLedgerVars: AppendShardLedgerVariables = {
  targetFirebaseUid: ..., 
  deltaShards: ..., 
  reason: ..., 
  referenceId: ..., // optional
};

// Call the `appendShardLedger()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await appendShardLedger(appendShardLedgerVars);
// Variables can be defined inline as well.
const { data } = await appendShardLedger({ targetFirebaseUid: ..., deltaShards: ..., reason: ..., referenceId: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await appendShardLedger(dataConnect, appendShardLedgerVars);

console.log(data.shardLedger_insert);
console.log(data.user_update);

// Or, you can use the `Promise` API.
appendShardLedger(appendShardLedgerVars).then((response) => {
  const data = response.data;
  console.log(data.shardLedger_insert);
  console.log(data.user_update);
});
```

### Using `AppendShardLedger`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, appendShardLedgerRef, AppendShardLedgerVariables } from '@dataconnect/admin-generated';

// The `AppendShardLedger` mutation requires an argument of type `AppendShardLedgerVariables`:
const appendShardLedgerVars: AppendShardLedgerVariables = {
  targetFirebaseUid: ..., 
  deltaShards: ..., 
  reason: ..., 
  referenceId: ..., // optional
};

// Call the `appendShardLedgerRef()` function to get a reference to the mutation.
const ref = appendShardLedgerRef(appendShardLedgerVars);
// Variables can be defined inline as well.
const ref = appendShardLedgerRef({ targetFirebaseUid: ..., deltaShards: ..., reason: ..., referenceId: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = appendShardLedgerRef(dataConnect, appendShardLedgerVars);

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

## CreateCreatorCardCatalogItem
You can execute the `CreateCreatorCardCatalogItem` mutation using the following action shortcut function, or by calling `executeMutation()` after calling the following `MutationRef` function, both of which are defined in [dataconnect-admin-generated/index.d.ts](./index.d.ts):
```typescript
createCreatorCardCatalogItem(vars: CreateCreatorCardCatalogItemVariables): MutationPromise<CreateCreatorCardCatalogItemData, CreateCreatorCardCatalogItemVariables>;

interface CreateCreatorCardCatalogItemRef {
  ...
  /* Allow users to create refs without passing in DataConnect */
  (vars: CreateCreatorCardCatalogItemVariables): MutationRef<CreateCreatorCardCatalogItemData, CreateCreatorCardCatalogItemVariables>;
}
export const createCreatorCardCatalogItemRef: CreateCreatorCardCatalogItemRef;
```
You can also pass in a `DataConnect` instance to the action shortcut function or `MutationRef` function.
```typescript
createCreatorCardCatalogItem(dc: DataConnect, vars: CreateCreatorCardCatalogItemVariables): MutationPromise<CreateCreatorCardCatalogItemData, CreateCreatorCardCatalogItemVariables>;

interface CreateCreatorCardCatalogItemRef {
  ...
  (dc: DataConnect, vars: CreateCreatorCardCatalogItemVariables): MutationRef<CreateCreatorCardCatalogItemData, CreateCreatorCardCatalogItemVariables>;
}
export const createCreatorCardCatalogItemRef: CreateCreatorCardCatalogItemRef;
```

If you need the name of the operation without creating a ref, you can retrieve the operation name by calling the `operationName` property on the createCreatorCardCatalogItemRef:
```typescript
const name = createCreatorCardCatalogItemRef.operationName;
console.log(name);
```

### Variables
The `CreateCreatorCardCatalogItem` mutation requires an argument of type `CreateCreatorCardCatalogItemVariables`, which is defined in [dataconnect-admin-generated/index.d.ts](./index.d.ts). It has the following fields:

```typescript
export interface CreateCreatorCardCatalogItemVariables {
  catalogCardId: string;
  displayName: string;
  rarityTier?: string | null;
}
```
### Return Type
Recall that executing the `CreateCreatorCardCatalogItem` mutation returns a `MutationPromise` that resolves to an object with a `data` property.

The `data` property is an object of type `CreateCreatorCardCatalogItemData`, which is defined in [dataconnect-admin-generated/index.d.ts](./index.d.ts). It has the following fields:
```typescript
export interface CreateCreatorCardCatalogItemData {
  creatorCard_insert: CreatorCard_Key;
}
```
### Using `CreateCreatorCardCatalogItem`'s action shortcut function

```typescript
import { getDataConnect } from 'firebase/data-connect';
import { connectorConfig, createCreatorCardCatalogItem, CreateCreatorCardCatalogItemVariables } from '@dataconnect/admin-generated';

// The `CreateCreatorCardCatalogItem` mutation requires an argument of type `CreateCreatorCardCatalogItemVariables`:
const createCreatorCardCatalogItemVars: CreateCreatorCardCatalogItemVariables = {
  catalogCardId: ..., 
  displayName: ..., 
  rarityTier: ..., // optional
};

// Call the `createCreatorCardCatalogItem()` function to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await createCreatorCardCatalogItem(createCreatorCardCatalogItemVars);
// Variables can be defined inline as well.
const { data } = await createCreatorCardCatalogItem({ catalogCardId: ..., displayName: ..., rarityTier: ..., });

// You can also pass in a `DataConnect` instance to the action shortcut function.
const dataConnect = getDataConnect(connectorConfig);
const { data } = await createCreatorCardCatalogItem(dataConnect, createCreatorCardCatalogItemVars);

console.log(data.creatorCard_insert);

// Or, you can use the `Promise` API.
createCreatorCardCatalogItem(createCreatorCardCatalogItemVars).then((response) => {
  const data = response.data;
  console.log(data.creatorCard_insert);
});
```

### Using `CreateCreatorCardCatalogItem`'s `MutationRef` function

```typescript
import { getDataConnect, executeMutation } from 'firebase/data-connect';
import { connectorConfig, createCreatorCardCatalogItemRef, CreateCreatorCardCatalogItemVariables } from '@dataconnect/admin-generated';

// The `CreateCreatorCardCatalogItem` mutation requires an argument of type `CreateCreatorCardCatalogItemVariables`:
const createCreatorCardCatalogItemVars: CreateCreatorCardCatalogItemVariables = {
  catalogCardId: ..., 
  displayName: ..., 
  rarityTier: ..., // optional
};

// Call the `createCreatorCardCatalogItemRef()` function to get a reference to the mutation.
const ref = createCreatorCardCatalogItemRef(createCreatorCardCatalogItemVars);
// Variables can be defined inline as well.
const ref = createCreatorCardCatalogItemRef({ catalogCardId: ..., displayName: ..., rarityTier: ..., });

// You can also pass in a `DataConnect` instance to the `MutationRef` function.
const dataConnect = getDataConnect(connectorConfig);
const ref = createCreatorCardCatalogItemRef(dataConnect, createCreatorCardCatalogItemVars);

// Call `executeMutation()` on the reference to execute the mutation.
// You can use the `await` keyword to wait for the promise to resolve.
const { data } = await executeMutation(ref);

console.log(data.creatorCard_insert);

// Or, you can use the `Promise` API.
executeMutation(ref).then((response) => {
  const data = response.data;
  console.log(data.creatorCard_insert);
});
```

