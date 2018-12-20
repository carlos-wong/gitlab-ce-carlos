# Suggest Changes API

Every API call to suggestions must be authenticated.

## Applying suggestions

Applies a suggested patch in a merge request. Users must be
at least [Developer](../user/permissions.md) to perform such action.

```
PUT /suggestions/:id/apply
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | integer/string | yes | The ID of a suggestion |

```bash
curl --request PUT --header "PRIVATE-TOKEN: 9koXpg98eAheJpvBs5tK" https://gitlab.example.com/api/v4/suggestions/5/apply
```

Example response:

```json
  {
    "id": 36,
    "from_original_line": 10,
    "to_original_line": 10,
    "from_line": 10,
    "to_line": 10,
    "appliable": false,
    "applied": true,
    "from_content": "        \"--talk-name=org.freedesktop.\",\n",
    "to_content": "        \"--talk-name=org.free.\",\n        \"--talk-name=org.desktop.\",\n"
  }
```
