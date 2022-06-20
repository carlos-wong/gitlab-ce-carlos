---
stage: Enablement
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: reference
---

# GitLab application limits **(FREE SELF)**

GitLab, like most large applications, enforces limits within certain features to maintain a
minimum quality of performance. Allowing some features to be limitless could affect security,
performance, data, or could even exhaust the allocated resources for the application.

## Rate limits

Rate limits can be used to improve the security and durability of GitLab.

Read more about [configuring rate limits](../security/rate_limits.md).

### Issue creation

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/28129) in GitLab 12.10.

This setting limits the request rate to the issue creation endpoint.

Read more about [issue creation rate limits](../user/admin_area/settings/rate_limit_on_issues_creation.md).

- **Default rate limit**: Disabled by default.

### By User or IP

This setting limits the request rate per user or IP.

Read more about [User and IP rate limits](../user/admin_area/settings/user_and_ip_rate_limits.md).

- **Default rate limit**: Disabled by default.

### By raw endpoint

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/30829) in GitLab 12.2.

This setting limits the request rate per endpoint.

Read more about [raw endpoint rate limits](../user/admin_area/settings/rate_limits_on_raw_endpoints.md).

- **Default rate limit**: 300 requests per project, per commit and per file path.

### By protected path

This setting limits the request rate on specific paths.

GitLab rate limits the following paths by default:

```plaintext
'/users/password',
'/users/sign_in',
'/api/#{API::API.version}/session.json',
'/api/#{API::API.version}/session',
'/users',
'/users/confirmation',
'/unsubscribes/',
'/import/github/personal_access_token',
'/admin/session'
```

Read more about [protected path rate limits](../user/admin_area/settings/protected_paths.md).

- **Default rate limit**: After 10 requests, the client must wait 60 seconds before trying again.

### Package Registry

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/57029) in GitLab 13.12.

This setting limits the request rate on the Packages API per user or IP. For more information, see
[Package Registry Rate Limits](../user/admin_area/settings/package_registry_rate_limits.md).

- **Default rate limit**: Disabled by default.

### Git LFS

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/68642) in GitLab 14.3.

This setting limits the request rate on the [Git LFS](../topics/git/lfs/index.md)
requests per user. For more information, read
[GitLab Git Large File Storage (LFS) Administration](../administration/lfs/index.md).

- **Default rate limit**: Disabled by default.

### Files API

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/68561) in GitLab 14.3 [with a flag](../administration/feature_flags.md) named `files_api_throttling`. Disabled by default.
> - [Generally available](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/75918) in GitLab 14.6. [Feature flag `files_api_throttling`](https://gitlab.com/gitlab-org/gitlab/-/issues/338903) removed.

This setting limits the request rate on the Packages API per user or IP address. For more information, read
[Files API rate limits](../user/admin_area/settings/files_api_rate_limits.md).

- **Default rate limit**: Disabled by default.

### Deprecated API endpoints

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/68645) in GitLab 14.4.

This setting limits the request rate on deprecated API endpoints per user or IP address. For more information, read
[Deprecated API rate limits](../user/admin_area/settings/deprecated_api_rate_limits.md).

- **Default rate limit**: Disabled by default.

### Import/Export

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/35728) in GitLab 13.2.

This setting limits the import/export actions for groups and projects.

| Limit                   | Default (per minute per user) |
|-------------------------|-------------------------------|
| Project Import          | 6 |
| Project Export          | 6 |
| Project Export Download | 1 |
| Group Import            | 6 |
| Group Export            | 6 |
| Group Export Download   | 1 |

Read more about [import/export rate limits](../user/admin_area/settings/import_export_rate_limits.md).

### Member Invitations

Limit the maximum daily member invitations allowed per group hierarchy.

- GitLab.com: Free members may invite 20 members per day.
- Self-managed: Invites are not limited.

### Webhook rate limit

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/61151) in GitLab 13.12.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/330133) in GitLab 14.1.

Limit the number of times any given webhook can be called per minute.
This only applies to project and group webhooks.

Calls over the rate limit are logged into `auth.log`.

