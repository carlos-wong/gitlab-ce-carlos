---
stage: Release
group: Release
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Deploy keys **(FREE)**

Use deploy keys to access repositories that are hosted in GitLab. In most cases, you use deploy keys
to access a repository from an external host, like a build server or Continuous Integration (CI) server.

Depending on your needs, you might want to use a [deploy token](../deploy_tokens/) to access a repository instead.

| Attribute        |  Deploy key | Deploy token |
|------------------|-------------|--------------|
| Sharing          | Shareable between multiple projects, even those in different groups. | Belong to a project or group. |
| Source           | Public SSH key generated on an external host. | Generated on your GitLab instance, and is provided to users only at creation time. |
| Validity         | Valid as long as it's registered and enabled. | Can be given an expiration date. |
| Registry access  | Cannot access a package registry. | Can read from and write to a package registry. |

## Scope

A deploy key has a defined scope when it is created:

- **Project deploy key:** Access is limited to the selected project.
- **Public deploy key:** Access can be granted to _any_ project in a GitLab instance. Access to each
    project must be [granted](#grant-project-access-to-a-public-deploy-key) by a user with at least
    the Maintainer role.

You cannot change a deploy key's scope after creating it.

## Permissions

A deploy key is given a permission level when it is created:

- **Read-only:** A read-only deploy key can only read from the repository.
- **Read-write:** A read-write deploy key can read from, and write to, the repository.

You can change a deploy key's permission level after creating it. Changing a project deploy key's
permissions only applies for the current project.

When a read-write deploy key is used to push a commit, GitLab checks if the creator of the
deploy key has permission to access the resource.

For example:

- When a deploy key is used to push a commit to a [protected branch](../protected_branches.md),
  the _creator_ of the deploy key must have access to the branch.
- When a deploy key is used to push a commit that triggers a CI/CD pipeline, the _creator_ of the
  deploy key must have access to the CI/CD resources, including protected environments and secret
  variables.

## View deploy keys

To view the deploy keys available to a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Deploy keys**.

The deploy keys available are listed:

- **Enabled deploy keys:** Deploy keys that have access to the project.
- **Privately accessible deploy keys:** Project deploy keys that don't have access to the project.
- **Public accessible deploy keys:** Public deploy keys that don't have access to the project.

## Create a project deploy key

Prerequisites:

- You must have at least the Maintainer role for the project.
- [Generate an SSH key pair](../../ssh.md#generate-an-ssh-key-pair). Put the private SSH
  key on the host that requires access to the repository.

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Deploy keys**.
1. Complete the fields.
1. Optional. To grant `read-write` permission, select the **Grant write permissions to this key**
   checkbox.

A project deploy key is enabled when it is created. You can modify only a project deploy key's
name and permissions.

## Create a public deploy key

Prerequisites:

- You must have administrator access.
- [Generate an SSH key pair](../../ssh.md#generate-an-ssh-key-pair). Put the private SSH
  key on the host that requires access to the repository.

To create a public deploy key:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Deploy Keys**.
1. Select **New deploy key**.
1. Complete the fields.
   - Use a meaningful description for **Name**. For example, include the name of the external host
     or application that will use the public deploy key.

You can modify only a public deploy key's name.

## Grant project access to a public deploy key

Prerequisites:

- You must have at least the Maintainer role for the project.

To grant a public deploy key access to a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Deploy keys**.
1. Select **Publicly accessible deploy keys**.
1. In the key's row, select **Enable**.
1. To grant read-write permission to the public deploy key:
   1. In the key's row, select **Edit** (**{pencil}**).
   1. Select the **Grant write permissions to this key** checkbox.

## Revoke project access of a deploy key

To revoke a deploy key's access to a project, you can disable it. Any service that relies on
a deploy key stops working when the key is disabled.

Prerequisites:

- You must have at least the Maintainer role for the project.

To disable a deploy key:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Deploy keys**.
1. Select **Disable** (**{cancel}**).

What happens to the deploy key when it is disabled depends on the following:

- If the key is publicly accessible, it is removed from the project but still available in the
  **Publicly accessible deploy keys** tab.
- If the key is privately accessible and only in use by this project, it is deleted.
- If the key is privately accessible and also in use by other projects, it is removed from the
  project, but still available in the **Privately accessible deploy keys** tab.

## Troubleshooting

### Deploy key cannot push to a protected branch

There are a few scenarios where a deploy key will fail to push to a [protected
branch](../protected_branches.md).

- The owner associated to a deploy key does not have access to the protected branch.
- The owner associated to a deploy key does not have [membership](../members/index.md) to the project of the protected branch.
- **No one** is selected in [the **Allowed to push** section](../protected_branches.md#configure-a-protected-branch) of the protected branch.

All deploy keys are associated to an account. Since the permissions for an account can change, this might lead to scenarios where a deploy key that was working is suddenly unable to push to a protected branch.

We recommend you create a service account, and associate a deploy key to the service account, for projects using deploy keys.
