# Applications API

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/8160) in GitLab 10.5.

Applications API operates on OAuth applications for:

- [Using GitLab as an authentication provider](../integration/oauth_provider.md).
- [Allowing access to GitLab resources on a user's behalf](oauth2.md).

NOTE: **Note:**
Only admin users can use the Applications API.

## Create an application

Create an application by posting a JSON payload.

Returns `200` if the request succeeds.

```text
POST /applications
```

Parameters:

| Attribute      | Type   | Required | Description                      |
|:---------------|:-------|:---------|:---------------------------------|
| `name`         | string | yes      | Name of the application.         |
| `redirect_uri` | string | yes      | Redirect URI of the application. |
| `scopes`       | string | yes      | Scopes of the application.       |

Example request:

```sh
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" --data "name=MyApplication&redirect_uri=http://redirect.uri&scopes=" https://gitlab.example.com/api/v4/applications
```

Example response:

```json
{
    "id":1,
    "application_id": "5832fc6e14300a0d962240a8144466eef4ee93ef0d218477e55f11cf12fc3737",
    "application_name": "MyApplication",
    "secret": "ee1dd64b6adc89cf7e2c23099301ccc2c61b441064e9324d963c46902a85ec34",
    "callback_url": "http://redirect.uri"
}
```

## List all applications

List all registered applications.

```text
GET /applications
```

Example request:

```sh
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/applications
```

Example response:

```json
[
    {
        "id":1,
        "application_id": "5832fc6e14300a0d962240a8144466eef4ee93ef0d218477e55f11cf12fc3737",
        "application_name": "MyApplication",
        "callback_url": "http://redirect.uri"
    }
]
```

NOTE: **Note:**
The `secret` value will not be exposed by this API.

## Delete an application

Delete a specific application.

Returns `204` if the request succeeds.

```text
DELETE /applications/:id
```

Parameters:

| Attribute | Type    | Required | Description                                         |
|:----------|:--------|:---------|:----------------------------------------------------|
| `id`      | integer | yes      | The id of the application (not the application_id). |

Example request:

```sh
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/applications/:id
```
