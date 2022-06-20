---
stage: Create
group: Source Code
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments"
type: reference, api
---

# Repository files API **(FREE)**

You can fetch, create, update, and delete files in your repository with this API.
You can also [configure rate limits](../user/admin_area/settings/files_api_rate_limits.md)
for this API.

## Available scopes for personal access tokens

The different scopes available using [personal access tokens](../user/profile/personal_access_tokens.md) are depicted
in the following table.

| Scope | Description |
| ----- | ----------- |
| `read_repository` | Allows read-access to the repository files. |
| `api` | Allows read-write access to the repository files. |

## Get file from repository

> The `execute_filemode` field in the response was [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/83499) in GitLab 14.10.

Allows you to receive information about file in repository like name, size,
content. File content is Base64 encoded. This endpoint can be accessed
without authentication if the repository is publicly accessible.

```plaintext
GET /projects/:id/repository/files/:file_path
```

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fmodels%2Fkey%2Erb?ref=master"
```

| Attribute   | Type           | Required | Description                                                                                                     |
|-------------|----------------|----------|-----------------------------------------------------------------------------------------------------------------|
| `id`        | integer or string | yes   | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user  |
| `file_path` | string         | yes      | URL encoded full path to new file. Ex. `lib%2Fclass%2Erb`.                                                      |
| `ref`       | string         | yes      | The name of branch, tag or commit                                                                               |

Example response:

```json
{
  "file_name": "key.rb",
  "file_path": "app/models/key.rb",
  "size": 1476,
  "encoding": "base64",
  "content": "IyA9PSBTY2hlbWEgSW5mb3...",
  "content_sha256": "4c294617b60715c1d218e61164a3abd4808a4284cbc30e6728a01ad9aada4481",
  "ref": "master",
  "blob_id": "79f7bbd25901e8334750839545a9bd021f0e4c83",
  "commit_id": "d5a3ff139356ce33e37e73add446f16869741b50",
  "last_commit_id": "570e7b2abdd848b95f2f578043fc23bd6f6fd24d",
  "execute_filemode": false
}
```

NOTE:
`blob_id` is the blob SHA, see [repositories - Get a blob from repository](repositories.md#get-a-blob-from-repository)

In addition to the `GET` method, you can also use `HEAD` to get just file metadata.

```plaintext
HEAD /projects/:id/repository/files/:file_path
```

```shell
curl --head --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fmodels%2Fkey%2Erb?ref=master"
```

Example response:

```plaintext
HTTP/1.1 200 OK
...
X-Gitlab-Blob-Id: 79f7bbd25901e8334750839545a9bd021f0e4c83
X-Gitlab-Commit-Id: d5a3ff139356ce33e37e73add446f16869741b50
X-Gitlab-Content-Sha256: 4c294617b60715c1d218e61164a3abd4808a4284cbc30e6728a01ad9aada4481
X-Gitlab-Encoding: base64
X-Gitlab-File-Name: key.rb
X-Gitlab-File-Path: app/models/key.rb
X-Gitlab-Last-Commit-Id: 570e7b2abdd848b95f2f578043fc23bd6f6fd24d
X-Gitlab-Ref: master
X-Gitlab-Size: 1476
X-Gitlab-Execute-Filemode: false
...
```

## Get file blame from repository

Allows you to receive blame information. Each blame range contains lines and corresponding commit information.

```plaintext
GET /projects/:id/repository/files/:file_path/blame
```

| Attribute   | Type           | Required | Description                                                                                                     |
|-------------|----------------|----------|-----------------------------------------------------------------------------------------------------------------|
| `id`        | integer or string | yes   | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user  |
| `file_path` | string         | yes      | URL encoded full path to new file. Ex. `lib%2Fclass%2Erb`.                                                      |
| `ref`       | string         | yes      | The name of branch, tag or commit                                                                               |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/13083/repository/files/path%2Fto%2Ffile.rb/blame?ref=master"
```

Example response:

```json
[
  {
    "commit": {
      "id": "d42409d56517157c48bf3bd97d3f75974dde19fb",
      "message": "Add feature\n\nalso fix bug\n",
      "parent_ids": [
        "cc6e14f9328fa6d7b5a0d3c30dc2002a3f2a3822"
      ],
      "authored_date": "2015-12-18T08:12:22.000Z",
      "author_name": "John Doe",
      "author_email": "john.doe@example.com",
      "committed_date": "2015-12-18T08:12:22.000Z",
      "committer_name": "John Doe",
      "committer_email": "john.doe@example.com"
    },
    "lines": [
      "require 'fileutils'",
      "require 'open3'",
      ""
    ]
  },
  ...
]
```

