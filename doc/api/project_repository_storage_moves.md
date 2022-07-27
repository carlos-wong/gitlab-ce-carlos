---
stage: Systems
group: Gitaly
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Project repository storage moves API **(FREE SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/31285) in GitLab 13.0.

Project repositories including wiki and design repositories can be moved between storages. This can be useful when
[migrating to Gitaly Cluster](../administration/gitaly/index.md#migrate-to-gitaly-cluster),
for example.

As project repository storage moves are processed, they transition through different states. Values
of `state` are:

- `initial`: The record has been created but the background job has not yet been scheduled.
- `scheduled`: The background job has been scheduled.
- `started`: The project repositories are being copied to the destination storage.
- `replicated`: The project has been moved.
- `failed`: The project repositories failed to copy or the checksums did not match.
- `finished`: The project has been moved and the repositories on the source storage have been deleted.
- `cleanup failed`: The project has been moved but the repositories on the source storage could not be deleted.

To ensure data integrity, projects are put in a temporary read-only state for the
duration of the move. During this time, users receive a `The repository is temporarily
read-only. Please try again later.` message if they try to push new commits.

This API requires you to [authenticate yourself](index.md#authentication) as an administrator.

For other repository types see:

- [Snippet repository storage moves API](snippet_repository_storage_moves.md).
- [Group repository storage moves API](group_repository_storage_moves.md).

## Retrieve all project repository storage moves

```plaintext
GET /project_repository_storage_moves
```

By default, `GET` requests return 20 results at a time because the API results
are [paginated](index.md#pagination).

Example request:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/project_repository_storage_moves"
```

Example response:

```json
[
  {
    "id": 1,
    "created_at": "2020-05-07T04:27:17.234Z",
    "state": "scheduled",
    "source_storage_name": "default",
    "destination_storage_name": "storage2",
    "project": {
      "id": 1,
      "description": null,
      "name": "project1",
      "name_with_namespace": "John Doe2 / project1",
      "path": "project1",
      "path_with_namespace": "namespace1/project1",
      "created_at": "2020-05-07T04:27:17.016Z"
    }
  }
]
```

## Retrieve all repository storage moves for a project

```plaintext
GET /projects/:project_id/repository_storage_moves
```

By default, `GET` requests return 20 results at a time because the API results
are [paginated](index.md#pagination).

Parameters:

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `project_id` | integer | yes | ID of the project |

Example request:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/1/repository_storage_moves"
```

Example response:

```json
[
  {
    "id": 1,
    "created_at": "2020-05-07T04:27:17.234Z",
    "state": "scheduled",
    "source_storage_name": "default",
    "destination_storage_name": "storage2",
    "project": {
      "id": 1,
      "description": null,
      "name": "project1",
      "name_with_namespace": "John Doe2 / project1",
      "path": "project1",
      "path_with_namespace": "namespace1/project1",
      "created_at": "2020-05-07T04:27:17.016Z"
    }
  }
]
```

## Get a single project repository storage move

```plaintext
GET /project_repository_storage_moves/:repository_storage_id
```

Parameters:

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `repository_storage_id` | integer | yes | ID of the project repository storage move |

Example request:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/project_repository_storage_moves/1"
```

Example response:

```json
{
  "id": 1,
  "created_at": "2020-05-07T04:27:17.234Z",
  "state": "scheduled",
  "source_storage_name": "default",
  "destination_storage_name": "storage2",
  "project": {
    "id": 1,
    "description": null,
    "name": "project1",
    "name_with_namespace": "John Doe2 / project1",
    "path": "project1",
    "path_with_namespace": "namespace1/project1",
    "created_at": "2020-05-07T04:27:17.016Z"
  }
}
```

## Get a single repository storage move for a project

```plaintext
GET /projects/:project_id/repository_storage_moves/:repository_storage_id
```

Parameters:

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `project_id` | integer | yes | ID of the project |
| `repository_storage_id` | integer | yes | ID of the project repository storage move |

Example request:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/1/repository_storage_moves/1"
```

Example response:

```json
{
  "id": 1,
  "created_at": "2020-05-07T04:27:17.234Z",
  "state": "scheduled",
  "source_storage_name": "default",
  "destination_storage_name": "storage2",
  "project": {
    "id": 1,
    "description": null,
    "name": "project1",
    "name_with_namespace": "John Doe2 / project1",
    "path": "project1",
    "path_with_namespace": "namespace1/project1",
    "created_at": "2020-05-07T04:27:17.016Z"
  }
}
```

## Schedule a repository storage move for a project

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/34119) in GitLab 13.1.
> - [Introduced](https://gitlab.com/gitlab-org/gitaly/-/issues/2618) in GitLab 13.3, original repository is automatically removed after successful move and integrity check.

WARNING:
Before GitLab 13.3, a repository move worked more like a repository copy as the
original repository was not deleted from the original storage disk location and
had to be manually cleaned up.

```plaintext
POST /projects/:project_id/repository_storage_moves
```

Parameters:

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `project_id` | integer | yes | ID of the project |
| `destination_storage_name` | string | no | Name of the destination storage shard. In [GitLab 13.5 and later](https://gitlab.com/gitlab-org/gitaly/-/issues/3209), the storage is selected [automatically based on storage weights](../administration/repository_storage_paths.md#configure-where-new-repositories-are-stored) if not provided |

Example request:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --header "Content-Type: application/json" \
     --data '{"destination_storage_name":"storage2"}' \
     "https://gitlab.example.com/api/v4/projects/1/repository_storage_moves"
```

Example response:

```json
{
  "id": 1,
  "created_at": "2020-05-07T04:27:17.234Z",
  "state": "scheduled",
  "source_storage_name": "default",
  "destination_storage_name": "storage2",
  "project": {
    "id": 1,
    "description": null,
    "name": "project1",
    "name_with_namespace": "John Doe2 / project1",
    "path": "project1",
    "path_with_namespace": "namespace1/project1",
    "created_at": "2020-05-07T04:27:17.016Z"
  }
}
```

## Schedule repository storage moves for all projects on a storage shard

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/47142) in GitLab 13.7.

Schedules repository storage moves for each project repository stored on the source storage shard.

```plaintext
POST /project_repository_storage_moves
```

Parameters:

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `source_storage_name` | string | yes | Name of the source storage shard. |
| `destination_storage_name` | string | no | Name of the destination storage shard. The storage is selected [automatically based on storage weights](../administration/repository_storage_paths.md#configure-where-new-repositories-are-stored) if not provided. |

Example request:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --header "Content-Type: application/json" \
     --data '{"source_storage_name":"default"}' \
     "https://gitlab.example.com/api/v4/project_repository_storage_moves"
```

Example response:

```json
{
  "message": "202 Accepted"
}
```
