---
type: reference
---

# Multi-project pipelines **[PREMIUM]**

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/issues/2121) in
[GitLab Premium 9.3](https://about.gitlab.com/2017/06/22/gitlab-9-3-released/#multi-project-pipeline-graphs).

When you set up [GitLab CI/CD](README.md) across multiple projects, you can visualize
the entire pipeline, including all cross-project inter-dependencies.

## Overview

GitLab CI/CD is a powerful continuous integration tool that works not only per project, but also across projects. When you
configure GitLab CI for your project, you can visualize the stages
of your [jobs](pipelines.md#configuring-pipelines) on a [pipeline graph](pipelines.md#visualizing-pipelines).

![Multi-project pipeline graph](img/multi_project_pipeline_graph.png)

In the Merge Request Widget, multi-project pipeline mini-graphs are displayed,
and when hovering or tapping (on touchscreen devices) they will expand and be shown adjacent to each other.

![Multi-project mini graph](img/multi_pipeline_mini_graph.gif)

Multi-project pipelines are useful for larger products that require cross-project inter-dependencies, such as those
adopting a [microservices architecture](https://about.gitlab.com/2016/08/16/trends-in-version-control-land-microservices/).

For a demonstration of how cross-functional development teams can use cross-pipeline
triggering to trigger multiple pipelines for different microservices projects, see
[Cross-project Pipeline Triggering and Visualization](https://about.gitlab.com/handbook/marketing/product-marketing/demo/#cross-project-pipeline-triggering-and-visualization-may-2019---1110).

## Use cases

Let's assume you deploy your web app from different projects in GitLab:

- One for the free version, which has its own pipeline that builds and tests your app
- One for the paid version add-ons, which also pass through builds and tests
- One for the documentation, which also builds, tests, and deploys with an SSG

With Multi-Project Pipelines, you can visualize the entire pipeline, including all stages of builds and tests for the three projects.

## Triggering multi-project pipelines through API

When you use the [`CI_JOB_TOKEN` to trigger pipelines](triggers/README.md#ci-job-token), GitLab
recognizes the source of the job token, and thus internally ties these pipelines
together, allowing you to visualize their relationships on pipeline graphs.

These relationships are displayed in the pipeline graph by showing inbound and
outbound connections for upstream and downstream pipeline dependencies.

## Creating multi-project pipelines from `.gitlab-ci.yml`

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/issues/8997) in [GitLab Premium](https://about.gitlab.com/pricing/) 11.8.

### Triggering a downstream pipeline using a bridge job

Before GitLab 11.8, it was necessary to implement a pipeline job that was
responsible for making the API request [to trigger a pipeline](#triggering-multi-project-pipelines-through-api)
in a different project.

In GitLab 11.8, GitLab provides a new CI/CD configuration syntax to make this
task easier, and avoid needing GitLab Runner for triggering cross-project
pipelines. The following illustrates configuring a bridge job:

```yaml
rspec:
  stage: test
  script: bundle exec rspec

staging:
  variables:
    ENVIRONMENT: staging
  stage: deploy
  trigger: my/deployment
```

In the example above, as soon as `rspec` job succeeds in the `test` stage,
the `staging` bridge job is going to be started. The initial status of this
job will be `pending`. GitLab will create a downstream pipeline in the
`my/deployment` project and, as soon as the pipeline gets created, the
`staging` job will succeed. `my/deployment` is a full path to that project.

The user that created the upstream pipeline needs to have access rights to the
downstream project (`my/deployment` in this case). If a downstream project can
not be found, or a user does not have access rights to create pipeline there,
the `staging` job is going to be marked as _failed_.

CAUTION: **Caution:**
`staging` will succeed as soon as a downstream pipeline gets created.
GitLab does not support status attribution yet, however adding first-class
`trigger` configuration syntax is ground work for implementing
[status attribution](https://gitlab.com/gitlab-org/gitlab-ce/issues/39640).

NOTE: **Note:**
Bridge jobs do not support every configuration entry that a user can use
in the case of regular jobs. Bridge jobs will not to be picked by a Runner,
thus there is no point in adding support for `script`, for example. If a user
tries to use unsupported configuration syntax, YAML validation will fail upon
pipeline creation.

### Specifying a downstream pipeline branch

It is possible to specify a branch name that a downstream pipeline will use:

```yaml
rspec:
  stage: test
  script: bundle exec rspec

staging:
  stage: deploy
  trigger:
    project: my/deployment
    branch: stable-11-2
```

Use a `project` keyword to specify full path to a downstream project. Use
a `branch` keyword to specify a branch name.

GitLab will use a commit that is currently on the HEAD of the branch when
creating a downstream pipeline.

### Passing variables to a downstream pipeline

Sometimes you might want to pass variables to a downstream pipeline.
You can do that using the `variables` keyword, just like you would when
defining a regular job.

```yaml
rspec:
  stage: test
  script: bundle exec rspec

staging:
  variables:
    ENVIRONMENT: staging
  stage: deploy
  trigger: my/deployment
```

The `ENVIRONMENT` variable will be passed to every job defined in a downstream
pipeline. It will be available as an environment variable when GitLab Runner picks a job.

In the following configuration, the `MY_VARIABLE` variable will be passed to the downstream pipeline
that is created when the `trigger-downstream` job is queued. This is because `trigger-downstream`
job inherits variables declared in global variables blocks, and then we pass these variables to a downstream pipeline.

```yaml
variables:
  MY_VARIABLE: my-value

trigger-downstream:
  variables:
    ENVIRONMENT: something
  trigger: my/project
```

You might want to pass some information about the upstream pipeline using, for
example, predefined variables. In order to do that, you can use interpolation
to pass any variable. For example:

```yaml
downstream-job:
  variables:
    UPSTREAM_BRANCH: $CI_COMMIT_REF_NAME
  trigger: my/project
```

In this scenario, the `UPSTREAM_BRANCH` variable with a value related to the
upstream pipeline will be passed to the `downstream-job` job, and will be available
within the context of all downstream builds.

### Limitations

Because bridge jobs are a little different to regular jobs, it is not
possible to use exactly the same configuration syntax here, as one would
normally do when defining a regular job that will be picked by a runner.

Some features are not implemented yet. For example, support for environments.

[Configuration keywords](yaml/README.md) available for bridge jobs are:

- `trigger` (to define a downstream pipeline trigger)
- `stage`
- `allow_failure`
- `only` and `except`
- `when`
- `extends`
