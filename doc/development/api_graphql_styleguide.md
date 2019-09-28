# GraphQL API

## Deep Dive

In March 2019, Nick Thomas hosted a [Deep Dive](https://gitlab.com/gitlab-org/create-stage/issues/1)
on GitLab's [GraphQL API](../api/graphql/index.md) to share his domain specific knowledge
with anyone who may work in this part of the code base in the future. You can find the
[recording on YouTube](https://www.youtube.com/watch?v=-9L_1MWrjkg), and the slides on
[Google Slides](https://docs.google.com/presentation/d/1qOTxpkTdHIp1CRjuTvO-aXg0_rUtzE3ETfLUdnBB5uQ/edit)
and in [PDF](https://gitlab.com/gitlab-org/create-stage/uploads/8e78ea7f326b2ef649e7d7d569c26d56/GraphQL_Deep_Dive__Create_.pdf).
Everything covered in this deep dive was accurate as of GitLab 11.9, and while specific
details may have changed since then, it should still serve as a good introduction.

## Authentication

Authentication happens through the `GraphqlController`, right now this
uses the same authentication as the Rails application. So the session
can be shared.

It is also possible to add a `private_token` to the querystring, or
add a `HTTP_PRIVATE_TOKEN` header.

## Types

When exposing a model through the GraphQL API, we do so by creating a
new type in `app/graphql/types`.

When exposing properties in a type, make sure to keep the logic inside
the definition as minimal as possible. Instead, consider moving any
logic into a presenter:

```ruby
class Types::MergeRequestType < BaseObject
  present_using MergeRequestPresenter

  name 'MergeRequest'
end
```

An existing presenter could be used, but it is also possible to create
a new presenter specifically for GraphQL.

The presenter is initialized using the object resolved by a field, and
the context.

### Exposing Global ids

When exposing an `id` field on a type, we will by default try to
expose a global id by calling `to_global_id` on the resource being
rendered.

To override this behaviour, you can implement an `id` method on the
type for which you are exposing an id. Please make sure that when
exposing a `GraphQL::ID_TYPE` using a custom method that it is
globally unique.

The records that are exposing a `full_path` as an `ID_TYPE` are one of
these exceptions. Since the full path is a unique identifier for a
`Project` or `Namespace`.

### Connection Types

GraphQL uses [cursor based
pagination](https://graphql.org/learn/pagination/#pagination-and-edges)
to expose collections of items. This provides the clients with a lot
of flexibility while also allowing the backend to use different
pagination models.

To expose a collection of resources we can use a connection type. This wraps the array with default pagination fields. For example a query for project-pipelines could look like this:

```
query($project_path: ID!) {
  project(fullPath: $project_path) {
    pipelines(first: 2) {
      pageInfo {
        hasNextPage
        hasPreviousPage
      }
      edges {
        cursor
        node {
          id
          status
        }
      }
    }
  }
}
```

This would return the first 2 pipelines of a project and related
pagination info., ordered by descending ID. The returned data would
look like this:

```json
{
  "data": {
    "project": {
      "pipelines": {
        "pageInfo": {
          "hasNextPage": true,
          "hasPreviousPage": false
        },
        "edges": [
          {
            "cursor": "Nzc=",
            "node": {
              "id": "gid://gitlab/Pipeline/77",
              "status": "FAILED"
            }
          },
          {
            "cursor": "Njc=",
            "node": {
              "id": "gid://gitlab/Pipeline/67",
              "status": "FAILED"
            }
          }
        ]
      }
    }
  }
}
```

To get the next page, the cursor of the last known element could be
passed:

```
query($project_path: ID!) {
  project(fullPath: $project_path) {
    pipelines(first: 2, after: "Njc=") {
      pageInfo {
        hasNextPage
        hasPreviousPage
      }
      edges {
        cursor
        node {
          id
          status
        }
      }
    }
  }
}
```

### Exposing permissions for a type

To expose permissions the current user has on a resource, you can call
the `expose_permissions` passing in a separate type representing the
permissions for the resource.

For example:

```ruby
module Types
  class MergeRequestType < BaseObject
    expose_permissions Types::MergeRequestPermissionsType
  end
end
```

The permission type inherits from `BasePermissionType` which includes
some helper methods, that allow exposing permissions as non-nullable
booleans:

```ruby
class MergeRequestPermissionsType < BasePermissionType
  present_using MergeRequestPresenter

  graphql_name 'MergeRequestPermissions'

  abilities :admin_merge_request, :update_merge_request, :create_note

  ability_field :resolve_note,
                description: 'Whether or not the user can resolve disussions on the merge request'
  permission_field :push_to_source_branch, method: :can_push_to_source_branch?
end
```

- **`permission_field`**: Will act the same as `graphql-ruby`'s
  `field` method but setting a default description and type and making
  them non-nullable. These options can still be overridden by adding
  them as arguments.
- **`ability_field`**: Expose an ability defined in our policies. This
  takes behaves the same way as `permission_field` and the same
  arguments can be overridden.
- **`abilities`**: Allows exposing several abilities defined in our
  policies at once. The fields for these will all have be non-nullable
  booleans with a default description.

## Enums

GitLab GraphQL enums are defined in `app/graphql/types`. When defining new enums, the
following rules apply:

- Values must be uppercase.
- Class names must end with the string `Enum`.
- The `graphql_name` must not contain the string `Enum`.

For example:

```ruby
module Types
  class TrafficLightStateEnum < BaseEnum
    graphql_name 'TrafficLightState'
    description 'State of a traffic light'

    value 'RED', description: 'Drivers must stop'
    value 'YELLOW', description: 'Drivers must stop when it is safe to'
    value 'GREEN', description: 'Drivers can start or keep driving'
  end
end
```

If the enum will be used for a class property in Ruby that is not an uppercase string,
you can provide a `value:` option that will adapt the uppercase value.

In the following example:

- GraphQL inputs of `OPENED` will be converted to `'opened'`.
- Ruby values of `'opened'` will be converted to `"OPENED"` in GraphQL responses.

```ruby
module Types
  class EpicStateEnum < BaseEnum
    graphql_name 'EpicState'
    description 'State of a GitLab epic'

    value 'OPENED', value: 'opened', description: 'An open Epic'
    value 'CLOSED', value: 'closed', description: 'An closed Epic'
  end
end

```

## Authorization

Authorizations can be applied to both types and fields using the same
abilities as in the Rails app.

If the:

- Currently authenticated user fails the authorization, the authorized
  resource will be returned as `null`.
- Resource is part of a collection, the collection will be filtered to
  exclude the objects that the user's authorization checks failed against.

TIP: **Tip:**
Try to load only what the currently authenticated user is allowed to
view with our existing finders first, without relying on authorization
to filter the records. This minimizes database queries and unnecessary
authorization checks of the loaded records.

### Type authorization

Authorize a type by passing an ability to the `authorize` method. All
fields with the same type will be authorized by checking that the
currently authenticated user has the required ability.

For example, the following authorization ensures that the currently
authenticated user can only see projects that they have the
`read_project` ability for (so long as the project is returned in a
field that uses `Types::ProjectType`):

```ruby
module Types
  class ProjectType < BaseObject
    authorize :read_project
  end
end
```

You can also authorize against multiple abilities, in which case all of
the ability checks must pass.

For example, the following authorization ensures that the currently
authenticated user must have `read_project` and `another_ability`
abilities to see a project:

```ruby
module Types
  class ProjectType < BaseObject
    authorize [:read_project, :another_ability]
  end
end
```

### Field authorization

Fields can be authorized with the `authorize` option.

For example, the following authorization ensures that the currently
authenticated user must have the `owner_access` ability to see the
project:

```ruby
module Types
  class MyType < BaseObject
    field :project, Types::ProjectType, null: true, resolver: Resolvers::ProjectResolver, authorize: :owner_access
  end
end
```

Fields can also be authorized against multiple abilities, in which case
all of ability checks must pass. **Note:** This requires explicitly
passing a block to `field`:

```ruby
module Types
  class MyType < BaseObject
    field :project, Types::ProjectType, null: true, resolver: Resolvers::ProjectResolver do
      authorize [:owner_access, :another_ability]
    end
  end
end
```

NOTE: **Note:** If the field's type already [has a particular
authorization](#type-authorization) then there is no need to add that
same authorization to the field.

### Type and Field authorizations together

Authorizations are cumulative, so where authorizations are defined on
a field, and also on the field's type, then the currently authenticated
user would need to pass all ability checks.

In the following simplified example the currently authenticated user
would need both `first_permission` and `second_permission` abilities in
order to see the author of the issue.

```ruby
class UserType
  authorize :first_permission
end
```

```ruby
class IssueType
  field :author, UserType, authorize: :second_permission
end
```

## Resolvers

To find objects to display in a field, we can add resolvers to
`app/graphql/resolvers`.

Arguments can be defined within the resolver, those arguments will be
made available to the fields using the resolver.

We already have a `FullPathLoader` that can be included in other
resolvers to quickly find Projects and Namespaces which will have a
lot of dependant objects.

To limit the amount of queries performed, we can use `BatchLoader`.

## Mutations

Mutations are used to change any stored values, or to trigger
actions. In the same way a GET-request should not modify data, we
cannot modify data in a regular GraphQL-query. We can however in a
mutation.

### Fields

In the most common situations, a mutation would return 2 fields:

- The resource being modified
- A list of errors explaining why the action could not be
  performed. If the mutation succeeded, this list would be empty.

By inheriting any new mutations from `Mutations::BaseMutation` the
`errors` field is automatically added. A `clientMutationId` field is
also added, this can be used by the client to identify the result of a
single mutation when multiple are performed within a single request.

### Building Mutations

Mutations live in `app/graphql/mutations` ideally grouped per
resources they are mutating, similar to our services. They should
inherit `Mutations::BaseMutation`. The fields defined on the mutation
will be returned as the result of the mutation.

Always provide a consistent GraphQL-name to the mutation, this name is
used to generate the input types and the field the mutation is mounted
on. The name should look like `<Resource being modified><Mutation
class name>`, for example the `Mutations::MergeRequests::SetWip`
mutation has GraphQL name `MergeRequestSetWip`.

Arguments required by the mutation can be defined as arguments
required for a field. These will be wrapped up in an input type for
the mutation. For example, the `Mutations::MergeRequests::SetWip`
with GraphQL-name `MergeRequestSetWip` defines these arguments:

```ruby
argument :project_path, GraphQL::ID_TYPE,
         required: true,
         description: "The project the merge request to mutate is in"

argument :iid, GraphQL::STRING_TYPE,
         required: true,
         description: "The iid of the merge request to mutate"

argument :wip,
         GraphQL::BOOLEAN_TYPE,
         required: false,
         description: <<~DESC
                      Whether or not to set the merge request as a WIP.
                      If not passed, the value will be toggled.
                      DESC
```

This would automatically generate an input type called
`MergeRequestSetWipInput` with the 3 arguments we specified and the
`clientMutationId`.

These arguments are then passed to the `resolve` method of a mutation
as keyword arguments. From here, we can call the service that will
modify the resource.

The `resolve` method should then return a hash with the same field
names as defined on the mutation and an `errors` array. For example,
the `Mutations::MergeRequests::SetWip` defines a `merge_request`
field:

```ruby
field :merge_request,
      Types::MergeRequestType,
      null: true,
      description: "The merge request after mutation"
```

This means that the hash returned from `resolve` in this mutation
should look like this:

```ruby
{
  # The merge request modified, this will be wrapped in the type
  # defined on the field
  merge_request: merge_request,
  # An array if strings if the mutation failed after authorization
  errors: merge_request.errors.full_messages
}
```

To make the mutation available it should be defined on the mutation
type that lives in `graphql/types/mutation_types`. The
`mount_mutation` helper method will define a field based on the
GraphQL-name of the mutation:

```ruby
module Types
  class MutationType < BaseObject
    include Gitlab::Graphql::MountMutation

    graphql_name "Mutation"

    mount_mutation Mutations::MergeRequests::SetWip
  end
end
```

Will generate a field called `mergeRequestSetWip` that
`Mutations::MergeRequests::SetWip` to be resolved.

### Authorizing resources

To authorize resources inside a mutation, we first provide the required
 abilities on the mutation like this:

```ruby
module Mutations
  module MergeRequests
    class SetWip < Base
      graphql_name 'MergeRequestSetWip'

      authorize :update_merge_request
    end
  end
end
```

We can then call `authorize!` in the `resolve` method, passing in the resource we
want to validate the abilities for.

Alternatively, we can add a `find_object` method that will load the
object on the mutation. This would allow you to use the
`authorized_find!` helper method.

When a user is not allowed to perform the action, or an object is not
found, we should raise a
`Gitlab::Graphql::Errors::ResourceNotAvailable` error. Which will be
correctly rendered to the clients.

## Testing

_full stack_ tests for a graphql query or mutation live in
`spec/requests/api/graphql`.

When adding a query, the `a working graphql query` shared example can
be used to test if the query renders valid results.

Using the `GraphqlHelpers#all_graphql_fields_for`-helper, a query
including all available fields can be constructed. This makes it easy
to add a test rendering all possible fields for a query.

To test GraphQL mutation requests, `GraphqlHelpers` provides 2
helpers: `graphql_mutation` which takes the name of the mutation, and
a hash with the input for the mutation. This will return a struct with
a mutation query, and prepared variables.

This struct can then be passed to the `post_graphql_mutation` helper,
that will post the request with the correct params, like a GraphQL
client would do.

To access the response of a mutation, the `graphql_mutation_response`
helper is available.

Using these helpers, we can build specs like this:

```ruby
let(:mutation) do
  graphql_mutation(
    :merge_request_set_wip,
    project_path: 'gitlab-org/gitlab-ce',
    iid: '1',
    wip: true
  )
end

it 'returns a successful response' do
   post_graphql_mutation(mutation, current_user: user)

   expect(response).to have_gitlab_http_status(:success)
   expect(graphql_mutation_response(:merge_request_set_wip)['errors']).to be_empty
end
```
