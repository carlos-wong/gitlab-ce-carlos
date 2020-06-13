# Project remote mirrors API

[Push mirrors](../user/project/repository/repository_mirroring.md#pushing-to-a-remote-repository-core)
defined on a project's repository settings are called "remote mirrors", and the
state of these mirrors can be queried and modified via the remote mirror API
outlined below.

## List a project's remote mirrors

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/38121) in GitLab 12.9.

Returns an Array of remote mirrors and their statuses:

```text
GET /projects/:id/remote_mirrors
```

Example request:

```sh
curl --header "PRIVATE-TOKEN: <your_access_token>" 'https://gitlab.example.com/api/v4/projects/42/remote_mirrors'
```

Example response:

```json
[
  {
    "enabled": true,
    "id": 101486,
    "last_error": null,
    "last_successful_update_at": "2020-01-06T17:32:02.823Z",
    "last_update_at": "2020-01-06T17:32:02.823Z",
    "last_update_started_at": "2020-01-06T17:31:55.864Z",
    "only_protected_branches": true,
    "update_status": "finished",
    "url": "https://*****:*****@gitlab.com/gitlab-org/security/gitlab.git"
  }
]
```

NOTE: **Note:**
For security reasons, the `url` attribute will always be scrubbed of username
and password information.

## Create a remote mirror

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/24189) in GitLab 12.9.

Create a remote mirror for a project. The mirror will be disabled by default. You can enable it by including the optional parameter `enabled` when creating it:

```text
POST /projects/:id/remote_mirrors
```

| Attribute                 | Type    | Required   | Description                                         |
| :----------               | :-----  | :--------- | :------------                                       |
| `url`                     | String  | yes        | The URL of the remote repository to be mirrored.    |
| `enabled`                 | Boolean | no         | Determines if the mirror is enabled.                |
| `only_protected_branches` | Boolean | no         | Determines if only protected branches are mirrored. |

Example request:

```sh
curl --request POST --data "url=https://username:token@example.com/gitlab/example.git" --header "PRIVATE-TOKEN: <your_access_token>" 'https://gitlab.example.com/api/v4/projects/42/remote_mirrors'
```

Example response:

```json
{
    "enabled": false,
    "id": 101486,
    "last_error": null,
    "last_successful_update_at": null,
    "last_update_at": null,
    "last_update_started_at": null,
    "only_protected_branches": false,
    "update_status": "none",
    "url": "https://*****:*****@example.com/gitlab/example.git"
}
```

## Update a remote mirror's attributes

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/38121) in GitLab 12.9.

Toggle a remote mirror on or off, or change which types of branches are
mirrored:

```text
PUT /projects/:id/remote_mirrors/:mirror_id
```

| Attribute                 | Type    | Required   | Description                                         |
| :----------               | :-----  | :--------- | :------------                                       |
| `mirror_id`               | Integer | yes        | The remote mirror ID.                               |
| `enabled`                 | Boolean | no         | Determines if the mirror is enabled.                |
| `only_protected_branches` | Boolean | no         | Determines if only protected branches are mirrored. |

Example request:

```sh
curl --request PUT --data "enabled=false" --header "PRIVATE-TOKEN: <your_access_token>" 'https://gitlab.example.com/api/v4/projects/42/remote_mirrors/101486'
```

Example response:

```json
{
    "enabled": false,
    "id": 101486,
    "last_error": null,
    "last_successful_update_at": "2020-01-06T17:32:02.823Z",
    "last_update_at": "2020-01-06T17:32:02.823Z",
    "last_update_started_at": "2020-01-06T17:31:55.864Z",
    "only_protected_branches": true,
    "update_status": "finished",
    "url": "https://*****:*****@gitlab.com/gitlab-org/security/gitlab.git"
}
```
