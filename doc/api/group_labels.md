# Group Labels API

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/21368) in GitLab 11.8.

This API supports managing of [group labels](../user/project/labels.md#project-labels-and-group-labels). It allows to list, create, update, and delete group labels. Furthermore, users can subscribe and unsubscribe to and from group labels.

## List group labels

Get all labels for a given group.

```
GET /groups/:id/labels
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user. |

```bash
curl --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/groups/5/labels
```

Example response:

```json
[
  {
    "id": 7,
    "name": "bug",
    "color": "#FF0000",
    "text_color" : "#FFFFFF",
    "description": null,
    "open_issues_count": 0,
    "closed_issues_count": 0,
    "open_merge_requests_count": 0,
    "subscribed": false
  },
  {
    "id": 4,
    "name": "feature",
    "color": "#228B22",
    "text_color" : "#FFFFFF",
    "description": null,
    "open_issues_count": 0,
    "closed_issues_count": 0,
    "open_merge_requests_count": 0,
    "subscribed": false
  }
]
```

## Create a new group label

Create a new group label for a given group.

```
POST /groups/:id/labels
```

| Attribute     | Type    | Required | Description                  |
| ------------- | ------- | -------- | ---------------------------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user |
| `name`        | string  | yes      | The name of the label        |
| `color`       | string  | yes      | The color of the label given in 6-digit hex notation with leading '#' sign (e.g. #FFAABB) or one of the [CSS color names](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#Color_keywords) |
| `description` | string  | no       | The description of the label, |

```bash
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --header "Content-Type: application/json" --data '{"name": "Feature Proposal", "color": "#FFA500", "description": "Describes new ideas" }' https://gitlab.example.com/api/v4/groups/5/labels
```

Example response:

```json
{
  "id": 9,
  "name": "Feature Proposal",
  "color": "#FFA500",
  "text_color" : "#FFFFFF",
  "description": "Describes new ideas",
  "open_issues_count": 0,
  "closed_issues_count": 0,
  "open_merge_requests_count": 0,
  "subscribed": false
}
```

## Update a group label

Updates an existing group label. At least one parameter is required, to update the group label.

```
PUT /groups/:id/labels
```

| Attribute     | Type    | Required | Description                  |
| ------------- | ------- | -------- | ---------------------------- |
| `id` | integer/string | yes | The ID or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user |
| `name`        | string  | yes      | The name of the label        |
| `new_name`    | string  | no      | The new name of the label        |
| `color`       | string  | no      | The color of the label given in 6-digit hex notation with leading '#' sign (e.g. #FFAABB) or one of the [CSS color names](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#Color_keywords) |
| `description` | string  | no       | The description of the label. |

```bash
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" --header "Content-Type: application/json" --data '{"name": "Feature Proposal", "new_name": "Feature Idea" }' https://gitlab.example.com/api/v4/groups/5/labels
```

Example response:

```json
{
  "id": 9,
  "name": "Feature Idea",
  "color": "#FFA500",
  "text_color" : "#FFFFFF",
  "description": "Describes new ideas",
  "open_issues_count": 0,
  "closed_issues_count": 0,
  "open_merge_requests_count": 0,
  "subscribed": false
}
```

## Delete a group label

Deletes a group label with a given name.

```
DELETE /groups/:id/labels
```

| Attribute | Type    | Required | Description           |
| --------- | ------- | -------- | --------------------- |
| `id`      | integer/string    | yes      | The ID or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user |
| `name`    | string  | yes      | The name of the label. |

```bash
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/groups/5/labels?name=bug
```

## Subscribe to a group label

Subscribes the authenticated user to a group label to receive notifications. If
the user is already subscribed to the label, the status code `304` is returned.

```
POST /groups/:id/labels/:label_id/subscribe
```

| Attribute  | Type              | Required | Description                          |
| ---------- | ----------------- | -------- | ------------------------------------ |
| `id`      | integer/string    | yes      | The ID or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user |
| `label_id` | integer or string | yes      | The ID or title of a group's label. |

```bash
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/groups/5/labels/9/subscribe
```

Example response:

```json
{
  "id": 9,
  "name": "Feature Idea",
  "color": "#FFA500",
  "text_color" : "#FFFFFF",
  "description": "Describes new ideas",
  "open_issues_count": 0,
  "closed_issues_count": 0,
  "open_merge_requests_count": 0,
  "subscribed": true
}
```

## Unsubscribe from a group label

Unsubscribes the authenticated user from a group label to not receive
notifications from it. If the user is not subscribed to the label, the status
code `304` is returned.

```
POST /groups/:id/labels/:label_id/unsubscribe
```

| Attribute  | Type              | Required | Description                          |
| ---------- | ----------------- | -------- | ------------------------------------ |
| `id`      | integer/string    | yes      | The ID or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user |
| `label_id` | integer or string | yes      | The ID or title of a group's label. |

```bash
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/groups/5/labels/9/unsubscribe
```

Example response:

```json
{
  "id": 9,
  "name": "Feature Idea",
  "color": "#FFA500",
  "text_color" : "#FFFFFF",
  "description": "Describes new ideas",
  "open_issues_count": 0,
  "closed_issues_count": 0,
  "open_merge_requests_count": 0,
  "subscribed": false
}
```
