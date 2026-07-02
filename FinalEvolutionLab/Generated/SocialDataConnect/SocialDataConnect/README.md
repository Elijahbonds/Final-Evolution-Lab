This Swift package contains the generated Swift code for the connector `social`.

You can use this package by adding it as a local Swift package dependency in your project.

# Accessing the connector

Add the necessary imports

```
import FirebaseDataConnect
import SocialDataConnect

```

The connector can be accessed using the following code:

```
let connector = DataConnect.socialConnector

```


## Connecting to the local Emulator
By default, the connector will connect to the production service.

To connect to the emulator, you can use the following code, which can be called from the `init` function of your SwiftUI app

```
connector.useEmulator()
```

# Queries

## ListRecentPostsQuery


### Using the Query Reference
```
struct MyView: View {
   var listRecentPostsQueryRef = DataConnect.socialConnector.listRecentPostsQuery.ref(...)

  var body: some View {
    VStack {
      if let data = listRecentPostsQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await listRecentPostsQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.listRecentPostsQuery.execute(...)
```


## GetPostWithThreadQuery
### Variables
#### Required
```swift

let postKey: PostKey = ...
```




### Using the Query Reference
```
struct MyView: View {
   var getPostWithThreadQueryRef = DataConnect.socialConnector.getPostWithThreadQuery.ref(...)

  var body: some View {
    VStack {
      if let data = getPostWithThreadQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await getPostWithThreadQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.getPostWithThreadQuery.execute(...)
```


## GetUserByFirebaseUidQuery


### Using the Query Reference
```
struct MyView: View {
   var getUserByFirebaseUidQueryRef = DataConnect.socialConnector.getUserByFirebaseUidQuery.ref(...)

  var body: some View {
    VStack {
      if let data = getUserByFirebaseUidQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await getUserByFirebaseUidQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.getUserByFirebaseUidQuery.execute(...)
```


## GetMyPrivateProfileQuery


### Using the Query Reference
```
struct MyView: View {
   var getMyPrivateProfileQueryRef = DataConnect.socialConnector.getMyPrivateProfileQuery.ref(...)

  var body: some View {
    VStack {
      if let data = getMyPrivateProfileQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await getMyPrivateProfileQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.getMyPrivateProfileQuery.execute(...)
```


## GetUserProfileQuery
### Variables
#### Required
```swift

let userId: UUID = ...
```




### Using the Query Reference
```
struct MyView: View {
   var getUserProfileQueryRef = DataConnect.socialConnector.getUserProfileQuery.ref(...)

  var body: some View {
    VStack {
      if let data = getUserProfileQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await getUserProfileQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.getUserProfileQuery.execute(...)
```


## ListCommentsForPostQuery
### Variables
#### Required
```swift

let postId: UUID = ...
```




### Using the Query Reference
```
struct MyView: View {
   var listCommentsForPostQueryRef = DataConnect.socialConnector.listCommentsForPostQuery.ref(...)

  var body: some View {
    VStack {
      if let data = listCommentsForPostQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await listCommentsForPostQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.listCommentsForPostQuery.execute(...)
```


## ListShardLedgerForUserQuery
### Variables


#### Optional
```swift

let limit: Int = ...
```



### Using the Query Reference
```
struct MyView: View {
   var listShardLedgerForUserQueryRef = DataConnect.socialConnector.listShardLedgerForUserQuery.ref(...)

  var body: some View {
    VStack {
      if let data = listShardLedgerForUserQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await listShardLedgerForUserQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.listShardLedgerForUserQuery.execute(...)
```


## ListCreatorCardsQuery
### Variables


#### Optional
```swift

let limit: Int = ...
```



### Using the Query Reference
```
struct MyView: View {
   var listCreatorCardsQueryRef = DataConnect.socialConnector.listCreatorCardsQuery.ref(...)

  var body: some View {
    VStack {
      if let data = listCreatorCardsQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await listCreatorCardsQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.listCreatorCardsQuery.execute(...)
```


## ListActiveCardMarketListingsQuery
### Variables


#### Optional
```swift

let limit: Int = ...
```



### Using the Query Reference
```
struct MyView: View {
   var listActiveCardMarketListingsQueryRef = DataConnect.socialConnector.listActiveCardMarketListingsQuery.ref(...)

  var body: some View {
    VStack {
      if let data = listActiveCardMarketListingsQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await listActiveCardMarketListingsQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.listActiveCardMarketListingsQuery.execute(...)
```


## GetCreatorCardCreatorQuery
### Variables
#### Required
```swift

let catalogCardId: String = ...
```