To set this limit for a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
# If limits don't exist for the default plan, you can create one with:
# Plan.default.create_limits!

Plan.default.actual_limits.update!(web_hook_calls: 10)
```

Set the limit to `0` to disable it.

- **Default rate limit**: Disabled (unlimited).

### Search rate limit

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/80631) in GitLab 14.9

This setting limits global search requests.

| Limit                   | Default (requests per minute) |
|-------------------------|-------------------------------|
| Authenticated user      | 30 |
| Unauthenticated user    | 10 |

## Gitaly concurrency limit

Clone traffic can put a large strain on your Gitaly service. To prevent such workloads from overwhelming your Gitaly server, you can set concurrency limits in Gitaly's configuration file.

Read more about [Gitaly concurrency limits](gitaly/configure_gitaly.md#limit-rpc-concurrency).

- **Default rate limit**: Disabled.

## Number of comments per issue, merge request, or commit

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/22388) in GitLab 12.4.

There's a limit to the number of comments that can be submitted on an issue,
merge request, or commit. When the limit is reached, system notes can still be
added so that the history of events is not lost, but the user-submitted
comment fails.

- **Max limit**: 5,000 comments.

## Size of comments and descriptions of issues, merge requests, and epics

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/61974) in GitLab 12.2.

There is a limit to the size of comments and descriptions of issues, merge requests, and epics.
Attempting to add a body of text larger than the limit, results in an error, and the
item is also not created.

It's possible that this limit changes to a lower number in the future.

- **Max size**: ~1 million characters / ~1 MB.

## Size of commit titles and descriptions

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/292039) in GitLab 13.9

Commits with arbitrarily large messages may be pushed to GitLab, but when
displaying commits, titles (the first line of the commit message)
limits to 1KiB, and descriptions (the rest of the message) limits to
1MiB.

## Number of issues in the milestone overview

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/39453) in GitLab 12.10.
> - [Set](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/58168) to 500 in GitLab 13.11.

The maximum number of issues loaded on the milestone overview page is 500.
When the number exceeds the limit the page displays an alert and links to a paginated
[issue list](../user/project/issues/managing_issues.md) of all issues in the milestone.

- **Limit**: 500 issues.

## Number of pipelines per Git push

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/51401) in GitLab 11.10.

When pushing multiple changes with a single Git push, like multiple tags or branches,
only four tag or branch pipelines can be triggered. This limit prevents the accidental
creation of a large number of pipelines when using `git push --all` or `git push --mirror`.

[Merge request pipelines](../ci/pipelines/merge_request_pipelines.md) are not limited.
If the Git push updates multiple merge requests at the same time, a merge request pipeline
can trigger for every updated merge request.

To remove the limit so that any number of pipelines can trigger for a single Git push event,
administrators can enable the `git_push_create_all_pipelines` [feature flag](feature_flags.md).
Enabling this feature flag is not recommended, as it can cause excessive load on the GitLab
instance if too many changes are pushed at once and a flood of pipelines are created accidentally.

## Retention of activity history

Activity history for projects and individuals' profiles was limited to one year until [GitLab 11.4](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/52246) when it was extended to two years, and in [GitLab 12.4](https://gitlab.com/gitlab-org/gitlab/-/issues/33840) to three years.

## Number of embedded metrics

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/14939) in GitLab 12.7.

There is a limit when embedding metrics in GitLab Flavored Markdown (GLFM) for performance reasons.

- **Max limit**: 100 embeds.

## Webhook limits

Also see [Webhook rate limits](#webhook-rate-limit).

### Number of webhooks

To set the maximum number of group or project webhooks for a self-managed installation,
run the following in the [GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
# If limits don't exist for the default plan, you can create one with:
# Plan.default.create_limits!

# For project webhooks
Plan.default.actual_limits.update!(project_hooks: 200)

# For group webhooks
Plan.default.actual_limits.update!(group_hooks: 100)
```

Set the limit to `0` to disable it.

The default maximum number of webhooks is `100` per project, `50` per group.

For GitLab.com, see the [webhook limits for GitLab.com](../user/gitlab_com/index.md#webhooks).

### Webhook payload size

The maximum webhook payload size is 25 MB.

### Recursive webhooks

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/329743) in GitLab 14.8.

