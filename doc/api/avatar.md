# Avatar API

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/19121) in GitLab 11.0.

## Get a single avatar URL

Get a single [avatar](../user/profile/index.md#profile-settings) URL for a user with the given email address.

If:

- No user with the given public email address is found, results from external avatar services are
  returned.
- Public visibility is restricted, response will be `403 Forbidden` when unauthenticated.

NOTE: **Note:**
This endpoint can be accessed without authentication.

```text
GET /avatar?email=admin@example.com
```

Parameters:

| Attribute | Type    | Required | Description                                                                                                                             |
|:----------|:--------|:---------|:----------------------------------------------------------------------------------------------------------------------------------------|
| `email`   | string  | yes      | Public email address of the user.                                                                                                       |
| `size`    | integer | no       | Single pixel dimension (since images are squares). Only used for avatar lookups at `Gravatar` or at the configured `Libravatar` server. |

Example request:

```shell
curl https://gitlab.example.com/api/v4/avatar?email=admin@example.com&size=32
```

Example response:

```json
{
  "avatar_url": "https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=64&d=identicon"
}
```
