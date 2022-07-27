---
stage: Manage
group: Authentication and Authorization
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments"
type: reference, howto
---

# Group access tokens

With group access tokens, you can use a single token to:

- Perform actions for groups.
- Manage the projects within the group.

You can use a group access token to authenticate:

- With the [GitLab API](../../../api/index.md#personalprojectgroup-access-tokens).
- In [GitLab 14.2](https://gitlab.com/gitlab-org/gitlab/-/issues/330718) and later, authenticate with Git over HTTPS.
  Use:

  - Any non-blank value as a username.
  - The group access token as the password.

Group access tokens are similar to [project access tokens](../../project/settings/project_access_tokens.md)
and [personal access tokens](../../profile/personal_access_tokens.md), except they are
associated with a group rather than a project or user.

In self-managed instances, group access tokens are subject to the same [maximum lifetime limits](../../admin_area/settings/account_and_limit_settings.md#limit-the-lifetime-of-access-tokens) as personal access tokens if the limit is set.

You can use group access tokens:

- On GitLab SaaS if you have the Premium license tier or higher. Group access tokens are not available with a [trial license](https://about.gitlab.com/free-trial/).
- On self-managed instances of GitLab, with any license tier. If you have the Free tier:
  - Review your security and compliance policies around
    [user self-enrollment](../../admin_area/settings/sign_up_restrictions.md#disable-new-sign-ups).
  - Consider [disabling group access tokens](#enable-or-disable-group-access-token-creation) to
    lower potential abuse.

You cannot use group access tokens to create other group, project, or personal access tokens.

Group access tokens inherit the [default prefix setting](../../admin_area/settings/account_and_limit_settings.md#personal-access-token-prefix)
configured for personal access tokens.

## Create a group access token using UI

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/214045) in GitLab 14.7.

To create a group access token:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Settings > Access Tokens**.
1. Enter a name. The token name is visible to any user with permissions to view the group.
1. Optional. Enter an expiry date for the token. The token will expire on that date at midnight UTC. An instance-wide [maximum lifetime](../../admin_area/settings/account_and_limit_settings.md#limit-the-lifetime-of-access-tokens) setting can limit the maximum allowable lifetime in self-managed instances.
1. Select a role for the token.
1. Select the [desired scopes](#scopes-for-a-group-access-token).
1. Select  **Create group access token**.

A group access token is displayed. Save the group access token somewhere safe. After you leave or refresh the page, you can't view it again.

## Create a group access token using Rails console

GitLab 14.6 and earlier doesn't support creating group access tokens using the UI
or API. However, administrators can use a workaround:

1. Run the following commands in a [Rails console](../../../administration/operations/rails_console.md):

   ```ruby
   # Set the GitLab administration user to use. If user ID 1 is not available or is not an administrator, use 'admin = User.admins.first' instead to select an administrator.
   admin = User.find(1)

   # Set the group group you want to create a token for. For example, group with ID 109.
   group = Group.find(109)

   # Create the group bot user. For further group access tokens, the username should be group_#{group.id}_bot#{bot_count}. For example, group_109_bot2 and email address group_109_bot2@example.com.
   bot = Users::CreateService.new(admin, { name: 'group_token', username: "group_#{group.id}_bot", email: "group_#{group.id}_bot@example.com", user_type: :project_bot }).execute

   # Confirm the group bot.
   bot.confirm

   # Add the bot to the group with the required role.
   group.add_member(bot, :maintainer)

   # Give the bot a personal access token.
   token = bot.personal_access_tokens.create(scopes:[:api, :write_repository], name: 'group_token')

   # Get the token value.
   gtoken = token.token
   ```

1. Test if the generated group access token works:

   1. Use the group access token in the `PRIVATE-TOKEN` header with GitLab REST APIs. For example:

      - [Create an epic](../../../api/epics.md#new-epic) in the group.
      - [Create a project pipeline](../../../api/pipelines.md#create-a-new-pipeline) in one of the group's projects.
      - [Create an issue](../../../api/issues.md#new-issue) in one of the group's projects.

   1. Use the group token to [clone a group's project](../../../gitlab-basics/start-using-git.md#clone-with-https)
      using HTTPS.

## Revoke a group access token using the UI

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/214045) in GitLab 14.7.

To revoke a group access token:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Settings > Access Tokens**.
1. Next to the group access token to revoke, select **Revoke**.

## Revoke a group access token using Rails console

GitLab 14.6 and earlier doesn't support revoking group access tokens using the UI
or API. However, administrators can use a workaround.

To revoke a group access token, run the following command in a [Rails console](../../../administration/operations/rails_console.md):

```ruby
bot = User.find_by(username: 'group_109_bot') # the owner of the token you want to revoke
token = bot.personal_access_tokens.last # the token you want to revoke
token.revoke!
```

## Scopes for a group access token

The scope determines the actions you can perform when you authenticate with a group access token.

| Scope              | Description                                                                                                                                                                      |
|:-------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `api`              | Grants complete read and write access to the scoped group and related project API, including the [Package Registry](../../packages/package_registry/index.md).                   |
| `read_api`         | Grants read access to the scoped group and related project API, including the [Package Registry](../../packages/package_registry/index.md).                                      |
| `read_registry`    | Allows read access (pull) to the [Container Registry](../../packages/container_registry/index.md) images if any project within a group is private and authorization is required. |
| `write_registry`   | Allows write access (push) to the [Container Registry](../../packages/container_registry/index.md).                                                                              |
| `read_repository`  | Allows read access (pull) to all repositories within a group.                                                                                                                    |
| `write_repository` | Allows read and write access (pull and push) to all repositories within a group.                                                                                                 |

## Enable or disable group access token creation

To enable or disable group access token creation for all sub-groups in a top-level group:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Settings > General**.
1. Expand **Permissions and group features**.
1. Under **Permissions**, turn on or off **Users can create project access tokens and group access tokens in this group**.

Even when creation is disabled, you can still use and revoke existing group access tokens.

## Bot users for groups

Each time you create a group access token, a bot user is created and added to the group. These bot users are similar to
[bot users for projects](../../project/settings/project_access_tokens.md#bot-users-for-projects), except they are added
to groups instead of projects. Bot users for groups:

- Do not count as licensed seats.
- Can have a maximum role of Owner for a group. For more information, see
  [Create a group access token](../../../api/group_access_tokens.md#create-a-group-access-token).

For more information, see [Bot users for projects](../../project/settings/project_access_tokens.md#bot-users-for-projects).
