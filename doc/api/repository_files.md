# Repository files API

**CRUD for repository files**

**Create, read, update and delete repository files using this API**

The different scopes available using [personal access tokens](../user/profile/personal_access_tokens.md) are depicted
in the following table.

| Scope | Description |
| ----- | ----------- |
| `read_repository` | Allows read-access to the repository files. |
| `api` | Allows read-write access to the repository files. |

> `read_repository` scope was [introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/23534) in GitLab 11.6.

## Get file from repository

Allows you to receive information about file in repository like name, size,
content. Note that file content is Base64 encoded. This endpoint can be accessed
without authentication if the repository is publicly accessible.

```
GET /projects/:id/repository/files/:file_path
```

```bash
curl --request GET --header 'PRIVATE-TOKEN: <your_access_token>' 'https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fmodels%2Fkey%2Erb?ref=master'
```

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
  "last_commit_id": "570e7b2abdd848b95f2f578043fc23bd6f6fd24d"
}
```

Parameters:

- `file_path` (required) - Url encoded full path to new file. Ex. lib%2Fclass%2Erb
- `ref` (required) - The name of branch, tag or commit

NOTE: **Note:**
`blob_id` is the blob sha, see [repositories - Get a blob from repository](repositories.md#get-a-blob-from-repository)

In addition to the `GET` method, you can also use `HEAD` to get just file metadata.

```
HEAD /projects/:id/repository/files/:file_path
```

```bash
curl --head --header 'PRIVATE-TOKEN: <your_access_token>' 'https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fmodels%2Fkey%2Erb?ref=master'
```

Example response:

```text
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
...
```

## Get raw file from repository

```
GET /projects/:id/repository/files/:file_path/raw
```

```bash
curl --request GET --header 'PRIVATE-TOKEN: <your_access_token>' 'https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fmodels%2Fkey%2Erb/raw?ref=master'
```

Parameters:

- `file_path` (required) - Url encoded full path to new file. Ex. lib%2Fclass%2Erb
- `ref` (required) - The name of branch, tag or commit

NOTE: **Note:**
Like [Get file from repository](repository_files.md#get-file-from-repository) you can use `HEAD` to get just file metadata.

## Create new file in repository

This allows you to create a single file. For creating multiple files with a single request see the [commits API](commits.html#create-a-commit-with-multiple-files-and-actions).

```
POST /projects/:id/repository/files/:file_path
```

```bash
curl --request POST --header 'PRIVATE-TOKEN: <your_access_token>' --header "Content-Type: application/json" \
  --data '{"branch": "master", "author_email": "author@example.com", "author_name": "Firstname Lastname", \
    "content": "some content", "commit_message": "create a new file"}' \
  'https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fproject%2Erb'
```

Example response:

```json
{
  "file_path": "app/project.rb",
  "branch": "master"
}
```

Parameters:

- `file_path` (required) - Url encoded full path to new file. Ex. lib%2Fclass%2Erb
- `branch` (required) - Name of the branch
- `start_branch` (optional) - Name of the branch to start the new commit from
- `encoding` (optional) - Change encoding to 'base64'. Default is text.
- `author_email` (optional) - Specify the commit author's email address
- `author_name` (optional) - Specify the commit author's name
- `content` (required) - File content
- `commit_message` (required) - Commit message

## Update existing file in repository

This allows you to update a single file. For updating multiple files with a single request see the [commits API](commits.html#create-a-commit-with-multiple-files-and-actions).

```
PUT /projects/:id/repository/files/:file_path
```

```bash
curl --request PUT --header 'PRIVATE-TOKEN: <your_access_token>' --header "Content-Type: application/json" \
  --data '{"branch": "master", "author_email": "author@example.com", "author_name": "Firstname Lastname", \
    "content": "some content", "commit_message": "update file"}' \
  'https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fproject%2Erb'
```

Example response:

```json
{
  "file_path": "app/project.rb",
  "branch": "master"
}
```

Parameters:

- `file_path` (required) - Url encoded full path to new file. Ex. lib%2Fclass%2Erb
- `branch` (required) - Name of the branch
- `start_branch` (optional) - Name of the branch to start the new commit from
- `encoding` (optional) - Change encoding to 'base64'. Default is text.
- `author_email` (optional) - Specify the commit author's email address
- `author_name` (optional) - Specify the commit author's name
- `content` (required) - New file content
- `commit_message` (required) - Commit message
- `last_commit_id` (optional) - Last known file commit id

If the commit fails for any reason we return a 400 error with a non-specific
error message. Possible causes for a failed commit include:

- the `file_path` contained `/../` (attempted directory traversal);
- the new file contents were identical to the current file contents, i.e. the
  user tried to make an empty commit;
- the branch was updated by a Git push while the file edit was in progress.

Currently gitlab-shell has a boolean return code, preventing GitLab from specifying the error.

## Delete existing file in repository

This allows you to delete a single file. For deleting multiple files with a single request, see the [commits API](commits.html#create-a-commit-with-multiple-files-and-actions).

```
DELETE /projects/:id/repository/files/:file_path
```

```bash
curl --request DELETE --header 'PRIVATE-TOKEN: <your_access_token>' --header "Content-Type: application/json" \
  --data '{"branch": "master", "author_email": "author@example.com", "author_name": "Firstname Lastname", \
    "commit_message": "delete file"}' \
  'https://gitlab.example.com/api/v4/projects/13083/repository/files/app%2Fproject%2Erb'
```

Parameters:

- `file_path` (required) - Url encoded full path to new file. Ex. lib%2Fclass%2Erb
- `branch` (required) - Name of the branch
- `start_branch` (optional) - Name of the branch to start the new commit from
- `author_email` (optional) - Specify the commit author's email address
- `author_name` (optional) - Specify the commit author's name
- `commit_message` (required) - Commit message
- `last_commit_id` (optional) - Last known file commit id
