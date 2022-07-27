---
stage: Growth
group: Acquisition
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Invitations API **(FREE)**

Use the Invitations API to invite or add users to a group or project, and to list pending
invitations.

## Valid access levels

To send an invitation, you must have access to the project or group you are sending email for. Valid access
levels are defined in the `Gitlab::Access` module. Currently, these levels are valid:

- No access (`0`)
- Minimal access (`5`) ([Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/220203) in GitLab 13.5.)
- Guest (`10`)
- Reporter (`20`)
- Developer (`30`)
- Maintainer (`40`)
- Owner (`50`). Valid for projects in [GitLab 14.9 and later](https://gitlab.com/gitlab-org/gitlab/-/issues/21432).

NOTE:
From [GitLab 14.9](https://gitlab.com/gitlab-org/gitlab/-/issues/351211) and later, projects have a maximum role of Owner.
Because of a [known issue](https://gitlab.com/gitlab-org/gitlab/-/issues/219299) in GitLab 14.8 and earlier, projects have a maximum role of Maintainer.

## Add a member to a group or project

Adds a new member. You can specify a user ID or invite a user by email.

```plaintext
POST /groups/:id/invitations
POST /projects/:id/invitations
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project or group](index.md#namespaced-path-encoding) owned by the authenticated user |
| `email` | string | yes (if `user_id` isn't provided) | The email of the new member or multiple emails separated by commas. |
| `user_id`   | integer/string | yes (if `email` isn't provided) | The ID of the new member or multiple IDs separated by commas. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/350999) in GitLab 14.10. |
| `access_level` | integer | yes | A valid access level |
| `expires_at` | string | no | A date string in the format YEAR-MONTH-DAY |
| `invite_source` | string | no | The source of the invitation that starts the member creation process. See [this issue](https://gitlab.com/gitlab-org/gitlab/-/issues/327120). |
| `tasks_to_be_done` | array of strings | no | Tasks the inviter wants the member to focus on. The tasks are added as issues to a specified project. The possible values are: `ci`, `code` and `issues`. If specified, requires `tasks_project_id`. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/69299) in GitLab 14.6 |
| `tasks_project_id` | integer | no | The project ID in which to create the task issues. If specified, requires `tasks_to_be_done`. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/69299) in GitLab 14.6 |

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
     --data "email=test@example.com&user_id=1&access_level=30" "https://gitlab.example.com/api/v4/groups/:id/invitations"
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
     --data "email=test@example.com&user_id=1&access_level=30" "https://gitlab.example.com/api/v4/projects/:id/invitations"
```

Example responses:

When all emails were successfully sent:

```json
{  "status":  "success"  }
```

When there was any error sending the email:

```json
{
  "status": "error",
  "message": {
               "test@example.com": "Invite email has already been taken",
               "test2@example.com": "User already exists in source",
               "test_username": "Access level is not included in the list"
             }
}
```

## List all invitations pending for a group or project

Gets a list of invited group or project members viewable by the authenticated user.
Returns invitations to direct members only, and not through inherited ancestors' groups.

This function takes pagination parameters `page` and `per_page` to restrict the list of members.

```plaintext
GET /groups/:id/invitations
GET /projects/:id/invitations
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project or group](index.md#namespaced-path-encoding) owned by the authenticated user |
| `page`    | integer | no   | Page to retrieve                      |
| `per_page`| integer | no   | Number of member invitations to return per page |
| `query`   | string  | no   | A query string to search for invited members by invite email. Query text must match email address exactly. When empty, returns all invitations. |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/:id/invitations?query=member@example.org"
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/:id/invitations?query=member@example.org"
```

Example response:

```json
 [
   {
     "id": 1,
     "invite_email": "member@example.org",
     "created_at": "2020-10-22T14:13:35Z",
     "access_level": 30,
     "expires_at": "2020-11-22T14:13:35Z",
     "user_name": "Raymond Smith",
     "created_by_name": "Administrator"
   },
]
```

## Update an invitation to a group or project

Updates a pending invitation's access level or access expiry date.

```plaintext
PUT /groups/:id/invitations/:email
PUT /projects/:id/invitations/:email
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project or group](index.md#namespaced-path-encoding) owned by the authenticated user. |
| `email`   | string | yes    | The email address to which the invitation was previously sent. |
| `access_level` | integer | no | A valid access level (defaults: `30`, the Developer role). |
| `expires_at` | string | no | A date string in ISO 8601 format (`YYYY-MM-DDTHH:MM:SSZ`). |

```shell
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/55/invitations/email@example.org?access_level=40"
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/55/invitations/email@example.org?access_level=40"
```

Example response:

```json
{
  "expires_at": "2012-10-22T14:13:35Z",
  "access_level": 40,
}
```

## Delete an invitation to a group or project

Deletes a pending invitation by email address.

```plaintext
DELETE /groups/:id/invitations/:email
DELETE /projects/:id/invitations/:email
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | integer/string | yes | The ID or [URL-encoded path of the project or group](index.md#namespaced-path-encoding) owned by the authenticated user |
| `email`   | string | yes    | The email address to which the invitation was previously sent |

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/55/invitations/email@example.org"
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/55/invitations/email@example.org"
```

- Returns `204` and no content on success.
- Returns `403` forbidden if unauthorized to delete the invitation.
- Returns `404` not found if authorized and no invitation is found for that email address.
- Returns `409` if the request was valid but the invitation could not be deleted.
