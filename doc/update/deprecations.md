---
stage: none
group: none
info: "See the Technical Writers assigned to Development Guidelines: https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments-to-development-guidelines"
---

# Deprecations by version

<!-- vale off -->

<!--
DO NOT EDIT THIS PAGE DIRECTLY

This page is automatically generated from the YAML files in `/data/deprecations` by the rake task
located at `lib/tasks/gitlab/docs/compile_deprecations.rake`.

For deprecation authors (usually Product Managers and Engineering Managers):

- To add a deprecation, use the example.yml file in `/data/deprecations/templates` as a template.
- For more information about authoring deprecations, check the the deprecation item guidance:
  https://about.gitlab.com/handbook/marketing/blog/release-posts/#creating-a-deprecation-entry

For deprecation reviewers (Technical Writers only):

- To update the deprecation doc, run: `bin/rake gitlab:docs:compile_deprecations`
- To verify the deprecations doc is up to date, run: `bin/rake gitlab:docs:check_deprecations`
- For more information about updating the deprecation doc, see the deprecation doc update guidance:
  https://about.gitlab.com/handbook/marketing/blog/release-posts/#update-the-deprecations-doc
-->

{::options parse_block_html="true" /}

In each release, GitLab announces features that are deprecated and no longer recommended for use.
Each deprecated feature will be removed in a future release.
Some features cause breaking changes when they are removed.

DISCLAIMER:
This page contains information related to upcoming products, features, and functionality.
It is important to note that the information presented is for informational purposes only.
Please do not rely on this information for purchasing or planning purposes.
As with all projects, the items mentioned on this page are subject to change or delay.
The development, release, and timing of any products, features, or functionality remain at the
sole discretion of GitLab Inc.
<div class="js-deprecation-filters"></div>

<div class="announcement-milestone">

## Announced in 15.2

<div class="deprecation removal-160 breaking-change">

### Remove `job_age` parameter from `POST /jobs/request` Runner endpoint

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `job_age` parameter, returned from the `POST /jobs/request` API endpoint used in communication with GitLab Runner, was never used by any GitLab or Runner feature. This parameter will be removed in GitLab 16.0.

This could be a breaking change for anyone that developed their own runner that relies on this parameter being returned by the endpoint. This is not a breaking change for anyone using an officially released version of GitLab Runner, including public shared runners on GitLab.com.

</div>
</div>

<div class="announcement-milestone">

## Announced in 15.1

<div class="deprecation removal-160 breaking-change">

