# Snippets API

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/6373) in GitLab 8.15.

Snippets API operates on [snippets](../user/snippets.md).

## Snippet visibility level

Snippets in GitLab can be either private, internal, or public.
You can set it with the `visibility` field in the snippet.

Valid values for snippet visibility levels are:

| Visibility | Description                                         |
|:-----------|:----------------------------------------------------|
| `private`  | Snippet is visible only to the snippet creator.     |
| `internal` | Snippet is visible for any logged in user.          |
| `public`   | Snippet can be accessed without any authentication. |

## List all snippets for a user

Get a list of the current user's snippets.

```text
GET /snippets
```

Example request:

```sh
curl --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/snippets
```

Example response:

```json
[
    {
        "id": 42,
        "title": "Voluptatem iure ut qui aut et consequatur quaerat.",
        "file_name": "mclaughlin.rb",
        "description": null,
        "visibility": "internal",
        "author": {
            "id": 22,
            "name": "User 0",
            "username": "user0",
            "state": "active",
            "avatar_url": "https://www.gravatar.com/avatar/52e4ce24a915fb7e51e1ad3b57f4b00a?s=80&d=identicon",
            "web_url": "http://localhost:3000/user0"
        },
        "updated_at": "2018-09-18T01:12:26.383Z",
        "created_at": "2018-09-18T01:12:26.383Z",
        "project_id": null,
        "web_url": "http://localhost:3000/snippets/42",
        "raw_url": "http://localhost:3000/snippets/42/raw"
    },
    {
        "id": 41,
        "title": "Ut praesentium non et atque.",
        "file_name": "ondrickaemard.rb",
        "description": null,
        "visibility": "internal",
        "author": {
            "id": 22,
            "name": "User 0",
            "username": "user0",
            "state": "active",
            "avatar_url": "https://www.gravatar.com/avatar/52e4ce24a915fb7e51e1ad3b57f4b00a?s=80&d=identicon",
            "web_url": "http://localhost:3000/user0"
        },
        "updated_at": "2018-09-18T01:12:26.360Z",
        "created_at": "2018-09-18T01:12:26.360Z",
        "project_id": null,
        "web_url": "http://localhost:3000/snippets/41",
        "raw_url": "http://localhost:3000/snippets/41/raw"
    }
]
```

## Get a single snippet

Get a single snippet.

```text
GET /snippets/:id
```

Parameters:

| Attribute | Type    | Required | Description                |
|:----------|:--------|:---------|:---------------------------|
| `id`      | integer | yes      | ID of snippet to retrieve. |

Example request:

```sh
curl --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/snippets/1
```

Example response:

```json
{
  "id": 1,
  "title": "test",
  "file_name": "add.rb",
  "description": "Ruby test snippet",
  "visibility": "private",
  "author": {
    "id": 1,
    "username": "john_smith",
    "email": "john@example.com",
    "name": "John Smith",
    "state": "active",
    "created_at": "2012-05-23T08:00:58Z"
  },
  "expires_at": null,
  "updated_at": "2012-06-28T10:52:04Z",
  "created_at": "2012-06-28T10:52:04Z",
  "web_url": "http://example.com/snippets/1",
}
```

## Single snippet contents

Get a single snippet's raw contents.

```text
GET /snippets/:id/raw
```

Parameters:

| Attribute | Type    | Required | Description                |
|:----------|:--------|:---------|:---------------------------|
| `id`      | integer | yes      | ID of snippet to retrieve. |

Example request:

```sh
curl --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/snippets/1/raw
```

Example response:

```text
Hello World snippet
```

## Create new snippet

Create a new snippet.

NOTE: **Note:**
The user must have permission to create new snippets.

```text
POST /snippets
```

Parameters:

| Attribute     | Type   | Required | Description                                        |
|:--------------|:-------|:---------|:---------------------------------------------------|
| `title`       | string | yes      | Title of a snippet.                                |
| `file_name`   | string | yes      | Name of a snippet file.                            |
| `code`     | string | yes      | Content of a snippet.                              |
| `description` | string | no       | Description of a snippet.                          |
| `visibility`  | string | yes       | Snippet's [visibility](#snippet-visibility-level). |

Example request:

```sh
curl --request POST \
     --data '{"title": "This is a snippet", "code": "Hello world", "description": "Hello World snippet", "file_name": "test.txt", "visibility": "internal" }' \
     --header 'Content-Type: application/json' \
     --header "PRIVATE-TOKEN: valid_api_token" \
     https://gitlab.example.com/api/v4/snippets
```

Example response:

