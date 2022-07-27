---
stage: Manage
group: Workspace
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments"
type: reference, index, howto
---

# Project settings **(FREE)**

Use the **Settings** page to manage the configuration options in your [project](../index.md).

## View project settings

You must have at least the Maintainer role to view project settings.

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. To display all settings in a section, select **Expand**.
1. Optional. Use the search box to find a setting.

## Edit project name and description

Use the project general settings to edit your project details.

1. Sign in to GitLab with at least the Maintainer role.
1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. In the **Project name** text box, enter your project name.
1. In the **Project description** text box, enter your project description.
1. Under **Project avatar**, to change your project avatar, select **Choose file**.

## Assign topics to a project

Use topics to categorize projects and find similar new projects.

To assign topics to a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings** > **General**.
1. In the **Topics** text box, enter the project topics. Popular topics are suggested as you type.
1. Select **Save changes**.

## Compliance frameworks **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/276221) in GitLab 13.9.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/287779) in GitLab 13.12.

You can create a compliance framework label to identify that your project has certain compliance
requirements or needs additional oversight. The label can optionally apply
[compliance pipeline configuration](#compliance-pipeline-configuration).

Group owners can create, edit, and delete compliance frameworks:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Settings** > **General**.
1. Expand the **Compliance frameworks** section.

Compliance frameworks created can then be assigned to projects within the group using:

- The GitLab UI, using the project settings page.
- In [GitLab 14.2](https://gitlab.com/gitlab-org/gitlab/-/issues/333249) and later, using the
  [GraphQL API](../../../api/graphql/reference/index.md#mutationprojectsetcomplianceframework).

NOTE:
Creating compliance frameworks on subgroups with GraphQL causes the framework to be
created on the root ancestor if the user has the correct permissions. The GitLab UI presents a
read-only view to discourage this behavior.

### Compliance pipeline configuration **(ULTIMATE)**

> - [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/3156) in GitLab 13.9, disabled behind `ff_evaluate_group_level_compliance_pipeline` [feature flag](../../../administration/feature_flags.md).
> - [Enabled by default](https://gitlab.com/gitlab-org/gitlab/-/issues/300324) in GitLab 13.11.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/331231) in GitLab 14.2.

Compliance framework pipelines allow group owners to define
a compliance pipeline in a separate repository that gets
executed in place of the local project's `.gitlab-ci.yml` file. As part of this pipeline, an
`include` statement can reference the local project's `.gitlab-ci.yml` file. This way, the compliance
pipeline jobs can run alongside the project-specific jobs any time the pipeline runs.
Jobs and variables defined in the compliance
pipeline can't be changed by variables in the local project's `.gitlab-ci.yml` file.

When you set up the compliance framework, use the **Compliance pipeline configuration** box to link
the compliance framework to specific CI/CD configuration. Use the
`path/file.y[a]ml@group-name/project-name` format. For example:

- `.compliance-ci.yml@gitlab-org/gitlab`.
- `.compliance-ci.yaml@gitlab-org/gitlab`.

This configuration is inherited by projects where the compliance framework label is applied. The
result forces projects with the label to run the compliance CI/CD configuration in addition to
the project's own CI/CD configuration. When a project with a compliance framework label executes a
pipeline, it evaluates configuration in the following order:

1. Compliance pipeline configuration.
1. Project-specific pipeline configuration.

The user running the pipeline in the project must at least have the Reporter role on the compliance
project.

Example `.compliance-gitlab-ci.yml`:

```yaml
# Allows compliance team to control the ordering and interweaving of stages/jobs.
# Stages without jobs defined will remain hidden.
stages:
  - pre-compliance
  - build
  - test
  - pre-deploy-compliance
  - deploy
  - post-compliance

variables:  # Can be overridden by setting a job-specific variable in project's local .gitlab-ci.yml
  FOO: sast

sast:  # None of these attributes can be overridden by a project's local .gitlab-ci.yml
  variables:
    FOO: sast
  image: ruby:2.6
  stage: pre-compliance
  rules:
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS && $CI_PIPELINE_SOURCE == "push"
      when: never
    - when: always  # or when: on_success
  allow_failure: false
  before_script:
    - "# No before scripts."
  script:
    - echo "running $FOO"
  after_script:
    - "# No after scripts."

sanity check:
  image: ruby:2.6
  stage: pre-deploy-compliance
  rules:
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS && $CI_PIPELINE_SOURCE == "push"
      when: never
    - when: always  # or when: on_success
  allow_failure: false
  before_script:
    - "# No before scripts."
  script:
    - echo "running $FOO"
  after_script:
    - "# No after scripts."

audit trail:
  image: ruby:2.6
  stage: post-compliance
  rules:
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS && $CI_PIPELINE_SOURCE == "push"
      when: never
    - when: always  # or when: on_success
  allow_failure: false
  before_script:
    - "# No before scripts."
  script:
    - echo "running $FOO"
  after_script:
    - "# No after scripts."

include:  # Execute individual project's configuration (if project contains .gitlab-ci.yml)
  project: '$CI_PROJECT_PATH'
  file: '$CI_CONFIG_PATH'
  ref: '$CI_COMMIT_REF_NAME' # Must be defined or MR pipelines always use the use default branch
```

When used to enforce scan execution, this feature has some overlap with [scan execution policies](../../application_security/policies/scan-execution-policies.md),
as we have not [unified the user experience for these two features](https://gitlab.com/groups/gitlab-org/-/epics/7312).
For details on the similarities and differences between these features, see
[Enforce scan execution](../../application_security/#enforce-scan-execution).

### Ensure compliance jobs are always run

Compliance pipelines use GitLab CI/CD to give you an incredible amount of flexibility
for defining any sort of compliance jobs you like. Depending on your goals, these jobs
can be configured to be:

- Modified by users.
- Non-modifiable.

At a high-level, if a value in a compliance job:

- Is set, it cannot be changed or overridden by project-level configurations.
- Is not set, a project-level configuration may set.

Either might be wanted or not depending on your use case.

There are a few best practices for ensuring that these jobs are always run exactly
as you define them and that downstream, project-level pipeline configurations
cannot change them:

- Add a `rules:when:always` block to each of your compliance jobs. This ensures they are
  non-modifiable and are always run.
- Explicitly set any variables the job references. This:
  - Ensures that project-level pipeline configurations do not set them and alter their
    behavior.
  - Includes any jobs that drive the logic of your job.
- Explicitly set the container image file to run the job in. This ensures that your script
  steps execute in the correct environment.
- Explicitly set any relevant GitLab pre-defined [job keywords](../../../ci/yaml/index.md#job-keywords).
  This ensures that your job uses the settings you intend and that they are not overridden by
  project-level pipelines.

### Avoid parent and child pipelines in GitLab 14.7 and earlier

NOTE:
This advice does not apply to GitLab 14.8 and later because [a fix](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/78878) added
compatibility for combining compliance pipelines, and parent and child pipelines.

Compliance pipelines start on the run of _every_ pipeline in a relevant project. This means that if a pipeline in the relevant project
triggers a child pipeline, the compliance pipeline runs first. This can trigger the parent pipeline, instead of the child pipeline.

Therefore, in projects with compliance frameworks, we recommend replacing
[parent-child pipelines](../../../ci/pipelines/parent_child_pipelines.md) with the following:

- Direct [`include`](../../../ci/yaml/index.md#include) statements that provide the parent pipeline with child pipeline configuration.
- Child pipelines placed in another project that are run using the [trigger API](../../../ci/triggers/) rather than the parent-child
  pipeline feature.

This alternative ensures the compliance pipeline does not re-start the parent pipeline.

## Configure project visibility, features, and permissions

To configure visibility, features, and permissions for a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility, project features, permissions** section.
1. To change the project visibility, select the dropdown list. If you select to **Public**, you limit access to some features to **Only Project Members**.
1. To allow users to request access to the project, select the **Users can request access** checkbox.
1. Use the [toggles](#project-feature-settings) to enable or disable features in the project.
1. Select **Save changes**.

### Project feature settings

Use the toggles to enable or disable features in the project.

| Option                           | More access limit options | Description   |
|:---------------------------------|:--------------------------|:--------------|
| **Issues**                       | ✓                         | Activates the GitLab issues tracker. |
| **Repository**                   | ✓                         | Enables [repository](../repository/) functionality |
| **Merge requests**               | ✓                         | Enables [merge request](../merge_requests/) functionality; also see [Merge request settings](#configure-merge-request-settings-for-a-project). |
| **Forks**                        | ✓                         | Enables [forking](../repository/forking_workflow.md) functionality. |
| **Git Large File Storage (LFS)** |                           | Enables the use of [large files](../../../topics/git/lfs/index.md#git-large-file-storage-lfs). |
| **Packages**                     |                           | Supports configuration of a [package registry](../../../administration/packages/index.md#gitlab-package-registry-administration) functionality. |
| **CI/CD**                        | ✓                         | Enables [CI/CD](../../../ci/index.md) functionality. |
| **Container Registry**           |                           | Activates a [registry](../../packages/container_registry/) for your Docker images. |
| **Analytics**                    | ✓                         | Enables [analytics](../../analytics/). |
| **Requirements**                 | ✓                         | Control access to [Requirements Management](../requirements/index.md). |
| **Security & Compliance**        | ✓                         | Control access to [security features](../../application_security/index.md). |
| **Wiki**                         | ✓                         | Enables a separate system for [documentation](../wiki/). |
| **Snippets**                     | ✓                         | Enables [sharing of code and text](../../snippets.md). |
| **Pages**                        | ✓                         | Allows you to [publish static websites](../pages/). |
| **Operations**                   | ✓                         | Control access to Operations-related features, including [Operations Dashboard](../../../operations/index.md), [Environments and Deployments](../../../ci/environments/index.md), [Feature Flags](../../../operations/feature_flags.md). |
| **Metrics Dashboard**            | ✓                         | Control access to [metrics dashboard](../integrations/prometheus.md). |

When you disable a feature, the following additional features are also disabled:

- If you disable the **Issues** feature, project users cannot use:
  - **Issue Boards**
  - **Service Desk**
  - Project users can still access **Milestones** from merge requests.

- If you disable **Issues** and **Merge Requests**, project users cannot use:
  - **Labels**
  - **Milestones**

- If you disable **Repository**, project users cannot access:
  - **Merge requests**
  - **CI/CD**
  - **Container Registry**
  - **Git Large File Storage**
  - **Packages**

- Metrics dashboard access requires reading project environments and deployments.
  Users with access to the metrics dashboard can also access environments and deployments.

## Disable CVE identifier request in issues **(FREE SAAS)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/41203) in GitLab 13.4, only for public projects on GitLab.com.

In some environments, users can submit a [CVE identifier request](../../application_security/cve_id_request.md) in an issue.

To disable the CVE identifier request option in issues in your project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility, project features, permissions** section.
1. Under **Issues**, turn off the **CVE ID requests in the issue sidebar** toggle.
1. Select **Save changes**.

## Disable project email notifications

Prerequisites:

- You must be an Owner of the project to disable email notifications related to the project.

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility, project features, permissions** section.
1. Clear the **Disable email notifications** checkbox.

## Configure merge request settings for a project

Configure your project's merge request settings:

- Set up the [merge request method](../merge_requests/methods/index.md) (merge commit, fast-forward merge).
- Add merge request [description templates](../description_templates.md#description-templates).
- Enable [merge request approvals](../merge_requests/approvals/index.md).
- Enable [status checks](../merge_requests/status_checks.md).
- Enable [merge only if pipeline succeeds](../merge_requests/merge_when_pipeline_succeeds.md).
- Enable [merge only when all threads are resolved](../../discussions/index.md#prevent-merge-unless-all-threads-are-resolved).
- Enable [require an associated issue from Jira](../../../integration/jira/issues.md#require-associated-jira-issue-for-merge-requests-to-be-merged).
- Enable [`delete source branch after merge` option by default](../merge_requests/getting_started.md#deleting-the-source-branch).
- Configure [suggested changes commit messages](../merge_requests/reviews/suggestions.md#configure-the-commit-message-for-applied-suggestions).
- Configure [merge and squash commit message templates](../merge_requests/commit_templates.md).
- Configure [the default target project](../merge_requests/creating_merge_requests.md#set-the-default-target-project) for merge requests coming from forks.

## Service Desk

Enable [Service Desk](../service_desk.md) for your project to offer customer support.

## Export project

Learn how to [export a project](import_export.md#import-a-project-and-its-data) in GitLab.

## Advanced project settings

Use the advanced settings to archive, rename, transfer,
remove a fork relationship, or delete a project.

### Archive a project

When you archive a project, the repository, packages, issues, merge requests, and all
other features are read-only. Archived projects are also hidden from project listings.

To archive a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand **Advanced**.
1. In the **Archive project** section, select **Archive project**.
1. To confirm, select **OK**.

### Unarchive a project

When you unarchive a project, you remove the read-only restriction and make it
available in project lists.

Prerequisites:

- To unarchive a project, you must be an administrator or a project Owner.

1. Find the archived project.
   1. On the top bar, select **Menu > Project**.
   1. Select **Explore projects**.
   1. In the **Sort projects** dropdown list, select **Show archived projects**.
   1. In the **Filter by name** field, enter the project name.
   1. Select the project link.
1. On the left sidebar, select **Settings > General**.
1. Under **Advanced**, select **Expand**.
1. In the **Unarchive project** section, select **Unarchive project**.
1. To confirm, select **OK**.

### Rename a repository

A project's repository name defines its URL and its place on the file disk
where GitLab is installed.

Prerequisites:

You must be a project maintainer or administrator to rename a repository.

NOTE:
When you change the repository path, users may experience issues if they push to, or pull from, the old URL. For more information, see
[redirects when renaming repositories](../repository/index.md#what-happens-when-a-repository-path-changes).

To rename a repository:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Advanced** section.
1. In the **Change path** text box, edit the path.
1. Select **Change path**.

## Transfer a project to another namespace

When you transfer a project to another namespace, you move the project to a different group.

Prerequisites:

- You must have at least the Maintainer role for the [group](../../group/index.md#create-a-group) to which you are transferring.
- You must be the Owner of the project you transfer.
- The group must allow creation of new projects.
- The project must not contain any [container images](../../packages/container_registry/index.md#limitations).
  - If you transfer a project to a different root namespace,
    the project must not contain any
    [NPM packages](../../packages/npm_registry/index.md#limitations).

To transfer a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand **Advanced**.
1. Under **Transfer project**, choose the namespace to transfer the project to.
1. Select **Transfer project**.
1. Enter the project's name and select **Confirm**.

You are redirected to the project's new page and GitLab applies a redirect. For more information about repository redirects, see [What happens when a repository path changes](../repository/index.md#what-happens-when-a-repository-path-changes).

NOTE:
If you are an administrator, you can also use the [administration interface](../../admin_area/index.md#administering-projects)
to move any project to any namespace.

### Transferring a GitLab SaaS project to a different subscription tier

When you transfer a project from a namespace licensed for GitLab SaaS Premium or Ultimate to GitLab Free, the following paid feature data is deleted:

- [Project access tokens](../../../user/project/settings/project_access_tokens.md) are revoked
- [Pipeline subscriptions](../../../ci/pipelines/multi_project_pipelines.md#trigger-a-pipeline-when-an-upstream-project-is-rebuilt)
and [test cases](../../../ci/test_cases/index.md) are deleted.

## Delete a project

You can mark a project to be deleted.

Prerequisite:

- You must have at least the Owner role for a project.

To delete a project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand **Advanced**.
1. In the "Delete project" section, select **Delete project**.
1. Confirm the action when asked to.

This action deletes a project including all associated resources (issues, merge requests, and so on).

WARNING:
The default deletion behavior for projects was changed to [delayed project deletion](https://gitlab.com/gitlab-org/gitlab/-/issues/32935)
in GitLab 12.6, and then to [immediate deletion](https://gitlab.com/gitlab-org/gitlab/-/issues/220382) in GitLab 13.2.

### Delayed project deletion **(PREMIUM)**

> [Enabled for projects in personal namespaces](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/89466) in GitLab 15.1.

Projects can be deleted after a delay period. Multiple settings can affect whether
delayed project deletion is enabled for a particular project:

- Self-managed instance [settings](../../admin_area/settings/visibility_and_access_controls.md#delayed-project-deletion).
  You can enable delayed project deletion as the default setting for new groups, and configure the number of days for the
  delay. For GitLab.com, see the [GitLab.com settings](../../gitlab_com/index.md#delayed-project-deletion).
- Group [settings](../../group/index.md#enable-delayed-project-deletion) to enabled delayed project deletion for all
  projects in the group.

### Delete a project immediately

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/191367) in GitLab 14.1.

If you don't want to wait, you can delete a project immediately.

Prerequisites:

- You must have at least the Owner role for a project.
- You have [marked the project for deletion](#delete-a-project).

To immediately delete a project marked for deletion:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand **Advanced**.
1. In the "Permanently delete project" section, select **Delete project**.
1. Confirm the action when asked to.

The following are deleted:

- Your project and its repository.
- All related resources including issues and merge requests.

## Restore a project **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/32935) in GitLab 12.6.

To restore a project marked for deletion:

1. Navigate to your project, and select **Settings > General > Advanced**.
1. In the Restore project section, select **Restore project**.

## Remove a fork relationship

Prerequisites:

- You must be a project owner to remove a fork relationship.

WARNING:
If you remove a fork relationship, you can't send merge requests to the source. If anyone has forked your project, their fork also loses the relationship.
To restore the fork relationship, [use the API](../../../api/projects.md#create-a-forked-fromto-relation-between-existing-projects).

To remove a fork relationship:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand **Advanced**.
1. In the **Remove fork relationship** section, select **Remove fork relationship**.
1. To confirm, enter the project path and select **Confirm**.

## Monitor settings

### Alerts

Configure [alert integrations](../../../operations/incident_management/integrations.md#configuration) to triage and manage critical problems in your application as [alerts](../../../operations/incident_management/alerts.md).

### Incidents

#### Alert integration

Automatically [create](../../../operations/incident_management/incidents.md#create-incidents-automatically), [notify on](../../../operations/incident_management/paging.md#email-notifications-for-alerts), and [resolve](../../../operations/incident_management/incidents.md#automatically-close-incidents-via-recovery-alerts) incidents based on GitLab alerts.

#### PagerDuty integration

[Create incidents in GitLab for each PagerDuty incident](../../../operations/incident_management/incidents.md#create-incidents-via-the-pagerduty-webhook).

#### Incident settings

[Manage Service Level Agreements for incidents](../../../operations/incident_management/incidents.md#service-level-agreement-countdown-timer) with an SLA countdown timer.

### Error Tracking

Configure Error Tracking to discover and view [Sentry errors within GitLab](../../../operations/error_tracking.md).

### Status Page **(ULTIMATE)**

[Add Storage credentials](../../../operations/incident_management/status_page.md#sync-incidents-to-the-status-page)
to enable the syncing of public Issues to a [deployed status page](../../../operations/incident_management/status_page.md#create-a-status-page-project).
