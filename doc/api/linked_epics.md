---
stage: Plan
group: Product Planning
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Linked epics API **(ULTIMATE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/352493) in GitLab 14.9 [with a flag](../administration/feature_flags.md) named `related_epics_widget`. Enabled by default.

FLAG:
On self-managed GitLab, by default this feature is available. To hide the feature, ask an administrator to [disable the feature flag](../administration/feature_flags.md) named `related_epics_widget`. On GitLab.com, this feature is available.

If the Related Epics feature is not available in your GitLab plan, a `403` status code is returned.

## List linked epics

Get a list of a given epic's linked epics filtered according to the user authorizations.

```plaintext
GET /groups/:id/epics/:epic_iid/related_epics
```

Supported attributes:

| Attribute  | Type           | Required               | Description                                                               |
| ---------- | -------------- | ---------------------- | ------------------------------------------------------------------------- |
| `epic_iid` | integer        | **{check-circle}** Yes | Internal ID of a group's epic                                             |
| `id`       | integer/string | **{check-circle}** Yes | ID or [URL-encoded path of the group](index.md#namespaced-path-encoding). |

Example request:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/:id/epics/:epic_iid/related_epics"
```

Example response:

```json
[
   {
      "id":2,
      "iid":2,
      "color":"#1068bf",
      "text_color":"#FFFFFF",
      "group_id":2,
      "parent_id":null,
      "parent_iid":null,
      "title":"My title 2",
      "description":null,
      "confidential":false,
      "author":{
         "id":3,
         "username":"user3",
         "name":"Sidney Jones4",
         "state":"active",
         "avatar_url":"https://www.gravatar.com/avatar/82797019f038ab535a84c6591e7bc936?s=80u0026d=identicon",
         "web_url":"http://localhost/user3"
      },
      "start_date":null,
      "end_date":null,
      "due_date":null,
      "state":"opened",
      "web_url":"http://localhost/groups/group1/-/epics/2",
      "references":{
         "short":"u00262",
         "relative":"u00262",
         "full":"group1u00262"
      },
      "created_at":"2022-03-10T18:35:24.479Z",
      "updated_at":"2022-03-10T18:35:24.479Z",
      "closed_at":null,
      "labels":[

      ],
      "upvotes":0,
      "downvotes":0,
      "_links":{
         "self":"http://localhost/api/v4/groups/2/epics/2",
         "epic_issues":"http://localhost/api/v4/groups/2/epics/2/issues",
         "group":"http://localhost/api/v4/groups/2",
         "parent":null
      },
      "related_epic_link_id":1,
      "link_type":"relates_to",
      "link_created_at":"2022-03-10T18:35:24.496+00:00",
      "link_updated_at":"2022-03-10T18:35:24.496+00:00"
   }
]
```

## Create a related epic link

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/352840) in GitLab 14.10.

Create a two-way relation between two epics. The user must be allowed to
update both epics to succeed.

```plaintext
POST /groups/:id/epics/:epic_iid/related_epics
```

Supported attributes:

| Attribute           | Type           | Required                    | Description                           |
|---------------------|----------------|-----------------------------|---------------------------------------|
| `epic_iid`          | integer        | **{check-circle}** Yes      | Internal ID of a group's epic.        |
| `id`                | integer/string | **{check-circle}** Yes      | ID or [URL-encoded path of the group](index.md#namespaced-path-encoding) owned by the authenticated user. |
| `target_epic_iid`   | integer/string | **{check-circle}** Yes      | Internal ID of a target group's epic. |
| `target_group_id`   | integer/string | **{check-circle}** Yes      | ID or [URL-encoded path of the target group](index.md#namespaced-path-encoding). |
| `link_type`         | string         | **{dotted-circle}** No      | Type of the relation (`relates_to`, `blocks`, `is_blocked_by`), defaults to `relates_to`. |

Example request:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/26/epics/1/related_epics?target_group_id=26&target_epic_iid=5"
```

Example response:

```json
{
  "source_epic": {
    "id": 21,
    "iid": 1,
    "color": "#1068bf",
    "text_color": "#FFFFFF",
    "group_id": 26,
    "parent_id": null,
    "parent_iid": null,
    "title": "Aspernatur recusandae distinctio omnis et qui est iste.",
    "description": "some description",
    "confidential": false,
    "author": {
      "id": 15,
      "username": "trina",
      "name": "Theresia Robel",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/085e28df717e16484cbf6ceca75e9a93?s=80&d=identicon",
      "web_url": "http://gitlab.example.com/trina"
    },
    "start_date": null,
    "end_date": null,
    "due_date": null,
    "state": "opened",
    "web_url": "http://gitlab.example.com/groups/flightjs/-/epics/1",
    "references": {
      "short": "&1",
      "relative": "&1",
      "full": "flightjs&1"
    },
    "created_at": "2022-01-31T15:10:44.988Z",
    "updated_at": "2022-03-16T09:32:35.712Z",
    "closed_at": null,
    "labels": [],
    "upvotes": 0,
    "downvotes": 0,
    "_links": {
      "self": "http://gitlab.example.com/api/v4/groups/26/epics/1",
      "epic_issues": "http://gitlab.example.com/api/v4/groups/26/epics/1/issues",
      "group": "http://gitlab.example.com/api/v4/groups/26",
      "parent": null
    }
  },
  "target_epic": {
    "id": 25,
    "iid": 5,
    "color": "#1068bf",
    "text_color": "#FFFFFF",
    "group_id": 26,
    "parent_id": null,
    "parent_iid": null,
    "title": "Aut assumenda id nihil distinctio fugiat vel numquam est.",
    "description": "some description",
    "confidential": false,
    "author": {
      "id": 3,
      "username": "valerie",
      "name": "Erika Wolf",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/9ef7666abb101418a4716a8ed4dded80?s=80&d=identicon",
      "web_url": "http://gitlab.example.com/valerie"
    },
    "start_date": null,
    "end_date": null,
    "due_date": null,
    "state": "opened",
    "web_url": "http://gitlab.example.com/groups/flightjs/-/epics/5",
    "references": {
      "short": "&5",
      "relative": "&5",
      "full": "flightjs&5"
    },
    "created_at": "2022-01-31T15:10:45.080Z",
    "updated_at": "2022-03-16T09:32:35.842Z",
    "closed_at": null,
    "labels": [],
    "upvotes": 0,
    "downvotes": 0,
    "_links": {
      "self": "http://gitlab.example.com/api/v4/groups/26/epics/5",
      "epic_issues": "http://gitlab.example.com/api/v4/groups/26/epics/5/issues",
      "group": "http://gitlab.example.com/api/v4/groups/26",
      "parent": null
    }
  },
  "link_type": "relates_to"
}
```

## Delete a related epic link

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/352840) in GitLab 14.10.

