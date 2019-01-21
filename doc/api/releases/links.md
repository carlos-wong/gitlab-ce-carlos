# Release links API

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/issues/41766) in GitLab 11.7.

Using this API you can manipulate GitLab's [Release](../../user/project/releases/index.md) links. For manipulating other Release assets, see [Release API](index.md).

## Get links

Get assets as links from a Release.

```
GET /projects/:id/releases/:tag_name/assets/links
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |

Example request:

```sh
curl --header "PRIVATE-TOKEN: gDybLx3yrUK_HLp3qPjS" "http://localhost:3000/api/v4/projects/24/releases/v0.1/assets/links"
```

Example response:

```json
[
   {
      "id":2,
      "name":"awesome-v0.2.msi",
      "url":"http://192.168.10.15:3000/msi",
      "external":true
   },
   {
      "id":1,
      "name":"awesome-v0.2.dmg",
      "url":"http://192.168.10.15:3000",
      "external":true
   }
]
```

## Get a link

Get an asset as a link from a Release.

```
GET /projects/:id/releases/:tag_name/assets/links/:link_id
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |
| `link_id`    | integer         | yes      | The id of the link. |

Example request:

```sh
curl --header "PRIVATE-TOKEN: gDybLx3yrUK_HLp3qPjS" "http://localhost:3000/api/v4/projects/24/releases/v0.1/assets/links/1"
```

Example response:

```json
{
   "id":1,
   "name":"awesome-v0.2.dmg",
   "url":"http://192.168.10.15:3000",
   "external":true
}
```

## Create a link

Create an asset as a link from a Release.

```
POST /projects/:id/releases/:tag_name/assets/links
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |
| `name`        | string         | yes      | The name of the link. |
| `url`        | string         | yes      | The URL of the link. |

Example request:

```sh
curl --request POST \
     --header "PRIVATE-TOKEN: gDybLx3yrUK_HLp3qPjS" \
     --data name="awesome-v0.2.dmg" \
     --data url="http://192.168.10.15:3000" \
     "http://localhost:3000/api/v4/projects/24/releases/v0.1/assets/links"
```

Example response:

```json
{
   "id":1,
   "name":"awesome-v0.2.dmg",
   "url":"http://192.168.10.15:3000",
   "external":true
}
```

## Update a link

Update an asset as a link from a Release.

```
PUT /projects/:id/releases/:tag_name/assets/links/:link_id
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |
| `link_id`    | integer         | yes      | The id of the link. |
| `name`        | string         | no | The name of the link. |
| `url`        | string         | no | The URL of the link. |

NOTE: **NOTE**
You have to specify at least one of `name` or `url`

Example request:

```sh
curl --request PUT --data name="new name" --header "PRIVATE-TOKEN: gDybLx3yrUK_HLp3qPjS" "http://localhost:3000/api/v4/projects/24/releases/v0.1/assets/links/1"
```

Example response:

```json
{
   "id":1,
   "name":"new name",
   "url":"http://192.168.10.15:3000",
   "external":true
}
```

## Delete a link

Delete an asset as a link from a Release.

```
DELETE /projects/:id/releases/:tag_name/assets/links/:link_id
```

| Attribute     | Type           | Required | Description                             |
| ------------- | -------------- | -------- | --------------------------------------- |
| `id`          | integer/string | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding). |
| `tag_name`    | string         | yes      | The tag associated with the Release. |
| `link_id`    | integer         | yes      | The id of the link. |

Example request:

```sh
curl --request DELETE --header "PRIVATE-TOKEN: gDybLx3yrUK_HLp3qPjS" "http://localhost:3000/api/v4/projects/24/releases/v0.1/assets/links/1"
```

Example response:

```json
{
   "id":1,
   "name":"new name",
   "url":"http://192.168.10.15:3000",
   "external":true
}
```