```json
{
  "id": 1,
  "title": "This is a snippet",
  "file_name": "test.txt",
  "description": "Hello World snippet",
  "visibility": "internal",
  "author": {
    "id": 1,
    "username": "john_smith",
    "email": "john@example.com",
    "name": "John Smith",
    "state": "active",
    "created_at": "2012-05-23T08:00:58Z"
  },
  "expires_at": null,
  "updated_at": "2012-06-28T10:52:04Z",
  "created_at": "2012-06-28T10:52:04Z",
  "web_url": "http://example.com/snippets/1",
}
```

## Update snippet

Update an existing snippet.

NOTE: **Note:**
The user must have permission to change an existing snippet.

```text
PUT /snippets/:id
```

Parameters:

| Attribute     | Type    | Required | Description                                        |
|:--------------|:--------|:---------|:---------------------------------------------------|
| `id`          | integer | yes      | ID of snippet to update.                           |
| `title`       | string  | no       | Title of a snippet.                                |
| `file_name`   | string  | no       | Name of a snippet file.                            |
| `description` | string  | no       | Description of a snippet.                          |
| `code`     | string  | no       | Content of a snippet.                              |
| `visibility`  | string  | no       | Snippet's [visibility](#snippet-visibility-level). |

Example request:

```sh
curl --request PUT \
     --data '{"title": "foo", "code": "bar"}' \
     --header 'Content-Type: application/json' \
     --header "PRIVATE-TOKEN: valid_api_token" \
     https://gitlab.example.com/api/v4/snippets/1
```

Example response:

```json
{
  "id": 1,
  "title": "test",
  "file_name": "add.rb",
  "description": "description of snippet",
  "visibility": "internal",
  "author": {
    "id": 1,
    "username": "john_smith",
    "email": "john@example.com",
    "name": "John Smith",
    "state": "active",
    "created_at": "2012-05-23T08:00:58Z"
  },
  "expires_at": null,
  "updated_at": "2012-06-28T10:52:04Z",
  "created_at": "2012-06-28T10:52:04Z",
  "web_url": "http://example.com/snippets/1",
}
```

## Delete snippet

Delete an existing snippet.

```text
DELETE /snippets/:id
```

Parameters:

| Attribute | Type    | Required | Description              |
|:----------|:--------|:---------|:-------------------------|
| `id`      | integer | yes      | ID of snippet to delete. |

Example request:

```sh
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/snippets/1"
```

The following are possible return codes:

| Code  | Description                                 |
|:------|:--------------------------------------------|
| `204` | Delete was successful. No data is returned. |
| `404` | The snippet wasn't found.                   |

## List all public snippets

List all public snippets.

```text
GET /snippets/public
```

Parameters:

| Attribute  | Type    | Required | Description                            |
|:-----------|:--------|:---------|:---------------------------------------|
| `per_page` | integer | no       | Number of snippets to return per page. |
| `page`     | integer | no       | Page to retrieve.                      |

Example request:

```sh
curl --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/snippets/public?per_page=2&page=1
```

Example response:

```json
[
    {
        "author": {
            "avatar_url": "http://www.gravatar.com/avatar/edaf55a9e363ea263e3b981d09e0f7f7?s=80&d=identicon",
            "id": 12,
            "name": "Libby Rolfson",
            "state": "active",
            "username": "elton_wehner",
            "web_url": "http://localhost:3000/elton_wehner"
        },
        "created_at": "2016-11-25T16:53:34.504Z",
        "file_name": "oconnerrice.rb",
        "id": 49,
        "raw_url": "http://localhost:3000/snippets/49/raw",
        "title": "Ratione cupiditate et laborum temporibus.",
        "updated_at": "2016-11-25T16:53:34.504Z",
        "web_url": "http://localhost:3000/snippets/49"
    },
    {
        "author": {
            "avatar_url": "http://www.gravatar.com/avatar/36583b28626de71061e6e5a77972c3bd?s=80&d=identicon",
            "id": 16,
            "name": "Llewellyn Flatley",
            "state": "active",
            "username": "adaline",
            "web_url": "http://localhost:3000/adaline"
        },
        "created_at": "2016-11-25T16:53:34.479Z",
        "file_name": "muellershields.rb",
        "id": 48,
        "raw_url": "http://localhost:3000/snippets/48/raw",
        "title": "Minus similique nesciunt vel fugiat qui ullam sunt.",
        "updated_at": "2016-11-25T16:53:34.479Z",
        "web_url": "http://localhost:3000/snippets/48",
        "visibility": "public"
    }
]
```

## Get user agent details

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/12655) in GitLab 9.4.

NOTE: **Note:**
Available only for administrators.

```text
GET /snippets/:id/user_agent_detail
```

| Attribute | Type    | Required | Description    |
|:----------|:--------|:---------|:---------------|
| `id`      | integer | yes      | ID of snippet. |

Example request:

```sh
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/snippets/1/user_agent_detail
```

Example response:

```json
{
  "user_agent": "AppleWebKit/537.36",
  "ip_address": "127.0.0.1",
  "akismet_submitted": false
}
```
