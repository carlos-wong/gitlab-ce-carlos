# Container Registry API

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/55978) in GitLab 11.8.

This is the API docs of the [GitLab Container Registry](../user/packages/container_registry/index.md).

## List registry repositories

### Within a project

Get a list of registry repositories in a project.

```
GET /projects/:id/registry/repositories
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) accessible by the authenticated user. |
| `tags`      | boolean | no | If the param is included as true, each repository will include an array of `"tags"` in the response. |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/registry/repositories"
```

Example response:

```json
[
  {
    "id": 1,
    "name": "",
    "path": "group/project",
    "project_id": 9,
    "location": "gitlab.example.com:5000/group/project",
    "created_at": "2019-01-10T13:38:57.391Z"
  },
  {
    "id": 2,
    "name": "releases",
    "path": "group/project/releases",
    "project_id": 9,
    "location": "gitlab.example.com:5000/group/project/releases",
    "created_at": "2019-01-10T13:39:08.229Z"
  }
]
```

### Within a group

Get a list of registry repositories in a group.

```
GET /groups/:id/registry/repositories
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the group](README.md#namespaced-path-encoding) accessible by the authenticated user. |
| `tags`      | boolean | no | If the param is included as true, each repository will include an array of `"tags"` in the response. |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/2/registry/repositories?tags=1"
```

Example response:

```json
[
  {
    "id": 1,
    "name": "",
    "path": "group/project",
    "project_id": 9,
    "location": "gitlab.example.com:5000/group/project",
    "created_at": "2019-01-10T13:38:57.391Z",
    "tags": [
      {
        "name": "0.0.1",
        "path": "group/project:0.0.1",
        "location": "gitlab.example.com:5000/group/project:0.0.1"
      }
    ]
  },
  {
    "id": 2,
    "name": "",
    "path": "group/other_project",
    "project_id": 11,
    "location": "gitlab.example.com:5000/group/other_project",
    "created_at": "2019-01-10T13:39:08.229Z",
    "tags": [
      {
        "name": "0.0.1",
        "path": "group/other_project:0.0.1",
        "location": "gitlab.example.com:5000/group/other_project:0.0.1"
      },
      {
        "name": "0.0.2",
        "path": "group/other_project:0.0.2",
        "location": "gitlab.example.com:5000/group/other_project:0.0.2"
      },
      {
        "name": "latest",
        "path": "group/other_project:latest",
        "location": "gitlab.example.com:5000/group/other_project:latest"
      }
    ]
  }
]
```

## Delete registry repository

Delete a repository in registry.

This operation is executed asynchronously and might take some time to get executed.

```
DELETE /projects/:id/registry/repositories/:repository_id
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user. |
| `repository_id` | integer | yes | The ID of registry repository. |

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/registry/repositories/2"
```

## List registry repository tags

### Within a project

Get a list of tags for given registry repository.

```
GET /projects/:id/registry/repositories/:repository_id/tags
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) accessible by the authenticated user. |
| `repository_id` | integer | yes | The ID of registry repository. |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/registry/repositories/2/tags"
```

Example response:

```json
[
  {
    "name": "A",
    "path": "group/project:A",
    "location": "gitlab.example.com:5000/group/project:A"
  },
  {
    "name": "latest",
    "path": "group/project:latest",
    "location": "gitlab.example.com:5000/group/project:latest"
  }
]
```

## Get details of a registry repository tag

Get details of a registry repository tag.

```
GET /projects/:id/registry/repositories/:repository_id/tags/:tag_name
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) accessible by the authenticated user. |
| `repository_id` | integer | yes | The ID of registry repository. |
| `tag_name` | string | yes | The name of tag. |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/registry/repositories/2/tags/v10.0.0"
```

Example response:

```json
{
  "name": "v10.0.0",
  "path": "group/project:latest",
  "location": "gitlab.example.com:5000/group/project:latest",
  "revision": "e9ed9d87c881d8c2fd3a31b41904d01ba0b836e7fd15240d774d811a1c248181",
  "short_revision": "e9ed9d87c",
  "digest": "sha256:c3490dcf10ffb6530c1303522a1405dfaf7daecd8f38d3e6a1ba19ea1f8a1751",
  "created_at": "2019-01-06T16:49:51.272+00:00",
  "total_size": 350224384
}
```

## Delete a registry repository tag

Delete a registry repository tag.

```
DELETE /projects/:id/registry/repositories/:repository_id/tags/:tag_name
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user. |
| `repository_id` | integer | yes | The ID of registry repository. |
| `tag_name` | string | yes | The name of tag. |

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/registry/repositories/2/tags/v10.0.0"
```

This action does not delete blobs. In order to delete them and recycle disk space,
[run the garbage collection](https://docs.gitlab.com/omnibus/maintenance/README.html#removing-unused-layers-not-referenced-by-manifests).

## Delete registry repository tags in bulk

Delete registry repository tags in bulk based on given criteria.

```
DELETE /projects/:id/registry/repositories/:repository_id/tags
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user. |
| `repository_id` | integer | yes | The ID of registry repository. |
| `name_regex` | string | yes | The [re2](https://github.com/google/re2/wiki/Syntax) regex of the name to delete. To delete all tags specify `.*`.|
| `keep_n` | integer | no | The amount of latest tags of given name to keep. |
| `older_than` | string | no | Tags to delete that are older than the given time, written in human readable form `1h`, `1d`, `1month`. |

This API call performs the following operations:

1. It orders all tags by creation date. The creation date is the time of the
   manifest creation, not the time of tag push.
1. It removes only the tags matching the given `name_regex`.
1. It never removes the tag named `latest`.
1. It keeps N latest matching tags (if `keep_n` is specified).
1. It only removes tags that are older than X amount of time (if `older_than` is specified).
1. It schedules the asynchronous job to be executed in the background.

These operations are executed asynchronously and it might
take time to get executed. You can run this at most
once an hour for a given container repository.
This action does not delete blobs. In order to delete them and recycle disk space,
[run the garbage collection](https://docs.gitlab.com/omnibus/maintenance/README.html#removing-unused-layers-not-referenced-by-manifests).

NOTE: **Note:**
Since GitLab 12.4, individual tags are deleted.
For more details, see the [discussion](https://gitlab.com/gitlab-org/gitlab/issues/15737).

Examples:

1. Remove tag names that are matching the regex (Git SHA), keep always at least 5,
   and remove ones that are older than 2 days:

   ```shell
   curl --request DELETE --data 'name_regex=[0-9a-z]{40}' --data 'keep_n=5' --data 'older_than=2d' --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/registry/repositories/2/tags"
   ```

1. Remove all tags, but keep always the latest 5:

   ```shell
   curl --request DELETE --data 'name_regex=.*' --data 'keep_n=5' --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/registry/repositories/2/tags"
   ```

1. Remove all tags that are older than 1 month:

   ```shell
   curl --request DELETE --data 'name_regex=.*' --data 'older_than=1month' --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/registry/repositories/2/tags"
   ```