GitLab detects and blocks webhooks that are recursive or that exceed the limit
of webhooks that can be triggered from other webhooks. This enables GitLab to
continue to support workflows that use webhooks to call the API non-recursively, or that
do not trigger an unreasonable number of other webhooks.

Recursion can happen when a webhook is configured to make a call
to its own GitLab instance (for example, the API). The call then triggers the same
webhook and creates an infinite loop.

The maximum number of requests to an instance made by a series of webhooks that
trigger other webhooks is 100. When the limit is reached, GitLab blocks any further
webhooks that would be triggered by the series.

Blocked recursive webhook calls are logged in `auth.log` with the message `"Recursive webhook blocked from executing"`.

## Pull Mirroring Interval

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/237891) in GitLab 13.7.

The [minimum wait time between pull refreshes](../user/project/repository/mirror/index.md)
defaults to 300 seconds (5 minutes). For example, a pull refresh only runs once in a given 300 second period, regardless of how many times you trigger it.

This setting applies in the context of pull refreshes invoked via the [projects API](../api/projects.md#start-the-pull-mirroring-process-for-a-project), or when forcing an update by selecting the **Update now** (**{retry}**) button within **Settings > Repository > Mirroring repositories**. This setting has no effect on the automatic 30 minute interval schedule used by Sidekiq for [pull mirroring](../user/project/repository/mirror/pull.md).

To change this limit for a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
# If limits don't exist for the default plan, you can create one with:
# Plan.default.create_limits!

Plan.default.actual_limits.update!(pull_mirror_interval_seconds: 200)
```

## Incoming emails from auto-responders

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/30327) in GitLab 12.4.

GitLab ignores all incoming emails sent from auto-responders by looking for the `X-Autoreply`
header. Such emails don't create comments on issues or merge requests.

## Amount of data sent from Sentry through Error Tracking

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/14926) in GitLab 12.6.

Sentry payloads sent to GitLab have a 1 MB maximum limit, both for security reasons
and to limit memory consumption.

## Max offset allowed by the REST API for offset-based pagination

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/34565) in GitLab 13.0.

When using offset-based pagination in the REST API, there is a limit to the maximum
requested offset into the set of results. This limit is only applied to endpoints that
support keyset-based pagination. More information about pagination options can be
found in the [API docs section on pagination](../api/index.md#pagination).

To set this limit for a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
# If limits don't exist for the default plan, you can create one with:
# Plan.default.create_limits!

Plan.default.actual_limits.update!(offset_pagination_limit: 10000)
```

- **Default offset pagination limit**: `50000`.

Set the limit to `0` to disable it.

## CI/CD limits

### Number of jobs in active pipelines

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/32823) in GitLab 12.6.

The total number of jobs in active pipelines can be limited per project. This limit is checked
each time a new pipeline is created. An active pipeline is any pipeline in one of the following states:

- `created`
- `pending`
- `running`

If a new pipeline would cause the total number of jobs to exceed the limit, the pipeline
fails with a `job_activity_limit_exceeded` error.

