---
stage: Release
group: Release
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Release links API **(FREE)**

Use this API to manipulate GitLab [Release](../../user/project/releases/index.md)
links. For manipulating other Release assets, see [Release API](index.md).

GitLab supports links to `http`, `https`, and `ftp` assets.

## Authentication

For authentication, the Release Links API accepts:

- A [Personal Access Token](../../user/profile/personal_access_tokens.md) using the
  `PRIVATE-TOKEN` header.
- A [Project Access Token](../../user/project/settings/project_access_tokens.md) using the `PRIVATE-TOKEN` header.

The [GitLab CI/CD job token](../../ci/jobs/ci_job_token.md) `$CI_JOB_TOKEN` is not supported. See [GitLab issue #50819](https://gitlab.com/gitlab-org/gitlab/-/issues/250819) for more details.

## Get links

Get assets as links from a Release.

```plaintext
GET /projects/:id/releases/:tag_name/assets/links
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](../index.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |

Example request:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/24/releases/v0.1/assets/links"
```

Example response:

```json
[
   {
      "id":2,
      "name":"awesome-v0.2.msi",
      "url":"http://192.168.10.15:3000/msi",
      "external":true,
      "link_type":"other"
   },
   {
      "id":1,
      "name":"awesome-v0.2.dmg",
      "url":"http://192.168.10.15:3000",
      "external":true,
      "link_type":"other"
   }
]
```

## Get a link

Get an asset as a link from a Release.

```plaintext
GET /projects/:id/releases/:tag_name/assets/links/:link_id
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](../index.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |
| `link_id`    | integer         | yes      | The ID of the link. |

Example request:

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/24/releases/v0.1/assets/links/1"
```

Example response:

```json
{
   "id":1,
   "name":"awesome-v0.2.dmg",
   "url":"http://192.168.10.15:3000",
   "external":true,
   "link_type":"other"
}
```

## Create a link

Create an asset as a link from a Release.

```plaintext
POST /projects/:id/releases/:tag_name/assets/links
```

| Attribute     | Type           | Required | Description                                                                                                      |
| ------------- | -------------- | -------- | ---------------------------------------------------------------------------------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](../index.md#namespaced-path-encoding).                              |
| `tag_name`    | string         | yes      | The tag associated with the Release.                                                                             |
| `name`        | string         | yes      | The name of the link. Link names must be unique within the release.                                              |
| `url`         | string         | yes      | The URL of the link. Link URLs must be unique within the release.                                                |
| `filepath`    | string         | no       | Optional path for a [Direct Asset link](../../user/project/releases/index.md#permanent-links-to-release-assets). |
| `link_type`   | string         | no       | The type of the link: `other`, `runbook`, `image`, `package`. Defaults to `other`.                               |

Example request:

```shell
curl --request POST \
    --header "PRIVATE-TOKEN: <your_access_token>" \
    --data name="hellodarwin-amd64" \
    --data url="https://gitlab.example.com/mynamespace/hello/-/jobs/688/artifacts/raw/bin/hello-darwin-amd64" \
    --data filepath="/bin/hellodarwin-amd64" \
    "https://gitlab.example.com/api/v4/projects/20/releases/v1.7.0/assets/links"
```

Example response:

```json
{
   "id":2,
   "name":"hellodarwin-amd64",
   "url":"https://gitlab.example.com/mynamespace/hello/-/jobs/688/artifacts/raw/bin/hello-darwin-amd64",
   "direct_asset_url":"https://gitlab.example.com/mynamespace/hello/-/releases/v1.7.0/downloads/bin/hellodarwin-amd64",
   "external":false,
   "link_type":"other"
}
```

## Update a link

Update an asset as a link from a Release.

```plaintext
PUT /projects/:id/releases/:tag_name/assets/links/:link_id
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](../index.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |
| `link_id`     | integer         | yes      | The ID of the link. |
| `name`        | string         | no | The name of the link. |
| `url`         | string         | no | The URL of the link. |
| `filepath` | string     | no | Optional path for a [Direct Asset link](../../user/project/releases/index.md#permanent-links-to-release-assets).
| `link_type`        | string         | no       | The type of the link: `other`, `runbook`, `image`, `package`. Defaults to `other`. |

NOTE:
You have to specify at least one of `name` or `url`

Example request:

```shell
curl --request PUT --data name="new name" --data link_type="runbook" \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     "https://gitlab.example.com/api/v4/projects/24/releases/v0.1/assets/links/1"
```

Example response:

```json
{
   "id":1,
   "name":"new name",
   "url":"http://192.168.10.15:3000",
   "external":true,
   "link_type":"runbook"
}
```

## Delete a link

Delete an asset as a link from a Release.

```plaintext
DELETE /projects/:id/releases/:tag_name/assets/links/:link_id
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](../index.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |
| `link_id`    | integer         | yes      | The ID of the link. |

Example request:

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/24/releases/v0.1/assets/links/1"
```

Example response:

```json
{
   "id":1,
   "name":"new name",
   "url":"http://192.168.10.15:3000",
   "external":true,
   "link_type":"other"
}
```
