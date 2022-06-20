---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
comments: false
description: 'Learn how to use and administer GitLab, the most scalable Git-based fully integrated platform for software development.'
---

<!-- markdownlint-disable MD044 -->
<!-- MD044/proper-names test disabled after this line to make page compatible with markdownlint-cli 0.29.0. -->
<!-- See https://docs.gitlab.com/ee/development/documentation/testing.html#disable-markdownlint-tests -->

<div class="d-none">
  <h3>Visit <a href="https://docs.gitlab.com/ee/">docs.gitlab.com</a> for the latest version
  of this help information with enhanced navigation, discoverability, and readability.</h3>
</div>
<!-- the div above will not display on the docs site but will display on /help -->

<!-- markdownlint-enable MD044 -->

# GitLab Docs

Welcome to [GitLab](https://about.gitlab.com/) documentation.

Here you can access the complete documentation for GitLab, the single application for the
[entire DevOps lifecycle](#the-entire-devops-lifecycle).

## Overview

No matter how you use GitLab, we have documentation for you.

| Essential documentation | Essential documentation |
|:------------------------|:------------------------|
| [**User documentation**](user/index.md)<br>Discover features and concepts for GitLab users.                          | [**Administrator documentation**](administration/index.md)<br/>Everything GitLab self-managed administrators need to know. |
| [**Contributing to GitLab**](#contributing-to-gitlab)<br/>At GitLab, everyone can contribute!                        | [**New to Git and GitLab?**](tutorials/index.md)<br/>We have the resources to get you started. |
| [**Build an integration with GitLab**](#build-an-integration-with-gitlab)<br/>Consult our integration documentation. | [**Coming to GitLab from another platform?**](#coming-to-gitlab-from-another-platform)<br/>Consult our guides. |
| [**Install GitLab**](https://about.gitlab.com/install/)<br/>Installation options for different platforms.            | [**Customers**](subscriptions/index.md)<br/>Information for new and existing customers. |
| [**Update GitLab**](update/index.md)<br/>Update your GitLab self-managed instance to the latest version.            | [**Reference Architectures**](administration/reference_architectures/index.md)<br/>GitLab reference architectures. |
| [**GitLab releases**](https://about.gitlab.com/releases/)<br/>What's new in GitLab.                                  |  |

## Popular topics

Have a look at some of our most popular topics:

| Popular topic                                                                              | Description |
|:-------------------------------------------------------------------------------------------|:------------|
| [Two-factor authentication](user/profile/account/two_factor_authentication.md)             | Improve the security of your GitLab account. |
| [GitLab groups](user/group/index.md)                                                       | Manage projects together. |
| [Keyword reference for the `.gitlab-ci.yml` file](ci/yaml/index.md)                        | Available configuration options for `.gitlab-ci.yml` files. |
| [Activate GitLab EE with a license](user/admin_area/license.md)                            | Activate GitLab Enterprise Edition functionality with a license. |
| [Back up and restore GitLab](raketasks/backup_restore.md)                                  | Rake tasks for backing up and restoring GitLab self-managed instances. |
| [GitLab release and maintenance policy](policy/maintenance.md)                             | Policies for version naming and cadence, and also upgrade recommendations. |
| [Elasticsearch integration](integration/elasticsearch.md)                                  | Integrate Elasticsearch with GitLab to enable advanced searching. |
| [Omnibus GitLab database settings](https://docs.gitlab.com/omnibus/settings/database.html) | Database settings for Omnibus GitLab self-managed instances. |
| [Omnibus GitLab NGINX settings](https://docs.gitlab.com/omnibus/settings/nginx.html)       | NGINX settings for Omnibus GitLab self-managed instances. |
| [Omnibus GitLab SSL configuration](https://docs.gitlab.com/omnibus/settings/ssl.html)      | SSL settings for Omnibus GitLab self-managed instances. |
| [GitLab.com settings](user/gitlab_com/index.md)                                            | Settings used for GitLab.com. |

## The entire DevOps lifecycle

GitLab is the first single application for software development, security,
and operations that enables [Concurrent DevOps](https://about.gitlab.com/topics/concurrent-devops/).
GitLab makes the software lifecycle faster and radically improves the speed of business.

GitLab provides solutions for [each of the stages of the DevOps lifecycle](https://about.gitlab.com/stages-devops-lifecycle/).

### User account

Learn more about GitLab account management:

| Topic                                                      | Description |
|:-----------------------------------------------------------|:------------|
| [User account](user/profile/index.md)                      | Manage your account. |
| [Authentication](topics/authentication/index.md)           | Account security with two-factor authentication, set up your SSH keys, and deploy keys for secure access to your projects. |
| [User settings](user/profile/index.md#access-your-user-settings) | Manage your user settings, two factor authentication, and more. |
| [User permissions](user/permissions.md)                    | Learn what each role in a project can do. |

## Coming to GitLab from another platform

If you are coming to GitLab from another platform, the following information is useful:

| Topic                                               | Description |
|:----------------------------------------------------|:------------|
| [Importing to GitLab](user/project/import/index.md) | Import your projects from GitHub, Bitbucket, GitLab.com, FogBugz, and SVN into GitLab. |
| [Migrating from SVN](user/project/import/svn.md)    | Convert a SVN repository to Git and GitLab. |

## Build an integration with GitLab

There are many ways to integrate with GitLab, including:

| Topic                                      | Description |
|:-------------------------------------------|:------------|
| [GitLab REST API](api/index.md)           | Integrate with GitLab using our REST API. |
| [GitLab GraphQL API](api/graphql/index.md) | Integrate with GitLab using our GraphQL API. |
| [Integrations](integration/index.md)      | Integrations with third-party products. |

## Contributing to GitLab

GitLab Community Edition is [open source](https://gitlab.com/gitlab-org/gitlab-foss/)
and GitLab Enterprise Edition is [open-core](https://gitlab.com/gitlab-org/gitlab/).

Learn how to contribute to GitLab with the following resources:

| Topic                                                       | Description |
|:------------------------------------------------------------|:------------|
| [Development](development/index.md)                        | How to contribute to GitLab development. |
| [Legal](legal/index.md)                                    | Contributor license agreements. |
| [Writing documentation](development/documentation/index.md) | How to contribute to GitLab Docs. |
