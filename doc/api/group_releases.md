---
stage: Release
group: Release
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Group releases API **(FREE)**

Review your groups' [releases](../user/project/releases/index.md) with the REST API.

NOTE:
For information about the project releases API, visit the [Releases API](releases/index.md) page.

FLAG:
On self-managed GitLab, by default this feature is not available. To make it available, ask an administrator to [enable the feature flag](../administration/feature_flags.md) named `group_releases_finder_inoperator`.

## List group releases

Returns a list of group releases.

```plaintext
GET /groups/:id/releases
GET /groups/:id/releases?simple=true
```

Parameters:

| Attribute           | Type           | Required | Description                                                                                                   |
|---------------------|----------------|----------|---------------------------------------------------------------------------------------------------------------|
| `id`                | integer/string | yes      | The ID or [URL-encoded path of the group](index.md#namespaced-path-encoding) owned by the authenticated user. |
| `sort`              | string         | no       | The direction of the order. Either `desc` (default) for descending order or `asc` for ascending order.        |
| `simple`            | boolean        | no       | Return only limited fields for each release.                                                                  |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/5/releases"
```

Example response:

```json
[
  {
    "name": "standard release",
    "tag_name": "releasetag",
    "description": "",
    "created_at": "2022-01-10T15:23:15.529Z",
    "released_at": "2022-01-10T15:23:15.529Z",
    "author": {
      "id": 1,
      "username": "root",
      "name": "Administrator",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon",
      "web_url": "https://gitlab.com/root"
    },
    "commit": {
      "id": "e8cbb845ae5a53a2fef2938cf63cf82efc10d993",
      "short_id": "e8cbb845",
      "created_at": "2022-01-10T15:20:29.000+00:00",
      "parent_ids": [],
      "title": "Update test",
      "message": "Update test",
      "author_name": "Administrator",
      "author_email": "admin@example.com",
      "authored_date": "2022-01-10T15:20:29.000+00:00",
      "committer_name": "Administrator",
      "committer_email": "admin@example.com",
      "committed_date": "2022-01-10T15:20:29.000+00:00",
      "trailers": {},
      "web_url": "https://gitlab.com/groups/gitlab-org/-/commit/e8cbb845ae5a53a2fef2938cf63cf82efc10d993"
    },
    "upcoming_release": false,
    "commit_path": "/testgroup/test/-/commit/e8cbb845ae5a53a2fef2938cf63cf82efc10d993",
    "tag_path": "/testgroup/test/-/tags/testtag"
  }
]
```
