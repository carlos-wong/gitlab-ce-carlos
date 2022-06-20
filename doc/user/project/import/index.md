---
type: reference, howto
stage: Manage
group: Import
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Migrate projects to a GitLab instance **(FREE)**

See these documents to migrate to GitLab:

- [From Bitbucket Cloud](bitbucket.md)
- [From Bitbucket Server (also known as Stash)](bitbucket_server.md)
- [From ClearCase](clearcase.md)
- [From CVS](cvs.md)
- [From FogBugz](fogbugz.md)
- [From GitHub.com or GitHub Enterprise](github.md)
- [From GitLab.com](gitlab_com.md)
- [From Gitea](gitea.md)
- [From Perforce](perforce.md)
- [From SVN](svn.md)
- [From TFVC](tfvc.md)
- [From repository by URL](repo_by_url.md)
- [By uploading a manifest file (AOSP)](manifest.md)
- [From Phabricator](phabricator.md)
- [From Jira (issues only)](jira.md)

You can also import any Git repository through HTTP from the **New Project** page. Note that if the
repository is too large, the import can timeout.

You can also [connect your external repository to get CI/CD benefits](../../../ci/ci_cd_for_external_repos/index.md).

## Project import history

You can view all project imports created by you. This list includes the following:

- Source (without credentials for security reasons)
- Destination
- Status
- Error details if the import failed

To view project import history:

1. Sign in to GitLab.
1. On the top bar, select **New** (**{plus}**).
1. Select **New project/repository**.
1. Select **Import project**.
1. Select **History**.

![Project import history page](img/gitlab_import_history_page_v14_10.png)

The history also includes projects created from [built-in](../working_with_projects.md#create-a-project-from-a-built-in-template)
or [custom](../working_with_projects.md#create-a-project-from-a-built-in-template)
templates. GitLab uses [import repository by URL](repo_by_url.md)
to create a new project from a template.

## LFS authentication

When importing a project that contains LFS objects, if the project has an [`.lfsconfig`](https://github.com/git-lfs/git-lfs/blob/master/docs/man/git-lfs-config.5.ronn)
file with a URL host (`lfs.url`) different from the repository URL host, LFS files are not downloaded.

## Migrate from self-managed GitLab to GitLab.com

If you only need to migrate Git repositories, you can [import each project by URL](repo_by_url.md).
However, you can't import issues and merge requests this way. To retain all metadata like issues and
merge requests, use the [import/export feature](../settings/import_export.md)
to export projects from self-managed GitLab and import those projects into GitLab.com. All GitLab
user associations (such as comment author) are changed to the user importing the project. For more
information, see the prerequisites and important notes in these sections:

- [Export a project and its data](../settings/import_export.md#export-a-project-and-its-data).
- [Import the project](../settings/import_export.md#import-a-project-and-its-data).

NOTE:
When migrating to GitLab.com, you must create users manually unless [SCIM](../../../user/group/saml_sso/scim_setup.md)
will be used. Creating users with the API is limited to self-managed instances as it requires
administrator access.

To migrate all data from self-managed to GitLab.com, you can leverage the [API](../../../api/index.md).
Migrate the assets in this order:

1. [Groups](../../../api/groups.md)
1. [Projects](../../../api/projects.md)
1. [Project variables](../../../api/project_level_variables.md)

Keep in mind the limitations of the [import/export feature](../settings/import_export.md#items-that-are-exported).

You must still migrate your [Container Registry](../../packages/container_registry/)
over a series of Docker pulls and pushes. Re-run any CI pipelines to retrieve any build artifacts.

## Migrate from GitLab.com to self-managed GitLab

The process is essentially the same as [migrating from self-managed GitLab to GitLab.com](#migrate-from-self-managed-gitlab-to-gitlabcom).
The main difference is that an administrator can create users on the self-managed GitLab instance
through the UI or the [users API](../../../api/users.md#user-creation).

## Migrate between two self-managed GitLab instances

To migrate from an existing self-managed GitLab instance to a new self-managed GitLab instance, it's
best to [back up](../../../raketasks/backup_restore.md)
the existing instance and restore it on the new instance. For example, this is useful when migrating
a self-managed instance from an old server to a new server.

The backups produced don't depend on the operating system running GitLab. You can therefore use
the restore method to switch between different operating system distributions or versions, as long
as the same GitLab version [is available for installation](../../../administration/package_information/supported_os.md).

To instead merge two self-managed GitLab instances together, use the instructions in
[Migrate from self-managed GitLab to GitLab.com](#migrate-from-self-managed-gitlab-to-gitlabcom).
This method is useful when both self-managed instances have existing data that must be preserved.

Also note that administrators can use the [Users API](../../../api/users.md)
to migrate users.

## Project aliases **(PREMIUM SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/3264) in GitLab 12.1.

GitLab repositories are usually accessed with a namespace and a project name. When migrating
frequently accessed repositories to GitLab, however, you can use project aliases to access those
repositories with the original name. Accessing repositories through a project alias reduces the risk
associated with migrating such repositories.

This feature is only available on Git over SSH. Also, only GitLab administrators can create project
aliases, and they can only do so through the API. For more information, see the
[Project Aliases API documentation](../../../api/project_aliases.md).

After an administrator creates an alias for a project, you can use the alias to clone the
repository. For example, if an administrator creates the alias `gitlab` for the project
`https://gitlab.com/gitlab-org/gitlab`, you can clone the project with
`git clone git@gitlab.com:gitlab.git` instead of `git clone git@gitlab.com:gitlab-org/gitlab.git`.

## Automate group and project import **(PREMIUM)**

The GitLab Professional Services team uses [Congregate](https://gitlab.com/gitlab-org/professional-services-automation/tools/migration/congregate)
to orchestrate user, group, and project import API calls. With Congregate, you can migrate data to
GitLab from:

- Other GitLab instances
- GitHub Enterprise
- GitHub.com
- Bitbucket Server
- Bitbucket Data Center

See the [Quick Start Guide](https://gitlab.com/gitlab-org/professional-services-automation/tools/migration/congregate/-/blob/master/docs/using-congregate.md#quick-start)
to learn how to use this approach for migrating users, groups, and projects at scale.