### Jira GitHub Enterprise DVCS integration

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The [Jira DVCS Connector](https://docs.gitlab.com/ee/integration/jira/dvcs.html) (which enables the [Jira Development Panel](https://support.atlassian.com/jira-software-cloud/docs/view-development-information-for-an-issue/)), will no longer support Jira Cloud users starting with GitLab 16.0. The [GitLab for Jira App](https://docs.gitlab.com/ee/integration/jira/connect-app.html) has always been recommended for Jira Cloud users, and it will be required instead of the DVCS connector. If you are a Jira Cloud user, we recommended you begin migrating to the GitLab for Jira App.
Any Jira Server and Jira Data Center users will need to confirm they are not using the GitHub Enterprise Connector to enable the GitLab DVCS integration, but they may continue to use the [native GitLab DVCS integration](https://docs.gitlab.com/ee/integration/jira/dvcs.html) (supported in Jira 8.14 and later).

</div>

<div class="deprecation removal-160 breaking-change">

### PipelineSecurityReportFinding name GraphQL field

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Previously, the [PipelineSecurityReportFinding GraphQL type was updated](https://gitlab.com/gitlab-org/gitlab/-/issues/335372) to include a new `title` field. This field is an alias for the current `name` field, making the less specific `name` field redundant. The `name` field will be removed from the PipelineSecurityReportFinding type in GitLab 16.0.

</div>

<div class="deprecation removal-160 breaking-change">

### PipelineSecurityReportFinding projectFingerprint GraphQL field

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The [`project_fingerprint`](https://gitlab.com/groups/gitlab-org/-/epics/2791) attribute of vulnerability findings is being deprecated in favor of a `uuid` attribute. By using UUIDv5 values to identify findings, we can easily associate any related entity with a finding. The `project_fingerprint` attribute is no longer being used to track findings, and will be removed in GitLab 16.0.

</div>

<div class="deprecation removal-160 breaking-change">

### REST API Runner maintainer_note

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `maintainer_note` argument in the `POST /runners` REST endpoint was deprecated in  GitLab 14.8 and replaced with the `maintenance_note` argument.
The `maintainer_note` argument will be removed in GitLab 16.0.

</div>

<div class="deprecation removal-153">

### Vulnerability Report sort by Tool

Planned removal: GitLab <span class="removal-milestone">15.3</span> (2022-08-22)

The ability to sort the Vulnerability Report by the `Tool` column (scan type) was disabled and put behind a feature flag in GitLab 14.10 due to a refactor
of the underlying data model. The feature flag has remained off by default as further refactoring will be required to ensure sorting
by this value remains performant. Due to very low usage of the `Tool` column for sorting, the feature flag will instead be removed in
GitLab 15.3 to simplify the codebase and prevent any unwanted performance degradation.

</div>

<div class="deprecation removal-160 breaking-change">

### project.pipeline.securityReportFindings GraphQL query

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Previous work helped [align the vulnerabilities calls for pipeline security tabs](https://gitlab.com/gitlab-org/gitlab/-/issues/343469) to match the vulnerabilities calls for project-level and group-level vulnerability reports. This helped the frontend have a more consistent interface. The old `project.pipeline.securityReportFindings` query was formatted differently than other vulnerability data calls. Now that it has been replaced with the new `project.pipeline.vulnerabilities` field, the old `project.pipeline.securityReportFindings` is being deprecated and will be removed in GitLab 16.0.

</div>
</div>

<div class="announcement-milestone">

## Announced in 15.0

<div class="deprecation removal-160 breaking-change">

### CiCdSettingsUpdate mutation renamed to ProjectCiCdSettingsUpdate

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `CiCdSettingsUpdate` mutation was renamed to `ProjectCiCdSettingsUpdate` in GitLab 15.0.
The `CiCdSettingsUpdate` mutation will be removed in GitLab 16.0.
Any user scripts that use the `CiCdSettingsUpdate` mutation must be updated to use `ProjectCiCdSettingsUpdate`
instead.

</div>

<div class="deprecation removal-160 breaking-change">

### GraphQL API legacyMode argument for Runner status

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `legacyMode` argument to the `status` field in `RunnerType` will be rendered non-functional in the 16.0 release
as part of the deprecations details in the [issue](https://gitlab.com/gitlab-org/gitlab/-/issues/351109).

In GitLab 16.0 and later, the `status` field will act as if `legacyMode` is null. The `legacyMode` argument will
be present during the 16.x cycle to avoid breaking the API signature, and will be removed altogether in the
17.0 release.

</div>

<div class="deprecation removal-160 breaking-change">

### PostgreSQL 12 deprecated

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Support for PostgreSQL 12 is scheduled for removal in GitLab 16.0.
In GitLab 16.0, PostgreSQL 13 becomes the minimum required PostgreSQL version.

PostgreSQL 12 will be supported for the full GitLab 15 release cycle.
PostgreSQL 13 will also be supported for instances that want to upgrade prior to GitLab 16.0.

Upgrading to PostgreSQL 13 is not yet supported for GitLab instances with Geo enabled. Geo support for PostgreSQL 13 will be announced in a minor release version of GitLab 15, after the process is fully supported and validated. For more information, read the Geo related verifications on the [support epic for PostgreSQL 13](https://gitlab.com/groups/gitlab-org/-/epics/3832).

</div>

<div class="deprecation removal-152">

### Vulnerability Report sort by State

Planned removal: GitLab <span class="removal-milestone">15.2</span> (2022-07-22)

The ability to sort the Vulnerability Report by the `State` column was disabled and put behind a feature flag in GitLab 14.10 due to a refactor
of the underlying data model. The feature flag has remained off by default as further refactoring will be required to ensure sorting
by this value remains performant. Due to very low usage of the `State` column for sorting, the feature flag will instead be removed in
GitLab 15.2 to simplify the codebase and prevent any unwanted performance degradation.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.10

<div class="deprecation removal-150 breaking-change">

### Dependency Scanning default Java version changed to 17

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

In GitLab 15.0, for Dependency Scanning, the default version of Java that the scanner expects will be updated from 11 to 17. Java 17 is [the most up-to-date Long Term Support (LTS) version](https://en.wikipedia.org/wiki/Java_version_history). Dependency scanning continues to support the same [range of versions (8, 11, 13, 14, 15, 16, 17)](https://docs.gitlab.com/ee/user/application_security/dependency_scanning/#supported-languages-and-package-managers), only the default version is changing. If your project uses the previous default of Java 11, be sure to [set the `DS_Java_Version` variable to match](https://docs.gitlab.com/ee/user/application_security/dependency_scanning/#configuring-specific-analyzers-used-by-dependency-scanning).

</div>

<div class="deprecation removal-160 breaking-change">

### Manual iteration management

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-04-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Manual iteration management is deprecated and only automatic iteration cadences will be supported in the future.

Creating and deleting iterations will be fully removed in 16.0. Updating all iteration fields except for
`description` will also be removed.

On the GraphQL API the following mutations will be removed:

  1. `iterationCreate`
  1. `iterationDelete`

The update `updateIteration` mutation will only allow updating the iteration's `description`. The following
arguments will be removed:

  1. `title`
  1. `dueDate`
  1. `startDate`

For more information about iteration cadences, you can refer to
[the documentation of the feature](https://docs.gitlab.com/ee/user/group/iterations/#iteration-cadences).

</div>

<div class="deprecation removal-150 breaking-change">

### Outdated indices of Advanced Search migrations

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

As Advanced Search migrations usually require support multiple code paths for a long period of time, it’s important to clean those up when we safely can. We use GitLab major version upgrades as a safe time to remove backward compatibility for indices that have not been fully migrated. See the [upgrade documentation](https://docs.gitlab.com/ee/update/index.html#upgrading-to-a-new-major-version) for details.

</div>

<div class="deprecation removal-160 breaking-change">

### Toggle notes confidentiality on APIs

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Toggling notes confidentiality with REST and GraphQL APIs is being deprecated. Updating notes confidential attribute is no longer supported by any means. We are changing this to simplify the experience and prevent private information from being unintentionally exposed.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.9

<div class="deprecation removal-150 breaking-change">

### Background upload for object storage

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

To reduce the overall complexity and maintenance burden of GitLab's [object storage feature](https://docs.gitlab.com/ee/administration/object_storage.html), support for using `background_upload` to upload files is deprecated and will be fully removed in GitLab 15.0. Review the [15.0 specific changes](https://docs.gitlab.com/omnibus/update/gitlab_15_changes.html) for the [removed background uploads settings for object storage](https://docs.gitlab.com/omnibus/update/gitlab_15_changes.html#removed-background-uploads-settings-for-object-storage).

This impacts a small subset of object storage providers:

- **OpenStack** Customers using OpenStack need to change their configuration to use the S3 API instead of Swift.
- **RackSpace** Customers using RackSpace-based object storage need to migrate data to a different provider.

GitLab will publish additional guidance to assist affected customers in migrating.

</div>

<div class="deprecation removal-151">

### Deprecate support for Debian 9

Planned removal: GitLab <span class="removal-milestone">15.1</span> (2022-06-22)

Long term service and support (LTSS) for [Debian 9 Stretch ends in July 2022](https://wiki.debian.org/LTS). Therefore, we will no longer support the Debian 9 distribution for the GitLab package. Users can upgrade to Debian 10 or Debian 11.

</div>

<div class="deprecation removal-150">

### GitLab Pages running as daemon

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

In 15.0, support for daemon mode for GitLab Pages will be removed.

</div>

<div class="deprecation removal-160 breaking-change">

### GitLab self-monitoring project

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

GitLab self-monitoring gives administrators of self-hosted GitLab instances the tools to monitor the health of their instances. This feature is deprecated in GitLab 14.9, and is scheduled for removal in 16.0.

</div>

<div class="deprecation removal-150 breaking-change">

### GraphQL permissions change for Package settings

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The GitLab Package stage offers a Package Registry, Container Registry, and Dependency Proxy to help you manage all of your dependencies using GitLab. Each of these product categories has a variety of settings that can be adjusted using the API.

The permissions model for GraphQL is being updated. After 15.0, users with the Guest, Reporter, and Developer role can no longer update these settings:

- [Package Registry settings](https://docs.gitlab.com/ee/api/graphql/reference/#packagesettings)
- [Container Registry cleanup policy](https://docs.gitlab.com/ee/api/graphql/reference/#containerexpirationpolicy)
- [Dependency Proxy time-to-live policy](https://docs.gitlab.com/ee/api/graphql/reference/#dependencyproxyimagettlgrouppolicy)
- [Enabling the Dependency Proxy for your group](https://docs.gitlab.com/ee/api/graphql/reference/#dependencyproxysetting)

</div>

<div class="deprecation removal-150">

### Move `custom_hooks_dir` setting from GitLab Shell to Gitaly

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

The [`custom_hooks_dir`](https://docs.gitlab.com/ee/administration/server_hooks.html#create-a-global-server-hook-for-all-repositories) setting is now configured in Gitaly, and will be removed from GitLab Shell in GitLab 15.0.

</div>

<div class="deprecation removal-1410 breaking-change">

### Permissions change for downloading Composer dependencies

Planned removal: GitLab <span class="removal-milestone">14.10</span> (2022-04-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The GitLab Composer repository can be used to push, search, fetch metadata about, and download PHP dependencies. All these actions require authentication, except for downloading dependencies.

Downloading Composer dependencies without authentication is deprecated in GitLab 14.9, and will be removed in GitLab 15.0. Starting with GitLab 15.0, you must authenticate to download Composer dependencies.

</div>

<div class="deprecation removal-150 breaking-change">

### htpasswd Authentication for the Container Registry

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The Container Registry supports [authentication](https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs/configuration.md#auth) with `htpasswd`. It relies on an [Apache `htpasswd` file](https://httpd.apache.org/docs/2.4/programs/htpasswd.html), with passwords hashed using `bcrypt`.

Since it isn't used in the context of GitLab (the product), `htpasswd` authentication will be deprecated in GitLab 14.9 and removed in GitLab 15.0.

</div>

<div class="deprecation removal-150 breaking-change">

### user_email_lookup_limit API field

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `user_email_lookup_limit` [API field](https://docs.gitlab.com/ee/api/settings.html) is deprecated and will be removed in GitLab 15.0. Until GitLab 15.0, `user_email_lookup_limit` is aliased to `search_rate_limit` and existing workflows will continue to work.

Any API calls attempting to change the rate limits for `user_email_lookup_limit` should use `search_rate_limit` instead.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.8

<div class="deprecation removal-149">

### Configurable Gitaly `per_repository` election strategy

Planned removal: GitLab <span class="removal-milestone">14.9</span> (2022-03-22)

Configuring the `per_repository` Gitaly election strategy is [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/352612).
`per_repository` has been the only option since GitLab 14.0.

This change is part of regular maintenance to keep our codebase clean.

</div>

<div class="deprecation removal-150 breaking-change">

### Container Network and Host Security

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

All functionality related to GitLab's Container Network Security and Container Host Security categories is deprecated in GitLab 14.8 and scheduled for removal in GitLab 15.0. Users who need a replacement for this functionality are encouraged to evaluate the following open source projects as potential solutions that can be installed and managed outside of GitLab: [AppArmor](https://gitlab.com/apparmor/apparmor), [Cilium](https://github.com/cilium/cilium), [Falco](https://github.com/falcosecurity/falco), [FluentD](https://github.com/fluent/fluentd), [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/). To integrate these technologies into GitLab, add the desired Helm charts into your copy of the [Cluster Management Project Template](https://docs.gitlab.com/ee/user/clusters/management_project_template.html). Deploy these Helm charts in production by calling commands through GitLab [CI/CD](https://docs.gitlab.com/ee/user/clusters/agent/ci_cd_workflow.html).

As part of this change, the following specific capabilities within GitLab are now deprecated, and are scheduled for removal in GitLab 15.0:

- The **Security & Compliance > Threat Monitoring** page.
- The `Network Policy` security policy type, as found on the **Security & Compliance > Policies** page.
- The ability to manage integrations with the following technologies through GitLab: AppArmor, Cilium, Falco, FluentD, and Pod Security Policies.
- All APIs related to the above functionality.

For additional context, or to provide feedback regarding this change, please reference our open [deprecation issue](https://gitlab.com/groups/gitlab-org/-/epics/7476).

</div>

<div class="deprecation removal-150 breaking-change">

### Dependency Scanning Python 3.9 and 3.6 image deprecation

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

For those using Dependency Scanning for Python projects, we are deprecating the default `gemnasium-python:2` image which uses Python 3.6 as well as the custom `gemnasium-python:2-python-3.9` image which uses Python 3.9. The new default image as of GitLab 15.0 will be for Python 3.9 as it is a [supported version](https://endoflife.date/python) and 3.6 [is no longer supported](https://endoflife.date/python).

For users using Python 3.9 or 3.9-compatible projects, you should not need to take action and dependency scanning should begin to work in GitLab 15.0. If you wish to test the new container now please run a test pipeline in your project with this container (which will be removed in 15.0). Use the Python 3.9 image:

```yaml
gemnasium-python-dependency_scanning:
  image:
    name: registry.gitlab.com/gitlab-org/security-products/analyzers/gemnasium-python:2-python-3.9
```

For users using Python 3.6, as of GitLab 15.0 you will no longer be able to use the default template for dependency scanning. You will need to switch to use the deprecated `gemnasium-python:2` analyzer image. If you are impacted by this please comment in [this issue](https://gitlab.com/gitlab-org/gitlab/-/issues/351503) so we can extend the removal if needed.

For users using the 3.9 special exception image, you must instead use the default value and no longer override your container. To verify if you are using the 3.9 special exception image, check your `.gitlab-ci.yml` file for the following reference:

```yaml
gemnasium-python-dependency_scanning:
  image:
    name: registry.gitlab.com/gitlab-org/security-products/analyzers/gemnasium-python:2-python-3.9
```

</div>

<div class="deprecation removal-150">

### Deprecate Geo Admin UI Routes

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

In GitLab 13.0, we introduced new project and design replication details routes in the Geo Admin UI. These routes are `/admin/geo/replication/projects` and `/admin/geo/replication/designs`. We kept the legacy routes and redirected them to the new routes. In GitLab 15.0, we will remove support for the legacy routes `/admin/geo/projects` and `/admin/geo/designs`. Please update any bookmarks or scripts that may use the legacy routes.

</div>

<div class="deprecation removal-150">

### Deprecate custom Geo:db:* Rake tasks

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

In GitLab 14.8, we are [replacing the `geo:db:*` Rake tasks with built-in tasks](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/77269/diffs) that are now possible after [switching the Geo tracking database to use Rails' 6 support of multiple databases](https://gitlab.com/groups/gitlab-org/-/epics/6458).
The following `geo:db:*` tasks will be replaced with their corresponding `db:*:geo` tasks:

- `geo:db:drop` -> `db:drop:geo`
- `geo:db:create` -> `db:create:geo`
- `geo:db:setup` -> `db:setup:geo`
- `geo:db:migrate` -> `db:migrate:geo`
- `geo:db:rollback` -> `db:rollback:geo`
- `geo:db:version` -> `db:version:geo`
- `geo:db:reset` -> `db:reset:geo`
- `geo:db:seed` -> `db:seed:geo`
- `geo:schema:load:geo` -> `db:schema:load:geo`
- `geo:db:schema:dump` -> `db:schema:dump:geo`
- `geo:db:migrate:up` -> `db:migrate:up:geo`
- `geo:db:migrate:down` -> `db:migrate:down:geo`
- `geo:db:migrate:redo` -> `db:migrate:redo:geo`
- `geo:db:migrate:status` -> `db:migrate:status:geo`
- `geo:db:test:prepare` -> `db:test:prepare:geo`
- `geo:db:test:load` -> `db:test:load:geo`
- `geo:db:test:purge` -> `db:test:purge:geo`

</div>

<div class="deprecation removal-150 breaking-change">

### Deprecate feature flag PUSH_RULES_SUPERSEDE_CODE_OWNERS

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The feature flag `PUSH_RULES_SUPERSEDE_CODE_OWNERS` is being removed in GitLab 15.0. Upon its removal, push rules will supersede CODEOWNERS. The CODEOWNERS feature will no longer be available for access control.

</div>

<div class="deprecation removal-150 breaking-change">

### Deprecate legacy Gitaly configuration methods

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Using environment variables `GIT_CONFIG_SYSTEM` and `GIT_CONFIG_GLOBAL` to configure Gitaly is [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/352609).
These variables are being replaced with standard [`config.toml` Gitaly configuration](https://docs.gitlab.com/ee/administration/gitaly/reference.html).

GitLab instances that use `GIT_CONFIG_SYSTEM` and `GIT_CONFIG_GLOBAL` to configure Gitaly should switch to configuring using
`config.toml`.

</div>

<div class="deprecation removal-150 breaking-change">

### Elasticsearch 6.8

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Elasticsearch 6.8 is deprecated in GitLab 14.8 and scheduled for removal in GitLab 15.0.
Customers using Elasticsearch 6.8 need to upgrade their Elasticsearch version to 7.x prior to upgrading to GitLab 15.0.
We recommend using the latest version of Elasticsearch 7 to benefit from all Elasticsearch improvements.

Elasticsearch 6.8 is also incompatible with Amazon OpenSearch, which we [plan to support in GitLab 15.0](https://gitlab.com/gitlab-org/gitlab/-/issues/327560).

</div>

<div class="deprecation removal-150 breaking-change">

### External status check API breaking changes

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The [external status check API](https://docs.gitlab.com/ee/api/status_checks.html) was originally implemented to
support pass-by-default requests to mark a status check as passing. Pass-by-default requests are now deprecated.
Specifically, the following are deprecated:

- Requests that do not contain the `status` field.
- Requests that have the `status` field set to `approved`.

Beginning in GitLab 15.0, status checks will only be updated to a passing state if the `status` field is both present
and set to `passed`. Requests that:

- Do not contain the `status` field will be rejected with a `422` error. For more information, see [the relevant issue](https://gitlab.com/gitlab-org/gitlab/-/issues/338827).
- Contain any value other than `passed` will cause the status check to fail. For more information, see [the relevant issue](https://gitlab.com/gitlab-org/gitlab/-/issues/339039).

To align with this change, API calls to list external status checks will also return the value of `passed` rather than
`approved` for status checks that have passed.

</div>

<div class="deprecation removal-150 breaking-change">

### GraphQL ID and GlobalID compatibility

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-04-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

We are removing a non-standard extension to our GraphQL processor, which we added for backwards compatibility. This extension modifies the validation of GraphQL queries, allowing the use of the `ID` type for arguments where it would normally be rejected.
Some arguments originally had the type `ID`. These were changed to specific
kinds of `ID`. This change may be a breaking change if you:

- Use GraphQL.
- Use the `ID` type for any argument in your query signatures.

Some field arguments still have the `ID` type. These are typically for
IID values, or namespace paths. An example is `Query.project(fullPath: ID!)`.

For a list of affected and unaffected field arguments,
see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352832).

You can test if this change affects you by validating
your queries locally, using schema data fetched from a GitLab server.
You can do this by using the GraphQL explorer tool for the relevant GitLab
instance. For example: `https://gitlab.com/-/graphql-explorer`.

For example, the following query illustrates the breaking change:

```graphql
# a query using the deprecated type of Query.issue(id:)
# WARNING: This will not work after GitLab 15.0
query($id: ID!) {
  deprecated: issue(id: $id) {
    title, description
  }
}
```

The query above will not work after GitLab 15.0 is released, because the type
of `Query.issue(id:)` is actually `IssueID!`.

Instead, you should use one of the following two forms:

```graphql
# This will continue to work
query($id: IssueID!) {
  a: issue(id: $id) {
    title, description
  }
  b: issue(id: "gid://gitlab/Issue/12345") {
    title, description
  }
}
```

This query works now, and will continue to work after GitLab 15.0.
You should convert any queries in the first form (using `ID` as a named type in the signature)
to one of the other two forms (using the correct appropriate type in the signature, or using
an inline argument expression).

</div>

<div class="deprecation removal-150 breaking-change">

### OAuth tokens without expiration

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

By default, all new applications expire access tokens after 2 hours. In GitLab 14.2 and earlier, OAuth access tokens
had no expiration. In GitLab 15.0, an expiry will be automatically generated for any existing token that does not
already have one.

You should [opt in](https://docs.gitlab.com/ee/integration/oauth_provider.html#expiring-access-tokens) to expiring
tokens before GitLab 15.0 is released:

1. Edit the application.
1. Select **Expire access tokens** to enable them. Tokens must be revoked or they don’t expire.

</div>

<div class="deprecation removal-150 breaking-change">

### Optional enforcement of PAT expiration

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The feature to disable enforcement of PAT expiration is unusual from a security perspective.
We have become concerned that this unusual feature could create unexpected behavior for users.
Unexpected behavior in a security feature is inherently dangerous, so we have decided to remove this feature.

</div>

<div class="deprecation removal-150 breaking-change">

### Optional enforcement of SSH expiration

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The feature to disable enforcement of SSH expiration is unusual from a security perspective.
We have become concerned that this unusual feature could create unexpected behavior for users.
Unexpected behavior in a security feature is inherently dangerous, so we have decided to remove this feature.

</div>

<div class="deprecation removal-150 breaking-change">

### Out-of-the-box SAST support for Java 8

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The [GitLab SAST SpotBugs analyzer](https://gitlab.com/gitlab-org/security-products/analyzers/spotbugs) scans [Java, Scala, Groovy, and Kotlin code](https://docs.gitlab.com/ee/user/application_security/sast/#supported-languages-and-frameworks) for security vulnerabilities.
For technical reasons, the analyzer must first compile the code before scanning.
Unless you use the [pre-compilation strategy](https://docs.gitlab.com/ee/user/application_security/sast/#pre-compilation), the analyzer attempts to automatically compile your project's code.

In GitLab versions prior to 15.0, the analyzer image includes Java 8 and Java 11 runtimes to facilitate compilation.

In GitLab 15.0, we will:

- Remove Java 8 from the analyzer image to reduce the size of the image.
- Add Java 17 to the analyzer image to make it easier to compile with Java 17.

If you rely on Java 8 being present in the analyzer environment, you must take action as detailed in the [deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/352549#breaking-change).

</div>

<div class="deprecation removal-150 breaking-change">

### Querying Usage Trends via the `instanceStatisticsMeasurements` GraphQL node

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `instanceStatisticsMeasurements` GraphQL node has been renamed to `usageTrendsMeasurements` in 13.10 and the old field name has been marked as deprecated. To fix the existing GraphQL queries, replace `instanceStatisticsMeasurements` with `usageTrendsMeasurements`.

</div>

<div class="deprecation removal-160 breaking-change">

### REST API Runner will not accept `status` filter values of `active` or `paused`

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-04-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The GitLab Runner REST endpoints will stop accepting `paused` or `active` as a status value in GitLab 16.0.

A runner's status will only relate to runner contact status, such as: `online`, `offline`.
Status values `paused` or `active` will no longer be accepted and will be replaced by the `paused` query parameter.

When checking for paused runners, API users are advised to specify `paused=true` as the query parameter.
When checking for active runners, specify `paused=false`.

</div>

<div class="deprecation removal-160 breaking-change">

### REST API endpoint to list group runners no longer accepts `project_type` value for `type` argument

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-04-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `GET /groups/:id/runners?type=project_type` endpoint will be removed in GitLab 16.0. The endpoint always returned an empty collection.

</div>

<div class="deprecation removal-160 breaking-change">

### REST and GraphQL API Runner usage of `active` replaced by `paused`

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-04-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Occurrences of the `active` identifier in the GitLab Runner REST and GraphQL API endpoints will be
renamed to `paused` in GitLab 16.0, namely:

- GraphQL API:
  - the `CiRunner` property;
  - the `RunnerUpdateInput` input type for the `runnerUpdate` mutation;
  - the `runners` and `Group.runners` queries.
- REST API:
  - endpoints taking or returning `active` properties, such as:
    - `GET /runners`
    - `GET /runners/all`
    - `GET /runners/:id` / `PUT /runners/:id`
    - `PUT --form "active=false" /runners/:runner_id`
    - `GET /projects/:id/runners` / `POST /projects/:id/runners`
    - `GET /groups/:id/runners`

The 16.0 release of the GitLab Runner will start using the `paused` property when registering runners, and therefore
will only be compatible with GitLab 16.0 and later. Until 16.0, GitLab will accept the deprecated `active` flag from
existing runners.

</div>

<div class="deprecation removal-150 breaking-change">

### Request profiling

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

[Request profiling](https://docs.gitlab.com/ee/administration/monitoring/performance/request_profiling.html) is deprecated in GitLab 14.8 and scheduled for removal in GitLab 15.0.

We're working on [consolidating our profiling tools](https://gitlab.com/groups/gitlab-org/-/epics/7327) and making them more easily accessible.
We [evaluated](https://gitlab.com/gitlab-org/gitlab/-/issues/350152) the use of this feature and we found that it is not widely used.
It also depends on a few third-party gems that are not actively maintained anymore, have not been updated for the latest version of Ruby, or crash frequently when profiling heavy page loads.

For more information, check the [summary section of the deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352488#deprecation-summary).

</div>

<div class="deprecation removal-150 breaking-change">

### Required pipeline configurations in Premium tier

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The [required pipeline configuration](https://docs.gitlab.com/ee/user/admin_area/settings/continuous_integration.html#required-pipeline-configuration) feature is deprecated in GitLab 14.8 for Premium customers and is scheduled for removal in GitLab 15.0. This feature is not deprecated for GitLab Ultimate customers.

This change to move the feature to GitLab's Ultimate tier is intended to help our features better align with our [pricing philosophy](https://about.gitlab.com/company/pricing/#three-tiers) as we see demand for this feature originating primarily from executives.

This change will also help GitLab remain consistent in its tiering strategy with the other related Ultimate-tier features of:
[Security policies](https://docs.gitlab.com/ee/user/application_security/policies/) and [compliance framework pipelines](https://docs.gitlab.com/ee/user/project/settings/index.html#compliance-pipeline-configuration).

</div>

<div class="deprecation removal-150 breaking-change">

### Retire-JS Dependency Scanning tool

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

As of 14.8 the retire.js job is being deprecated from Dependency Scanning. It will continue to be included in our CI/CD template while deprecated. We are removing retire.js from Dependency Scanning on May 22, 2022 in GitLab 15.0. JavaScript scanning functionality will not be affected as it is still being covered by Gemnasium.

If you have explicitly excluded retire.js using DS_EXCLUDED_ANALYZERS you will need to clean up (remove the reference) in 15.0. If you have customized your pipeline's Dependency Scanning configuration related to the `retire-js-dependency_scanning` job you will want to switch to gemnasium-dependency_scanning before the removal in 15.0, to prevent your pipeline from failing. If you have not used the DS_EXCLUDED_ANALYZERS to reference retire.js, or customized your template specifically for retire.js, you will not need to take action.

</div>

<div class="deprecation removal-154 breaking-change">

### SAST analyzer consolidation and CI/CD template changes

Planned removal: GitLab <span class="removal-milestone">15.4</span> (2022-09-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

GitLab SAST uses various [analyzers](https://docs.gitlab.com/ee/user/application_security/sast/analyzers/) to scan code for vulnerabilities.

We are reducing the number of analyzers used in GitLab SAST as part of our long-term strategy to deliver a better and more consistent user experience.
Streamlining the set of analyzers will also enable faster [iteration](https://about.gitlab.com/handbook/values/#iteration), better [results](https://about.gitlab.com/handbook/values/#results), and greater [efficiency](https://about.gitlab.com/handbook/values/#efficiency) (including a reduction in CI runner usage in most cases).

In GitLab 15.4, GitLab SAST will no longer use the following analyzers:

- [ESLint](https://gitlab.com/gitlab-org/security-products/analyzers/eslint) (JavaScript, TypeScript, React)
- [Gosec](https://gitlab.com/gitlab-org/security-products/analyzers/gosec) (Go)
- [Bandit](https://gitlab.com/gitlab-org/security-products/analyzers/bandit) (Python)

NOTE:
This change was originally planned for GitLab 15.0 and has been postponed.

These analyzers will be removed from the [GitLab-managed SAST CI/CD template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/SAST.gitlab-ci.yml) and replaced with the [Semgrep-based analyzer](https://gitlab.com/gitlab-org/security-products/analyzers/semgrep).
They will no longer receive routine updates, except for security issues.
We will not delete container images previously published for these analyzers; any such change would be announced as a [deprecation, removal, or breaking change announcement](https://about.gitlab.com/handbook/marketing/blog/release-posts/#deprecations-removals-and-breaking-changes).

We will also remove Java from the scope of the [SpotBugs](https://gitlab.com/gitlab-org/security-products/analyzers/spotbugs) analyzer and replace it with the [Semgrep-based analyzer](https://gitlab.com/gitlab-org/security-products/analyzers/semgrep).
This change will make it simpler to scan Java code; compilation will no longer be required.
This change will be reflected in the automatic language detection portion of the [GitLab-managed SAST CI/CD template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/SAST.gitlab-ci.yml). Note that the SpotBugs-based analyzer will continue to cover Groovy, Kotlin, and Scala.

If you've already dismissed a vulnerability finding from one of the deprecated analyzers, the replacement attempts to respect your previous dismissal. The system behavior depends on:

- whether you’ve excluded the Semgrep-based analyzer from running in the past.
- which analyzer first discovered the vulnerabilities shown in the project’s Vulnerability Report.

See [Vulnerability translation documentation](https://docs.gitlab.com/ee/user/application_security/sast/analyzers.html#vulnerability-translation) for further details.

If you applied customizations to any of the affected analyzers or if you currently disable the Semgrep analyzer in your pipelines, you must take action as detailed in the [deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/352554#breaking-change).

</div>

<div class="deprecation removal-150 breaking-change">

### SAST support for .NET 2.1

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The GitLab SAST Security Code Scan analyzer scans .NET code for security vulnerabilities.
For technical reasons, the analyzer must first build the code to scan it.

In GitLab versions prior to 15.0, the default analyzer image (version 2) includes support for:

- .NET 2.1
- .NET 3.0 and .NET Core 3.0
- .NET Core 3.1
- .NET 5.0

In GitLab 15.0, we will change the default major version for this analyzer from version 2 to version 3. This change:

- Adds [severity values for vulnerabilities](https://gitlab.com/gitlab-org/gitlab/-/issues/350408) along with [other new features and improvements](https://gitlab.com/gitlab-org/security-products/analyzers/security-code-scan/-/blob/master/CHANGELOG.md).
- Removes .NET 2.1 support.
- Adds support for .NET 6.0, Visual Studio 2019, and Visual Studio 2022.

Version 3 was [announced in GitLab 14.6](https://about.gitlab.com/releases/2021/12/22/gitlab-14-6-released/#sast-support-for-net-6) and made available as an optional upgrade.

If you rely on .NET 2.1 support being present in the analyzer image by default, you must take action as detailed in the [deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/352553#breaking-change).

</div>

<div class="deprecation removal-150">

### Secret Detection configuration variables deprecated

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

To make it simpler and more reliable to [customize GitLab Secret Detection](https://docs.gitlab.com/ee/user/application_security/secret_detection/#customizing-settings), we're deprecating some of the variables that you could previously set in your CI/CD configuration.

The following variables currently allow you to customize the options for historical scanning, but interact poorly with the [GitLab-managed CI/CD template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/Secret-Detection.gitlab-ci.yml) and are now deprecated:

- `SECRET_DETECTION_COMMIT_FROM`
- `SECRET_DETECTION_COMMIT_TO`
- `SECRET_DETECTION_COMMITS`
- `SECRET_DETECTION_COMMITS_FILE`

The `SECRET_DETECTION_ENTROPY_LEVEL` previously allowed you to configure rules that only considered the entropy level of strings in your codebase, and is now deprecated.
This type of entropy-only rule created an unacceptable number of incorrect results (false positives) and is no longer supported.

In GitLab 15.0, we'll update the Secret Detection [analyzer](https://docs.gitlab.com/ee/user/application_security/terminology/#analyzer) to ignore these deprecated options.
You'll still be able to configure historical scanning of your commit history by setting the [`SECRET_DETECTION_HISTORIC_SCAN` CI/CD variable](https://docs.gitlab.com/ee/user/application_security/secret_detection/#available-cicd-variables).

For further details, see [the deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/352565).

</div>

<div class="deprecation removal-150 breaking-change">

### Secure and Protect analyzer images published in new location

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

GitLab uses various [analyzers](https://docs.gitlab.com/ee/user/application_security/terminology/#analyzer) to [scan for security vulnerabilities](https://docs.gitlab.com/ee/user/application_security/).
Each analyzer is distributed as a container image.

Starting in GitLab 14.8, new versions of GitLab Secure and Protect analyzers are published to a new registry location under `registry.gitlab.com/security-products`.

We will update the default value of [GitLab-managed CI/CD templates](https://gitlab.com/gitlab-org/gitlab/-/tree/master/lib/gitlab/ci/templates/Security) to reflect this change:

- For all analyzers except Container Scanning, we will update the variable `SECURE_ANALYZERS_PREFIX` to the new image registry location.
- For Container Scanning, the default image address is already updated. There is no `SECURE_ANALYZERS_PREFIX` variable for Container Scanning.

In a future release, we will stop publishing images to `registry.gitlab.com/gitlab-org/security-products/analyzers`.
Once this happens, you must take action if you manually pull images and push them into a separate registry. This is commonly the case for [offline deployments](https://docs.gitlab.com/ee/user/application_security/offline_deployments/index.html).
Otherwise, you won't receive further updates.

See the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352564) for more details.

</div>

<div class="deprecation removal-150 breaking-change">

### Secure and Protect analyzer major version update

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The Secure and Protect stages will be bumping the major versions of their analyzers in tandem with the GitLab 15.0 release. This major bump will enable a clear delineation for analyzers, between:

- Those released prior to May 22, 2022, which generate reports that _are not_ subject to stringent schema validation.
- Those released after May 22, 2022, which generate reports that _are_ subject to stringent schema validation.

If you are not using the default inclusion templates, or have pinned your analyzer versions you will need to update your CI/CD job definition to either remove the pinned version or to update the latest major version.
Users of GitLab 12.0-14.10 will continue to experience analyzer updates as normal until the release of GitLab 15.0, following which all newly fixed bugs and newly released features in the new major versions of the analyzers will not be available in the deprecated versions because we do not backport bugs and new features as per our [maintenance policy](https://docs.gitlab.com/ee/policy/maintenance.html). As required security patches will be backported within the latest 3 minor releases.
Specifically, the following are being deprecated and will no longer be updated after 15.0 GitLab release:

- API Security: version 1
- Container Scanning: version 4
- Coverage-guided fuzz testing: version 2
- Dependency Scanning: version 2
- Dynamic Application Security Testing (DAST): version 2
- Infrastructure as Code (IaC) Scanning: version 1
- License Scanning: version 3
- Secret Detection: version 3
- Static Application Security Testing (SAST): version 2 of [all analyzers](https://docs.gitlab.com/ee/user/application_security/sast/#supported-languages-and-frameworks), except `gosec` which is currently at version 3
  - `bandit`: version 2
  - `brakeman`: version 2
  - `eslint`: version 2
  - `flawfinder`: version 2
  - `gosec`: version 3
  - `kubesec`: version 2
  - `mobsf`: version 2
  - `nodejs-scan`: version 2
  - `phpcs-security-audit`: version 2
  - `pmd-apex`: version 2
  - `security-code-scan`: version 2
  - `semgrep`: version 2
  - `sobelow`: version 2
  - `spotbugs`: version 2

</div>

<div class="deprecation removal-150 breaking-change">

### Support for gRPC-aware proxy deployed between Gitaly and rest of GitLab

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Although not recommended or documented, it was possible to deploy a gRPC-aware proxy between Gitaly and
the rest of GitLab. For example, NGINX and Envoy. The ability to deploy a gRPC-aware proxy is
[deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/352517). If you currently use a gRPC-aware proxy for
Gitaly connections, you should change your proxy configuration to use TCP or TLS proxying (OSI layer 4) instead.

Gitaly Cluster became incompatible with gRPC-aware proxies in GitLab 13.12. Now all GitLab installations will be incompatible with
gRPC-aware proxies, even without Gitaly Cluster.

By sending some of our internal RPC traffic through a custom protocol (instead of gRPC) we
increase throughput and reduce Go garbage collection latency. For more information, see
the [relevant epic](https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/463).

</div>

<div class="deprecation removal-150 breaking-change">

### Test coverage project CI/CD setting

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

To simplify setting a test coverage pattern, in GitLab 15.0 the
[project setting for test coverage parsing](https://docs.gitlab.com/ee/ci/pipelines/settings.html#add-test-coverage-results-using-project-settings-removed)
is being removed.

Instead, using the project’s `.gitlab-ci.yml`, provide a regular expression with the `coverage` keyword to set
testing coverage results in merge requests.

</div>

<div class="deprecation removal-150 breaking-change">

### Vulnerability Check

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The vulnerability check feature is deprecated in GitLab 14.8 and scheduled for removal in GitLab 15.0. We encourage you to migrate to the new security approvals feature instead. You can do so by navigating to **Security & Compliance > Policies** and creating a new Scan Result Policy.

The new security approvals feature is similar to vulnerability check. For example, both can require approvals for MRs that contain security vulnerabilities. However, security approvals improve the previous experience in several ways:

- Users can choose who is allowed to edit security approval rules. An independent security or compliance team can therefore manage rules in a way that prevents development project maintainers from modifying the rules.
- Multiple rules can be created and chained together to allow for filtering on different severity thresholds for each scanner type.
- A two-step approval process can be enforced for any desired changes to security approval rules.
- A single set of security policies can be applied to multiple development projects to allow for ease in maintaining a single, centralized ruleset.

</div>

<div class="deprecation removal-160 breaking-change">

### `CI_BUILD_*` predefined variables

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-04-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The predefined CI/CD variables that start with `CI_BUILD_*` were deprecated in GitLab 9.0, and will be removed in GitLab 16.0. If you still use these variables, be sure to change to the replacement [predefined variables](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html) which are functionally identical:

| Removed variable      | Replacement variable    |
| --------------------- |------------------------ |
| `CI_BUILD_BEFORE_SHA` | `CI_COMMIT_BEFORE_SHA`  |
| `CI_BUILD_ID`         | `CI_JOB_ID`             |
| `CI_BUILD_MANUAL`     | `CI_JOB_MANUAL`         |
| `CI_BUILD_NAME`       | `CI_JOB_NAME`           |
| `CI_BUILD_REF`        | `CI_COMMIT_SHA`         |
| `CI_BUILD_REF_NAME`   | `CI_COMMIT_REF_NAME`    |
| `CI_BUILD_REF_SLUG`   | `CI_COMMIT_REF_SLUG`    |
| `CI_BUILD_REPO`       | `CI_REPOSITORY_URL`     |
| `CI_BUILD_STAGE`      | `CI_JOB_STAGE`          |
| `CI_BUILD_TAG`        | `CI_COMMIT_TAG`         |
| `CI_BUILD_TOKEN`      | `CI_JOB_TOKEN`          |
| `CI_BUILD_TRIGGERED`  | `CI_PIPELINE_TRIGGERED` |

</div>

<div class="deprecation removal-150 breaking-change">

### `projectFingerprint` in `PipelineSecurityReportFinding` GraphQL

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `projectFingerprint` field in the [PipelineSecurityReportFinding](https://docs.gitlab.com/ee/api/graphql/reference/index.html#pipelinesecurityreportfinding)
GraphQL object is being deprecated. This field contains a "fingerprint" of security findings used to determine uniqueness.
The method for calculating fingerprints has changed, resulting in different values. Going forward, the new values will be
exposed in the UUID field. Data previously available in the projectFingerprint field will eventually be removed entirely.

</div>

<div class="deprecation removal-150 breaking-change">

### `started` iterations API field

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `started` field in the [iterations API](https://docs.gitlab.com/ee/api/iterations.html#list-project-iterations) is being deprecated and will be removed in GitLab 15.0. This field is being replaced with the `current` field (already available) which aligns with the naming for other time-based entities, such as milestones.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.7

<div class="deprecation removal-150">

### Container scanning schemas below 14.0.0

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

[Container scanning report schemas](https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/releases)
versions earlier than 14.0.0 will no longer be supported in GitLab 15.0. Reports that do not pass validation
against the schema version declared in the report will also no longer be supported in GitLab 15.0.

Third-party tools that [integrate with GitLab by outputting a container scanning security report](https://docs.gitlab.com/ee/development/integrations/secure.html#report)
as a pipeline job artifact are affected. You must ensure that all output reports adhere to the correct schema with a minimum version of 14.0.0. Reports with a lower version or that fail to validate against the declared schema version will not be processed, and vulnerability findings will not display in MRs, pipelines, or Vulnerability Reports.

To help with the transition, from GitLab 14.10, non-compliant reports will display a
[warning](https://gitlab.com/gitlab-org/gitlab/-/issues/335789#note_672853791)
in the Vulnerability Report.

</div>

<div class="deprecation removal-150">

### Coverage guided fuzzing schemas below 14.0.0

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

[Coverage guided fuzzing report schemas](https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/releases)
below version 14.0.0 will no longer be supported in GitLab 15.0. Reports that do not pass validation
against the schema version declared in the report will also no longer be supported in GitLab 15.0.

Third-party tools that [integrate with GitLab by outputting a coverage guided fuzzing security report](https://docs.gitlab.com/ee/development/integrations/secure.html#report)
as a pipeline job artifact are affected. You must ensure that all output reports adhere to the correct
schema with a minimum version of 14.0.0. Any reports with a lower version or that fail to validate
against the declared schema version will not be processed, and vulnerability
findings will not display in MRs, pipelines, or Vulnerability Reports.

To help with the transition, from GitLab 14.10, non-compliant reports will display a
[warning](https://gitlab.com/gitlab-org/gitlab/-/issues/335789#note_672853791)
in the Vulnerability Report.

</div>

<div class="deprecation removal-150">

### DAST schemas below 14.0.0

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

[DAST report schemas](https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/releases)
versions earlier than 14.0.0 will no longer be supported in GitLab 15.0. Reports that do not pass validation
against the schema version declared in the report will also no longer be supported as of GitLab 15.0.

Third-party tools that [integrate with GitLab by outputting a DAST security report](https://docs.gitlab.com/ee/development/integrations/secure.html#report)
as a pipeline job artifact are affected. You must ensure that all output reports adhere to the correct
schema with a minimum version of 14.0.0. Reports with a lower version or that fail to validate
against the declared schema version will not be processed, and vulnerability
findings will not display in MRs, pipelines, or Vulnerability Reports.

To help with the transition, from GitLab 14.10, non-compliant reports will cause a
[warning to be displayed](https://gitlab.com/gitlab-org/gitlab/-/issues/335789#note_672853791)
in the Vulnerability Report.

</div>

<div class="deprecation removal-150">

### Dependency scanning schemas below 14.0.0

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

[Dependency scanning report schemas](https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/releases)
versions earlier than 14.0.0 will no longer be supported in GitLab 15.0. Reports that do not pass validation
against the schema version declared in the report will also no longer be supported as of GitLab 15.0.

Third-party tools that [integrate with GitLab by outputting a Dependency scanning security report](https://docs.gitlab.com/ee/development/integrations/secure.html#report)
as a pipeline job artifact are affected. You must ensure that all output reports adhere to the correct
schema with a minimum version of 14.0.0. Reports with a lower version or that fail to validate
against the declared schema version will not be processed, and vulnerability
findings will not display in MRs, pipelines, or Vulnerability Reports.

To help with the transition, from GitLab 14.10, non-compliant reports will cause a
[warning to be displayed](https://gitlab.com/gitlab-org/gitlab/-/issues/335789#note_672853791)
in the Vulnerability Report.

</div>

<div class="deprecation removal-150">

### Enforced validation of security report schemas

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

[Security report schemas](https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/releases)
versions earlier than 14.0.0 will no longer be supported in GitLab 15.0. Reports that do not pass validation
against the schema version declared in the report will also no longer be supported in GitLab 15.0.

Security tools that [integrate with GitLab by outputting security reports](https://docs.gitlab.com/ee/development/integrations/secure.html#report)
as pipeline job artifacts are affected. You must ensure that all output reports adhere to the correct
schema with a minimum version of 14.0.0. Reports with a lower version or that fail to validate
against the declared schema version will not be processed, and vulnerability
findings will not display in MRs, pipelines, or Vulnerability Reports.

To help with the transition, from GitLab 14.10, non-compliant reports will display a
[warning](https://gitlab.com/gitlab-org/gitlab/-/issues/335789#note_672853791)
in the Vulnerability Report.

</div>

<div class="deprecation removal-150">

### Godep support in License Compliance

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

The Godep dependency manager for Golang was deprecated in 2020 by Go and
has been replaced with Go modules.
To reduce our maintenance cost we are deprecating License Compliance for Godep projects as of 14.7
and will remove it in GitLab 15.0

</div>

<div class="deprecation removal-150 breaking-change">

### Logging in GitLab

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The logging features in GitLab allow users to install the ELK stack (Elasticsearch, Logstash, and Kibana) to aggregate and manage application logs. Users can search for relevant logs in GitLab. However, since deprecating certificate-based integration with Kubernetes clusters and GitLab Managed Apps, we don't have a recommended solution for logging within GitLab. For more information, you can follow the issue for [integrating Opstrace with GitLab](https://gitlab.com/groups/gitlab-org/-/epics/6976).

</div>

<div class="deprecation removal-160 breaking-change">

### Monitor performance metrics through Prometheus

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

By displaying data stored in a Prometheus instance, GitLab allows users to view performance metrics. GitLab also displays visualizations of these metrics in dashboards. The user can connect to a previously-configured external Prometheus instance, or set up Prometheus as a GitLab Managed App.
However, since certificate-based integration with Kubernetes clusters is deprecated in GitLab, the metrics functionality in GitLab that relies on Prometheus is also deprecated. This includes the metrics visualizations in dashboards. GitLab is working to develop a single user experience based on [Opstrace](https://about.gitlab.com/press/releases/2021-12-14-gitlab-acquires-opstrace-to-expand-its-devops-platform-with-open-source-observability-solution.html). An [issue exists](https://gitlab.com/groups/gitlab-org/-/epics/6976) for you to follow work on the Opstrace integration.

</div>

<div class="deprecation removal-150">

### Pseudonymizer

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

The Pseudonymizer feature is generally unused,
can cause production issues with large databases,
and can interfere with object storage development.
It is now considered deprecated, and will be removed in GitLab 15.0.

</div>

<div class="deprecation removal-150">

### SAST schemas below 14.0.0

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

[SAST report schemas](https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/releases)
versions earlier than 14.0.0 will no longer be supported in GitLab 15.0. Reports that do not pass validation
against the schema version declared in the report will also no longer be supported as of GitLab 15.0.

Third-party tools that [integrate with GitLab by outputting a SAST security report](https://docs.gitlab.com/ee/development/integrations/secure.html#report)
as a pipeline job artifact are affected. You must ensure that all output reports adhere to the correct
schema with a minimum version of 14.0.0. Reports with a lower version or that fail to validate
against the declared schema version will not be processed, and vulnerability
findings will not display in MRs, pipelines, or Vulnerability Reports.

To help with the transition, from GitLab 14.10, non-compliant reports will display a
[warning](https://gitlab.com/gitlab-org/gitlab/-/issues/335789#note_672853791)
in the Vulnerability Report.

</div>

<div class="deprecation removal-150">

### Secret detection schemas below 14.0.0

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

[Secret detection report schemas](https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/releases)
versions earlier than 14.0.0 will no longer be supported in GitLab 15.0. Reports that do not pass validation
against the schema version declared in the report will also no longer be supported as of GitLab 15.0.

Third-party tools that [integrate with GitLab by outputting a Secret detection security report](https://docs.gitlab.com/ee/development/integrations/secure.html#report)
as a pipeline job artifact are affected. You must ensure that all output reports adhere to the correct
schema with a minimum version of 14.0.0. Reports with a lower version or that fail to validate
against the declared schema version will not be processed, and vulnerability
findings will not display in MRs, pipelines, or Vulnerability Reports.

To help with the transition, from GitLab 14.10, non-compliant reports will display a
[warning](https://gitlab.com/gitlab-org/gitlab/-/issues/335789#note_672853791)
in the Vulnerability Report.

</div>

<div class="deprecation removal-150 breaking-change">

### Sidekiq metrics and health checks configuration

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Exporting Sidekiq metrics and health checks using a single process and port is deprecated.
Support will be removed in 15.0.

We have updated Sidekiq to export [metrics and health checks from two separate processes](https://gitlab.com/groups/gitlab-org/-/epics/6409)
to improve stability and availability and prevent data loss in edge cases.
As those are two separate servers, a configuration change will be required in 15.0
to explicitly set separate ports for metrics and health-checks.
The newly introduced settings for `sidekiq['health_checks_*']`
should always be set in `gitlab.rb`.
For more information, check the documentation for [configuring Sidekiq](https://docs.gitlab.com/ee/administration/sidekiq.html).

These changes also require updates in either Prometheus to scrape the new endpoint or k8s health-checks to target the new
health-check port to work properly, otherwise either metrics or health-checks will disappear.

For the deprecation period those settings are optional
and GitLab will default the Sidekiq health-checks port to the same port as `sidekiq_exporter`
and only run one server (not changing the current behaviour).
Only if they are both set and a different port is provided, a separate metrics server will spin up
to serve the Sidekiq metrics, similar to the way Sidekiq will behave in 15.0.

</div>

<div class="deprecation removal-150">

### Static Site Editor

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

The Static Site Editor will no longer be available starting in GitLab 15.0. Improvements to the Markdown editing experience across GitLab will deliver smiliar benefit but with a wider reach. Incoming requests to the Static Site Editor will be redirected to the [Web IDE](https://docs.gitlab.com/ee/user/project/web_ide/index.html).

Current users of the Static Site Editor can view the [documentation](https://docs.gitlab.com/ee/user/project/static_site_editor/) for more information, including how to remove the configuration files from existing projects.

</div>

<div class="deprecation removal-150 breaking-change">

### Tracing in GitLab

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Tracing in GitLab is an integration with Jaeger, an open-source end-to-end distributed tracing system. GitLab users can navigate to their Jaeger instance to gain insight into the performance of a deployed application, tracking each function or microservice that handles a given request. Tracing in GitLab is deprecated in GitLab 14.7, and scheduled for removal in 15.0. To track work on a possible replacement, see the issue for [Opstrace integration with GitLab](https://gitlab.com/groups/gitlab-org/-/epics/6976).

</div>

<div class="deprecation removal-150">

### `artifacts:reports:cobertura` keyword

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

Currently, test coverage visualizations in GitLab only support Cobertura reports. Starting 15.0, the
`artifacts:reports:cobertura` keyword will be replaced by
[`artifacts:reports:coverage_report`](https://gitlab.com/gitlab-org/gitlab/-/issues/344533). Cobertura will be the
only supported report file in 15.0, but this is the first step towards GitLab supporting other report types.

</div>

<div class="deprecation removal-150 breaking-change">

### merged_by API field

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `merged_by` field in the [merge request API](https://docs.gitlab.com/ee/api/merge_requests.html#list-merge-requests) is being deprecated and will be removed in GitLab 15.0. This field is being replaced with the `merge_user` field (already present in GraphQL) which more correctly identifies who merged a merge request when performing actions (merge when pipeline succeeds, add to merge train) other than a simple merge.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.6

<div class="deprecation removal-150 breaking-change">

### CI/CD job name length limit

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

In GitLab 15.0 we are going to limit the number of characters in CI/CD job names to 255. Any pipeline with job names that exceed the 255 character limit will stop working after the 15.0 release.

</div>

<div class="deprecation removal-150 breaking-change">

### Legacy approval status names from License Compliance API

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

We deprecated legacy names for approval status of license policy (blacklisted, approved) in the `managed_licenses` API but they are still used in our API queries and responses. They will be removed in 15.0.

If you are using our License Compliance API you should stop using the `approved` and `blacklisted` query parameters, they are now `allowed` and `denied`. In 15.0 the responses will also stop using `approved` and `blacklisted` so you need to adjust any of your custom tools to use the old and new values so they do not break with the 15.0 release.

</div>

<div class="deprecation removal-150 breaking-change">

### `type` and `types` keyword in CI/CD configuration

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `type` and `types` CI/CD keywords will be removed in GitLab 15.0. Pipelines that use these keywords will stop working, so you must switch to `stage` and `stages`, which have the same behavior.

</div>

<div class="deprecation removal-150 breaking-change">

### apiFuzzingCiConfigurationCreate GraphQL mutation

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The API Fuzzing configuration snippet is now being generated client-side and does not require an
API request anymore. We are therefore deprecating the `apiFuzzingCiConfigurationCreate` mutation
which isn't being used in GitLab anymore.

</div>

<div class="deprecation removal-150 breaking-change">

### bundler-audit Dependency Scanning tool

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

As of 14.6 bundler-audit is being deprecated from Dependency Scanning. It will continue to be in our CI/CD template while deprecated. We are removing bundler-audit from Dependency Scanning on May 22, 2022 in 15.0. After this removal Ruby scanning functionality will not be affected as it is still being covered by Gemnasium.

If you have explicitly excluded bundler-audit using DS_EXCLUDED_ANALYZERS you will need to clean up (remove the reference) in 15.0. If you have customized your pipeline's Dependency Scanning configuration, for example to edit the `bundler-audit-dependency_scanning` job, you will want to switch to gemnasium-dependency_scanning before removal in 15.0, to prevent your pipeline from failing. If you have not used the DS_EXCLUDED_ANALYZERS to reference bundler-audit, or customized your template specifically for bundler-audit, you will not need to take action.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.5

<div class="deprecation removal-150 breaking-change">

### Changing an instance (shared) runner to a project (specific) runner

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

In GitLab 15.0, you can no longer change an instance (shared) runner to a project (specific) runner.

Users often accidentally change instance runners to project runners, and they're unable to change them back. GitLab does not allow you to change a project runner to a shared runner because of the security implications. A runner meant for one project could be set to run jobs for an entire instance.

Administrators who need to add runners for multiple projects can register a runner for one project, then go to the Admin view and choose additional projects.

</div>

<div class="deprecation removal-150 breaking-change">

### Known host required for GitLab Runner SSH executor

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

In [GitLab 14.3](https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/3074), we added a configuration setting in the GitLab Runner `config.toml` file. This setting, [`[runners.ssh.disable_strict_host_key_checking]`](https://docs.gitlab.com/runner/executors/ssh.html#security), controls whether or not to use strict host key checking with the SSH executor.

In GitLab 15.0 and later, the default value for this configuration option will change from `true` to `false`. This means that strict host key checking will be enforced when using the GitLab Runner SSH executor.

</div>

<div class="deprecation removal-160 breaking-change">

### Package pipelines in API payload is paginated

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

A request to the API for `/api/v4/projects/:id/packages` returns a paginated result of packages. Each package lists all of its pipelines in this response. This is a performance concern, as it's possible for a package to have hundreds or thousands of associated pipelines.

In milestone 16.0, we will remove the `pipelines` attribute from the API response.

</div>

<div class="deprecation removal-160 breaking-change">

### REST and GraphQL API Runner status will not return `paused`

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-04-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The GitLab Runner REST and GraphQL API endpoints will not return `paused` or `active` as a status in GitLab 16.0.

A runner's status will only relate to runner contact status, such as:
`online`, `offline`, or `not_connected`. Status `paused` or `active` will no longer appear.

When checking if a runner is `paused`, API users are advised to check the boolean attribute
`paused` to be `true` instead. When checking if a runner is `active`, check if `paused` is `false`.

</div>

<div class="deprecation removal-156 breaking-change">

### SaaS certificate-based integration with Kubernetes

Planned removal: GitLab <span class="removal-milestone">15.6</span> (2022-11-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The certificate-based integration with Kubernetes will be [deprecated and removed](https://about.gitlab.com/blog/2021/11/15/deprecating-the-cert-based-kubernetes-integration/). As a GitLab SaaS customer, on new namespaces, you will no longer be able to integrate GitLab and your cluster using the certificate-based approach as of GitLab 15.0. The integration for current users will be enabled per namespace. The integrations are expected to be switched off completely on GitLab SaaS around 2022 November 22.

For a more robust, secure, forthcoming, and reliable integration with Kubernetes, we recommend you use the
[agent for Kubernetes](https://docs.gitlab.com/ee/user/clusters/agent/) to connect Kubernetes clusters with GitLab. [How do I migrate?](https://docs.gitlab.com/ee/user/infrastructure/clusters/migrate_to_gitlab_agent.html)

For updates and details about this deprecation, follow [this epic](https://gitlab.com/groups/gitlab-org/configure/-/epics/8).

GitLab self-managed customers can still use the feature [with a feature flag](https://docs.gitlab.com/ee/update/deprecations.html#self-managed-certificate-based-integration-with-kubernetes).

</div>

<div class="deprecation removal-160 breaking-change">

### Self-managed certificate-based integration with Kubernetes

Planned removal: GitLab <span class="removal-milestone">16.0</span> (2023-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The certificate-based integration with Kubernetes [will be deprecated and removed](https://about.gitlab.com/blog/2021/11/15/deprecating-the-cert-based-kubernetes-integration/).

As a self-managed customer, we are introducing the [feature flag](../administration/feature_flags.md#enable-or-disable-the-feature) `certificate_based_clusters` in GitLab 15.0 so you can keep your certificate-based integration enabled. However, the feature flag will be disabled by default, so this change is a **breaking change**.

In GitLab 16.0 we will remove both the feature and its related code. Until the final removal in 16.0, features built on this integration will continue to work, if you enable the feature flag. Until the feature is removed, GitLab will continue to fix security and critical issues as they arise.

For a more robust, secure, forthcoming, and reliable integration with Kubernetes, we recommend you use the
[agent for Kubernetes](https://docs.gitlab.com/ee/user/clusters/agent/) to connect Kubernetes clusters with GitLab. [How do I migrate?](https://docs.gitlab.com/ee/user/infrastructure/clusters/migrate_to_gitlab_agent.html)

For updates and details about this deprecation, follow [this epic](https://gitlab.com/groups/gitlab-org/configure/-/epics/8).

</div>

<div class="deprecation removal-150 breaking-change">

### Support for SLES 12 SP2

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Long term service and support (LTSS) for SUSE Linux Enterprise Server (SLES) 12 SP2 [ended on March 31, 2021](https://www.suse.com/lifecycle/). The CA certificates on SP2 include the expired DST root certificate, and it's not getting new CA certificate package updates. We have implemented some [workarounds](https://gitlab.com/gitlab-org/gitlab-omnibus-builder/-/merge_requests/191), but we will not be able to continue to keep the build running properly.

</div>

<div class="deprecation removal-150 breaking-change">

### Update to the Container Registry group-level API

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

In milestone 15.0, support for the `tags` and `tags_count` parameters will be removed from the Container Registry API that [gets registry repositories from a group](../api/container_registry.md#within-a-group).

The `GET /groups/:id/registry/repositories` endpoint will remain, but won't return any info about tags. To get the info about tags, you can use the existing `GET /registry/repositories/:id` endpoint, which will continue to support the `tags` and `tag_count` options as it does today. The latter must be called once per image repository.

</div>

<div class="deprecation removal-150 breaking-change">

### Value Stream Analytics filtering calculation change

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

We are changing how the date filter works in Value Stream Analytics. Instead of filtering by the time that the issue or merge request was created, the date filter will filter by the end event time of the given stage. This will result in completely different figures after this change has rolled out.

If you monitor Value Stream Analytics metrics and rely on the date filter, to avoid losing data, you must save the data prior to this change.

</div>

<div class="deprecation removal-150 breaking-change">

### `Versions` on base `PackageType`

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

As part of the work to create a [Package Registry GraphQL API](https://gitlab.com/groups/gitlab-org/-/epics/6318), the Package group deprecated the `Version` type for the basic `PackageType` type and moved it to [`PackageDetailsType`](https://docs.gitlab.com/ee/api/graphql/reference/index.html#packagedetailstype).

In milestone 15.0, we will completely remove `Version` from `PackageType`.

</div>

<div class="deprecation removal-150 breaking-change">

### `defaultMergeCommitMessageWithDescription` GraphQL API field

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The GraphQL API field `defaultMergeCommitMessageWithDescription` has been deprecated and will be removed in GitLab 15.0. For projects with a commit message template set, it will ignore the template.

</div>

<div class="deprecation removal-150 breaking-change">

### `dependency_proxy_for_private_groups` feature flag

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

We added a feature flag because [GitLab-#11582](https://gitlab.com/gitlab-org/gitlab/-/issues/11582) changed how public groups use the Dependency Proxy. Prior to this change, you could use the Dependency Proxy without authentication. The change requires authentication to use the Dependency Proxy.

In milestone 15.0, we will remove the feature flag entirely. Moving forward, you must authenticate when using the Dependency Proxy.

</div>

<div class="deprecation removal-150 breaking-change">

### `pipelines` field from the `version` field

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

In GraphQL, there are two `pipelines` fields that you can use in a [`PackageDetailsType`](https://docs.gitlab.com/ee/api/graphql/reference/#packagedetailstype) to get the pipelines for package versions:

- The `versions` field's `pipelines` field. This returns all the pipelines associated with all the package's versions, which can pull an unbounded number of objects in memory and create performance concerns.
- The `pipelines` field of a specific `version`. This returns only the pipelines associated with that single package version.

To mitigate possible performance problems, we will remove the `versions` field's `pipelines` field in milestone 15.0. Although you will no longer be able to get all pipelines for all versions of a package, you can still get the pipelines of a single version through the remaining `pipelines` field for that version.

</div>

<div class="deprecation removal-150 breaking-change">

### `promote-db` command from `gitlab-ctl`

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

In GitLab 14.5, we introduced the command `gitlab-ctl promote` to promote any Geo secondary node to a primary during a failover. This command replaces `gitlab-ctl promote-db` which is used to promote database nodes in multi-node Geo secondary sites. `gitlab-ctl promote-db` will continue to function as-is and be available until GitLab 15.0. We recommend that Geo customers begin testing the new `gitlab-ctl promote` command in their staging environments and incorporating the new command in their failover procedures.

</div>

<div class="deprecation removal-150 breaking-change">

### `promote-to-primary-node` command from `gitlab-ctl`

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

In GitLab 14.5, we introduced the command `gitlab-ctl promote` to promote any Geo secondary node to a primary during a failover. This command replaces `gitlab-ctl promote-to-primary-node` which was only usable for single-node Geo sites. `gitlab-ctl promote-to-primary-node` will continue to function as-is and be available until GitLab 15.0. We recommend that Geo customers begin testing the new `gitlab-ctl promote` command in their staging environments and incorporating the new command in their failover procedures.

</div>

<div class="deprecation removal-148">

### openSUSE Leap 15.2 packages

Planned removal: GitLab <span class="removal-milestone">14.8</span> (2022-02-22)

Distribution support and security updates for openSUSE Leap 15.2 are [ending December 2021](https://en.opensuse.org/Lifetime#openSUSE_Leap).

Starting in 14.5 we are providing packages for openSUSE Leap 15.3, and will stop providing packages for openSUSE Leap 15.2 in the 14.8 milestone.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.3

<div class="deprecation removal-150 breaking-change">

### Audit events for repository push events

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

Audit events for [repository events](https://docs.gitlab.com/ee/administration/audit_events.html#removed-events) are now deprecated and will be removed in GitLab 15.0.

These events have always been disabled by default and had to be manually enabled with a
feature flag. Enabling them can cause too many events to be generated which can
dramatically slow down GitLab instances. For this reason, they are being removed.

</div>

<div class="deprecation removal-150 breaking-change">

### GitLab Serverless

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

[GitLab Serverless](https://docs.gitlab.com/ee/user/project/clusters/serverless/) is a feature set to support Knative-based serverless development with automatic deployments and monitoring.

We decided to remove the GitLab Serverless features as they never really resonated with our users. Besides, given the continuous development of Kubernetes and Knative, our current implementations do not even work with recent versions.

</div>

<div class="deprecation removal-150 breaking-change">

### Legacy database configuration

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The syntax of [GitLabs database](https://docs.gitlab.com/omnibus/settings/database.html)
configuration located in `database.yml` is changing and the legacy format is deprecated. The legacy format
supported using a single PostgreSQL adapter, whereas the new format is changing to support multiple databases. The `main:` database needs to be defined as a first configuration item.

This deprecation mainly impacts users compiling GitLab from source because Omnibus will handle this configuration automatically.

</div>

<div class="deprecation removal-150 breaking-change">

### OmniAuth Kerberos gem

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The `omniauth-kerberos` gem will be removed in our next major release, GitLab 15.0.

This gem has not been maintained and has very little usage. We therefore plan to remove support for this authentication method and recommend using the Kerberos [SPNEGO](https://en.wikipedia.org/wiki/SPNEGO) integration instead. You can follow the [upgrade instructions](https://docs.gitlab.com/ee/integration/kerberos.html#upgrading-from-password-based-to-ticket-based-kerberos-sign-ins) to upgrade from the `omniauth-kerberos` integration to the supported one.

Note that we are not deprecating the Kerberos SPNEGO integration, only the old password-based Kerberos integration.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.2

<div class="deprecation removal-146">

### Release CLI distributed as a generic package

Planned removal: GitLab <span class="removal-milestone">14.6</span> (2021-12-22)

The [release-cli](https://gitlab.com/gitlab-org/release-cli) will be released as a [generic package](https://gitlab.com/gitlab-org/release-cli/-/packages) starting in GitLab 14.2. We will continue to deploy it as a binary to S3 until GitLab 14.5 and stop distributing it in S3 in GitLab 14.6.

</div>

<div class="deprecation removal-145">

### Rename Task Runner pod to Toolbox

Planned removal: GitLab <span class="removal-milestone">14.5</span> (2021-11-22)

The Task Runner pod is used to execute periodic housekeeping tasks within the GitLab application and is often confused with the GitLab Runner. Thus, [Task Runner will be renamed to Toolbox](https://gitlab.com/groups/gitlab-org/charts/-/epics/25).

This will result in the rename of the sub-chart: `gitlab/task-runner` to `gitlab/toolbox`. Resulting pods will be named along the lines of `{{ .Release.Name }}-toolbox`, which will often be `gitlab-toolbox`. They will be locatable with the label `app=toolbox`.

</div>
</div>

<div class="announcement-milestone">

## Announced in 14.0

<div class="deprecation removal-156">

### NFS for Git repository storage

Planned removal: GitLab <span class="removal-milestone">15.6</span> (2022-11-22)

With the general availability of Gitaly Cluster ([introduced in GitLab 13.0](https://about.gitlab.com/releases/2020/05/22/gitlab-13-0-released/)), we have deprecated development (bugfixes, performance improvements, etc) for NFS for Git repository storage in GitLab 14.0. We will continue to provide technical support for NFS for Git repositories throughout 14.x, but we will remove all support for NFS on November 22, 2022. This was originally planned for May 22, 2022, but in an effort to allow continued maturity of Gitaly Cluster, we have chosen to extend our deprecation of support date. Please see our official [Statement of Support](https://about.gitlab.com/support/statement-of-support.html#gitaly-and-nfs) for further information.

Gitaly Cluster offers tremendous benefits for our customers such as:

- [Variable replication factors](https://docs.gitlab.com/ee/administration/gitaly/index.html#replication-factor).
- [Strong consistency](https://docs.gitlab.com/ee/administration/gitaly/index.html#strong-consistency).
- [Distributed read capabilities](https://docs.gitlab.com/ee/administration/gitaly/index.html#distributed-reads).

We encourage customers currently using NFS for Git repositories to plan their migration by reviewing our documentation on [migrating to Gitaly Cluster](https://docs.gitlab.com/ee/administration/gitaly/index.html#migrate-to-gitaly-cluster).

</div>

<div class="deprecation removal-150 breaking-change">

### OAuth implicit grant

Planned removal: GitLab <span class="removal-milestone">15.0</span> (2022-05-22)

WARNING:
This is a [breaking change](https://docs.gitlab.com/ee/development/contributing/#breaking-changes).
Review the details carefully before upgrading.

The OAuth implicit grant authorization flow will be removed in our next major release, GitLab 15.0. Any applications that use OAuth implicit grant should switch to alternative [supported OAuth flows](https://docs.gitlab.com/ee/api/oauth2.html).

</div>
</div>
