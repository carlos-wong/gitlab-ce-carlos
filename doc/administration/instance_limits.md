---
type: reference
---

# GitLab application limits

GitLab, like most large applications, enforces limits within certain features to maintain a
minimum quality of performance. Allowing some features to be limitless could affect security,
performance, data, or could even exhaust the allocated resources for the application.

## Number of comments per issue, merge request or commit

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/22388) in GitLab 12.4.

There's a limit to the number of comments that can be submitted on an issue,
merge request, or commit. When the limit is reached, system notes can still be
added so that the history of events is not lost, but user-submitted comments
will fail.

- **Max limit:** 5.000 comments

## Number of pipelines per Git push

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/51401) in GitLab 11.10.

The number of pipelines that can be created in a single push is 4.
This is to prevent the accidental creation of pipelines when `git push --all`
or `git push --mirror` is used.

Read more in the [CI documentation](../ci/yaml/README.md#processing-git-pushes).

## Retention of activity history

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/21164) in GitLab 8.12.

Activity history for projects and individuals' profiles was limited to one year until [GitLab 11.4](https://gitlab.com/gitlab-org/gitlab-foss/issues/52246) when it was extended to two years, and in [GitLab 12.4](https://gitlab.com/gitlab-org/gitlab/issues/33840) to three years.

## Number of webhooks

On GitLab.com, the [maximum number of webhooks](../user/gitlab_com/index.md#maximum-number-of-webhooks) per project, and per group, is limited.

To set this limit on a self-managed installation, run the following in the
[GitLab Rails console](https://docs.gitlab.com/omnibus/maintenance/#starting-a-rails-console-session):

```ruby
# If limits don't exist for the default plan, you can create one with:
# Plan.default.create_limits!

# For project webhooks
Plan.default.limits.update!(project_hooks: 100)

# For group webhooks
Plan.default.limits.update!(group_hooks: 100)
```

NOTE: **Note:** Set the limit to `0` to disable it.

## CI/CD limits

### Number of jobs in active pipelines

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/32823) in GitLab 12.6.

The total number of jobs in active pipelines can be limited per project. This limit is checked
each time a new pipeline is created. An active pipeline is any pipeline in one of the following states:

- `created`
- `pending`
- `running`

If a new pipeline would cause the total number of jobs to exceed the limit, the pipeline
will fail with a `job_activity_limit_exceeded` error.

- On GitLab.com different [limits are defined per plan](../user/gitlab_com/index.md#gitlab-cicd) and they affect all projects under that plan.
- On [GitLab Starter](https://about.gitlab.com/pricing/#self-managed) tier or higher self-managed installations, this limit is defined for the `default` plan that affects all projects.
  This limit is disabled by default.

To set this limit on a self-managed installation, run the following in the
[GitLab Rails console](https://docs.gitlab.com/omnibus/maintenance/#starting-a-rails-console-session):

```ruby
# If limits don't exist for the default plan, you can create one with:
# Plan.default.create_limits!

Plan.default.limits.update!(ci_active_jobs: 500)
```

NOTE: **Note:** Set the limit to `0` to disable it.

### Number of CI/CD subscriptions to a project

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/9045) in GitLab 12.9.

The total number of subscriptions can be limited per project. This limit is
checked each time a new subscription is created.

If a new subscription would cause the total number of subscription to exceed the
limit, the subscription will be considered invalid.

- On GitLab.com different [limits are defined per plan](../user/gitlab_com/index.md#gitlab-cicd) and they affect all projects under that plan.
- On [GitLab Starter](https://about.gitlab.com/pricing/#self-managed) tier or higher self-managed installations, this limit is defined for the `default` plan that affects all projects.

To set this limit on a self-managed installation, run the following in the
[GitLab Rails console](https://docs.gitlab.com/omnibus/maintenance/#starting-a-rails-console-session):

```ruby
Plan.default.limits.update!(ci_project_subscriptions: 500)
```

NOTE: **Note:** Set the limit to `0` to disable it.

### Number of pipeline schedules

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/29566) in GitLab 12.10.

The total number of pipeline schedules can be limited per project. This limit is
checked each time a new pipeline schedule is created. If a new pipeline schedule
would cause the total number of pipeline schedules to exceed the limit, the
pipeline schedule will not be created.

On GitLab.com, different limits are [defined per plan](../user/gitlab_com/index.md#gitlab-cicd),
and they affect all projects under that plan.

On self-managed instances ([GitLab Starter](https://about.gitlab.com/pricing/#self-managed)
or higher tiers), this limit is defined for the `default` plan that affects all
projects. By default, there is no limit.

To set this limit on a self-managed installation, run the following in the
[GitLab Rails console](https://docs.gitlab.com/omnibus/maintenance/#starting-a-rails-console-session):

```ruby
Plan.default.limits.update!(ci_pipeline_schedules: 100)
```

## Environment data on Deploy Boards

[Deploy Boards](../user/project/deploy_boards.md) load information from Kubernetes about
Pods and Deployments. However, data over 10 MB for a certain environment read from
Kubernetes won't be shown.

## Merge Request reports

Reports that go over the 20 MB limit won't be loaded. Affected reports:

- [Merge Request security reports](../user/project/merge_requests/index.md#security-reports-ultimate)
- [CI/CD parameter `artifacts:expose_as`](../ci/yaml/README.md#artifactsexpose_as)
- [JUnit test reports](../ci/junit_test_reports.md)

## Advanced Global Search limits

### Maximum field length

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/201826) in GitLab 12.8.

You can set a limit on the content of text fields indexed for Global Search.
Setting a maximum helps to reduce the load of the indexing processes. If any
text field exceeds this limit then the text will be truncated to this number of
characters and the rest will not be indexed and hence will not be searchable.

- On GitLab.com this is limited to 20000 characters
- For self-managed installations it is unlimited by default

This limit can be configured for self-managed installations when [enabling
Elasticsearch](../integration/elasticsearch.md#enabling-elasticsearch).

NOTE: **Note:** Set the limit to `0` to disable it.

## Wiki limits

- [Length restrictions for file and directory names](../user/project/wiki/index.md#length-restrictions-for-file-and-directory-names).