Delete a two-way relation between two epics. The user must be allowed to
update both epics to succeed.

```plaintext
DELETE /groups/:id/epics/:epic_iid/related_epics/:related_epic_link_id
```

Supported attributes:

| Attribute                | Type           | Required                    | Description                           |
|--------------------------|----------------|-----------------------------|---------------------------------------|
| `epic_iid`               | integer        | **{check-circle}** Yes      | Internal ID of a group's epic.        |
| `id`                     | integer/string | **{check-circle}** Yes      | ID or [URL-encoded path of the group](index.md#namespaced-path-encoding) owned by the authenticated user. |
| `related_epic_link_id`   | integer/string | **{check-circle}** Yes      | Internal ID of a related epic link. |

Example request:

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/26/epics/1/related_epics/1"
```

Example response:

```json
{
  "source_epic": {
    "id": 21,
    "iid": 1,
    "color": "#1068bf",
    "text_color": "#FFFFFF",
    "group_id": 26,
    "parent_id": null,
    "parent_iid": null,
    "title": "Aspernatur recusandae distinctio omnis et qui est iste.",
    "description": "some description",
    "confidential": false,
    "author": {
      "id": 15,
      "username": "trina",
      "name": "Theresia Robel",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/085e28df717e16484cbf6ceca75e9a93?s=80&d=identicon",
      "web_url": "http://gitlab.example.com/trina"
    },
    "start_date": null,
    "end_date": null,
    "due_date": null,
    "state": "opened",
    "web_url": "http://gitlab.example.com/groups/flightjs/-/epics/1",
    "references": {
      "short": "&1",
      "relative": "&1",
      "full": "flightjs&1"
    },
    "created_at": "2022-01-31T15:10:44.988Z",
    "updated_at": "2022-03-16T09:32:35.712Z",
    "closed_at": null,
    "labels": [],
    "upvotes": 0,
    "downvotes": 0,
    "_links": {
      "self": "http://gitlab.example.com/api/v4/groups/26/epics/1",
      "epic_issues": "http://gitlab.example.com/api/v4/groups/26/epics/1/issues",
      "group": "http://gitlab.example.com/api/v4/groups/26",
      "parent": null
    }
  },
  "target_epic": {
    "id": 25,
    "iid": 5,
    "color": "#1068bf",
    "text_color": "#FFFFFF",
    "group_id": 26,
    "parent_id": null,
    "parent_iid": null,
    "title": "Aut assumenda id nihil distinctio fugiat vel numquam est.",
    "description": "some description",
    "confidential": false,
    "author": {
      "id": 3,
      "username": "valerie",
      "name": "Erika Wolf",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/9ef7666abb101418a4716a8ed4dded80?s=80&d=identicon",
      "web_url": "http://gitlab.example.com/valerie"
    },
    "start_date": null,
    "end_date": null,
    "due_date": null,
    "state": "opened",
    "web_url": "http://gitlab.example.com/groups/flightjs/-/epics/5",
    "references": {
      "short": "&5",
      "relative": "&5",
      "full": "flightjs&5"
    },
    "created_at": "2022-01-31T15:10:45.080Z",
    "updated_at": "2022-03-16T09:32:35.842Z",
    "closed_at": null,
    "labels": [],
    "upvotes": 0,
    "downvotes": 0,
    "_links": {
      "self": "http://gitlab.example.com/api/v4/groups/26/epics/5",
      "epic_issues": "http://gitlab.example.com/api/v4/groups/26/epics/5/issues",
      "group": "http://gitlab.example.com/api/v4/groups/26",
      "parent": null
    }
  },
  "link_type": "relates_to"
}
```
