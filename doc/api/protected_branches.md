# Protected branches API

>**Note:** This feature was introduced in GitLab 9.5

**Valid access levels**

The access levels are defined in the `ProtectedRefAccess.allowed_access_levels` method. Currently, these levels are recognized:

```
0  => No access
30 => Developer access
40 => Maintainer access
```

## List protected branches

Gets a list of protected branches from a project.

```
GET /projects/:id/protected_branches
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user |

```bash
curl --header "PRIVATE-TOKEN: <your_access_token>" 'https://gitlab.example.com/api/v4/projects/5/protected_branches'
```

Example response:

```json
[
  {
    "name": "master",
    "push_access_levels": [
      {
        "access_level": 40,
        "access_level_description": "Maintainers"
      }
    ],
    "merge_access_levels": [
      {
        "access_level": 40,
        "access_level_description": "Maintainers"
      }
    ]
  },
  ...
]
```

## Get a single protected branch or wildcard protected branch

Gets a single protected branch or wildcard protected branch.

```
GET /projects/:id/protected_branches/:name
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user |
| `name` | string | yes | The name of the branch or wildcard |

```bash
curl --header "PRIVATE-TOKEN: <your_access_token>" 'https://gitlab.example.com/api/v4/projects/5/protected_branches/master'
```

Example response:

```json
{
  "name": "master",
  "push_access_levels": [
    {
      "access_level": 40,
      "access_level_description": "Maintainers"
    }
  ],
  "merge_access_levels": [
    {
      "access_level": 40,
      "access_level_description": "Maintainers"
    }
  ]
}
```

## Protect repository branches

Protects a single repository branch or several project repository
branches using a wildcard protected branch.

```
POST /projects/:id/protected_branches
```

```bash
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" 'https://gitlab.example.com/api/v4/projects/5/protected_branches?name=*-stable&push_access_level=30&merge_access_level=30'
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user |
| `name` | string | yes | The name of the branch or wildcard |
| `push_access_level` | string | no | Access levels allowed to push (defaults: `40`, maintainer access level) |
| `merge_access_level` | string | no | Access levels allowed to merge (defaults: `40`, maintainer access level) |

Example response:

```json
{
  "name": "*-stable",
  "push_access_levels": [
    {
      "access_level": 30,
      "access_level_description": "Developers + Maintainers"
    }
  ],
  "merge_access_levels": [
    {
      "access_level": 30,
      "access_level_description": "Developers + Maintainers"
    }
  ]
}
```

## Unprotect repository branches

Unprotects the given protected branch or wildcard protected branch.

```
DELETE /projects/:id/protected_branches/:name
```

```bash
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" 'https://gitlab.example.com/api/v4/projects/5/protected_branches/*-stable'
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user |
| `name` | string | yes | The name of the branch |
