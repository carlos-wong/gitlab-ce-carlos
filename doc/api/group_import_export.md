# Group Import/Export API

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/20353) in GitLab 12.8 as an experimental feature. May change in future releases.

Group Import/Export allows you to export group structure and import it to a new location.
When used with [Project Import/Export](project_import_export.md), you can preserve connections with
group-level relationships, such as connections between project issues and group epics.

Group exports include the following:

- Group milestones
- Group boards
- Group labels
- Group badges
- Group members
- Sub-groups. Each sub-group includes all data above

## Schedule new export

Start a new group export.

```plaintext
POST /groups/:id/export
```

| Attribute | Type           | Required | Description                              |
| --------- | -------------- | -------- | ---------------------------------------- |
| `id`      | integer/string | yes      | ID of the groupd owned by the authenticated user |

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/groups/1/export
```

```json
{
  "message": "202 Accepted"
}
```

## Export download

Download the finished export.

```text
GET /groups/:id/export/download
```

| Attribute | Type           | Required | Description                              |
| --------- | -------------- | -------- | ---------------------------------------- |
| `id`      | integer/string | yes      | ID of the group owned by the authenticated user |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" --remote-header-name --remote-name https://gitlab.example.com/api/v4/groups/1/export/download
```

```shell
ls *export.tar.gz
2020-12-05_22-11-148_namespace_export.tar.gz
```

Time spent on exporting a group may vary depending on a size of the group. This endpoint
returns either:

- The exported archive (when available)
- A 404 message

## Import a file

```text
POST /groups/import
```

| Attribute | Type           | Required | Description                              |
| --------- | -------------- | -------- | ---------------------------------------- |
| `name` | string | yes | The name of the group to be imported |
| `path` | string | yes | Name and path for new group |
| `file` | string | yes | The file to be uploaded |
| `parent_id` | integer | no | ID of a parent group that the group will be imported into. Defaults to the current user's namespace if not provided. |

To upload a file from your file system, use the `--form` argument. This causes
cURL to post data using the header `Content-Type: multipart/form-data`.
The `file=` parameter must point to a file on your file system and be preceded
by `@`. For example:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --form "name=imported-group" --form "path=imported-group" --form "file=@/path/to/file" https://gitlab.example.com/api/v4/groups/import
```

## Important notes

Note the following:

- To preserve group-level relationships from imported projects, run Group Import/Export first,
  to allow project imports into the desired group structure.
- Imported groups are given a `private` visibility level, unless imported into a parent group.
- If imported into a parent group, subgroups will inherit a similar level of visibility, unless otherwise restricted.
