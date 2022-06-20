---
type: reference, dev
stage: none
group: Development
info: "See the Technical Writers assigned to Development Guidelines: https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments-to-development-guidelines"
---

# GraphQL

## Getting Started

### Helpful Resources

**General resources**:

- [📚 Official Introduction to GraphQL](https://graphql.org/learn/)
- [📚 Official Introduction to Apollo](https://www.apollographql.com/docs/tutorial/introduction/)

**GraphQL at GitLab**:

<!-- vale gitlab.Spelling = NO -->

- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [GitLab Unfiltered GraphQL playlist](https://www.youtube.com/watch?v=wHPKZBDMfxE&list=PL05JrBw4t0KpcjeHjaRMB7IGB2oDWyJzv)
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [GraphQL at GitLab: Deep Dive](../api_graphql_styleguide.md#deep-dive) (video) by Nick Thomas
  - An overview of the history of GraphQL at GitLab (not frontend-specific)
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [GitLab Feature Walkthrough with GraphQL and Vue Apollo](https://www.youtube.com/watch?v=6yYp2zB7FrM) (video) by Natalia Tepluhina
  - A real-life example of implementing a frontend feature in GitLab using GraphQL
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [History of client-side GraphQL at GitLab](https://www.youtube.com/watch?v=mCKRJxvMnf0) (video) Illya Klymov and Natalia Tepluhina
- <i class="fa fa-youtube-play youtube" aria-hidden="true"></i> [From Vuex to Apollo](https://www.youtube.com/watch?v=9knwu87IfU8) (video) by Natalia Tepluhina
  - An overview of when Apollo might be a better choice than Vuex, and how one could go about the transition
- [🛠 Vuex -> Apollo Migration: a proof-of-concept project](https://gitlab.com/ntepluhina/vuex-to-apollo/blob/master/README.md)
  - A collection of examples that show the possible approaches for state management with Vue+GraphQL+(Vuex or Apollo) apps

<!-- vale gitlab.Spelling = YES -->

### Libraries

We use [Apollo](https://www.apollographql.com/) (specifically [Apollo Client](https://www.apollographql.com/docs/react/)) and [Vue Apollo](https://github.com/vuejs/vue-apollo)
when using GraphQL for frontend development.

If you are using GraphQL in a Vue application, the [Usage in Vue](#usage-in-vue) section
can help you learn how to integrate Vue Apollo.

For other use cases, check out the [Usage outside of Vue](#usage-outside-of-vue) section.

We use [Immer](https://immerjs.github.io/immer/) for immutable cache updates;
see [Immutability and cache updates](#immutability-and-cache-updates) for more information.

### Tooling

<!-- vale gitlab.Spelling = NO -->

- [Apollo Client Devtools](https://github.com/apollographql/apollo-client-devtools)

<!-- vale gitlab.Spelling = YES -->

#### [Apollo GraphQL VS Code extension](https://marketplace.visualstudio.com/items?itemName=apollographql.vscode-apollo)

If you use VS Code, the Apollo GraphQL extension supports autocompletion in `.graphql` files. To set up
the GraphQL extension, follow these steps:

1. Generate the schema: `bundle exec rake gitlab:graphql:schema:dump`
1. Add an `apollo.config.js` file to the root of your `gitlab` local directory.
1. Populate the file with the following content:

    ```javascript
    module.exports = {
      client: {
        includes: ['./app/assets/javascripts/**/*.graphql', './ee/app/assets/javascripts/**/*.graphql'],
        service: {
          name: 'GitLab',
          localSchemaFile: './tmp/tests/graphql/gitlab_schema.graphql',
        },
      },
    };
    ```

1. Restart VS Code.

### Exploring the GraphQL API

Our GraphQL API can be explored via GraphiQL at your instance's
`/-/graphql-explorer` or at [GitLab.com](https://gitlab.com/-/graphql-explorer). Consult the
[GitLab GraphQL API Reference documentation](../../api/graphql/reference)
where needed.

You can check all existing queries and mutations on the right side
of GraphiQL in its **Documentation explorer**. You can also
write queries and mutations directly on the left tab and check
their execution by clicking **Execute query** button on the top left:

![GraphiQL interface](img/graphiql_explorer_v12_4.png)

## Apollo Client

To save duplicated clients getting created in different apps, we have a
[default client](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/assets/javascripts/lib/graphql.js) that should be used. This sets up the
Apollo client with the correct URL and also sets the CSRF headers.

Default client accepts two parameters: `resolvers` and `config`.

- `resolvers` parameter is created to accept an object of resolvers for [local state management](#local-state-with-apollo) queries and mutations
- `config` parameter takes an object of configuration settings:
  - `cacheConfig` field accepts an optional object of settings to [customize Apollo cache](https://www.apollographql.com/docs/react/caching/cache-configuration/#configuring-the-cache)
  - `baseUrl` allows us to pass a URL for GraphQL endpoint different from our main endpoint (for example, `${gon.relative_url_root}/api/graphql`)
  - `fetchPolicy` determines how you want your component to interact with the Apollo cache. Defaults to "cache-first".

### Multiple client queries for the same object

If you are making multiple queries to the same Apollo client object you might encounter the following error: `Cache data may be lost when replacing the someProperty field of a Query object. To address this problem, either ensure all objects of SomeEntityhave an id or a custom merge function`. We are already checking `ID` presence for every GraphQL type that has an `ID`, so this shouldn't be the case. Most likely, the `SomeEntity` type doesn't have an `ID` property, and to fix this warning we need to define a custom merge function.

We have some client-wide types with `merge: true` defined in the default client as [typePolicies](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/assets/javascripts/lib/graphql.js) (this means that Apollo will merge existing and incoming responses in the case of subsequent queries). Please consider adding `SomeEntity` there or defining a custom merge function for it.

## GraphQL Queries

To save query compilation at runtime, webpack can directly import `.graphql`
files. This allows webpack to pre-process the query at compile time instead
of the client doing compilation of queries.

To distinguish queries from mutations and fragments, the following naming convention is recommended:

- `all_users.query.graphql` for queries;
- `add_user.mutation.graphql` for mutations;
- `basic_user.fragment.graphql` for fragments.

If you are using queries for the [CustomersDot GraphQL endpoint](https://gitlab.com/gitlab-org/gitlab/-/blob/be78ccd832fd40315c5e63bb48ee1596ae146f56/app/controllers/customers_dot/proxy_controller.rb), end the filename with `.customer.query.graphql`, `.customer.mutation.graphql`, or `.customer.fragment.graphql`.

### Fragments

[Fragments](https://graphql.org/learn/queries/#fragments) are a way to make your complex GraphQL queries more readable and re-usable. Here is an example of GraphQL fragment:

```javascript
fragment DesignListItem on Design {
  id
  image
  event
  filename
  notesCount
}
```

Fragments can be stored in separate files, imported and used in queries, mutations, or other fragments.

```javascript
#import "./design_list.fragment.graphql"
#import "./diff_refs.fragment.graphql"

fragment DesignItem on Design {
  ...DesignListItem
  fullPath
  diffRefs {
    ...DesignDiffRefs
  }
}
```

More about fragments:
[GraphQL documentation](https://graphql.org/learn/queries/#fragments)

## Global IDs

The GitLab GraphQL API expresses `id` fields as Global IDs rather than the PostgreSQL
primary key `id`. Global ID is [a convention](https://graphql.org/learn/global-object-identification/)
used for caching and fetching in client-side libraries.

To convert a Global ID to the primary key `id`, you can use `getIdFromGraphQLId`:

```javascript
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

const primaryKeyId = getIdFromGraphQLId(data.id);
```

**It is required** to query global `id` for every GraphQL type that has an `id` in the schema:

```javascript
query allReleases(...) {
  project(...) {
    id // Project has an ID in GraphQL schema so should fetch it
    releases(...) {
      nodes {
        // Release has no ID property in GraphQL schema
        name
        tagName
        tagPath
        assets {
          count
          links {
            nodes {
              id // Link has an ID in GraphQL schema so should fetch it
              name
            }
          }
        }
      }
      pageInfo {
        // PageInfo no ID property in GraphQL schema
        startCursor
        hasPreviousPage
        hasNextPage
        endCursor
      }
    }
  }
}
```

## Immutability and cache updates

From Apollo version 3.0.0 all the cache updates need to be immutable. It needs to be replaced entirely
with a **new and updated** object.

To facilitate the process of updating the cache and returning the new object we
use the library [Immer](https://immerjs.github.io/immer/).
Please, follow these conventions:

- The updated cache is named `data`.
- The original cache data is named `sourceData`.

A typical update process looks like this:

```javascript
...
const sourceData = client.readQuery({ query });

const data = produce(sourceData, draftState => {
  draftState.commits.push(newCommit);
});

client.writeQuery({
  query,
  data,
});
...
```

As shown in the code example by using `produce`, we can perform any kind of direct manipulation of the
`draftState`. Besides, `immer` guarantees that a new state which includes the changes to `draftState` is generated.

## Usage in Vue

To use Vue Apollo, import the [Vue Apollo](https://github.com/vuejs/vue-apollo) plugin as well
as the default client. This should be created at the same point
the Vue application is mounted.

```javascript
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

new Vue({
  ...,
  apolloProvider,
  ...
});
```

Read more about [Vue Apollo](https://github.com/vuejs/vue-apollo) in the [Vue Apollo documentation](https://vue-apollo.netlify.app/guide/).

### Local state with Apollo

It is possible to manage an application state with Apollo by using [client-site resolvers](#using-client-side-resolvers)
or [type policies with reactive variables](#using-type-policies-with-reactive-variables) when creating your default
client.

#### Using client-side resolvers

The default state can be set by writing to the cache after setting up the default client. In the
example below, we are using query with `@client` Apollo directive to write the initial data to
Apollo cache and then get this state in the Vue component:

```javascript
// user.query.graphql

query User {
  user @client {
    name
    surname
    age
  }
}
```

```javascript
// index.js

import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import userQuery from '~/user/user.query.graphql'
Vue.use(VueApollo);

const defaultClient = createDefaultClient();

defaultClient.cache.writeQuery({
  query: userQuery,
  data: {
    user: {
      name: 'John',
      surname: 'Doe',
      age: 30
    },
  },
});

const apolloProvider = new VueApollo({
  defaultClient,
});
```

```javascript
// App.vue
import userQuery from '~/user/user.query.graphql'

export default {
  apollo: {
    user: {
      query: userQuery
    }
  }
}
```

Along with creating local data, we can also extend existing GraphQL types with `@client` fields. This is extremely helpful when we need to mock an API response for fields not yet added to our GraphQL API.

##### Mocking API response with local Apollo cache

Using local Apollo Cache is helpful when we have a need to mock some GraphQL API responses, queries, or mutations locally (such as when they're still not added to our actual API).

For example, we have a [fragment](#fragments) on `DesignVersion` used in our queries:

```javascript
fragment VersionListItem on DesignVersion {
  id
  sha
}
```

We also need to fetch the version author and the `created at` property to display in the versions dropdown. But, these changes are still not implemented in our API. We can change the existing fragment to get a mocked response for these new fields:

```javascript
fragment VersionListItem on DesignVersion {
  id
  sha
  author @client {
    avatarUrl
    name
  }
  createdAt @client
}
```

Now Apollo tries to find a _resolver_ for every field marked with `@client` directive. Let's create a resolver for `DesignVersion` type (why `DesignVersion`? because our fragment was created on this type).

```javascript
// resolvers.js

const resolvers = {
  DesignVersion: {
    author: () => ({
      avatarUrl:
        'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon',
      name: 'Administrator',
      __typename: 'User',
    }),
    createdAt: () => '2019-11-13T16:08:11Z',
  },
};

export default resolvers;
```

We need to pass a resolvers object to our existing Apollo Client:

```javascript
// graphql.js

import createDefaultClient from '~/lib/graphql';
import resolvers from './graphql/resolvers';

const defaultClient = createDefaultClient(resolvers);
```

For each attempt to fetch a version, our client fetches `id` and `sha` from the remote API endpoint. It then assigns our hardcoded values to the `author` and `createdAt` version properties. With this data, frontend developers are able to work on their UI without being blocked by backend. When the response is added to the API, our custom local resolver can be removed. The only change to the query/fragment is to remove the `@client` directive.

Read more about local state management with Apollo in the [Vue Apollo documentation](https://vue-apollo.netlify.app/guide/local-state.html#local-state).

#### Using type policies with reactive variables

Apollo Client 3 offers an alternative to [client-side resolvers](#using-client-side-resolvers) by using
[reactive variables to store client state](https://www.apollographql.com/docs/react/local-state/reactive-variables/).

**NOTE:**
We are still learning the best practices for both **type policies** and **reactive vars**.
Take a moment to improve this guide or [leave a comment](https://gitlab.com/gitlab-org/frontend/rfcs/-/issues/100)
if you use it!

In the example below we define a `@client` query and its `typedefs`: 

```javascript
// ./graphql/typedefs.graphql
extend type Query {
  localData: String!
}
```

```javascript
// ./graphql/get_local_data.query.graphql
query getLocalData {
  localData @client
}
```

Similar to resolvers, your `typePolicies` will execute when the `@client` query is used. However,
using `makeVar` will trigger every relevant active Apollo query to reactively update when the state
mutates.

```javascript
// ./graphql/local_state.js

import { makeVar } from '@apollo/client/core';
import typeDefs from './typedefs.graphql';

export const createLocalState = () => {
  // set an initial value
  const localDataVar = makeVar('');

  const cacheConfig = {
    typePolicies: {
      Query: {
        fields: {
          localData() {
            // obtain current value
            // triggers when `localDataVar` is updated
            return localDataVar();
          },
        },
      },
    },
  };

  // methods that update local state
  const localMutations = {
    setLocalData(newData) {
      localDataVar(newData);
    },
    clearData() {
      localDataVar('');
    },
  };

  return {
    cacheConfig,
    typeDefs,
    localMutations,
  };
};
```

Pass the cache config to your Apollo Client:

```javascript
// index.js

// ...
import createDefaultClient from '~/lib/graphql';
import { createLocalState } from './graphql/local_state';

const { cacheConfig, typeDefs, localMutations } = createLocalState();

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient({}, { cacheConfig, typeDefs }),
});

return new Vue({
  el,
  apolloProvider,
  provide: {
    // inject local state mutations to your app
    localMutations,
  },
  render(h) {
    return h(MyApp);
  },
});
```

Wherever used, the local query will update as the state updates thanks to the **reactive variable**.

### Using with Vuex

When the Apollo Client is used in Vuex and fetched data is stored in the Vuex store, the Apollo Client cache does not need to be enabled. Otherwise we would have data from the API stored in two places - Vuex store and Apollo Client cache. With Apollo's default settings, a subsequent fetch from the GraphQL API could result in fetching data from Apollo cache (in the case where we have the same query and variables). To prevent this behavior, we need to disable Apollo Client cache by passing a valid `fetchPolicy` option to its constructor:

```javascript
import fetchPolicies from '~/graphql_shared/fetch_policy_constants';

export const gqClient = createGqClient(
  {},
  {
    fetchPolicy: fetchPolicies.NO_CACHE,
  },
);
```

### Working on GraphQL-based features when frontend and backend are not in sync

Any feature that requires GraphQL queries/mutations to be created or updated should be carefully
planned. Frontend and backend counterparts should agree on a schema that satisfies both client-side and
server-side requirements. This enables both departments to start implementing their parts without
blocking each other.

Ideally, the backend implementation should be done prior to the frontend so that the client can
immediately start querying the API with minimal back and forth between departments. However, we
recognize that priorities don't always align. For the sake of iteration and
delivering work we're committed to, it might be necessary for the frontend to be implemented ahead
of the backend.

#### Implementing frontend queries and mutations ahead of the backend

In such case, the frontend will define GraphQL schemas or fields that do not correspond to any
backend resolver yet. This is fine as long as the implementation is properly feature-flagged so it
does not translate to public-facing errors in the product. However, we do validate client-side
queries/mutations against the backend GraphQL schema with the `graphql-verify` CI job.
You must confirm your changes pass the validation if they are to be merged before the
backend actually supports them. Below are a few suggestions to go about this.

##### Using the `@client` directive

The preferred approach is to use the `@client` directive on any new query, mutation, or field that
isn't yet supported by the backend. Any entity with the directive is skipped by the
`graphql-verify` validation job.

Additionally Apollo will attempt to resolve them client-side, which can be used in conjunction with
[Mocking API response with local Apollo cache](#mocking-api-response-with-local-apollo-cache). This
provides a convenient way of testing your feature with fake data defined client-side.
When opening a merge request for your changes, it can be a good idea to provide local resolvers as a
patch that reviewers can apply in their GDK to easily smoke-test your work.

Make sure to track the removal of the directive in a follow-up issue, or as part of the backend
implementation plan.

##### Adding an exception to the list of known failures

GraphQL queries/mutations validation can be completely turned off for specific files by adding their
paths to the
[`config/known_invalid_graphql_queries.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/config/known_invalid_graphql_queries.yml)
file, much like you would disable ESLint for some files via an `.eslintignore` file.
Bear in mind that any file listed in here will not be validated at all. So if you're only adding
fields to an existing query, use the `@client` directive approach so that the rest of the query
is still validated.

Again, make sure that those overrides are as short-lived as possible by tracking their removal in
the appropriate issue.

#### Feature-flagged queries

In cases where the backend is complete and the frontend is being implemented behind a feature flag,
a couple options are available to leverage the feature flag in the GraphQL queries.

##### The `@include` directive

The `@include` (or its opposite, `@skip`) can be used to control whether an entity should be
included in the query. If the `@include` directive evaluates to `false`, the entity's resolver is
not hit and the entity is excluded from the response. For example:

```graphql
query getAuthorData($authorNameEnabled: Boolean = false) {
  username
  name @include(if: $authorNameEnabled)
}
```

Then in the Vue (or JavaScript) call to the query we can pass in our feature flag. This feature
flag needs to be already set up correctly. See the [feature flag documentation](../feature_flags/index.md)
for the correct way to do this.

```javascript
export default {
  apollo: {
    user: {
      query: QUERY_IMPORT,
      variables() {
        return {
          authorNameEnabled: gon?.features?.authorNameEnabled,
        };
      },
    }
  },
};
```

Note that, even if the directive evaluates to `false`, the guarded entity is sent to the backend and
matched against the GraphQL schema. So this approach requires that the feature-flagged entity
exists in the schema, even if the feature flag is disabled. When the feature flag is turned off, it
is recommended that the resolver returns `null` at the very least.

##### Different versions of a query

There's another approach that involves duplicating the standard query, and it should be avoided. The copy includes the new entities
while the original remains unchanged. It is up to the production code to trigger the right query
based on the feature flag's status. For example:

```javascript
export default {
  apollo: {
    user: {
      query() {
        return this.glFeatures.authorNameEnabled ? NEW_QUERY : ORIGINAL_QUERY,
      }
    }
  },
};
```

This approach is not recommended as it results in bigger merge requests and requires maintaining
two similar queries for as long as the feature flag exists. This can be used in cases where the new
GraphQL entities are not yet part of the schema, or if they are feature-flagged at the schema level
(`new_entity: :feature_flag`).

### Manually triggering queries

Queries on a component's `apollo` property are made automatically when the component is created.
Some components instead want the network request made on-demand, for example a dropdown with lazy-loaded items.

There are two ways to do this:

1. Use the `skip` property

```javascript
export default {
  apollo: {
    user: {
      query: QUERY_IMPORT,
      skip() {
        // only make the query when dropdown is open
        return !this.isOpen;
      },
    }
  },
};
```

1. Using `addSmartQuery`

You can manually create the Smart Query in your method.

```javascript
handleClick() {
  this.$apollo.addSmartQuery('user', {
    // this takes the same values as you'd have in the `apollo` section
    query: QUERY_IMPORT,
  }),
};
```

### Working with pagination

The GitLab GraphQL API uses [Relay-style cursor pagination](https://www.apollographql.com/docs/react/pagination/overview/#cursor-based)
for connection types. This means a "cursor" is used to keep track of where in the data
set the next items should be fetched from. [GraphQL Ruby Connection Concepts](https://graphql-ruby.org/pagination/connection_concepts.html)
is a good overview and introduction to connections.

Every connection type (for example, `DesignConnection` and `DiscussionConnection`) has a field `pageInfo` that contains an information required for pagination:

```javascript
pageInfo {
  endCursor
  hasNextPage
  hasPreviousPage
  startCursor
}
```

Here:

- `startCursor` and `endCursor` display the cursor of the first and last items
  respectively.
- `hasPreviousPage` and `hasNextPage` allow us to check if there are more pages
  available before or after the current page.

When we fetch data with a connection type, we can pass cursor as `after` or `before`
parameter, indicating a starting or ending point of our pagination. They should be
followed with `first` or `last` parameter respectively to indicate _how many_ items
we want to fetch after or before a given endpoint.

For example, here we're fetching 10 designs after a cursor (let us call this `projectQuery`):

```javascript
#import "~/graphql_shared/fragments/page_info.fragment.graphql"

query {
  project(fullPath: "root/my-project") {
    id
    issue(iid: "42") {
      designCollection {
        designs(atVersion: null, after: "Ihwffmde0i", first: 10) {
          edges {
            node {
              id
            }
          }
          pageInfo {
            ...PageInfo
          }
        }
      }
    }
  }
}
```

Note that we are using the [`page_info.fragment.graphql`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/assets/javascripts/graphql_shared/fragments/page_info.fragment.graphql) to populate the `pageInfo` information.

#### Using `fetchMore` method in components

This approach makes sense to use with user-handled pagination. For example, when the scrolling to fetch more data or explicitly clicking a **Next Page** button.
When we need to fetch all the data initially, it is recommended to use [a (non-smart) query, instead](#using-a-recursive-query-in-components).

When making an initial fetch, we usually want to start a pagination from the beginning.
In this case, we can either:

- Skip passing a cursor.
- Pass `null` explicitly to `after`.

After data is fetched, we can use the `update`-hook as an opportunity [to customize
the data that is set in the Vue component property](https://apollo.vuejs.org/api/smart-query.html#options). This allows us to get a hold of the `pageInfo` object among other data.

In the `result`-hook, we can inspect the `pageInfo` object to see if we need to fetch
the next page. Note that we also keep a `requestCount` to ensure that the application
does not keep requesting the next page, indefinitely:

```javascript
data() {
  return {
    pageInfo: null,
    requestCount: 0,
  }
},
apollo: {
  designs: {
    query: projectQuery,
    variables() {
      return {
        // ... The rest of the design variables
        first: 10,
      };
    },
    update(data) {
      const { id = null, issue = {} } = data.project || {};
      const { edges = [], pageInfo } = issue.designCollection?.designs || {};

      return {
        id,
        edges,
        pageInfo,
      };
    },
    result() {
      const { pageInfo } = this.designs;

      // Increment the request count with each new result
      this.requestCount += 1;
      // Only fetch next page if we have more requests and there is a next page to fetch
      if (this.requestCount < MAX_REQUEST_COUNT && pageInfo?.hasNextPage) {
        this.fetchNextPage(pageInfo.endCursor);
      }
    },
  },
},
```

When we want to move to the next page, we use an Apollo `fetchMore` method, passing a
new cursor (and, optionally, new variables) there.

```javascript
fetchNextPage(endCursor) {
  this.$apollo.queries.designs.fetchMore({
    variables: {
      // ... The rest of the design variables
      first: 10,
      after: endCursor,
    },
  });
}
```

##### Defining field merge policy

We would also need to define a field policy to specify how do we want to merge the existing results with the incoming results. For example, if we have `Previous/Next` buttons, it makes sense to replace the existing result with the incoming one:

```javascript
const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      cacheConfig: {
        typePolicies: {
          DesignCollection: {
            fields: {
              designs: {
                merge(existing, incoming) {
                  if (!incoming) return existing;
                  if (!existing) return incoming;

                  // We want to save only incoming nodes and replace existing ones
                  return incoming
                }
              }
            }
          }
        }
      },
    },
  ),
});
```

When we have an infinite scroll, it would make sense to add the incoming `designs` nodes to existing ones instead of replacing. In this case, merge function would be slightly different:

```javascript
const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      cacheConfig: {
        typePolicies: {
          DesignCollection: {
            fields: {
              designs: {
                merge(existing, incoming) {
                  if (!incoming) return existing;
                  if (!existing) return incoming;

                  const { nodes, ...rest } = incoming;
                  // We only need to merge the nodes array.
                  // The rest of the fields (pagination) should always be overwritten by incoming
                  let result = rest;
                  result.nodes = [...existing.nodes, ...nodes];
                  return result;
                }
              }
            }
          }
        }
      },
    },
  ),
});
```

`apollo-client` [provides](https://github.com/apollographql/apollo-client/blob/212b1e686359a3489b48d7e5d38a256312f81fde/src/utilities/policies/pagination.ts)
a few field policies to be used with paginated queries. Here's another way to achieve infinite
scroll pagination with the `concatPagination` policy:

```javascript
import { concatPagination } from '@apollo/client/utilities';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';

Vue.use(VueApollo);

export default new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      cacheConfig: {
        typePolicies: {
          Project: {
            fields: {
              dastSiteProfiles: {
                keyArgs: ['fullPath'], // You might need to set the keyArgs option to enforce the cache's integrity
              },
            },
          },
          DastSiteProfileConnection: {
            fields: {
              nodes: concatPagination(),
            },
          },
        },
      },
    },
  ),
});
```

This is similar to the `DesignCollection` example above as new page results are appended to the
previous ones.

#### Using a recursive query in components

When it is necessary to fetch all paginated data initially an Apollo query can do the trick for us.
If we need to fetch the next page based on user interactions, it is recommend to use a [`smartQuery`](https://apollo.vuejs.org/api/smart-query.html) along with the [`fetchMore`-hook](#using-fetchmore-method-in-components).

When the query resolves we can update the component data and inspect the `pageInfo` object. This allows us
to see if we need to fetch the next page, calling the method recursively.

Note that we also keep a `requestCount` to ensure that the application does not keep
requesting the next page, indefinitely.

```javascript
data() {
  return {
    requestCount: 0,
    isLoading: false,
    designs: {
      edges: [],
      pageInfo: null,
    },
  }
},
created() {
  this.fetchDesigns();
},
methods: {
  handleError(error) {
    this.isLoading = false;
    // Do something with `error`
  },
  fetchDesigns(endCursor) {
    this.isLoading = true;

    return this.$apollo
      .query({
        query: projectQuery,
        variables() {
          return {
            // ... The rest of the design variables
            first: 10,
            endCursor,
          };
        },
      })
      .then(({ data }) => {
        const { id = null, issue = {} } = data.project || {};
        const { edges = [], pageInfo } = issue.designCollection?.designs || {};

        // Update data
        this.designs = {
          id,
          edges: [...this.designs.edges, ...edges];
          pageInfo: pageInfo;
        };

        // Increment the request count with each new result
        this.requestCount += 1;
        // Only fetch next page if we have more requests and there is a next page to fetch
        if (this.requestCount < MAX_REQUEST_COUNT && pageInfo?.hasNextPage) {
          this.fetchDesigns(pageInfo.endCursor);
        } else {
          this.isLoading = false;
        }
      })
      .catch(this.handleError);
  },
},
```

#### Pagination and optimistic updates

When Apollo caches paginated data client-side, it includes `pageInfo` variables in the cache key.
If you wanted to optimistically update that data, you'd have to provide `pageInfo` variables
when interacting with the cache via [`.readQuery()`](https://www.apollographql.com/docs/react/v2/api/apollo-client/#ApolloClient.readQuery)
or [`.writeQuery()`](https://www.apollographql.com/docs/react/v2/api/apollo-client/#ApolloClient.writeQuery).
This can be tedious and counter-intuitive.

To make it easier to deal with cached paginated queries, Apollo provides the `@connection` directive.
The directive accepts a `key` parameter that is used as a static key when caching the data.
You'd then be able to retrieve the data without providing any pagination-specific variables.

Here's an example of a query using the `@connection` directive:

```graphql
#import "~/graphql_shared/fragments/page_info.fragment.graphql"

query DastSiteProfiles($fullPath: ID!, $after: String, $before: String, $first: Int, $last: Int) {
  project(fullPath: $fullPath) {
    siteProfiles: dastSiteProfiles(after: $after, before: $before, first: $first, last: $last)
      @connection(key: "dastSiteProfiles") {
      pageInfo {
        ...PageInfo
      }
      edges {
        cursor
        node {
          id
          # ...
        }
      }
    }
  }
}
```

In this example, Apollo stores the data with the stable `dastSiteProfiles` cache key.

To retrieve that data from the cache, you'd then only need to provide the `$fullPath` variable,
omitting pagination-specific variables like `after` or `before`:

```javascript
const data = store.readQuery({
  query: dastSiteProfilesQuery,
  variables: {
    fullPath: 'namespace/project',
  },
});
```

Read more about the `@connection` directive in [Apollo's documentation](https://www.apollographql.com/docs/react/caching/advanced-topics/#the-connection-directive).

### Managing performance

The Apollo client batches queries by default. Given 3 deferred queries,
Apollo groups them into one request, sends the single request to the server, and
responds after all 3 queries have completed.

If you need to have queries sent as individual requests, additional context can be provided
to tell Apollo to do this.

```javascript
export default {
  apollo: {
    user: {
      query: QUERY_IMPORT,
      context: {
        isSingleRequest: true,
      }
    }
  },
};
```

#### Polling and Performance

While the Apollo client has support for simple polling, for performance reasons, our [ETag-based caching](../polling.md) is preferred to hitting the database each time.

After the ETag resource is set up to be cached from backend, there are a few changes to make on the frontend.

First, get your ETag resource from the backend, which should be in the form of a URL path. In the example of the pipelines graph, this is called the `graphql_resource_etag`, which is used to create new headers to add to the Apollo context:

```javascript
/* pipelines/components/graph/utils.js */

/* eslint-disable @gitlab/require-i18n-strings */
const getQueryHeaders = (etagResource) => {
  return {
    fetchOptions: {
      method: 'GET',
    },
    headers: {
      /* This will depend on your feature */
      'X-GITLAB-GRAPHQL-FEATURE-CORRELATION': 'verify/ci/pipeline-graph',
      'X-GITLAB-GRAPHQL-RESOURCE-ETAG': etagResource,
      'X-REQUESTED-WITH': 'XMLHttpRequest',
    },
  };
};
/* eslint-enable @gitlab/require-i18n-strings */

/* component.vue */

apollo: {
  pipeline: {
    context() {
      return getQueryHeaders(this.graphqlResourceEtag);
    },
    query: getPipelineDetails,
    pollInterval: 10000,
    ..
  },
},
```

Here, the apollo query is watching for changes in `graphqlResourceEtag`. If your ETag resource dynamically changes, you should make sure the resource you are sending in the query headers is also updated. To do this, you can store and update the ETag resource dynamically in the local cache.

You can see an example of this in the pipeline status of the pipeline editor. The pipeline editor watches for changes in the latest pipeline. When the user creates a new commit, we update the pipeline query to poll for changes in the new pipeline.

```graphql
# pipeline_etag.query.graphql

query getPipelineEtag {
  pipelineEtag @client
}
```

```javascript
/* pipeline_editor/components/header/pipeline_status.vue */

import getPipelineEtag from '~/pipeline_editor/graphql/queries/client/pipeline_etag.query.graphql';

apollo: {
  pipelineEtag: {
    query: getPipelineEtag,
  },
  pipeline: {
    context() {
      return getQueryHeaders(this.pipelineEtag);
    },
    query: getPipelineQuery,
    pollInterval: POLL_INTERVAL,
  },
}

/* pipeline_editor/components/commit/commit_section.vue */

await this.$apollo.mutate({
  mutation: commitCIFile,
  update(store, { data }) {
    const pipelineEtag = data?.commitCreate?.commit?.commitPipelinePath;

    if (pipelineEtag) {
      store.writeQuery({ query: getPipelineEtag, data: { pipelineEtag } });
    }
  },
});
```

ETags depend on the request being a `GET` instead of GraphQL's usual `POST`. Our default link library does not support `GET` requests, so we must let our default Apollo client know to use a different library. Keep in mind, this means your app cannot batch queries.

```javascript
/* componentMountIndex.js */

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      useGet: true,
    },
  ),
});
```

Finally, we can add a visibility check so that the component pauses polling when the browser tab is not active. This should lessen the request load on the page.

```javascript
/* component.vue */

import { toggleQueryPollingByVisibility } from '~/pipelines/components/graph/utils';

export default {
  mounted() {
    toggleQueryPollingByVisibility(this.$apollo.queries.pipeline, POLL_INTERVAL);
  },
};
```

You can use [this MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/59672/) as a reference on how to fully implement ETag caching on the frontend.

Once subscriptions are mature, this process can be replaced by using them and we can remove the separate link library and return to batching queries.

##### How to test ETag caching

You can test that your implementation works by checking requests on the network tab. If there are no changes in your ETag resource, all polled requests should:

- Be `GET` requests instead of `POST` requests.
- Have an HTTP status of `304` instead of `200`.

Make sure that caching is not disabled in your developer tools when testing.

If you are using Chrome and keep seeing `200` HTTP status codes, it might be this bug: [Developer tools show 200 instead of 304](https://bugs.chromium.org/p/chromium/issues/detail?id=1269602). In this case, inspect the response headers' source to confirm that the request was actually cached and did return with a `304` status code.

#### Subscriptions

We use [subscriptions](https://www.apollographql.com/docs/react/data/subscriptions/) to receive real-time updates from GraphQL API via websockets. Currently, the number of existing subscriptions is limited, you can check a list of available ones in [GraphqiQL explorer](https://gitlab.com/-/graphql-explorer)

**NOTE:**
We cannot test subscriptions using GraphiQL, because they require an ActionCable client, which GraphiQL does not support at the moment.

Subscriptions don't require any additional configuration of Apollo Client instance, you can use them in the application right away. To distinguish subscriptions from queries and mutations, we recommend naming them with `.subscription.graphql` extension:

```graphql
// ~/sidebar/queries/issuable_assignees.subscription.graphql

subscription issuableAssigneesUpdated($issuableId: IssuableID!) {
  issuableAssigneesUpdated(issuableId: $issuableId) {
    ... on Issue {
      assignees {
        nodes {
          ...User
          status {
            availability
          }
        }
      }
    }
  }
}
```

When using GraphQL subscriptions in Vue application, we recommend updating existing Apollo query results with [subscribeToMore](https://apollo.vuejs.org/guide/apollo/subscriptions.html#subscribe-to-more) option:

```javascript
import issuableAssigneesSubscription from '~/sidebar/queries/issuable_assignees.subscription.graphql'

apollo: {
  issuable: {
    query() {
      return assigneesQueries[this.issuableType].query;
    },
    subscribeToMore: {
      // Specify the subscription that will update the query
      document() {
        return issuableAssigneesSubscription;
      },
      variables() {
        return {
          issuableId: convertToGraphQLId(this.issuableClass, this.issuableId),
        };
      },
    },
  },
},
```

We would need also to define a field policy similarly like we do it for the [paginated queries](#defining-field-merge-policy)

### Best Practices

#### When to use (and not use) `update` hook in mutations

Apollo Client's [`.mutate()`](https://www.apollographql.com/docs/react/api/core/ApolloClient/#ApolloClient.mutate)
method exposes an `update` hook that is invoked twice during the mutation lifecycle:

- Once at the beginning. That is, before the mutation has completed.
- Once after the mutation has completed.

You should use this hook only if you're adding or removing an item from the store
(that is, ApolloCache). If you're _updating_ an existing item, it is usually represented by
a global `id`.

In that case, presence of this `id` in your mutation query definition makes the store update
automatically. Here's an example of a typical mutation query with `id` present in it:

```graphql
mutation issueSetWeight($input: IssueSetWeightInput!) {
  issuableSetWeight: issueSetWeight(input: $input) {
    issuable: issue {
      id
      weight
    }
    errors
  }
}
```

### Testing

#### Generating the GraphQL schema

Some of our tests load the schema JSON files. To generate these files, run:

```shell
bundle exec rake gitlab:graphql:schema:dump
```

You should run this task after pulling from upstream, or when rebasing your
branch. This is run automatically as part of `gdk update`.

NOTE:
If you use the RubyMine IDE, and have marked the `tmp` directory as
"Excluded", you should "Mark Directory As -> Not Excluded" for
`gitlab/tmp/tests/graphql`. This will allow the **JS GraphQL** plugin to
automatically find and index the schema.

#### Testing Apollo components

If we use `ApolloQuery` or `ApolloMutation` in our components, in order to test their functionality we need to add a stub first:

```javascript
import { ApolloMutation } from 'vue-apollo';

function createComponent(props = {}) {
  wrapper = shallowMount(MyComponent, {
    sync: false,
    propsData: {
      ...props,
    },
    stubs: {
      ApolloMutation,
    },
  });
}
```

`ApolloMutation` component exposes `mutate` method via scoped slot. If we want to test this method, we need to add it to mocks:

```javascript
const mutate = jest.fn().mockResolvedValue();
const $apollo = {
  mutate,
};

function createComponent(props = {}) {
  wrapper = shallowMount(MyComponent, {
    sync: false,
    propsData: {
      ...props,
    },
    stubs: {
      ApolloMutation,
    },
    mocks: {
      $apollo,
    }
  });
}
```

Then we can check if `mutate` is called with correct variables:

```javascript
const mutationVariables = {
  mutation: createNoteMutation,
  update: expect.anything(),
  variables: {
    input: {
      noteableId: 'noteable-id',
      body: 'test',
      discussionId: '0',
    },
  },
};

it('calls mutation on submitting form ', () => {
  createComponent()
  findReplyForm().vm.$emit('submitForm');

  expect(mutate).toHaveBeenCalledWith(mutationVariables);
});
```

#### Mocking Apollo Client

To test the components with Apollo operations, we need to mock an Apollo Client in our unit tests. We use [`mock-apollo-client`](https://www.npmjs.com/package/mock-apollo-client) library to mock Apollo client and [`createMockApollo` helper](https://gitlab.com/gitlab-org/gitlab/-/blob/master/spec/frontend/__helpers__/mock_apollo_helper.js) we created on top of it.

We need to inject `VueApollo` into the Vue instance by calling `Vue.use(VueApollo)`. This will install `VueApollo` globally for all the tests in the file. It is recommended to call `Vue.use(VueApollo)` just after the imports.

```javascript
import VueApollo from 'vue-apollo';
import Vue from 'vue';

Vue.use(VueApollo);

function createMockApolloProvider() {
  return createMockApollo(requestHandlers);
}

function createComponent(options = {}) {
  const { mockApollo } = options;
  ...
  return shallowMount(..., {
    apolloProvider: mockApollo,
    ...
  });
}
```

After this, you can control whether you need a variable for `mockApollo` and assign it in the appropriate `describe`-scope:

```javascript
describe('Some component', () => {
  let wrapper;

  describe('with Apollo mock', () => {
    let mockApollo;

    beforeEach(() => {
      mockApollo = createMockApolloProvider();
      wrapper = createComponent({ mockApollo });
    });
  });
});
```

In the `createMockApolloProvider`-factory, we need to define an array of _handlers_ for every query or mutation:

```javascript
import getDesignListQuery from '~/design_management/graphql/queries/get_design_list.query.graphql';
import permissionsQuery from '~/design_management/graphql/queries/design_permissions.query.graphql';
import moveDesignMutation from '~/design_management/graphql/mutations/move_design.mutation.graphql';

describe('Some component with Apollo mock', () => {
  let wrapper;
  let mockApollo;

  function createMockApolloProvider() {
    Vue.use(VueApollo);

    const requestHandlers = [
      [getDesignListQuery, jest.fn().mockResolvedValue(designListQueryResponse)],
      [permissionsQuery, jest.fn().mockResolvedValue(permissionsQueryResponse)],
    ];
    ...
  }
})
```

After this, we need to create a mock Apollo Client instance using a helper:

```javascript
import createMockApollo from 'helpers/mock_apollo_helper';

describe('Some component', () => {
  let wrapper;

  function createMockApolloProvider() {
    Vue.use(VueApollo);

    const requestHandlers = [
      [getDesignListQuery, jest.fn().mockResolvedValue(designListQueryResponse)],
      [permissionsQuery, jest.fn().mockResolvedValue(permissionsQueryResponse)],
    ];

    return createMockApollo(requestHandlers);
  }

  function createComponent(options = {}) {
    const { mockApollo } = options;

    return shallowMount(Index, {
      apolloProvider: mockApollo,
    });
  }

  describe('with Apollo mock', () => {
    let mockApollo;

    beforeEach(() => {
      mockApollo = createMockApolloProvider();
      wrapper = createComponent({ mockApollo });
    });
  });
});
```

When mocking resolved values, ensure the structure of the response is the same
as the actual API response. For example, root property should be `data`.

When testing queries, please keep in mind they are promises, so they need to be _resolved_ to render a result. Without resolving, we can check the `loading` state of the query:

```javascript
it('renders a loading state', () => {
  const mockApollo = createMockApolloProvider();
  const wrapper = createComponent({ mockApollo });

  expect(wrapper.findComponent(LoadingSpinner).exists()).toBe(true)
});

it('renders designs list', async () => {
  const mockApollo = createMockApolloProvider();
  const wrapper = createComponent({ mockApollo });

  await waitForPromises()

  expect(findDesigns()).toHaveLength(3);
});
```

If we need to test a query error, we need to mock a rejected value as request handler:

```javascript
function createMockApolloProvider() {
  ...
  const requestHandlers = [
    [getDesignListQuery, jest.fn().mockRejectedValue(new Error('GraphQL error')],
  ];
  ...
}
...

it('renders error if query fails', async () => {
  const wrapper = createComponent();

  await waitForPromises()

  expect(wrapper.find('.test-error').exists()).toBe(true)
})
```

Request handlers can also be passed to component factory as a parameter.

Mutations could be tested the same way:

```javascript
function createMockApolloProvider({
  moveHandler = jest.fn().mockResolvedValue(moveDesignMutationResponse),
}) {
  Vue.use(VueApollo);

  moveDesignHandler = moveHandler;

  const requestHandlers = [
    [getDesignListQuery, jest.fn().mockResolvedValue(designListQueryResponse)],
    [permissionsQuery, jest.fn().mockResolvedValue(permissionsQueryResponse)],
    [moveDesignMutation, moveDesignHandler],
  ];

  return createMockApollo(requestHandlers);
}

function createComponent(options = {}) {
  const { mockApollo } = options;

  return shallowMount(Index, {
    apolloProvider: mockApollo,
  });
}
...
it('calls a mutation with correct parameters and reorders designs', async () => {
  const mockApollo = createMockApolloProvider({});
  const wrapper = createComponent({ mockApollo });

  wrapper.find(VueDraggable).vm.$emit('change', {
    moved: {
      newIndex: 0,
      element: designToMove,
    },
  });

  expect(moveDesignHandler).toHaveBeenCalled();

  await waitForPromises();

  expect(
    findDesigns()
      .at(0)
      .props('id'),
  ).toBe('2');
});
```

To mock multiple query response states, success and failure, Apollo Client's native retry behavior can combine with Jest's mock functions to create a series of responses. These do not need to be advanced manually, but they do need to be awaited in specific fashion.

```javascript
describe('when query times out', () => {
  const advanceApolloTimers = async () => {
    jest.runOnlyPendingTimers();
    await waitForPromises()
  };

  beforeEach(async () => {
    const failSucceedFail = jest
      .fn()
      .mockResolvedValueOnce({ errors: [{ message: 'timeout' }] })
      .mockResolvedValueOnce(mockPipelineResponse)
      .mockResolvedValueOnce({ errors: [{ message: 'timeout' }] });

    createComponentWithApollo(failSucceedFail);
    await waitForPromises();
  });

  it('shows correct errors and does not overwrite populated data when data is empty', async () => {
    /* fails at first, shows error, no data yet */
    expect(getAlert().exists()).toBe(true);
    expect(getGraph().exists()).toBe(false);

    /* succeeds, clears error, shows graph */
    await advanceApolloTimers();
    expect(getAlert().exists()).toBe(false);
    expect(getGraph().exists()).toBe(true);

    /* fails again, alert returns but data persists */
    await advanceApolloTimers();
    expect(getAlert().exists()).toBe(true);
    expect(getGraph().exists()).toBe(true);
  });
});
```

#### Testing `@client` queries

##### Using mock resolvers

If your application contains `@client` queries, you get
the following Apollo Client warning when passing only handlers:

```shell
Unexpected call of console.warn() with:
Warning: mock-apollo-client - The query is entirely client-side (using @client directives) and resolvers have been configured. The request handler will not be called.
```

To fix this you should define mock `resolvers` instead of
mock `handlers`. For example, given the following `@client` query:

```graphql
query getBlobContent($path: String, $ref: String!) {
  blobContent(path: $path, ref: $ref) @client {
    rawData
  }
}
```

And its actual client-side resolvers:

```javascript
import Api from '~/api';

export const resolvers = {
  Query: {
    blobContent(_, { path, ref }) {
      return {
        __typename: 'BlobContent',
        rawData: Api.getRawFile(path, { ref }).then(({ data }) => {
          return data;
        }),
      };
    },
  },
};

export default resolvers;
```

We can use a **mock resolver** that returns data with the
same shape, while mock the result with a mock function:

```javascript
let mockApollo;
let mockBlobContentData; // mock function, jest.fn();

const mockResolvers = {
  Query: {
    blobContent() {
      return {
        __typename: 'BlobContent',
        rawData: mockBlobContentData(), // the mock function can resolve mock data
      };
    },
  },
};

const createComponentWithApollo = ({ props = {} } = {}) => {
  mockApollo = createMockApollo([], mockResolvers); // resolvers are the second parameter

  wrapper = shallowMount(MyComponent, {
    propsData: {},
    apolloProvider: mockApollo,
    // ...
  })
};

```

After which, you can resolve or reject the value needed.

```javascript
beforeEach(() => {
  mockBlobContentData = jest.fn();
});

it('shows data', async() => {
  mockBlobContentData.mockResolvedValue(data); // you may resolve or reject to mock the result

  createComponentWithApollo();

  await waitForPromises(); // wait on the resolver mock to execute

  expect(findContent().text()).toBe(mockCiYml);
});
```

##### Using `cache.writeQuery`

Sometimes we want to test a `result` hook of the local query. In order to have it triggered, we need to populate a cache with correct data to be fetched with this query:

```javascript
query fetchLocalUser {
  fetchLocalUser @client {
    name
  }
}
```

```javascript
import fetchLocalUserQuery from '~/design_management/graphql/queries/fetch_local_user.query.graphql';

function createMockApolloProvider() {
  Vue.use(VueApollo);

  const requestHandlers = [
    [getDesignListQuery, jest.fn().mockResolvedValue(designListQueryResponse)],
    [permissionsQuery, jest.fn().mockResolvedValue(permissionsQueryResponse)],
  ];

  const mockApollo = createMockApollo(requestHandlers, {});
  mockApollo.clients.defaultClient.cache.writeQuery({
    query: fetchLocalUserQuery,
    data: {
      fetchLocalUser: {
        __typename: 'User',
        name: 'Test',
      },
    },
  });

  return mockApollo;
}

function createComponent(options = {}) {
  const { mockApollo } = options;

  return shallowMount(Index, {
    apolloProvider: mockApollo,
  });
}
```

Sometimes it is necessary to control what the local resolver returns and inspect how it is called by the component. This can be done by mocking your local resolver:

```javascript
import fetchLocalUserQuery from '~/design_management/graphql/queries/fetch_local_user.query.graphql';

function createMockApolloProvider(options = {}) {
  Vue.use(VueApollo);
  const { fetchLocalUserSpy } = options;

  const mockApollo = createMockApollo([], {
    Query: {
      fetchLocalUser: fetchLocalUserSpy,
    },
  });

  // Necessary for local resolvers to be activated
  mockApollo.clients.defaultClient.cache.writeQuery({
    query: fetchLocalUserQuery,
    data: {},
  });

  return mockApollo;
}
```

In the test you can then control what the spy is supposed to do and inspect the component after the request have returned:

```javascript
describe('My Index test with `createMockApollo`', () => {
  let wrapper;
  let fetchLocalUserSpy;

  afterEach(() => {
    wrapper.destroy();
    fetchLocalUserSpy = null;
  });

  describe('when loading', () => {
    beforeEach(() => {
      const mockApollo = createMockApolloProvider();
      wrapper = createComponent({ mockApollo });
    });

    it('displays the loader', () => {
      // Assess that the loader is present
    });
  });

  describe('with data', () => {
    beforeEach(async () => {
      fetchLocalUserSpy = jest.fn().mockResolvedValue(localUserQueryResponse);
      const mockApollo = createMockApolloProvider(fetchLocalUserSpy);
      wrapper = createComponent({ mockApollo });
      await waitForPromises();
    });

    it('should fetch data once', () => {
      expect(fetchLocalUserSpy).toHaveBeenCalledTimes(1);
    });

    it('displays data', () => {
      // Assess that data is present
    });
  });

  describe('with error', () => {
    const error = 'Error!';

    beforeEach(async () => {
      fetchLocalUserSpy = jest.fn().mockRejectedValueOnce(error);
      const mockApollo = createMockApolloProvider(fetchLocalUserSpy);
      wrapper = createComponent({ mockApollo });
      await waitForPromises();
    });

    it('should fetch data once', () => {
      expect(fetchLocalUserSpy).toHaveBeenCalledTimes(1);
    });

    it('displays the error', () => {
      // Assess that the error is displayed
    });
  });
});
```

When you need to configure the mocked apollo client's caching behavior,
provide additional cache options when creating a mocked client instance and the provided options will merge with the default cache option:

```javascript
const defaultCacheOptions = {
  fragmentMatcher: { match: () => true },
  addTypename: false,
};
```

```javascript
function createMockApolloProvider({ props = {}, requestHandlers } = {}) {
  Vue.use(VueApollo);

  const mockApollo = createMockApollo(
    requestHandlers,
    {},
    {
      dataIdFromObject: (object) =>
        // eslint-disable-next-line no-underscore-dangle
        object.__typename === 'Requirement' ? object.iid : defaultDataIdFromObject(object),
    },
  );

  return mockApollo;
}
```

## Handling errors

The GitLab GraphQL mutations have two distinct error modes: [Top-level](#top-level-errors) and [errors-as-data](#errors-as-data).

When utilising a GraphQL mutation, consider handling **both of these error modes** to ensure that the user receives the appropriate feedback when an error occurs.

### Top-level errors

These errors are located at the "top level" of a GraphQL response. These are non-recoverable errors including argument errors and syntax errors, and should not be presented directly to the user.

#### Handling top-level errors

Apollo is aware of top-level errors, so we are able to leverage Apollo's various error-handling mechanisms to handle these errors. For example, handling Promise rejections after invoking the [`mutate`](https://www.apollographql.com/docs/react/api/core/ApolloClient/#ApolloClient.mutate) method, or handling the `error` event emitted from the [`ApolloMutation`](https://apollo.vuejs.org/api/apollo-mutation.html#events) component.

Because these errors are not intended for users, error messages for top-level errors should be defined client-side.

### Errors-as-data

These errors are nested in the `data` object of a GraphQL response. These are recoverable errors that, ideally, can be presented directly to the user.

#### Handling errors-as-data

First, we must add `errors` to our mutation object:

```diff
mutation createNoteMutation($input: String!) {
  createNoteMutation(input: $input) {
    note {
      id
+     errors
    }
  }
```

Now, when we commit this mutation and errors occur, the response includes `errors` for us to handle:

```javascript
{
  data: {
    mutationName: {
      errors: ["Sorry, we were not able to update the note."]
    }
  }
}
```

When handling errors-as-data, use your best judgement to determine whether to present the error message in the response, or another message defined client-side, to the user.

## Usage outside of Vue

It is also possible to use GraphQL outside of Vue by directly importing
and using the default client with queries.

```javascript
import createDefaultClient from '~/lib/graphql';
import query from './query.graphql';

const defaultClient = createDefaultClient();

defaultClient.query({ query })
  .then(result => console.log(result));
```

When [using Vuex](#using-with-vuex), disable the cache when:

- The data is being cached elsewhere
- The use case does not need caching
if the data is being cached elsewhere, or if there is no need for it for the given use case.

```javascript
import createDefaultClient from '~/lib/graphql';
import fetchPolicies from '~/graphql_shared/fetch_policy_constants';

const defaultClient = createDefaultClient(
  {},
  {
    fetchPolicy: fetchPolicies.NO_CACHE,
  },
);
```

## Making initial queries early with GraphQL startup calls

To improve performance, sometimes we want to make initial GraphQL queries early. In order to do this, we can add them to **startup calls** with the following steps:

- Move all the queries you need initially in your application to `app/graphql/queries`;
- Add `__typename` property to every nested query level:

  ```javascript
  query getPermissions($projectPath: ID!) {
    project(fullPath: $projectPath) {
      __typename
      userPermissions {
        __typename
        pushCode
        forkProject
        createMergeRequestIn
      }
    }
  }
  ```

- If queries contain fragments, you need to move fragments to the query file directly instead of importing them:

  ```javascript
  fragment PageInfo on PageInfo {
    __typename
    hasNextPage
    hasPreviousPage
    startCursor
    endCursor
  }

  query getFiles(
    $projectPath: ID!
    $path: String
    $ref: String!
  ) {
    project(fullPath: $projectPath) {
      __typename
      repository {
        __typename
        tree(path: $path, ref: $ref) {
          __typename
            pageInfo {
              ...PageInfo
            }
          }
        }
      }
    }
  }
  ```

- If the fragment is used only once, we can also remove the fragment altogether:

  ```javascript
  query getFiles(
    $projectPath: ID!
    $path: String
    $ref: String!
  ) {
    project(fullPath: $projectPath) {
      __typename
      repository {
        __typename
        tree(path: $path, ref: $ref) {
          __typename
            pageInfo {
              __typename
              hasNextPage
              hasPreviousPage
              startCursor
              endCursor
            }
          }
        }
      }
    }
  }
  ```

- Add startup call(s) with correct variables to the HAML file that serves as a view
for your application. To add GraphQL startup calls, we use
`add_page_startup_graphql_call` helper where the first parameter is a path to the
query, the second one is an object containing query variables. Path to the query is
relative to `app/graphql/queries` folder: for example, if we need a
`app/graphql/queries/repository/files.query.graphql` query, the path is
`repository/files`.

## Troubleshooting

### Mocked client returns empty objects instead of mock response

If your unit test is failing because response contains empty objects instead of mock data, you would need to add `__typename` field to the mocked response. This happens because mocked client (unlike the real one) does not populate the response with typenames and in some cases we need to do it manually so the client is able to recognize a GraphQL type.

### Warning about losing cache data

Sometimes you can see a warning in the console: `Cache data may be lost when replacing the someProperty field of a Query object. To address this problem, either ensure all objects of SomeEntityhave an id or a custom merge function`. Please check section about [multiple queries](#multiple-client-queries-for-the-same-object) to resolve an issue.

  ```yaml
  - current_route_path = request.fullpath.match(/-\/tree\/[^\/]+\/(.+$)/).to_a[1]
  - add_page_startup_graphql_call('repository/path_last_commit', { projectPath: @project.full_path, ref: current_ref, path: current_route_path || "" })
  - add_page_startup_graphql_call('repository/permissions', { projectPath: @project.full_path })
  - add_page_startup_graphql_call('repository/files', { nextPageCursor: "", pageSize: 100, projectPath: @project.full_path, ref: current_ref, path: current_route_path || "/"})
  ```
