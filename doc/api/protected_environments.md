---
stage: Release
group: Release
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: concepts, howto
---

# Protected environments API **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/30595) in GitLab 12.8.

## Valid access levels

The access levels are defined in the `ProtectedEnvironment::DeployAccessLevel::ALLOWED_ACCESS_LEVELS` method.
Currently, these levels are recognized:

```plaintext
30 => Developer access
40 => Maintainer access
60 => Admin access
```

## List protected environments

Gets a list of protected environments from a project:

```shell
GET /projects/:id/protected_environments
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user. |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/protected_environments/"
```

Example response:

```json
[
   {
      "name":"production",
      "deploy_access_levels":[
         {
            "access_level":40,
            "access_level_description":"Maintainers",
            "user_id":null,
            "group_id":null
         }
      ],
     "required_approval_count": 0
   }
]
```

## Get a single protected environment

Gets a single protected environment:

```shell
GET /projects/:id/protected_environments/:name
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user |
| `name` | string | yes | The name of the protected environment |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/protected_environments/production"
```

Example response:

```json
{
   "name":"production",
   "deploy_access_levels":[
      {
         "access_level": 40,
         "access_level_description": "Maintainers",
         "user_id": null,
         "group_id": null
      }
   ],
  "required_approval_count": 0
}
```

## Protect repository environments

Protects a single environment:

```shell
POST /projects/:id/protected_environments
```

```shell
curl --header 'Content-Type: application/json' --request POST \
     --data '{"name": "production", "deploy_access_levels": [{"group_id": 9899826}], "approval_rules": [{"group_id": 134}, {"group_id": 135, "required_approvals": 2}]}' \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     "https://gitlab.example.com/api/v4/projects/22034114/protected_environments"
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`                            | integer/string | yes | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user. |
| `name`                          | string         | yes | The name of the environment. |
| `deploy_access_levels`          | array          | yes | Array of access levels allowed to deploy, with each described by a hash. |
| `required_approval_count` | integer        | no       | The number of approvals required to deploy to this environment. This is part of Deployment Approvals, which isn't yet available for use. For details, see [issue](https://gitlab.com/gitlab-org/gitlab/-/issues/343864). |
| `approval_rules`                | array          | no  | Array of access levels allowed to approve, with each described by a hash. See [Multiple approval rules](../ci/environments/deployment_approvals.md#multiple-approval-rules) for more information. |

Elements in the `deploy_access_levels` and `approval_rules` array should be one of `user_id`, `group_id` or
`access_level`, and take the form `{user_id: integer}`, `{group_id: integer}` or
`{access_level: integer}`.
Each user must have access to the project and each group must [have this project shared](../user/project/members/share_project_with_groups.md).

Example response:

```json
{
   "name": "production",
   "deploy_access_levels": [
      {
         "access_level": 40,
         "access_level_description": "protected-access-group",
         "user_id": null,
         "group_id": 9899826
      }
   ],
  "required_approval_count": 0,
  "approval_rules": [
    {
      "user_id": null,
      "group_id": 134,
      "access_level": null,
      "access_level_description": "qa-group",
      "required_approvals": 1
    },
    {
      "user_id": null,
      "group_id": 135,
      "access_level": null,
      "access_level_description": "security-group",
      "required_approvals": 2
    }
  ]
}
```

## Unprotect environment

Unprotects the given protected environment:

```shell
DELETE /projects/:id/protected_environments/:name
```

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/5/protected_environments/staging"
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the project](index.md#namespaced-path-encoding) owned by the authenticated user. |
| `name` | string | yes | The name of the protected environment. |