- GitLab SaaS subscribers have different limits [defined per plan](../user/gitlab_com/index.md#gitlab-cicd),
  and they affect all projects under that plan.
- On [GitLab Premium](https://about.gitlab.com/pricing/) self-managed or
  higher installations, this limit is defined under a `default` plan that affects all
  projects. This limit is disabled (`0`) by default.

To set this limit for a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
# If limits don't exist for the default plan, you can create one with:
# Plan.default.create_limits!

Plan.default.actual_limits.update!(ci_active_jobs: 500)
```

Set the limit to `0` to disable it.

### Maximum time jobs can run

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/16777) in GitLab 12.3.

The default maximum time that jobs can run for is 60 minutes. Jobs that run for
more than 60 minutes time out.

You can change the maximum time a job can run before it times out:

- At the project-level in the [project's CI/CD settings](../ci/pipelines/settings.md#set-a-limit-for-how-long-jobs-can-run)
  for a given project. This limit must be between 10 minutes and 1 month.
- At the [runner level](../ci/runners/configure_runners.md#set-maximum-job-timeout-for-a-runner).
  This limit must be 10 minutes or longer.

### Maximum number of deployment jobs in a pipeline

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/46931) in GitLab 13.7.

You can limit the maximum number of deployment jobs in a pipeline. A deployment is
any job with an [`environment`](../ci/environments/index.md) specified. The number
of deployments in a pipeline is checked at pipeline creation. Pipelines that have
too many deployments fail with a `deployments_limit_exceeded` error.

The default limit is 500 for all [GitLab self-managed and SaaS plans](https://about.gitlab.com/pricing/).

To change the limit for a self-managed installation, change the `default` plan's limit with the following
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session) command:

```ruby
# If limits don't exist for the default plan, you can create one with:
# Plan.default.create_limits!

Plan.default.actual_limits.update!(ci_pipeline_deployments: 500)
```

Set the limit to `0` to disable it.

### Number of CI/CD subscriptions to a project

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/9045) in GitLab 12.9.

The total number of subscriptions can be limited per project. This limit is
checked each time a new subscription is created.

If a new subscription would cause the total number of subscription to exceed the
limit, the subscription is considered invalid.

- GitLab SaaS subscribers have different limits [defined per plan](../user/gitlab_com/index.md#gitlab-cicd),
  and they affect all projects under that plan.
- On [GitLab Premium](https://about.gitlab.com/pricing/) self-managed
  or higher installations, this limit is defined under a `default` plan that
  affects all projects. By default, there is a limit of `2` subscriptions.

To set this limit for a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
Plan.default.actual_limits.update!(ci_project_subscriptions: 500)
```

Set the limit to `0` to disable it.

### Limit the number of pipeline triggers

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/33696) in GitLab 14.6.

You can set a limit on the maximum number of pipeline triggers per project. This
limit is checked every time a new trigger is created.

If a new trigger would cause the total number of pipeline triggers to exceed the
limit, the trigger is considered invalid.

Set the limit to `0` to disable it. Defaults to `150` on self-managed instances.

To set this limit to `100` on a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
Plan.default.actual_limits.update!(pipeline_triggers: 100)
```

This limit is [enabled on GitLab.com](../user/gitlab_com/index.md#gitlab-cicd).

### Number of pipeline schedules

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/29566) in GitLab 12.10.

The total number of pipeline schedules can be limited per project. This limit is
checked each time a new pipeline schedule is created. If a new pipeline schedule
would cause the total number of pipeline schedules to exceed the limit, the
pipeline schedule is not created.

GitLab SaaS subscribers have different limits [defined per plan](../user/gitlab_com/index.md#gitlab-cicd),
and they affect all projects under that plan.

On [GitLab Premium](https://about.gitlab.com/pricing/) self-managed or
higher installations, this limit is defined under a `default` plan that affects all
projects. By default, there is a limit of `10` pipeline schedules.

To set this limit for a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
Plan.default.actual_limits.update!(ci_pipeline_schedules: 100)
```

### Limit the number of pipelines created by a pipeline schedule per day

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/323066) in GitLab 14.0.

You can limit the number of pipelines that pipeline schedules can trigger per day.

Schedules that try to run pipelines more frequently than the limit are slowed to a maximum frequency.
The frequency is calculated by dividing 1440 (the number minutes in a day) by the
limit value. For example, for a maximum frequency of:

- Once per minute, the limit must be `1440`.
- Once per 10 minutes, the limit must be `144`.
- Once per 60 minutes, the limit must be `24`

There is no limit for self-managed instances by default.

To set this limit to `1440` on a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
Plan.default.actual_limits.update!(ci_daily_pipeline_schedule_triggers: 1440)
```

This limit is [enabled on GitLab.com](../user/gitlab_com/index.md#gitlab-cicd).

### Number of instance level variables

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/216097) in GitLab 13.1.

The total number of instance level CI/CD variables is limited at the instance level.
This limit is checked each time a new instance level variable is created. If a new variable
would cause the total number of variables to exceed the limit, the new variable is created.

On self-managed instances this limit is defined for the `default` plan. By default,
this limit is set to `25`.

To update this limit to a new value on a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
Plan.default.actual_limits.update!(ci_instance_level_variables: 30)
```

