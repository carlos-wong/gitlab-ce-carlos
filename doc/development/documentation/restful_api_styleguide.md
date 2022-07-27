---
info: For assistance with this Style Guide page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments-to-other-projects-and-subjects.
stage: none
group: unassigned
description: 'Writing styles, markup, formatting, and other standards for the GitLab RESTful APIs.'
---

# RESTful API

REST API resources are documented in Markdown under
[`/doc/api`](https://gitlab.com/gitlab-org/gitlab/-/tree/master/doc/api). Each
resource has its own Markdown file, which is linked from `api_resources.md`.

When modifying the Markdown, also update the corresponding
[OpenAPI definition](https://gitlab.com/gitlab-org/gitlab/-/tree/master/doc/api/openapi)
if one exists for the resource. If not, consider creating one. Match the latest
[OpenAPI 3.0.x specification](https://swagger.io/specification/). (For more
information, see the discussion in this
[issue](https://gitlab.com/gitlab-org/gitlab/-/issues/16023#note_370901810).)

In the Markdown doc for a resource (AKA endpoint):

- Every method must have the REST API request. For example:

  ```plaintext
  GET /projects/:id/repository/branches
  ```

- Every method must have a detailed [description of the attributes](#method-description).
- Every method must have a cURL example.
- Every method must have a detailed [description of the response body](#response-body-description).
- Every method must have a response body example (in JSON format).
- If an attribute is available only to higher level tiers than the other
  attributes, add the appropriate inline [tier badge](styleguide/index.md#product-tier-badges).
  Put the badge in the **Attribute** column, like the
  `**(<tier>)**` code in the following template.

## API topic template

Use the following template to help you get started. Be sure to list any
required attributes first in the table.

````markdown
## API name

> Version history note.

One or two sentence description of what endpoint does.

### Method title

> Version history note.

Description of the method.

```plaintext
METHOD /endpoint
```

Supported attributes:

| Attribute                | Type     | Required               | Description           |
|:-------------------------|:---------|:-----------------------|:----------------------|
| `attribute`              | datatype | **{check-circle}** Yes | Detailed description. |
| `attribute` **(<tier>)** | datatype | **{dotted-circle}** No | Detailed description. |
| `attribute`              | datatype | **{dotted-circle}** No | Detailed description. |
| `attribute`              | datatype | **{dotted-circle}** No | Detailed description. |

If successful, returns [`<status_code>`](../../api/index.md#status-codes) and the following
response attributes:

| Attribute                | Type     | Description           |
|:-------------------------|:---------|:----------------------|
| `attribute`              | datatype | Detailed description. |
| `attribute` **(<tier>)** | datatype | Detailed description. |

Example request:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/endpoint?parameters"
```

Example response:

```json
[
  {
  }
]
```
````

## Version history

Add [version history](versions.md#documenting-version-specific-features)
to describe new or updated API calls.

To add version history for an individual attribute, include it in the version history
for the section. For example:

```markdown
### Edit a widget

> `widget_message` [introduced](<link-to-issue>) in GitLab 14.3.
```

## Deprecations

To document the deprecation of an API endpoint, follow the steps to
[deprecate a page or topic](versions.md#deprecate-a-page-or-topic).

To deprecate an attribute:

1. Add a version history note.

   ```markdown
   > - `widget_name` [deprecated](<link-to-issue>) in GitLab 14.7.
   ```

1. Add inline deprecation text to the description.

   ```markdown
   | Attribute     | Type   | Required               | Description                                  |
   |:--------------|:-------|:-----------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------|
   | `widget_name` | string | **{dotted-circle}** No | [Deprecated](<link-to-issue>) in GitLab 14.7 and is planned for removal in 15.4. Use `widget_id` instead. The name of the widget. |
   ```

To widely announce a deprecation, or if it's a breaking change,
[update the deprecations and removals documentation](../deprecation_guidelines/#update-the-deprecations-and-removals-documentation).

## Method description

Use the following table headers to describe the methods. Attributes should
always be in code blocks using backticks (`` ` ``).

Sort the table by required attributes first, then alphabetically.

```markdown
| Attribute                    | Type          | Required               | Description                                         |
|:-----------------------------|:--------------|:-----------------------|:----------------------------------------------------|
| `title`                      | string        | **{check-circle}** Yes | Title of the issue.                                 |
| `assignee_ids` **(PREMIUM)** | integer array | **{dotted-circle}** No | IDs of the users to assign the issue to.            |
| `confidential`               | boolean       | **{dotted-circle}** No | Sets the issue to confidential. Default is `false`. |
```

Rendered example:

| Attribute                    | Type          | Required               | Description                                         |
|:-----------------------------|:--------------|:-----------------------|:----------------------------------------------------|
| `title`                      | string        | **{check-circle}** Yes | Title of the issue.                                 |
| `assignee_ids` **(PREMIUM)** | integer array | **{dotted-circle}** No | IDs of the users to assign the issue to.            |
| `confidential`               | boolean       | **{dotted-circle}** No | Sets the issue to confidential. Default is `false`. |

For information about writing attribute descriptions, see the [GraphQL API description style guide](../api_graphql_styleguide.md#description-style-guide).

## Response body description

Start the description with the following sentence, replacing `status code` with the
relevant [HTTP status code](../../api/index.md#status-codes), for example:

```markdown
If successful, returns [`200 OK`](../../api/index.md#status-codes) and the
following response attributes:
```

Use the following table headers to describe the response bodies. Attributes should
always be in code blocks using backticks (`` ` ``).

If the attribute is a complex type, like another object, represent sub-attributes
with dots (`.`), like `project.name` or `projects[].name` in case of an array.

Sort the table alphabetically.

```markdown
| Attribute                    | Type          | Description                               |
|:-----------------------------|:--------------|:------------------------------------------|
| `assignee_ids` **(PREMIUM)** | integer array | IDs of the users to assign the issue to.  |
| `confidential`               | boolean       | Whether the issue is confidential or not. |
| `title`                      | string        | Title of the issue.                       |
```

Rendered example:

| Attribute                    | Type          | Description                               |
|:-----------------------------|:--------------|:------------------------------------------|
| `assignee_ids` **(PREMIUM)** | integer array | IDs of the users to assign the issue to.  |
| `confidential`               | boolean       | Whether the issue is confidential or not. |
| `title`                      | string        | Title of the issue.                       |

For information about writing attribute descriptions, see the [GraphQL API description style guide](../api_graphql_styleguide.md#description-style-guide).

## cURL commands

- Use `https://gitlab.example.com/api/v4/` as an endpoint.
- Wherever needed use this personal access token: `<your_access_token>`.
- Always put the request first. `GET` is the default so you don't have to
  include it.
- Wrap the URL in double quotes (`"`).
- Prefer to use examples using the personal access token and don't pass data of
  username and password.

| Methods                                         | Description                                            |
|:------------------------------------------------|:-------------------------------------------------------|
| `--header "PRIVATE-TOKEN: <your_access_token>"` | Use this method as is, whenever authentication needed. |
| `--request POST`                                | Use this method when creating new objects.             |
| `--request PUT`                                 | Use this method when updating existing objects.        |
| `--request DELETE`                              | Use this method when removing existing objects.        |

## cURL Examples

The following sections include a set of [cURL](https://curl.se/) examples
you can use in the API documentation.

WARNING:
Do not use information for real users, URLs, or tokens. For documentation, refer to our
relevant style guide sections on [Fake user information](styleguide/index.md#fake-user-information),
[Fake URLs](styleguide/index.md#fake-urls), and [Fake tokens](styleguide/index.md#fake-tokens).

### Simple cURL command

Get the details of a group:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/gitlab-org"
```

### cURL example with parameters passed in the URL

Create a new project under the authenticated user's namespace:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects?name=foo"
```

### Post data using cURL's `--data`

Instead of using `--request POST` and appending the parameters to the URI, you
can use cURL's `--data` option. The example below will create a new project
`foo` under the authenticated user's namespace.

```shell
curl --data "name=foo" --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects"
```

### Post data using JSON content

This example creates a new group. Be aware of the use of single (`'`) and double
(`"`) quotes.

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --header "Content-Type: application/json" \
     --data '{"path": "my-group", "name": "My group"}' "https://gitlab.example.com/api/v4/groups"
```

For readability, you can also set up the `--data` by using the following format:

```shell
curl --request POST \
--url "https://gitlab.example.com/api/v4/groups" \
--header "content-type: application/json" \
--header "PRIVATE-TOKEN: <your_access_token>" \
--data '{
  "path": "my-group",
  "name": "My group"
}'
```

### Post data using form-data

Instead of using JSON or URL-encoding data, you can use `multipart/form-data` which
properly handles data encoding:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --form "title=ssh-key" \
     --form "key=ssh-rsa AAAAB3NzaC1yc2EA..." "https://gitlab.example.com/api/v4/users/25/keys"
```

The above example is run by and administrator and will add an SSH public key
titled `ssh-key` to user's account which has an ID of 25.

### Escape special characters

Spaces or slashes (`/`) may sometimes result to errors, thus it is recommended
to escape them when possible. In the example below we create a new issue which
contains spaces in its title. Observe how spaces are escaped using the `%20`
ASCII code.

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/42/issues?title=Hello%20Dude"
```

Use `%2F` for slashes (`/`).

### Pass arrays to API calls

The GitLab API sometimes accepts arrays of strings or integers. For example, to
exclude specific users when requesting a list of users for a project, you would
do something like this:

```shell
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" --data "skip_users[]=<user_id>" \
     --data "skip_users[]=<user_id>" "https://gitlab.example.com/api/v4/projects/<project_id>/users"
```