NOTE:
`HEAD` method return just file metadata as in [Get file from repository](repository_files.md#get-file-from-repository).

```shell
curl --head --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/13083/repository/files/path%2Fto%2Ffile.rb/blame?ref=master"
```

Example response:

```plaintext
HTTP/1.1 200 OK
...
X-Gitlab-Blob-Id: 79f7bbd25901e8334750839545a9bd021f0e4c83
X-Gitlab-Commit-Id: d5a3ff139356ce33e37e73add446f16869741b50
X-Gitlab-Content-Sha256: 4c294617b60715c1d218e61164a3abd4808a4284cbc30e6728a01ad9aada4481
X-Gitlab-Encoding: base64
X-Gitlab-File-Name: file.rb
X-Gitlab-File-Path: path/to/file.rb
X-Gitlab-Last-Commit-Id: 570e7b2abdd848b95f2f578043fc23bd6f6fd24d
X-Gitlab-Ref: master
X-Gitlab-Size: 1476
X-Gitlab-Execute-Filemode: false
...
```

## Get raw file from repository

```plaintext
GET /projects/:id/repository/files/:file_path/raw
```

| Attribute   | Type           | Required | Description                                                                                                     |
|-------------|----------------|----------|-----------------------------------------------------------------------------------------------------------------|
| `id`        | integer or string | yes   | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user  |
| `file_path` | string         | yes      | URL encoded full path to new file. Ex. `lib%2Fclass%2Erb`.                                                      |
| `ref`       | string         | yes      | The name of branch, tag or commit. Default is the `HEAD` of the project.                                        |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fmodels%2Fkey%2Erb/raw?ref=master"
```

NOTE:
Like [Get file from repository](repository_files.md#get-file-from-repository) you can use `HEAD` to get just file metadata.

## Create new file in repository

> The `execute_filemode` parameter was [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/83499) in GitLab 14.10.

This allows you to create a single file. For creating multiple files with a single request see the [commits API](commits.md#create-a-commit-with-multiple-files-and-actions).

```plaintext
POST /projects/:id/repository/files/:file_path
```

| Attribute        | Type           | Required | Description |
| ---------------- | -------------- | -------- | ----------- |
| `id`             | integer or string | yes   | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user. |
| `file_path`      | string         | yes      | URL-encoded full path to new file. For example:  `lib%2Fclass%2Erb`. |
| `branch`         | string         | yes      | Name of the new branch to create. The commit is added to this branch. |
| `start_branch`   | string         | no       | Name of the base branch to create the new branch from. |
| `encoding`       | string         | no       | Change encoding to `base64`. Default is `text`. |
| `author_email`   | string         | no       | The commit author's email address. |
| `author_name`    | string         | no       | The commit author's name. |
| `content`        | string         | yes      | The file's content. |
| `commit_message` | string         | yes      | The commit message. |
| `execute_filemode` | boolean      | no       | Enables or disables the `execute` flag on the file. Can be `true` or `false`. |

```shell
curl --request POST --header 'PRIVATE-TOKEN: <your_access_token>' \
     --header "Content-Type: application/json" \
     --data '{"branch": "master", "author_email": "author@example.com", "author_name": "Firstname Lastname",
               "content": "some content", "commit_message": "create a new file"}' \
     "https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fproject%2Erb"
```

Example response:

```json
{
  "file_path": "app/project.rb",
  "branch": "master"
}
```

## Update existing file in repository

> The `execute_filemode` parameter was [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/83499) in GitLab 14.10.

This allows you to update a single file. For updating multiple files with a single request see the [commits API](commits.md#create-a-commit-with-multiple-files-and-actions).

```plaintext
PUT /projects/:id/repository/files/:file_path
```

| Attribute        | Type           | Required | Description |
| ---------------- | -------------- | -------- | ----------- |
| `id`             | integer or string | yes   | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user  |
| `file_path`      | string         | yes      | URL-encoded full path to new file. For example: `lib%2Fclass%2Erb`. |
| `branch`         | string         | yes      | Name of the new branch to create. The commit is added to this branch. |
| `start_branch`   | string         | no       | Name of the base branch to create the new branch from. |
| `encoding`       | string         | no       | Change encoding to `base64`. Default is `text`.  |
| `author_email`   | string         | no       | The commit author's email address. |
| `author_name`    | string         | no       | The commit author's name. |
| `content`        | string         | yes      | The file's content. |
| `commit_message` | string         | yes      | The commit message. |
| `last_commit_id` | string         | no       | Last known file commit ID. |
| `execute_filemode` | boolean      | no       | Enables or disables the `execute` flag on the file. Can be `true` or `false`. |

```shell
curl --request PUT --header 'PRIVATE-TOKEN: <your_access_token>' \
     --header "Content-Type: application/json" \
     --data '{"branch": "master", "author_email": "author@example.com", "author_name": "Firstname Lastname",
       "content": "some content", "commit_message": "update file"}' \
     "https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fproject%2Erb"
```

Example response:

```json
{
  "file_path": "app/project.rb",
  "branch": "master"
}
```

If the commit fails for any reason we return a 400 error with a non-specific
error message. Possible causes for a failed commit include:

- the `file_path` contained `/../` (attempted directory traversal);
- the new file contents were identical to the current file contents. That is, the
  user tried to make an empty commit;
- the branch was updated by a Git push while the file edit was in progress.

GitLab Shell has a boolean return code, preventing GitLab from specifying the error.

## Delete existing file in repository

This allows you to delete a single file. For deleting multiple files with a single request, see the [commits API](commits.md#create-a-commit-with-multiple-files-and-actions).

```plaintext
DELETE /projects/:id/repository/files/:file_path
```

| Attribute        | Type           | Required | Description |
| ---------------- | -------------- | -------- | ----------- |
| `id`             | integer or string | yes   | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user. |
| `file_path`      | string         | yes      | URL-encoded full path to new file. For example: `lib%2Fclass%2Erb`. |
| `branch`         | string         | yes      | Name of the new branch to create. The commit is added to this branch. |
| `start_branch`   | string         | no       | Name of the base branch to create the new branch from. |
| `author_email`   | string         | no       | The commit author's email address. |
| `author_name`    | string         | no       | The commit author's name. |
| `commit_message` | string         | yes      | The commit message. |
| `last_commit_id` | string         | no       | Last known file commit ID. |

```shell
curl --request DELETE --header 'PRIVATE-TOKEN: <your_access_token>' \
     --header "Content-Type: application/json" \
     --data '{"branch": "master", "author_email": "author@example.com", "author_name": "Firstname Lastname",
       "commit_message": "delete file"}' \
     "https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fproject%2Erb"
```
