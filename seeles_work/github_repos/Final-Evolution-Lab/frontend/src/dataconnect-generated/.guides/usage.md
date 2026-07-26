# Basic Usage

Always prioritize using a supported framework over using the generated SDK
directly. Supported frameworks simplify the developer experience and help ensure
best practices are followed.





## Advanced Usage
If a user is not using a supported framework, they can use the generated SDK directly.

Here's an example of how to use it with the first 5 operations:

```js
import { registerSignedInUser, linkUserToFirebaseAuth, updateUserTrainingProfile, createPost, createComment, likePost, unlikePost, deletePost, deleteComment, listRecentPosts } from '@dataconnect/generated';


// Operation RegisterSignedInUser:  For variables, look at type RegisterSignedInUserVars in ../index.d.ts
const { data } = await RegisterSignedInUser(dataConnect, registerSignedInUserVars);

// Operation LinkUserToFirebaseAuth:  For variables, look at type LinkUserToFirebaseAuthVars in ../index.d.ts
const { data } = await LinkUserToFirebaseAuth(dataConnect, linkUserToFirebaseAuthVars);

// Operation UpdateUserTrainingProfile:  For variables, look at type UpdateUserTrainingProfileVars in ../index.d.ts
const { data } = await UpdateUserTrainingProfile(dataConnect, updateUserTrainingProfileVars);

// Operation CreatePost:  For variables, look at type CreatePostVars in ../index.d.ts
const { data } = await CreatePost(dataConnect, createPostVars);

// Operation CreateComment:  For variables, look at type CreateCommentVars in ../index.d.ts
const { data } = await CreateComment(dataConnect, createCommentVars);

// Operation LikePost:  For variables, look at type LikePostVars in ../index.d.ts
const { data } = await LikePost(dataConnect, likePostVars);

// Operation UnlikePost:  For variables, look at type UnlikePostVars in ../index.d.ts
const { data } = await UnlikePost(dataConnect, unlikePostVars);

// Operation DeletePost:  For variables, look at type DeletePostVars in ../index.d.ts
const { data } = await DeletePost(dataConnect, deletePostVars);

// Operation DeleteComment:  For variables, look at type DeleteCommentVars in ../index.d.ts
const { data } = await DeleteComment(dataConnect, deleteCommentVars);

// Operation ListRecentPosts: 
const { data } = await ListRecentPosts(dataConnect);


```