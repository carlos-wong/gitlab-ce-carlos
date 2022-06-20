---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Managing Go versions

## Overview

All Go binaries, with the exception of
[GitLab Runner](https://gitlab.com/gitlab-org/gitlab-runner) and [Security Projects](https://gitlab.com/gitlab-org/security-products), are built in
projects managed by the [Distribution team](https://about.gitlab.com/handbook/product/categories/#distribution-group).

The [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab) project creates a
single, monolithic operating system package containing all the binaries, while
the [Cloud-Native GitLab (CNG)](https://gitlab.com/gitlab-org/build/CNG) project
publishes a set of Docker images deployed and configured by Helm Charts or
the GitLab Operator.

Testing matrices for all projects using Go must include the version shipped
by Distribution:

- [Check the Go version shipping with Omnibus GitLab](https://gitlab.com/gitlab-org/gitlab-omnibus-builder/-/blob/master/docker/VERSIONS#L6).
- [Check the Go version shipping with Cloud-Native GitLab (CNG)](https://gitlab.com/gitlab-org/build/cng/blob/master/ci_files/variables.yml#L12).

## Supporting multiple Go versions

Individual Golang projects need to support multiple Go versions because:

- When a new version of Go is released, we should start integrating it into the CI pipelines to verify compatibility with the new compiler.
- We must support the [official Omnibus GitLab Go version](#updating-go-version), which may be behind the latest minor release.
- When Omnibus switches Go version, we still may need to support the old one for security backports.

These 3 requirements may easily be satisfied by keeping support for the [3 latest minor versions of Go](https://go.dev/dl/).

It is ok to drop support for the oldest Go version and support only the 2 latest releases,
if this is enough to support backports to the last 3 minor GitLab releases.

For example, if we want to drop support for `go 1.11` in GitLab `12.10`, we need
to verify which Go versions we are using in `12.9`, `12.8`, and `12.7`. We do not
consider the active milestone, `12.10`, because a backport for `12.7` is required
in case of a critical security release.

- If both [Omnibus GitLab and Cloud-Native GitLab (CNG)](#updating-go-version) were using Go `1.12` in GitLab `12.7` and later,
  then we can safely drop support for `1.11`.
- If Omnibus GitLab or Cloud-Native GitLab (CNG) were using `1.11` in GitLab `12.7`, then we still need to keep
  support for Go `1.11` for easier backporting of security fixes.

## Updating Go version

We should always:

- Use the same Go version for Omnibus GitLab and Cloud Native GitLab.
- Use a [supported version](https://go.dev/doc/devel/release#policy).
- Use the most recent patch-level for that version to keep up with security fixes.

Changing the version affects every project being compiled, so it's important to
ensure that all projects have been updated to test against the new Go version
before changing the package builders to use it. Despite [Go's compatibility promise](https://go.dev/doc/go1compat),
changes between minor versions can expose bugs or cause problems in our projects.

### Upgrade process

The upgrade process involves several key steps:

- [Track component updates and validation](#tracking-work).
- [Track component integration for release](#tracking-work).
- [Communication with stakeholders](#communication-plan).

#### Tracking work

Use [the product categories page](https://about.gitlab.com/handbook/product/categories/)
if you need help finding the correct person or labels:

1. Create the epic in `gitlab-org` group:
   - Title the epic `Update Go version to <VERSION_NUMBER>`.
   - Ping the engineering managers responsible for [the projects listed below](#known-dependencies-using-go).
     - Most engineering managers can be identified on
       [the product page](https://about.gitlab.com/handbook/product/categories/) or the
       [feature page](https://about.gitlab.com/handbook/product/categories/features/).
     - If you still can't find the engineering manager, use
       [Git blame](/ee/user/project/repository/git_blame.md) to identify a maintainer
       involved in the project.

1. Create an upgrade issue for each dependency in the
   [location indicated below](#known-dependencies-using-go) titled
   `Support building with Go <VERSION_NUMBER>`. Add the proper labels to each issue
   for easier triage. These should include the stage, group and section.
   - The issue should be assigned by a member of the maintaining group.
   - The milestone should be assigned by a member of the maintaining group.

   NOTE:
   Some overlap exists between project dependencies. When creating an issue for a
   dependency that is part of a larger product, note the relationship in the issue
   body. For example: Projects built in the context of Omnibus GitLab have their
   runtime Go version managed by Omnibus, but "support" and compatibility should
   be a concern of the individual project. Issues in the parent project's dependencies
   issue should be about adding support for the updated Go version.

   NOTE:
   The upgrade issues must include [upgrade validation items](#upgrade-validation)
   in their definition of done. Creating a second [performance testing issue](#upgrade-validation)
   titled `Validate operation and performance at scale with Go <VERSION_NUMBER>`
   is strongly recommended to help with scheduling tasks and managing workloads.

1. Schedule an update with the [GitLab Development Kit](https://gitlab.com/gitlab-org/gitlab-development-kit/-/issues):
   - Title the issue `Support using Go version <VERSION_NUMBER>`.
   - Set the issue as related to every issue created in the previous step.
1. Schedule one issue per Sec Section team that maintains Go based Security Analyzers and add the `section::sec` label to each:
   - [Static Analysis tracker](https://gitlab.com/gitlab-org/gitlab/-/issues).
   - [Composition Analysis tracker](https://gitlab.com/gitlab-org/gitlab/-/issues).
   - [Container Security tracker](https://gitlab.com/gitlab-org/gitlab/-/issues).

   NOTE:
   Updates to these Security analyzers should not block upgrades to Charts or Omnibus since
   the analyzers are built independently as separate container images.

1. Schedule builder updates with Distribution projects:
   - Dependency and GitLab Development Kit issues created in previous steps should be set as blockers.
   - Each issue should have the title `Support building with Go <VERSION_NUMBER>` and description as noted:
     - [Cloud-Native GitLab](https://gitlab.com/gitlab-org/charts/gitlab/-/issues)

       ```plaintext
       Update the `GO_VERSION` in `ci_files/variables.yml`.
       ```

     - [Omnibus GitLab Builder](https://gitlab.com/gitlab-org/gitlab-omnibus-builder/-/issues)

       ```plaintext
       Update `GO_VERSION` in `docker/VERSIONS`.
       ```

     - [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues)

       ```plaintext
       Update `BUILDER_IMAGE_REVISION` in `.gitlab-ci.yml` to match tag from builder.
       ```

   NOTE:
   If the component is not automatically upgraded for [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues)
   and [Cloud Native GitLab](https://gitlab.com/gitlab-org/charts/gitlab/-/issues),
   issues should be opened in their respective trackers titled `Updated bundled version of COMPONENT_NAME`
   and set as blocked by the component's upgrade issue.

#### Known dependencies using Go

| Component Name                | Where to track work |
|-------------------------------|---------------------|
| [Alertmanager](https://github.com/prometheus/alertmanager) | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab/-/issues) |
| Docker Distribution Pruner    | [Issue Tracker](https://gitlab.com/gitlab-org/docker-distribution-pruner) |
| Gitaly                        | [Issue Tracker](https://gitlab.com/gitlab-org/gitaly/-/issues) |
| GitLab Compose Kit            | [Issuer Tracker](https://gitlab.com/gitlab-org/gitlab-compose-kit/-/issues) |
| GitLab Container Registry     | [Issue Tracker](https://gitlab.com/gitlab-org/container-registry) |
| GitLab Elasticsearch Indexer  | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab-elasticsearch-indexer/-/issues) |
| GitLab agent server for Kubernetes (KAS) | [Issue Tracker](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/issues) |
| GitLab Pages                  | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab-pages/-/issues) |
| GitLab Quality Images         | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab-build-images/-/issues) |
| GitLab Shell                  | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab-shell/-/issues) |
| GitLab Workhorse              | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab/-/issues) |
| Labkit                        | [Issue Tracker](https://gitlab.com/gitlab-org/labkit/-/issues) |
| [Node Exporter](https://github.com/prometheus/node_exporter) | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab/-/issues) |
| [PgBouncer Exporter](https://github.com/prometheus-community/pgbouncer_exporter) | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab/-/issues) |
| [Postgres Exporter](https://github.com/prometheus-community/postgres_exporter) | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab/-/issues) |
| [Prometheus](https://github.com/prometheus/prometheus) | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab/-/issues) |
| [Redis Exporter](https://github.com/oliver006/redis_exporter) | [Issue Tracker](https://gitlab.com/gitlab-org/gitlab/-/issues) |

#### Communication plan

Communication is required at several key points throughout the process and should
be included in the relevant issues as part of the definition of done:

1. Immediately after creating the epic, it should be posted to Slack. Community members must ask the pinged engineering managers for assistance with this step. The responsible GitLab team member should share a link to the epic in the following Slack channels:
   - `#backend`
   - `#development`
1. Immediately after merging the GitLab Development Kit Update, the same maintainer should add an entry to the engineering week-in-review sync and
   announce the change in the following Slack channels:
   - `#backend`
   - `#development`
1. Immediately upon merge of the updated Go versions in
   [Cloud-Native GitLab](https://gitlab.com/gitlab-org/build/CNG) and
   [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab) add the
   change to the engineering-week-in-review sync and announce in the following
   Slack channels:
   - `#backend`
   - `#development`
   - `#releases`

#### Upgrade validation

Upstream component maintainers must validate their Go-based projects using:

- Established unit tests in the codebase.
- Procedures established in [Merge Request Performance Guidelines](../merge_request_performance_guidelines.md).
- Procedures established in [Performance, Reliability, and Availability guidelines](../code_review.md#performance-reliability-and-availability).

Upstream component maintainers should consider validating their Go-based
projects with:

- Isolated component operation performance tests.

  Integration tests are costly and should be testing inter-component
  operational issues. Isolated component testing reduces mean time to
  feedback on updates and decreases resource burn across the organization.

- Components should have end-to-end test coverage in the GitLab Performance Test tool.
- Integration validation through installation of fresh packages **_and_** upgrade from previous versions for:
  - Single GitLab Node
  - Reference Architecture Deployment
  - Geo Deployment