### Maximum file size per type of artifact

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/37226) in GitLab 13.3.

Job artifacts defined with [`artifacts:reports`](../ci/yaml/index.md#artifactsreports)
that are uploaded by the runner are rejected if the file size exceeds the maximum
file size limit. The limit is determined by comparing the project's
[maximum artifact size setting](../user/admin_area/settings/continuous_integration.md#maximum-artifacts-size)
with the instance limit for the given artifact type, and choosing the smaller value.

Limits are set in megabytes, so the smallest possible value that can be defined is `1 MB`.

Each type of artifact has a size limit that can be set. A default of `0` means there
is no limit for that specific artifact type, and the project's maximum artifact size
setting is used:

| Artifact limit name                         | Default value |
|---------------------------------------------|---------------|
| `ci_max_artifact_size_accessibility`              | 0             |
| `ci_max_artifact_size_api_fuzzing`                | 0             |
| `ci_max_artifact_size_archive`                    | 0             |
| `ci_max_artifact_size_browser_performance`        | 0             |
| `ci_max_artifact_size_cluster_applications`       | 0             |
| `ci_max_artifact_size_cluster_image_scanning`     | 0             |
| `ci_max_artifact_size_cobertura`                  | 0             |
| `ci_max_artifact_size_codequality`                | 0             |
| `ci_max_artifact_size_container_scanning`         | 0             |
| `ci_max_artifact_size_coverage_fuzzing`           | 0             |
| `ci_max_artifact_size_dast`                       | 0             |
| `ci_max_artifact_size_dependency_scanning`        | 0             |
| `ci_max_artifact_size_dotenv`                     | 0             |
| `ci_max_artifact_size_junit`                      | 0             |
| `ci_max_artifact_size_license_management`         | 0             |
| `ci_max_artifact_size_license_scanning`           | 0             |
| `ci_max_artifact_size_load_performance`           | 0             |
| `ci_max_artifact_size_lsif`                       | 100 MB ([Introduced at 20 MB](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/37226) in GitLab 13.3 and [raised to 100 MB](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/46980) in GitLab 13.6.) |
| `ci_max_artifact_size_metadata`                   | 0             |
| `ci_max_artifact_size_metrics_referee`            | 0             |
| `ci_max_artifact_size_metrics`                    | 0             |
| `ci_max_artifact_size_network_referee`            | 0             |
| `ci_max_artifact_size_performance`                | 0             |
| `ci_max_artifact_size_requirements`               | 0             |
| `ci_max_artifact_size_sast`                       | 0             |
| `ci_max_artifact_size_secret_detection`           | 0             |
| `ci_max_artifact_size_terraform`                  | 5 MB ([introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/37018) in GitLab 13.3) |
| `ci_max_artifact_size_trace`                      | 0             |

For example, to set the `ci_max_artifact_size_junit` limit to 10 MB on a self-managed
installation, run the following in the [GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
Plan.default.actual_limits.update!(ci_max_artifact_size_junit: 10)
```

### Number of files per GitLab Pages web-site

The total number of file entries (including directories and symlinks) is limited to `200,000` per
GitLab Pages website.

This is the default limit for all [GitLab self-managed and SaaS plans](https://about.gitlab.com/pricing/).

You can update the limit in your self-managed instance using the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session).
For example, to change the limit to `100`:

```ruby
Plan.default.actual_limits.update!(pages_file_entries: 100)
```

### Number of registered runners per scope

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/321368) in GitLab 13.12. Disabled by default.
> - Enabled on GitLab.com in GitLab 14.3.
> - Enabled on self-managed in GitLab 14.4.
> - Feature flag `ci_runner_limits` removed in GitLab 14.4.
> - Feature flag `ci_runner_limits_override` removed in GitLab 14.6.

The total number of registered runners is limited at the group and project levels. Each time a new runner is registered,
GitLab checks these limits against runners that have been active in the last 3 months.
A runner's registration fails if it exceeds the limit for the scope determined by the runner registration token.
If the limit value is set to zero, the limit is disabled.

- GitLab SaaS subscribers have different limits defined per plan, affecting all projects using that plan.
- Self-managed GitLab Premium and Ultimate limits are defined by a default plan that affects all projects:

    | Runner scope                                | Default value |
    |---------------------------------------------|---------------|
    | `ci_registered_group_runners`               | 1000          |
    | `ci_registered_project_runners`             | 1000          |

    To update these limits, run the following in the
    [GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

    ```ruby
    # Use ci_registered_group_runners or ci_registered_project_runners
    # depending on desired scope
    Plan.default.actual_limits.update!(ci_registered_project_runners: 100)
    ```

### Maximum file size for job logs

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/276192) in GitLab 14.1, disabled by default.
> - Enabled by default and [feature flag `ci_jobs_trace_size_limit` removed](https://gitlab.com/gitlab-org/gitlab/-/issues/335259) in GitLab 14.2.

The job log file size limit is 100 megabytes by default. Any job that exceeds this value is dropped.

You can change the limit in the [GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session).
Update `ci_jobs_trace_size_limit` with the new value in megabytes:

```ruby
Plan.default.actual_limits.update!(ci_jobs_trace_size_limit: 125)
```

### Maximum number of active DAST profile schedules per project

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/68551) in GitLab 14.3.

Limit the number of active DAST profile schedules per project. A DAST profile schedule can be active or inactive.

You can change the limit in the [GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session).
Update `dast_profile_schedules` with the new value:

```ruby
Plan.default.actual_limits.update!(dast_profile_schedules: 50)
```

### Maximum size and depth of CI/CD configuration YAML files

The default maximum size of a CI/CD configuration YAML file is 1 megabyte and the
default depth is 100.

You can change these limits in the [GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

- To update the maximum YAML size, update `max_yaml_size_bytes` with the new value in megabytes:

  ```ruby
  ApplicationSetting.update!(max_yaml_size_bytes: 2.megabytes)
  ```

  The `max_yaml_size_bytes` value is not directly tied to the size of the YAML file,
  but rather the memory allocated for the relevant objects.

- To update the maximum YAML depth, update `max_yaml_depth` with the new value in megabytes:

  ```ruby
  ApplicationSetting.update!(max_yaml_depth: 125)
  ```

To disable this limitation entirely, disable the feature flag in the console:

```ruby
Feature.disable(:ci_yaml_limit_size)
```

### Limit dotenv variables

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/321552) in GitLab 14.5.

You can set a limit on the maximum number of variables inside of a dotenv artifact.
This limit is checked every time a dotenv file is exported as an artifact.

Set the limit to `0` to disable it. Defaults to `0` on self-managed instances.

To set this limit to `100` on a self-managed instance, run the following command in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
Plan.default.actual_limits.update!(dotenv_variables: 100)
```

This limit is [enabled on GitLab.com](../user/gitlab_com/index.md#gitlab-cicd).

### Limit dotenv file size

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/321552) in GitLab 14.5.

You can set a limit on the maximum size of a dotenv artifact. This limit is checked
every time a dotenv file is exported as an artifact.

Set the limit to `0` to disable it. Defaults to 5KB.

To set this limit to 5KB on a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
Plan.default.actual_limits.update!(dotenv_size: 5.kilobytes)
```

## Instance monitoring and metrics

### Limit inbound incident management alerts

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/17859) in GitLab 12.5.

You can limit the number of inbound alerts for [incidents](../operations/incident_management/incidents.md)
that can be created in a period of time. The inbound [incident management](../operations/incident_management/index.md)
alert limit can help prevent overloading your incident responders by reducing the
number of alerts or duplicate issues.

To set inbound incident management alert limits:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > Network**.
1. Expand General **Incident Management Limits**.
1. Select the **Enable Incident Management inbound alert limit** checkbox.
1. Optional. Input a custom value for **Maximum requests per project per rate limit period**. Default is 3600.
1. Optional. Input a custom value for **Rate limit period**. Default is 3600 seconds.

### Prometheus Alert JSON payloads

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/19940) in GitLab 12.6.

Prometheus alert payloads sent to the `notify.json` endpoint are limited to 1 MB in size.

### Generic Alert JSON payloads

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/16441) in GitLab 12.4.

Alert payloads sent to the `notify.json` endpoint are limited to 1 MB in size.

### Metrics dashboard YAML files

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/34834) in GitLab 13.2.

The memory occupied by a parsed metrics dashboard YAML file cannot exceed 1 MB.

The maximum depth of each YAML file is limited to 100. The maximum depth of a YAML
file is the amount of nesting of its most nested key. Each hash and array on the
path of the most nested key counts towards its depth. For example, the depth of the
most nested key in the following YAML is 7:

```yaml
dashboard: 'Test dashboard'
links:
- title: Link 1
  url: https://gitlab.com
panel_groups:
- group: Group A
  priority: 1
  panels:
  - title: "Super Chart A1"
    type: "area-chart"
    y_label: "y_label"
    weight: 1
    max_value: 1
    metrics:
    - id: metric_a1
      query_range: 'query'
      unit: unit
      label: Legend Label
```

## Environment Dashboard limits **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/33895) in GitLab 13.4.

See [Environment Dashboard](../ci/environments/environments_dashboard.md#adding-a-project-to-the-dashboard) for the maximum number of displayed projects.

## Environment data on deploy boards

[Deploy boards](../user/project/deploy_boards.md) load information from Kubernetes about
Pods and Deployments. However, data over 10 MB for a certain environment read from
Kubernetes aren't shown.

## Merge requests

### Diff limits

GitLab has limits around:

- The patch size for a single file. [This is configurable on self-managed instance](../user/admin_area/diff_limits.md).
- The total size of all the diffs for a merge request.

An upper and lower limit applies to each of these:

- The number of changed files.
- The number of changed lines.
- The cumulative size of the changes displayed.

The lower limits result in additional diffs being collapsed. The higher limits
prevent any more changes from rendering. For more information about these limits,
[read the development documentation](../development/diffs.md#diff-limits).

### Merge request reports size limit

Reports that go over the 20 MB limit aren't loaded. Affected reports:

- [Merge request security reports](../user/project/merge_requests/testing_and_reports_in_merge_requests.md#security-reports)
- [CI/CD parameter `artifacts:expose_as`](../ci/yaml/index.md#artifactsexpose_as)
- [Unit test reports](../ci/unit_test_reports.md)

## Advanced Search limits

### Maximum file size indexed

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/8638) in GitLab 13.3.

You can set a limit on the content of repository files that are indexed in
Elasticsearch. Any files larger than this limit only index the filename.
The file content is neither indexed nor searchable.

Setting a limit helps reduce the memory usage of the indexing processes and
the overall index size. This value defaults to `1024 KiB` (1 MiB) as any
text files larger than this likely aren't meant to be read by humans.

You must set a limit, as unlimited file sizes aren't supported. Setting this
value to be greater than the amount of memory on GitLab Sidekiq nodes causes
the GitLab Sidekiq nodes to run out of memory, as this amount of memory
is pre-allocated during indexing.

### Maximum field length

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/201826) in GitLab 12.8.

You can set a limit on the content of text fields indexed for Advanced Search.
Setting a maximum helps to reduce the load of the indexing processes. If any
text field exceeds this limit, then the text is truncated to this number of
characters. The rest of the text is not indexed, and not searchable.
This applies to all indexed data except repository files that get
indexed, which have a separate limit. For more information, read
[Maximum file size indexed](#maximum-file-size-indexed).

- On GitLab.com, the field length limit is 20,000 characters.
- For self-managed installations, the field length is unlimited by default.

You can configure this limit for self-managed installations when you
[enable Elasticsearch](../integration/elasticsearch.md#enable-advanced-search).
Set the limit to `0` to disable it.

## Wiki limits

- [Wiki page content size limit](wikis/index.md#wiki-page-content-size-limit).
- [Length restrictions for file and directory names](../user/project/wiki/index.md#length-restrictions-for-file-and-directory-names).

## Snippets limits

See the [documentation about Snippets settings](snippets/index.md).

## Design Management limits

See the limits in the [Add a design to an issue](../user/project/issues/design_management.md#add-a-design-to-an-issue) section.

## Push Event Limits

### Webhooks and Project Services

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/31009) in GitLab 12.4.

Total number of changes (branches or tags) in a single push. If changes are more
than the specified limit, hooks are not executed.

More information can be found in these docs:

- [Webhooks push events](../user/project/integrations/webhook_events.md#push-events)
- [Project services push hooks limit](../user/project/integrations/overview.md#push-hooks-limit)

### Activities

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/31007) in GitLab 12.4.

Total number of changes (branches or tags) in a single push to determine whether
individual push events or a bulk push event are created.

More information can be found in the [Push event activities limit and bulk push events documentation](../user/admin_area/settings/push_event_activities_limit.md).

## Package Registry Limits

### File Size Limits

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/218017) in GitLab 13.4.

The default maximum file size for a package that's uploaded to the [GitLab Package Registry](../user/packages/package_registry/index.md) varies by format:

- Conan: 3 GB
- Generic: 5 GB
- Helm: 5 MB
- Maven: 3 GB
- npm: 500 MB
- NuGet: 500 MB
- PyPI: 3 GB
- Terraform: 1 GB

The [maximum file sizes on GitLab.com](../user/gitlab_com/index.md#package-registry-limits)
might be different.

To set these limits for a self-managed installation, run the following in the
[GitLab Rails console](operations/rails_console.md#starting-a-rails-console-session):

```ruby
# File size limit is stored in bytes

# For Conan Packages
Plan.default.actual_limits.update!(conan_max_file_size: 100.megabytes)

# For npm Packages
Plan.default.actual_limits.update!(npm_max_file_size: 100.megabytes)

# For NuGet Packages
Plan.default.actual_limits.update!(nuget_max_file_size: 100.megabytes)

# For Maven Packages
Plan.default.actual_limits.update!(maven_max_file_size: 100.megabytes)

# For PyPI Packages
Plan.default.actual_limits.update!(pypi_max_file_size: 100.megabytes)

# For Debian Packages
Plan.default.actual_limits.update!(debian_max_file_size: 100.megabytes)

# For Helm Charts
Plan.default.actual_limits.update!(helm_max_file_size: 100.megabytes)

# For Generic Packages
Plan.default.actual_limits.update!(generic_packages_max_file_size: 100.megabytes)
```

Set the limit to `0` to allow any file size.

### Package versions returned

When asking for versions of a given NuGet package name, the GitLab Package Registry returns a maximum of 300 versions.

## Dependency Proxy Limits

> [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/6396) in GitLab 14.5.

The maximum file size for an image cached in the
[Dependency Proxy](../user/packages/dependency_proxy/index.md)
varies by file type:

- Image blob: 5 GB
- Image manifest: 10 MB

## Branch retargeting on merge

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/320902) in GitLab 13.9.

If a branch is merged while open merge requests still point to it, GitLab can
retarget merge requests pointing to the now-merged branch. To learn more, read
[Branch retargeting on merge](../user/project/merge_requests/getting_started.md#branch-retargeting-on-merge).

## CDN-based limits on GitLab.com

In addition to application-based limits, GitLab.com is configured to use Cloudflare's standard DDoS protection and Spectrum to protect Git over SSH. Cloudflare terminates client TLS connections but is not application aware and cannot be used for limits tied to users or groups. Cloudflare page rules and rate limits are configured with Terraform. These configurations are [not public](https://about.gitlab.com/handbook/communication/#not-public) because they include security and abuse implementations that detect malicious activities and making them public would undermine those operations.

## Container Repository tag deletion limit

Container repository tags are in the Container Registry and, as such, each tag deletion will trigger network requests to the Container Registry. Because of this, we limit the number of tags that a single API call can delete to 20.

## Project-level Secure Files API limits

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/78227) in GitLab 14.8.

The [secure files API](../api/secure_files.md) enforces the following limits:

- Files must be smaller than 5 MB.
- Projects cannot have more than 100 secure files.
