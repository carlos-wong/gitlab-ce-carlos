---
stage: Manage
group: Workspace
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments"
---

# Manage projects **(FREE)**

Most work in GitLab is done in a [project](../../user/project/index.md). Files and
code are saved in projects, and most features are in the scope of projects.

## View projects

To explore projects:

1. On the top bar, select **Menu > Projects**.
1. Select **Explore projects**.

The **Projects** page shows a list of projects, sorted by last updated date.

- To view projects with the most [stars](#star-a-project), select **Most stars**.
- To view projects with the largest number of comments in the past month, select **Trending**.

NOTE:
The **Explore projects** tab is visible to unauthenticated users unless the
[**Public** visibility level](../admin_area/settings/visibility_and_access_controls.md#restrict-visibility-levels)
is restricted. Then the tab is visible only to signed-in users.

### Who can view the **Projects** page

When you select a project, the project landing page shows the project contents.

For public projects, and members of internal and private projects
with [permissions to view the project's code](../permissions.md#project-members-permissions),
the project landing page shows:

- A [`README` or index file](repository/index.md#readme-and-index-files).
- A list of directories in the project's repository.

For users without permission to view the project's code, the landing page shows:

- The wiki homepage.
- The list of issues in the project.

### Access a project page with the project ID

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/53671) in GitLab 11.8.

To access a project from the GitLab UI using the project ID,
visit the `/projects/:id` URL in your browser or other tool accessing the project.

## Explore topics

To explore project topics:

1. On the top bar, select **Menu > Projects**.
1. Select **Explore topics**.

The **Projects** page shows list of topics sorted by the number of associated projects.
To view projects associated with a topic, select a topic from the list.

You can assign topics to a project on the [Project Settings page](settings/index.md#assign-topics-to-a-project).

If you're an instance administrator, you can administer all project topics from the
[Admin Area's Topics page](../admin_area/index.md#administering-topics).

## Create a project

To create a project in GitLab:

1. On the top bar, select **Menu > Project > Create new project**.
1. On the **Create new project** page, choose if you want to:
   - Create a [blank project](#create-a-blank-project).
   - Create a project from a:
      - [built-in template](#create-a-project-from-a-built-in-template).
      - [custom template](#create-a-project-from-a-custom-template).
      - [HIPAA audit protocol template](#create-a-project-from-the-hipaa-audit-protocol-template).
   - [Import a project](../../user/project/import/index.md)
     from a different repository. Contact your GitLab administrator if this option is not available.
   - [Connect an external repository to GitLab CI/CD](../../ci/ci_cd_for_external_repos/index.md).

- For a list of words that you cannot use as project names, see
  [reserved project and group names](../../user/reserved_names.md).
- For a list of characters that you cannot use in project and group names, see
  [limitations on project and group names](../../user/reserved_names.md#limitations-on-project-and-group-names).

## Create a blank project

To create a blank project:

1. On the top bar, select **Menu > Projects > Create new project**.
1. Select **Create blank project**.
1. Enter the project details:
   - In the **Project name** field, enter the name of your project. You cannot use special characters at
     the start or end of a project name.
   - In the **Project slug** field, enter the path to your project. The GitLab instance uses the
     slug as the URL path to the project. To change the slug, first enter the project name,
     then change the slug.
   - In the **Project description (optional)** field, enter the description of your project's dashboard.
   - In the **Project target (optional)** field, select your project's deployment target.
     This information helps GitLab better understand its users and their deployment requirements.
   - To modify the project's [viewing and access rights](../public_access.md) for
     users, change the **Visibility Level**.
   - To create README file so that the Git repository is initialized, has a default branch, and
     can be cloned, select **Initialize repository with a README**.
   - To analyze the source code in the project for known security vulnerabilities,
     select **Enable Static Application Security Testing (SAST)**.
1. Select **Create project**.

## Create a project from a built-in template

A built-in project template populates a new project with files to get you started.
Built-in templates are sourced from the following groups:

- [`project-templates`](https://gitlab.com/gitlab-org/project-templates)
- [`pages`](https://gitlab.com/pages)

Anyone can [contribute a built-in template](../../development/project_templates.md).

To create a project from a built-in template:

1. On the top bar, select **Menu > Projects > Create new project**.
1. Select **Create from template**.
1. Select the **Built-in** tab.
1. From the list of templates:
   - To view a preview of the template, select **Preview**.
   - To use a template for the project, select **Use template**.
1. Enter the project details:
   - In the **Project name** field, enter the name of your project. You cannot use special characters at
     the start or end of a project name.
   - In the **Project slug** field, enter the path to your project. The GitLab instance uses the
     slug as the URL path to the project. To change the slug, first enter the project name,
     then change the slug.
   - In the **Project description (optional)** field, enter the description of your project's dashboard.
   - To modify the project's [viewing and access rights](../public_access.md) for users,
     change the **Visibility Level**.
1. Select **Create project**.

## Create a project from a custom template **(PREMIUM)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/6860) in GitLab 11.2.

Custom project templates are available at:

- The [instance-level](../../user/admin_area/custom_project_templates.md)
- The [group-level](../../user/group/custom_project_templates.md)

1. On the top bar, select **Menu > Projects > Create new project**.
1. Select **Create from template**.
1. Select the **Instance** or **Group** tab.
1. From the list of templates:
   - To view a preview of the template, select **Preview**.
   - To use a template for the project, select **Use template**.
1. Enter the project details:
   - In the **Project name** field, enter the name of your project. You cannot use special characters at
     the start or end of a project name.
   - In the **Project slug** field, enter the path to your project. The GitLab instance uses the
     slug as the URL path to the project. To change the slug, first enter the project name,
     then change the slug.
   - The description of your project's dashboard in the **Project description (optional)** field.
   - To modify the project's [viewing and access rights](../public_access.md) for users,
     change the **Visibility Level**.
1. Select **Create project**.

## Create a project from the HIPAA Audit Protocol template **(ULTIMATE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/13756) in GitLab 12.10

The HIPAA Audit Protocol template contains issues for audit inquiries in the
HIPAA Audit Protocol published by the U.S Department of Health and Human Services.

To create a project from the HIPAA Audit Protocol template:

1. On the top bar, select **Menu > Projects > Create new project**.
1. Select **Create from template**.
1. Select the **Built-in** tab.
1. Locate the **HIPAA Audit Protocol** template:
   - To view a preview of the template, select **Preview**.
   - To use the template for the project, select **Use template**.
1. Enter the project details:
   - In the **Project name** field, enter the name of your project. You cannot use special characters at
     the start or end of a project name.
   - In the **Project slug** field, enter the path to your project. The GitLab instance uses the
     slug as the URL path to the project. To change the slug, first enter the project name,
     then change the slug.
   - In the **Project description (optional)** field, enter the description of your project's dashboard.
   - To modify the project's [viewing and access rights](../public_access.md) for users,
     change the **Visibility Level**.
1. Select **Create project**.

## Create a new project with Git push

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/26388) in GitLab 10.5.

Use `git push` to push a local project repository to GitLab. After you push a repository,
GitLab creates your project in your chosen namespace.

You cannot use `git push` to create projects with project paths that:

- Have previously been used.
- Have been [renamed](settings/index.md#rename-a-repository).

Previously used project paths have a redirect. The redirect causes push attempts to redirect requests
to the renamed project location, instead of creating a new project. To create a new project for a previously
used or renamed project, use the [UI](#create-a-project) or the [Projects API](../../api/projects.md#create-project).

Prerequisites:

- To push with SSH, you must have [an SSH key](../ssh.md) that is
  [added to your GitLab account](../ssh.md#add-an-ssh-key-to-your-gitlab-account).
- You must have permission to add new projects to a namespace. To check if you have permission:

  1. On the top bar, select **Menu > Projects**.
  1. Select **Groups**.
  1. Select a group.
  1. Confirm that **New project** is visible in the upper right
     corner. Contact your GitLab
     administrator if you require permission.

To push your repository and create a project:

1. Push with SSH or HTTPS:
   - To push with SSH:

      ```shell
      git push --set-upstream git@gitlab.example.com:namespace/myproject.git master
      ```

   - To push with HTTPS:

      ```shell
      git push --set-upstream https://gitlab.example.com/namespace/myproject.git master
      ```

   - For `gitlab.example.com`, use the domain name of the machine that hosts your Git repository.
   - For `namespace`, use the name of your [namespace](../group/index.md#namespaces).
   - For `myproject`, use the name of your project.
   - Optional. To export existing repository tags, append the `--tags` flag to your `git push` command.
1. Optional. To configure the remote:

   ```shell
   git remote add origin https://gitlab.example.com/namespace/myproject.git
   ```

When the push completes, GitLab displays the message:

```shell
remote: The private project namespace/myproject was created.
```

To view your new project, go to `https://gitlab.example.com/namespace/myproject`.
Your project's visibility is set to **Private** by default. To change project visibility, adjust your
[project's settings](../public_access.md#change-project-visibility).

## Star a project

You can add a star to projects you use frequently to make them easier to find.

To add a star to a project:

1. On the top bar, select **Menu > Projects**.
1. Select **Your projects** or **Explore projects**.
1. Select a project.
1. In the upper right corner of the page, select **Star**.

## View starred projects

1. On the top bar, select **Menu > Projects**.
1. Select **Starred projects**.
1. GitLab displays information about your starred projects, including:

   - Project description, including name, description, and icon.
   - Number of times this project has been starred.
   - Number of times this project has been forked.
   - Number of open merge requests.
   - Number of open issues.

## View personal projects

Personal projects are projects created under your personal namespace.

For example, if you create an account with the username `alex`, and create a project
called `my-project` under your username, the project is created at `https://gitlab.example.com/alex/my-project`.

To view your personal projects:

1. On the top bar, select **Menu > Projects > Your Projects**.
1. Under **Your projects**, select **Personal**.

## Delete a project

After you delete a project, projects in personal namespaces are deleted immediately. To delay deletion of projects in a group
you can [enable delayed project removal](../group/index.md#enable-delayed-project-deletion).

To delete a project:

1. On the top bar, select **Menu > Projects**.
1. Select **Your projects** or **Explore projects**.
1. Select a project.
1. Select **Settings > General**.
1. Expand the **Advanced** section.
1. Scroll down to the **Delete project** section.
1. Select **Delete project**.
1. Confirm this action by completing the field.

## View projects pending deletion **(PREMIUM)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/37014) in GitLab 13.3 for Administrators.
> - [Tab renamed](https://gitlab.com/gitlab-org/gitlab/-/issues/347468) from **Deleted projects** in GitLab 14.6.
> - [Available to all users](https://gitlab.com/gitlab-org/gitlab/-/issues/346976) in GitLab 14.8 [with a flag](../../administration/feature_flags.md) named `project_owners_list_project_pending_deletion`. Enabled by default.
> - [Generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/351556) in GitLab 14.9. [Feature flag `project_owners_list_project_pending_deletion`](https://gitlab.com/gitlab-org/gitlab/-/issues/351556) removed.

When delayed project deletion is [enabled for a group](../group/index.md#enable-delayed-project-deletion),
projects within that group are not deleted immediately, but only after a delay.

To view a list of all projects that are pending deletion:

1. On the top bar, select **Menu > Projects > Explore projects**.
1. Based on your GitLab version:
   - GitLab 14.6 and later: select the **Pending deletion** tab.
   - GitLab 14.5 and earlier: select the **Deleted projects** tab.

Each project in the list shows:

- The time the project was marked for deletion.
- The time the project is scheduled for final deletion.
- A **Restore** link to stop the project being eventually deleted.

## View project activity

To view the activity of a project:

1. On the top bar, select **Menu > Projects**.
1. Select **Your projects** or **Explore projects**.
1. Select a project.
1. On the left sidebar, select **Project information > Activity**.
1. Select a tab to view the type of project activity.

## Search in projects

You can search through your projects.

1. On the top bar, select **Menu**.
1. In **Search your projects**, type the project name.

GitLab filters as you type.

You can also look for the projects you [starred](#star-a-project) (**Starred projects**).

You can **Explore** all public and internal projects available in GitLab.com, from which you can filter by visibility,
through **Trending**, best rated with **Most stars**, or **All** of them.

You can sort projects by:

- Name
- Created date
- Updated date
- Owner

You can also choose to hide or show archived projects.

## Leave a project

If you leave a project, you are no longer a project
member and cannot contribute.

To leave a project:

1. On the top bar, select **Menu > Projects**.
1. Select **Your projects** or **Explore projects**.
1. Select a project.
1. Select **Leave project**. The **Leave project** option only displays
on the project dashboard when a project is part of a group under a
[group namespace](../group/index.md#namespaces).

## Use a project as a Go package

Prerequisites:

- Contact your administrator to enable the [GitLab Go Proxy](../packages/go_proxy/index.md).
- To use a private project in a subgroup as a Go package, you must [authenticate Go requests](#authenticate-go-requests-to-private-projects). Go requests that are not authenticated cause
`go get` to fail. You don't need to authenticate Go requests for projects that are not in subgroups.

To use a project as a Go package, use the `go get` and `godoc.org` discovery requests. You can use the meta tags:

- [`go-import`](https://pkg.go.dev/cmd/go#hdr-Remote_import_paths)
- [`go-source`](https://github.com/golang/gddo/wiki/Source-Code-Links)

### Authenticate Go requests to private projects

Prerequisites:

- Your GitLab instance must be accessible with HTTPS.
- You must have a [personal access token](../profile/personal_access_tokens.md) with `read_api` scope.

To authenticate Go requests, create a [`.netrc`](https://everything.curl.dev/usingcurl/netrc) file with the following information:

```plaintext
machine gitlab.example.com
login <gitlab_user_name>
password <personal_access_token>
```

On Windows, Go reads `~/_netrc` instead of `~/.netrc`.

The `go` command does not transmit credentials over insecure connections. It authenticates
HTTPS requests made by Go, but does not authenticate requests made
through Git.

### Authenticate Git requests

If Go cannot fetch a module from a proxy, it uses Git. Git uses a `.netrc` file to authenticate requests, but you can
configure other authentication methods.

Configure Git to either:

- Embed credentials in the request URL:

    ```shell
    git config --global url."https://${user}:${personal_access_token}@gitlab.example.com".insteadOf "https://gitlab.example.com"
    ```

- Use SSH instead of HTTPS:

    ```shell
    git config --global url."git@gitlab.example.com:".insteadOf "https://gitlab.example.com/"
    ```

### Disable Go module fetching for private projects

To [fetch modules or packages](../../development/go_guide/dependencies.md#fetching), Go uses
the [environment variables](../../development/go_guide/dependencies.md#proxies):

- `GOPRIVATE`
- `GONOPROXY`
- `GONOSUMDB`

To disable fetching:

1. Disable `GOPRIVATE`:
    - To disable queries for one project, disable `GOPRIVATE=gitlab.example.com/my/private/project`.
    - To disable queries for all projects on GitLab.com, disable `GOPRIVATE=gitlab.example.com`.
1. Disable proxy queries in `GONOPROXY`.
1. Disable checksum queries in `GONOSUMDB`.

- If the module name or its prefix is in `GOPRIVATE` or `GONOPROXY`, Go does not query module
  proxies.
- If the module name or its prefix is in `GONOPRIVATE` or `GONOSUMDB`, Go does not query
  Checksum databases.

### Fetch Go modules from Geo secondary sites

Use [Geo](../../administration/geo/index.md) to access Git repositories that contain Go modules
on secondary Geo servers.

You can use SSH or HTTP to access the Geo secondary server.

#### Use SSH to access the Geo secondary server

To access the Geo secondary server with SSH:

1. Reconfigure Git on the client to send traffic for the primary to the secondary:

   ```shell
   git config --global url."git@gitlab-secondary.example.com".insteadOf "https://gitlab.example.com"
   git config --global url."git@gitlab-secondary.example.com".insteadOf "http://gitlab.example.com"
   ```

    - For `gitlab.example.com`, use the primary site domain name.
    - For `gitlab-secondary.example.com`, use the secondary site domain name.

1. Ensure the client is set up for SSH access to GitLab repositories. You can test this on the primary,
   and GitLab replicates the public key to the secondary.

The `go get` request generates HTTP traffic to the primary Geo server. When the module
download starts, the `insteadOf` configuration sends the traffic to the secondary Geo server.

#### Use HTTP to access the Geo secondary

You must use persistent access tokens that replicate to the secondary server. You cannot use
CI/CD job tokens to fetch Go modules with HTTP.

To access the Geo secondary server with HTTP:

1. Add a Git `insteadOf` redirect on the client:

   ```shell
   git config --global url."https://gitlab-secondary.example.com".insteadOf "https://gitlab.example.com"
   ```

   - For `gitlab.example.com`, use the primary site domain name.
   - For `gitlab-secondary.example.com`, use the secondary site domain name.

1. Generate a [personal access token](../profile/personal_access_tokens.md) and
   add the credentials in the client's `~/.netrc` file:

   ```shell
   machine gitlab.example.com login USERNAME password TOKEN
   machine gitlab-secondary.example.com login USERNAME password TOKEN
   ```

The `go get` request generates HTTP traffic to the primary Geo server. When the module
download starts, the `insteadOf` configuration sends the traffic to the secondary Geo server.

## Related topics

- [Import a project](../../user/project/import/index.md).
- [Connect an external repository to GitLab CI/CD](../../ci/ci_cd_for_external_repos/index.md).
- [Fork a project](repository/forking_workflow.md#creating-a-fork).
- [Adjust project visibility and access levels](settings/index.md#configure-project-visibility-features-and-permissions).
- [Limitations on project and group names](../../user/reserved_names.md#limitations-on-project-and-group-names)
