---
stage: Growth
group: Acquisition
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Broadcast Messages API **(FREE SELF)**

> `target_access_levels` [introduced](https://gitlab.com/gitlab-org/growth/team-tasks/-/issues/461) in GitLab 14.8 [with a flag](../administration/feature_flags.md) named `role_targeted_broadcast_messages`. Disabled by default.

Broadcast messages API operates on [broadcast messages](../user/admin_area/broadcast_messages.md).

As of GitLab 12.8, GET requests do not require authentication. All other broadcast message API endpoints are accessible only to administrators. Non-GET requests by:

- Guests result in `401 Unauthorized`.
- Regular users result in `403 Forbidden`.

## Get all broadcast messages **(FREE)**

List all broadcast messages.

```plaintext
GET /broadcast_messages
```

Example request:

```shell
curl "https://gitlab.example.com/api/v4/broadcast_messages"
```

Example response:

```json
[
    {
        "message":"Example broadcast message",
        "starts_at":"2016-08-24T23:21:16.078Z",
        "ends_at":"2016-08-26T23:21:16.080Z",
        "color":"#E75E40",
        "font":"#FFFFFF",
        "id":1,
        "active": false,
        "target_access_levels": [10,30],
        "target_path": "*/welcome",
        "broadcast_type": "banner",
        "dismissable": false
    }
]
```

## Get a specific broadcast message **(FREE)**

Get a specific broadcast message.

```plaintext
GET /broadcast_messages/:id
```

Parameters:

| Attribute | Type    | Required | Description                          |
|:----------|:--------|:---------|:-------------------------------------|
| `id`      | integer | yes      | ID of broadcast message to retrieve. |

Example request:

```shell
curl "https://gitlab.example.com/api/v4/broadcast_messages/1"
```

Example response:

```json
{
    "message":"Deploy in progress",
    "starts_at":"2016-08-24T23:21:16.078Z",
    "ends_at":"2016-08-26T23:21:16.080Z",
    "color":"#cecece",
    "font":"#FFFFFF",
    "id":1,
    "active":false,
    "target_access_levels": [10,30],
    "target_path": "*/welcome",
    "broadcast_type": "banner",
    "dismissable": false
}
```

## Create a broadcast message

Create a new broadcast message.

```plaintext
POST /broadcast_messages
```

Parameters:

| Attribute              | Type              | Required | Description                                           |
|:-----------------------|:------------------|:---------|:------------------------------------------------------|
| `message`              | string            | yes      | Message to display.                                   |
| `starts_at`            | datetime          | no       | Starting time (defaults to current time in UTC). Expected in ISO 8601 format (`2019-03-15T08:00:00Z`) |
| `ends_at`              | datetime          | no       | Ending time (defaults to one hour from current time in UTC). Expected in ISO 8601 format (`2019-03-15T08:00:00Z`) |
| `color`                | string            | no       | Background color hex code.                            |
| `font`                 | string            | no       | Foreground color hex code.                            |
| `target_access_levels` | array of integers | no       | Target access levels (roles) of the broadcast message.|
| `target_path`          | string            | no       | Target path of the broadcast message.                 |
| `broadcast_type`       | string            | no       | Appearance type (defaults to banner)                  |
| `dismissable`          | boolean           | no       | Can the user dismiss the message?                     |

The `target_access_levels` are defined in the `Gitlab::Access` module. The
following levels are valid:

- Guest (`10`)
- Reporter (`20`)
- Developer (`30`)
- Maintainer (`40`)
- Owner (`50`)

Example request:

```shell
curl --data "message=Deploy in progress&color=#cecece&target_access_levels[]=10&target_access_levels[]=30" \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     "https://gitlab.example.com/api/v4/broadcast_messages"
```

Example response:

```json
{
    "message":"Deploy in progress",
    "starts_at":"2016-08-26T00:41:35.060Z",
    "ends_at":"2016-08-26T01:41:35.060Z",
    "color":"#cecece",
    "font":"#FFFFFF",
    "id":1,
    "active": true,
    "target_access_levels": [10,30],
    "target_path": "*/welcome",
    "broadcast_type": "notification",
    "dismissable": false
}
```

## Update a broadcast message

Update an existing broadcast message.

```plaintext
PUT /broadcast_messages/:id
```

Parameters:

| Attribute              | Type              | Required | Description                                           |
|:-----------------------|:------------------|:---------|:------------------------------------------------------|
| `id`                   | integer           | yes      | ID of broadcast message to update.                    |
| `message`              | string            | no       | Message to display.                                   |
| `starts_at`            | datetime          | no       | Starting time (UTC). Expected in ISO 8601 format (`2019-03-15T08:00:00Z`) |
| `ends_at`              | datetime          | no       | Ending time (UTC). Expected in ISO 8601 format (`2019-03-15T08:00:00Z`) |
| `color`                | string            | no       | Background color hex code.                            |
| `font`                 | string            | no       | Foreground color hex code.                            |
| `target_access_levels` | array of integers | no       | Target access levels (roles) of the broadcast message.|
| `target_path`          | string            | no       | Target path of the broadcast message.                 |
| `broadcast_type`       | string            | no       | Appearance type (defaults to banner)                  |
| `dismissable`          | boolean           | no       | Can the user dismiss the message?                     |

The `target_access_levels` are defined in the `Gitlab::Access` module. The
following levels are valid:

- Guest (`10`)
- Reporter (`20`)
- Developer (`30`)
- Maintainer (`40`)
- Owner (`50`)

Example request:

```shell
curl --request PUT --data "message=Update message&color=#000" \
     --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/broadcast_messages/1"
```

Example response:

```json
{
    "message":"Update message",
    "starts_at":"2016-08-26T00:41:35.060Z",
    "ends_at":"2016-08-26T01:41:35.060Z",
    "color":"#000",
    "font":"#FFFFFF",
    "id":1,
    "active": true,
    "target_access_levels": [10,30],
    "target_path": "*/welcome",
    "broadcast_type": "notification",
    "dismissable": false
}
```

## Delete a broadcast message

Delete a broadcast message.

```plaintext
DELETE /broadcast_messages/:id
```

Parameters:

| Attribute | Type    | Required | Description                        |
|:----------|:--------|:---------|:-----------------------------------|
| `id`      | integer | yes      | ID of broadcast message to delete. |

Example request:

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/broadcast_messages/1"
```
