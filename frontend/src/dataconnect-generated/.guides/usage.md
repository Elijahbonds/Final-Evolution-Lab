# Basic Usage

Always prioritize using a supported framework over using the generated SDK
directly. Supported frameworks simplify the developer experience and help ensure
best practices are followed.





## Advanced Usage
If a user is not using a supported framework, they can use the generated SDK directly.

Here's an example of how to use it with the first 5 operations:

```js
import { registerSignedInUser, updateMyTrainingProfile, createPost, createComment, likePost, unlikePost, deletePost, deleteComment, spendEvolutionShards, claimCreatorCardOwnership } from '@dataconnect/generated';


// Operation RegisterSignedInUser:  For variables, look at type RegisterSignedInUserVars in ../index.d.ts
const { data } = await RegisterSignedInUser(dataConnect, registerSignedInUserVars);

// Operation UpdateMyTrainingProfile:  For variables, look at type UpdateMyTrainingProfileVars in ../index.d.ts
const { data } = await UpdateMyTrainingProfile(dataConnect, updateMyTrainingProfileVars);

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

// Operation SpendEvolutionShards:  For variables, look at type SpendEvolutionShardsVars in ../index.d.ts
const { data } = await SpendEvolutionShards(dataConnect, spendEvolutionShardsVars);

// Operation ClaimCreatorCardOwnership:  For variables, look at type ClaimCreatorCardOwnershipVars in ../index.d.ts
const { data } = await ClaimCreatorCardOwnership(dataConnect, claimCreatorCardOwnershipVars);


```