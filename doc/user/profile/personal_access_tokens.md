# Personal access tokens

> [Introduced][ce-3749] in GitLab 8.8.

Personal access tokens are the preferred way for third party applications and scripts to
authenticate with the [GitLab API][api], if using [OAuth2](../../api/oauth2.md) is not practical.

You can also use personal access tokens to authenticate against Git over HTTP or SSH. They must be used when you have [Two-Factor Authentication (2FA)][2fa] enabled. Authenticate with a token in place of your password.

To make [authenticated requests to the API][usage], use either the `private_token` parameter or the `Private-Token` header.

The expiration of personal access tokens happens on the date you define,
at midnight UTC.

## Creating a personal access token

You can create as many personal access tokens as you like from your GitLab
profile.

1. Log in to GitLab.
1. In the upper-right corner, click your avatar and select **Settings**.
1. On the  **User Settings** menu, select **Access Tokens**.
1. Choose a name and optional expiry date for the token.
1. Choose the [desired scopes](#limiting-scopes-of-a-personal-access-token).
1. Click the **Create personal access token** button.
1. Save the personal access token somewhere safe. Once you leave or refresh
   the page, you won't be able to access it again.

### Revoking a personal access token

At any time, you can revoke any personal access token by clicking the
respective **Revoke** button under the **Active Personal Access Token** area.

## Limiting scopes of a personal access token

Personal access tokens can be created with one or more scopes that allow various
actions that a given token can perform. The available scopes are depicted in
the following table.

| Scope              | Introduced in | Description |
| ------------------ | ------------- | ----------- |
| `read_user`        | [GitLab 8.15](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/5951)   | Allows access to the read-only endpoints under `/users`. Essentially, any of the `GET` requests in the [Users API][users] are allowed. |
| `api`              | [GitLab 8.15](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/5951)   | Grants complete access to the API and Container Registry (read/write). |
| `read_registry`    | [GitLab 9.3](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/11845)   | Allows to read (pull) [container registry] images if a project is private and authorization is required. |
| `sudo`             | [GitLab 10.2](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/14838)  | Allows performing API actions as any user in the system (if the authenticated user is an admin). |
| `read_repository`  | [GitLab 10.7](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/17894)  | Allows read-only access (pull) to the repository through git clone. |
| `write_repository` | [GitLab 11.11](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/26021) | Allows read-write access (pull, push) to the repository through git clone. Required for accessing Git repositories over HTTP when 2FA is enabled. |

[2fa]: ../account/two_factor_authentication.md
[api]: ../../api/README.md
[ce-3749]: https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/3749
[container registry]: ../project/container_registry.md
[users]: ../../api/users.md
[usage]: ../../api/README.md#personal-access-tokens
