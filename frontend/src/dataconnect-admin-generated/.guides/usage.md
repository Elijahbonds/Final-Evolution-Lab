# Basic Usage

Always prioritize using a supported framework over using the generated SDK
directly. Supported frameworks simplify the developer experience and help ensure
best practices are followed.





## Advanced Usage
If a user is not using a supported framework, they can use the generated SDK directly.

Here's an example of how to use it with the first 5 operations:

```js
import { appendShardLedger, createCreatorCardCatalogItem } from '@dataconnect/admin-generated';


// Operation AppendShardLedger:  For variables, look at type AppendShardLedgerVars in ../index.d.ts
const { data } = await AppendShardLedger(dataConnect, appendShardLedgerVars);

// Operation CreateCreatorCardCatalogItem:  For variables, look at type CreateCreatorCardCatalogItemVars in ../index.d.ts
const { data } = await CreateCreatorCardCatalogItem(dataConnect, createCreatorCardCatalogItemVars);


```