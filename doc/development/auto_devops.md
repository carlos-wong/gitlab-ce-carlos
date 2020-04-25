# Auto DevOps development guide

This document provides a development guide for contributors to
[Auto DevOps](../topics/autodevops/index.md)

## Development

Auto DevOps builds on top of GitLab CI to create an automatic pipeline
based on your project contents. When Auto DevOps is enabled for a
project, the user does not need to explicitly include any pipeline configuration
through a [`.gitlab-ci.yml` file](../ci/yaml/README.md).

In the absence of a `.gitlab-ci.yml` file, the [Auto DevOps CI
template](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Auto-DevOps.gitlab-ci.yml)
is used implicitly to configure the pipeline for the project. This
template is a top-level template that includes other sub-templates,
which then defines jobs.

Some jobs use images that are built from external projects:

- [Auto Build](../topics/autodevops/index.md#auto-build) uses
  [configuration](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Jobs/Build.gitlab-ci.yml)
  in which the `build` job uses an image that is built using the
  [`auto-build-image`](https://gitlab.com/gitlab-org/cluster-integration/auto-build-image)
  project.
- [Auto Deploy](../topics/autodevops/index.md#auto-deploy) uses
  [configuration](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Jobs/Deploy.gitlab-ci.yml)
  in which the jobs defined in this template use an image that is built using the
  [`auto-deploy-image`](https://gitlab.com/gitlab-org/cluster-integration/auto-deploy-image)
  project. By default, the Helm chart defined in
  [`auto-deploy-app`](https://gitlab.com/gitlab-org/charts/auto-deploy-app)
  is used to deploy.

There are extra variables that get passed to the CI jobs when Auto
DevOps is enabled that are not present in a normal CI job. These can be
found in
[`ProjectAutoDevops`](https://gitlab.com/gitlab-org/gitlab/blob/bf69484afa94e091c3e1383945f60dbe4e8681af/app/models/project_auto_devops.rb).

## Development environment

Configuring [GDK for Auto
DevOps](https://gitlab.com/gitlab-org/gitlab-development-kit/blob/master/doc/howto/auto_devops.md).

## Monitoring on GitLab.com

The metric
[`auto_devops_completed_pipelines_total`](https://thanos-query.ops.gitlab.net/graph?g0.range_input=72h&g0.max_source_resolution=0s&g0.expr=sum(increase(auto_devops_pipelines_completed_total%7Benvironment%3D%22gprd%22%7D%5B60m%5D))%20by%20(status)&g0.tab=0)
(only available to GitLab team members) counts completed Auto DevOps
pipelines, labeled by status.
