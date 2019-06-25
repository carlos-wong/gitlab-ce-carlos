# Managed Licenses API **[ULTIMATE]**

## List managed licenses

Get all managed licenses for a given project.

```
GET /projects/:id/managed_licenses
```

| Attribute | Type    | Required | Description           |
| --------- | ------- | -------- | --------------------- |
| `id`      | integer/string    | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) |

```bash
curl --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/projects/1/managed_licenses
```

Example response:

```json
[
  {
    "id": 1,
    "name": "MIT",
    "approval_status": "approved"
  },
  {
    "id": 3,
    "name": "ISC",
    "approval_status": "blacklisted"
  }
]
```

## Show an existing managed license

Shows an existing managed license.

```
GET /projects/:id/managed_licenses/:managed_license_id
```

| Attribute       | Type    | Required                          | Description                      |
| --------------- | ------- | --------------------------------- | -------------------------------  |
| `id`      | integer/string    | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user |
| `managed_license_id`      | integer/string    | yes      | The ID or URL-encoded name of the license belonging to the project |

```bash
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/1/managed_licenses/6"
```

Example response:

```json
{
  "id": 1,
  "name": "MIT",
  "approval_status": "blacklisted"
}
```

## Create a new managed license

Creates a new managed license for the given project with the given name and approval status.

```
POST /projects/:id/managed_licenses
```

| Attribute     | Type    | Required | Description                  |
| ------------- | ------- | -------- | ---------------------------- |
| `id`      | integer/string    | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user |
| `name`        | string  | yes      | The name of the managed license        |
| `approval_status`       | string  | yes      | The approval status. "approved" or "blacklisted" |

```bash
curl --data "name=MIT&approval_status=blacklisted" --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/1/managed_licenses"
```

Example response:

```json
{
  "id": 1,
  "name": "MIT",
  "approval_status": "approved"
}
```

## Delete a managed license

Deletes a managed license with a given id.

```
DELETE /projects/:id/managed_licenses/:managed_license_id
```

| Attribute | Type    | Required | Description           |
| --------- | ------- | -------- | --------------------- |
| `id`      | integer/string    | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user |
| `managed_license_id`      | integer/string    | yes      | The ID or URL-encoded name of the license belonging to the project |

```bash
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/1/managed_licenses/4"
```

When successful, it replies with an HTTP 204 response. 

## Edit an existing managed license

Updates an existing managed license with a new approval status.

```
PATCH /projects/:id/managed_licenses/:managed_license_id
```

| Attribute       | Type    | Required                          | Description                      |
| --------------- | ------- | --------------------------------- | -------------------------------  |
| `id`      | integer/string    | yes      | The ID or [URL-encoded path of the project](README.md#namespaced-path-encoding) owned by the authenticated user |
| `managed_license_id`      | integer/string    | yes      | The ID or URL-encoded name of the license belonging to the project |
| `approval_status`       | string  | yes      | The approval status. "approved" or "blacklisted" |

```bash
curl --request PATCH --data "approval_status=blacklisted" --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/1/managed_licenses/6"
```

Example response:

```json
{
  "id": 1,
  "name": "MIT",
  "approval_status": "blacklisted"
}
```
