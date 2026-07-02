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
### Variables
#### Required
```swift

let firebaseUid: String = ...
```




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

## LinkUserToFirebaseAuthMutation

### Variables

#### Required
```swift

let userKey: UserKey = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.linkUserToFirebaseAuthMutation.execute(...)
```

## UpdateUserTrainingProfileMutation

### Variables

#### Required
```swift

let userKey: UserKey = ...
let topPRQScore: Double = ...
```
 

#### Optional
```swift

let avatarUrl: String = ...
```

### One-shot execute
```
DataConnect.socialConnector.updateUserTrainingProfileMutation.execute(...)
```

## CreatePostMutation

### Variables

#### Required
```swift

let content: String = ...
let authorId: UUID = ...
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
let authorId: UUID = ...
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
let userId: UUID = ...
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
let userId: UUID = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.unlikePostMutation.execute(...)
```

## DeletePostMutation

### Variables

#### Required
```swift

let postKey: PostKey = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.deletePostMutation.execute(...)
```

## DeleteCommentMutation

### Variables

#### Required
```swift

let commentKey: CommentKey = ...
```
 

### One-shot execute
```
DataConnect.socialConnector.deleteCommentMutation.execute(...)
```

