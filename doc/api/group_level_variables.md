# Group-level Variables API

> [Introduced][ce-34519] in GitLab 9.5

## List group variables

Get list of a group's variables.

```plaintext
GET /groups/:id/variables
```

| Attribute | Type    | required | Description         |
|-----------|---------|----------|---------------------|
| `id`      | integer/string | yes      | The ID of a group or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/1/variables"
```

```json
[
    {
        "key": "TEST_VARIABLE_1",
        "variable_type": "env_var",
        "value": "TEST_1",
        "protected": false,
        "masked": false
    },
    {
        "key": "TEST_VARIABLE_2",
        "variable_type": "env_var",
        "value": "TEST_2",
        "protected": false,
        "masked": false
    }
]
```

## Show variable details

Get the details of a group's specific variable.

```plaintext
GET /groups/:id/variables/:key
```

| Attribute | Type    | required | Description           |
|-----------|---------|----------|-----------------------|
| `id`      | integer/string | yes      | The ID of a group or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user   |
| `key`     | string  | yes      | The `key` of a variable |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/1/variables/TEST_VARIABLE_1"
```

```json
{
    "key": "TEST_VARIABLE_1",
    "variable_type": "env_var",
    "value": "TEST_1",
    "protected": false,
    "masked": false
}
```

## Create variable

Create a new variable.

```plaintext
POST /groups/:id/variables
```

| Attribute       | Type    | required | Description           |
|-----------------|---------|----------|-----------------------|
| `id`            | integer/string | yes      | The ID of a group or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user   |
| `key`           | string  | yes      | The `key` of a variable; must have no more than 255 characters; only `A-Z`, `a-z`, `0-9`, and `_` are allowed |
| `value`         | string  | yes      | The `value` of a variable |
| `variable_type` | string  | no       | The type of a variable. Available types are: `env_var` (default) and `file` |
| `protected`     | boolean | no       | Whether the variable is protected |
| `masked`        | boolean | no       | Whether the variable is masked |

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/1/variables" --form "key=NEW_VARIABLE" --form "value=new value"
```

```json
{
    "key": "NEW_VARIABLE",
    "value": "new value",
    "variable_type": "env_var",
    "protected": false,
    "masked": false
}
```

## Update variable

Update a group's variable.

```plaintext
PUT /groups/:id/variables/:key
```

| Attribute       | Type    | required | Description             |
|-----------------|---------|----------|-------------------------|
| `id`            | integer/string | yes      | The ID of a group or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user     |
| `key`           | string  | yes      | The `key` of a variable   |
| `value`         | string  | yes      | The `value` of a variable |
| `variable_type` | string  | no       | The type of a variable. Available types are: `env_var` (default) and `file` |
| `protected`     | boolean | no       | Whether the variable is protected |
| `masked`        | boolean | no       | Whether the variable is masked |

```shell
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/1/variables/NEW_VARIABLE" --form "value=updated value"
```

```json
{
    "key": "NEW_VARIABLE",
    "value": "updated value",
    "variable_type": "env_var",
    "protected": true,
    "masked": true
}
```

## Remove variable

Remove a group's variable.

```plaintext
DELETE /groups/:id/variables/:key
```

| Attribute | Type    | required | Description             |
|-----------|---------|----------|-------------------------|
| `id`      | integer/string | yes      | The ID of a group or [URL-encoded path of the group](README.md#namespaced-path-encoding) owned by the authenticated user     |
| `key`     | string  | yes      | The `key` of a variable |

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/1/variables/VARIABLE_1"
```

[ce-34519]: https://gitlab.com/gitlab-org/gitlab-foss/issues/34519
