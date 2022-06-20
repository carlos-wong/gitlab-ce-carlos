---
stage: Release
group: Release
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
description: Require approvals prior to deploying to a Protected Environment
---

# Deployment approvals **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/343864) in GitLab 14.7 with a flag named `deployment_approvals`. Disabled by default.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/347342) in GitLab 14.8.

WARNING:
This feature is in a [Beta](../../policy/alpha-beta-support.md#beta-features) stage and subject to change without prior notice.

It may be useful to require additional approvals before deploying to certain protected environments (for example, production). This pre-deployment approval requirement is useful to accommodate testing, security, or compliance processes that must happen before each deployment.

When a protected environment requires one or more approvals, all deployments to that environment become blocked and wait for the required approvals from the `Allowed to Deploy` list before running.

NOTE:
See the [epic](https://gitlab.com/groups/gitlab-org/-/epics/6832) for planned features.

## Requirements

- Basic knowledge of [GitLab Environments and Deployments](index.md).
- Basic knowledge of [Protected Environments](protected_environments.md).

## Configure deployment approvals for a project

To configure deployment approvals for a project:

1. [Create a deployment job](#create-a-deployment-job).
1. [Require approvals for a protected environment](#require-approvals-for-a-protected-environment).

### Create a deployment job

Create a deployment job in the `.gitlab-ci.yaml` file of the desired project. The job does **not** need to be manual (`when: manual`).

Example:

   ```yaml
   stages:
     - deploy

   production:
     stage: deploy
     script:
       - 'echo "Deploying to ${CI_ENVIRONMENT_NAME}"'
     environment:
       name: ${CI_JOB_NAME}
   ```

### Require approvals for a protected environment

There are two ways to configure the approval requirements:

- [Unified approval setting](#unified-approval-setting) ... You can define who can execute **and** approve deployments.
  This is useful when there is no separation of duties between executors and approvers in your organization.
- [Multiple approval rules](#multiple-approval-rules) ... You can define who can execute **or** approve deployments.
  This is useful when there is a separation of duties between executors and approvers in your organization.

NOTE:
Multiple approval rules is a more flexible option than the unified approval setting, thus both configurations shouldn't
co-exist and multiple approval rules takes the precedence over the unified approval setting if it happens.

#### Unified approval setting

NOTE:
At this time, it is not possible to require approvals for an existing protected environment. The workaround is to unprotect the environment and configure approvals when re-protecting the environment.

There are two ways to configure approvals for a protected environment:

1. Using the [UI](protected_environments.md#protecting-environments)
   1. Set the **Required approvals** field to 1 or more.
1. Using the [REST API](../../api/protected_environments.md#protect-repository-environments)
   2. Set the `required_approval_count` field to 1 or more.

After this is configured, all jobs deploying to this environment automatically go into a blocked state and wait for approvals before running. Ensure that the number of required approvals is less than the number of users allowed to deploy.

Example:

```shell
curl --header 'Content-Type: application/json' --request POST \
     --data '{"name": "production", "deploy_access_levels": [{"group_id": 9899826}], "required_approval_count": 1}' \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     "https://gitlab.example.com/api/v4/projects/22034114/protected_environments"
```

NOTE:
To protect, update, or unprotect an environment, you must have at least the
Maintainer role.

#### Multiple approval rules

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/345678) in GitLab 14.10 with a flag named `deployment_approval_rules`. Disabled by default.

1. Using the [REST API](../../api/group_protected_environments.md#protect-an-environment).
   1. `deploy_access_levels` represents which entity can execute the deployment job.
   1. `approval_rules` represents which entity can approve the deployment job.

After this is configured, all jobs deploying to this environment automatically go into a blocked state and wait for approvals before running. Ensure that the number of required approvals is less than the number of users allowed to deploy.

Example:

```shell
curl --header 'Content-Type: application/json' --request POST \
     --data '{"name": "production", "deploy_access_levels": [{"group_id": 138}], "approval_rules": [{"group_id": 134}, {"group_id": 135, "required_approvals": 2}]}' \
     --header "PRIVATE-TOKEN: <your_access_token>" \
     "https://gitlab.example.com/api/v4/groups/128/protected_environments"
```

With this setup:

- The operator group (`group_id: 138`) has permission to execute the deployment jobs to the `production` environment in the organization (`group_id: 128`).
- The QA tester group (`group_id: 134`) and security group (`group_id: 135`) have permission to approve the deployment jobs to the `production` environment in the organization (`group_id: 128`).
- Unless two approvals from security group and one approval from QA tester group have been collected, the operator group can't execute the deployment jobs.

NOTE:
To protect, update, or unprotect an environment, you must have at least the
Maintainer role.

## Approve or reject a deployment

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/342180/) in GitLab 14.9

Using either the GitLab UI or the API, you can:

- Approve a deployment to allow it to proceed.
- Reject a deployment to prevent it.

### Approve or reject a deployment using the UI

Prerequisites:

- Permission to deploy to the protected environment.

To approve or reject a deployment to a protected environment using the UI:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Deployments > Environments**.
1. In the deployment's row, select **Approval options** (**{thumb-up}**).
1. Select **Approve** or **Reject**.

NOTE:
This feature might not work as expected when [Multiple approval rules](#multiple-approval-rules) is configured.
See the [issue](https://gitlab.com/gitlab-org/gitlab/-/issues/355708) for planned improvement.

### Approve or reject a deployment using the API

Prerequisites:

- Permission to deploy to the protected environment.

To approve or reject a deployment to a protected environment using the API, pass the
required attributes. For more details, see
[Approve or reject a blocked deployment](../../api/deployments.md#approve-or-reject-a-blocked-deployment).

Example:

```shell
curl --data "status=approved&comment=Looks good to me" \
     --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/1/deployments/1/approval"
```

## How to see blocked deployments

### Using the UI

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Deployments > Environments**.
1. Select the environment being deployed to.
1. Look for the `blocked` label.

### Using the API

Use the [Deployments API](../../api/deployments.md#get-a-specific-deployment) to see deployments.

- The `status` field indicates if a deployment is blocked.
- When the [unified approval setting](#unified-approval-setting) is configured:
  - The `pending_approval_count` field indicates how many approvals are remaining to run a deployment.
  - The `approvals` field contains the deployment's approvals.
- When the [multiple approval rules](#multiple-approval-rules) is configured:
  - The `approval_summary` field contains the current approval status per rule.

## Related features

For details about other GitLab features aimed at protecting deployments, see [safe deployments](deployment_safety.md).

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