### Using the Query Reference
```
struct MyView: View {
   var getCreatorCardCreatorQueryRef = DataConnect.socialConnector.getCreatorCardCreatorQuery.ref(...)

  var body: some View {
    VStack {
      if let data = getCreatorCardCreatorQueryRef.data {
        // use data in View
      }
      else {
        Text("Loading...")
      }
    }
    .task {
        do {
          let _ = try await getCreatorCardCreatorQueryRef.execute()
        } catch {
        }
      }
  }
}
```

### One-shot execute
```
DataConnect.socialConnector.getCreatorCardCreatorQuery.execute(...)
```


# Mutations
## RegisterSignedInUserMutation

### Variables

#### Required
```swift

let username: String = ...
let email: String = ...
```
 

#### Optional
```swift

let profilePictureUrl: String = ...
let avatarUrl: String = ...
```

### One-shot execute
```
DataConnect.socialConnector.registerSignedInUserMutation.execute(...)
```

## UpdateMyTrainingProfileMutation

### Variables

#### Required
```swift

let topPRQScore: Double = ...
```
 

#### Optional
```swift

let avatarUrl: String = ...
```

### One-shot execute
```
DataConnect.socialConnector.updateMyTrainingProfileMutation.execute(...)
```

## CreatePostMutation

### Variables

#### Required
```swift

let content: String = ...
```
 

#### Optional
```swift

let gameModeId: String = ...
let trainingScore: Double = ...
let clipUrl: String = ...
let feedSource: String = ...
```

### One-shot execute
```
DataConnect.socialConnector.createPostMutation.execute(...)
```

## CreateCommentMutation

### Variables

#### Required
```swift

let postId: UUID = ...
let content: String = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.createCommentMutation.execute(...)
```

## LikePostMutation

### Variables

#### Required
```swift

let postId: UUID = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.likePostMutation.execute(...)
```

## UnlikePostMutation

### Variables

#### Required
```swift

let postId: UUID = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.unlikePostMutation.execute(...)
```

## DeletePostMutation

### Variables

#### Required
```swift

let postId: UUID = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.deletePostMutation.execute(...)
```

## DeleteCommentMutation

### Variables

#### Required
```swift

let commentId: UUID = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.deleteCommentMutation.execute(...)
```

## SpendEvolutionShardsMutation

### Variables

#### Required
```swift

let deltaShards: Int = ...
let reason: String = ...
```
 

#### Optional
```swift

let referenceId: String = ...
```

### One-shot execute
```
DataConnect.socialConnector.spendEvolutionShardsMutation.execute(...)
```

## ClaimCreatorCardOwnershipMutation

### Variables

#### Required
```swift

let catalogCardId: String = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.claimCreatorCardOwnershipMutation.execute(...)
```

## CreateCritiqueRequestWithEscrowMutation

### Variables

#### Required
```swift

let requestKey: String = ...
let exerciseName: String = ...
```
 

#### Optional
```swift

let notes: String = ...
```

### One-shot execute
```
DataConnect.socialConnector.createCritiqueRequestWithEscrowMutation.execute(...)
```

## CreateCardMarketListingMutation

### Variables

#### Required
```swift

let catalogCardId: String = ...
let priceShards: Int = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.createCardMarketListingMutation.execute(...)
```

## DeactivateCardMarketListingMutation

### Variables

#### Required
```swift

let listingId: UUID = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.deactivateCardMarketListingMutation.execute(...)
```

## ExecuteMarketplacePurchaseMutation

### Variables

#### Required
```swift

let listingId: UUID = ...
let buyerId: UUID = ...
let sellerId: UUID = ...
let catalogCardId: String = ...
let buyerDeltaShards: Int = ...
let sellerDeltaShards: Int = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.executeMarketplacePurchaseMutation.execute(...)
```

## CreateCreatorCardCatalogItemMutation

### Variables

#### Required
```swift

let catalogCardId: String = ...
let displayName: String = ...
```
 

#### Optional
```swift

let rarityTier: String = ...
```

### One-shot execute
```
DataConnect.socialConnector.createCreatorCardCatalogItemMutation.execute(...)
```

## ExecuteMarketplacePurchaseWithRoyaltyMutation

### Variables

#### Required
```swift

let listingId: UUID = ...
let buyerId: UUID = ...
let sellerId: UUID = ...
let catalogCardId: String = ...
let buyerDeltaShards: Int = ...
let sellerDeltaShards: Int = ...
let creatorId: UUID = ...
let royaltyShards: Int = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.executeMarketplacePurchaseWithRoyaltyMutation.execute(...)
```

## ClaimRoyaltiesMutation

### Variables

#### Required
```swift

let claimId: String = ...
let amount: Int = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.claimRoyaltiesMutation.execute(...)
```

