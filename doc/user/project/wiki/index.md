---
stage: Create
group: Editor
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Wiki **(FREE)**

If you don't want to keep your documentation in your repository, but you want
to keep it in the same project as your code, you can use the wiki GitLab provides
in each GitLab project. Every wiki is a separate Git repository, so you can create
wiki pages in the web interface, or [locally using Git](#create-or-edit-wiki-pages-locally).

GitLab wikis support Markdown, RDoc, AsciiDoc, and Org for content.
Wiki pages written in Markdown support all [Markdown features](../../markdown.md),
and also provide some [wiki-specific behavior](../../markdown.md#wiki-specific-markdown)
for links.

In [GitLab 13.5 and later](https://gitlab.com/gitlab-org/gitlab/-/issues/17673/),
wiki pages display a sidebar, which you [can customize](#customize-sidebar). This
sidebar contains a partial list of pages in the wiki, displayed as a nested tree,
with sibling pages listed in alphabetical order. To view a list of all pages, select
**View All Pages** in the sidebar:

![Wiki sidebar](img/wiki_sidebar_v13_5.png)

## View a project wiki

To access a project wiki:

1. On the top bar, select **Menu > Projects** and find your project.
1. To display the wiki, either:
   - On the left sidebar, select **Wiki**.
   - On any page in the project, use the <kbd>g</kbd> + <kbd>w</kbd>
     [wiki keyboard shortcut](../../shortcuts.md).

If **Wiki** is not listed in the left sidebar of your project, a project administrator
has [disabled it](#enable-or-disable-a-project-wiki).

## Configure a default branch for your wiki

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/221159) in GitLab 14.1.

The default branch for your wiki repository depends on your version of GitLab:

- *GitLab versions 14.1 and later:* Wikis inherit the
  [default branch name](../repository/branches/default.md) configured for
  your instance or group. If no custom value is configured, GitLab uses `main`.
- *GitLab versions 14.0 and earlier:* GitLab uses `master`.

For any version of GitLab, you can
[rename this default branch](../repository/branches/default.md#update-the-default-branch-name-in-your-repository)
for previously created wikis.

## Create the wiki home page

When a wiki is created, it is empty. On your first visit, you can create the
home page users see when viewing the wiki. This page requires a specific title
to be used as your wiki's home page. To create it:

1. On the top bar, select **Menu**.
   - For project wikis, select **Projects** and find your project.
   - For group wikis, select **Groups** and find your group.
1. On the left sidebar, select **Wiki**.
1. Select **Create your first page**.
1. GitLab requires this first page be titled `home`. The page with this
   title serves as the front page for your wiki.
1. Select a **Format** for styling your text.
1. Add a welcome message for your home page in the **Content** section. You can
   always edit it later.
1. Add a **Commit message**. Git requires a commit message, so GitLab creates one
   if you don't enter one yourself.
1. Select **Create page**.

## Create a new wiki page

Users with at least the Developer role can create new wiki pages:

1. On the top bar, select **Menu**.
   - For project wikis, select **Projects** and find your project.
   - For group wikis, select **Groups** and find your group.
1. On the left sidebar, select **Wiki**.
1. Select **New page** on this page, or any other wiki page.
1. Select a content format.
1. Add a title for your new page. Page titles use
   [special characters](#special-characters-in-page-titles) for subdirectories and formatting,
   and have [length restrictions](#length-restrictions-for-file-and-directory-names).
1. Add content to your wiki page.
1. Optional. Attach a file, and GitLab stores it in the wiki's Git repository.
1. Add a **Commit message**. Git requires a commit message, so GitLab creates one
   if you don't enter one yourself.
1. Select **Create page**.

### Create or edit wiki pages locally

Wikis are based on Git repositories, so you can clone them locally and edit
them like you would do with every other Git repository. To clone a wiki repository
locally, select **Clone repository** from the right-hand sidebar of any wiki page,
and follow the on-screen instructions.

Files you add to your wiki locally must use one of the following
supported extensions, depending on the markup language you wish to use.
Files with unsupported extensions don't display when pushed to GitLab:

- Markdown extensions: `.mdown`, `.mkd`, `.mkdn`, `.md`, `.markdown`.
- AsciiDoc extensions: `.adoc`, `.ad`, `.asciidoc`.
- Other markup extensions: `.textile`, `.rdoc`, `.org`, `.creole`, `.wiki`, `.mediawiki`, `.rst`.

### Special characters in page titles

Wiki pages are stored as files in a Git repository, so certain characters have a special meaning:

- Spaces are converted into hyphens when storing a page.
- Hyphens (`-`) are converted back into spaces when displaying a page.
- Slashes (`/`) are used as path separators, and can't be displayed in titles. If you
  create a title containing `/` characters, GitLab creates all the subdirectories
  needed to build that path. For example, a title of `docs/my-page` creates a wiki
  page with a path `/wikis/docs/my-page`.

### Length restrictions for file and directory names

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/24364) in GitLab 12.8.

Many common file systems have a [limit of 255 bytes](https://en.wikipedia.org/wiki/Comparison_of_file_systems#Limits)
for file and directory names. Git and GitLab both support paths exceeding
those limits. However, if your file system enforces these limits, you cannot check out a
local copy of a wiki that contains filenames exceeding this limit. To prevent this
problem, the GitLab web interface and API enforce these limits:

- 245 bytes for page titles (reserving 10 bytes for the file extension).
- 255 bytes for directory names.

Non-ASCII characters take up more than one byte.

While you can still create files locally that exceed these limits, your teammates
may not be able to check out the wiki locally afterward.

## Edit a wiki page

You need at least the Developer role to edit a wiki page:

1. On the top bar, select **Menu**.
   - For project wikis, select **Projects** and find your project.
   - For group wikis, select **Groups** and find your group.
1. On the left sidebar, select **Wiki**.
1. Go to the page you want to edit, and either:
   - Use the <kbd>e</kbd> wiki [keyboard shortcut](../../shortcuts.md#wiki-pages).
   - Select the edit icon (**{pencil}**).
1. Edit the content.
1. Select **Save changes**.

### Create a table of contents

To generate a table of contents from a wiki page's subheadings, use the `[[_TOC_]]` tag.
For an example, read [Table of contents](../../markdown.md#table-of-contents).

## Delete a wiki page

You need at least the Developer role to delete a wiki page:

1. On the top bar, select **Menu**.
   - For project wikis, select **Projects** and find your project.
   - For group wikis, select **Groups** and find your group.
1. On the left sidebar, select **Wiki**.
1. Go to the page you want to delete.
1. Select the edit icon (**{pencil}**).
1. Select **Delete page**.
1. Confirm the deletion.

## Move a wiki page

You need at least the Developer role to move a wiki page:

1. On the top bar, select **Menu**.
   - For project wikis, select **Projects** and find your project.
   - For group wikis, select **Groups** and find your group.
1. On the left sidebar, select **Wiki**.
1. Go to the page you want to move.
1. Select the edit icon (**{pencil}**).
1. Add the new path to the **Title** field. For example, if you have a wiki page
   called `about` under `company` and you want to move it to the wiki's root,
   change the **Title** from `about` to `/about`.
1. Select **Save changes**.

## View history of a wiki page

The changes of a wiki page over time are recorded in the wiki's Git repository.
The history page shows:

![Wiki page history](img/wiki_page_history.png)

- The revision (Git commit SHA) of the page.
- The page author.
- The commit message.
- The last update.
- Previous revisions, by selecting a revision number in the **Page version** column.

To view the changes for a wiki page:

1. On the top bar, select **Menu**.
   - For project wikis, select **Projects** and find your project.
   - For group wikis, select **Groups** and find your group.
1. On the left sidebar, select **Wiki**.
1. Go to the page you want to view history for.
1. Select **Page history**.

### View changes between page versions

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/15242) in GitLab 13.2.

You can see the changes made in a version of a wiki page, similar to versioned diff file views:

1. On the top bar, select **Menu**.
   - For project wikis, select **Projects** and find your project.
   - For group wikis, select **Groups** and find your group.
1. On the left sidebar, select **Wiki**.
1. Go to the wiki page you're interested in.
1. Select **Page history** to see all page versions.
1. Select the commit message in the **Changes** column for the version you're interested in.

   ![Wiki page changes](img/wiki_page_diffs_v13_2.png)

## Track wiki events

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/14902) in GitLab 12.10.
> - Git events were [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/216014) in GitLab 13.0.
> - [Feature flag for Git events was removed](https://gitlab.com/gitlab-org/gitlab/-/issues/258665) in GitLab 13.5.

GitLab tracks wiki creation, deletion, and update events. These events are displayed on these pages:

- [User profile](../../profile/index.md#access-your-user-profile).
- Activity pages, depending on the type of wiki:
  - [Group activity](../../group/index.md#view-group-activity).
  - [Project activity](../working_with_projects.md#view-project-activity).

Commits to wikis are not counted in [repository analytics](../../analytics/repository_analytics.md).

## Customize sidebar

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/23109) in GitLab 13.8, the sidebar can be customized by selecting the **Edit sidebar** button.

You need at least the Developer role to customize the wiki
navigation sidebar. This process creates a wiki page named `_sidebar` which fully
replaces the default sidebar navigation:

1. On the top bar, select **Menu**.
   - For project wikis, select **Projects** and find your project.
   - For group wikis, select **Groups** and find your group.
1. On the left sidebar, select **Wiki**.
1. In the top right corner of the page, select **Edit sidebar**.
1. When complete, select **Save changes**.

A `_sidebar` example, formatted with Markdown:

```markdown
### [Home](home)

- [Hello World](hello)
- [Foo](foo)
- [Bar](bar)

---

- [Sidebar](_sidebar)
```

Support for displaying a generated table of contents with a custom side navigation is being considered.

## Enable or disable a project wiki

Wikis are enabled by default in GitLab. Project [administrators](../../permissions.md)
can enable or disable a project wiki by following the instructions in
[Sharing and permissions](../settings/index.md#configure-project-visibility-features-and-permissions).

Administrators for self-managed GitLab installs can
[configure additional wiki settings](../../../administration/wikis/index.md).

You can disable group wikis from the [group settings](group.md#configure-group-wiki-visibility)

## Link an external wiki

To add a link to an external wiki from a project's left sidebar:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Integrations**.
1. Select **External wiki**.
1. Add the URL to your external wiki.
1. Optional. To verify the connection, select **Test settings**.
1. Select **Save changes**.

You can now see the **External wiki** option from your project's
left sidebar.

When you enable this integration, the link to the external
wiki doesn't replace the link to the internal wiki.
To hide the internal wiki from the sidebar, [disable the project's wiki](#disable-the-projects-wiki).

To hide the link to an external wiki:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Integrations**.
1. Select **External wiki**.
1. In the **Enable integration** section, clear the **Active** checkbox.
1. Select **Save changes**.

## Disable the project's wiki

To disable a project's internal wiki:

1. On the top bar, select **Menu > Projects** and find your project.
1. Go to your project and select **Settings > General**.
1. Expand **Visibility, project features, permissions**.
1. Scroll down to find **Wiki** and toggle it off (in gray).
1. Select **Save changes**.

The internal wiki is now disabled, and users and project members:

- Cannot find the link to the wiki from the project's sidebar.
- Cannot add, delete, or edit wiki pages.
- Cannot view any wiki page.

Previously added wiki pages are preserved in case you
want to re-enable the wiki. To re-enable it, repeat the process
to disable the wiki but toggle it on (in blue).

## Content Editor

> - [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/5643) in GitLab 14.0.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/345398) switching between editing experiences in GitLab 14.7 [with a flag](../../../administration/feature_flags.md) named `wiki_switch_between_content_editor_raw_markdown`. Enabled by default.
> - Switching between editing experiences generally available in GitLab 14.10. [Feature flag `wiki_switch_between_content_editor_raw_markdown`](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/83760) removed.

GitLab provides a WYSIWYG editing experience for GitLab Flavored Markdown in wikis.

Support includes:

- Text formatting options, including bold, italics, block quotes, headings, and inline code.
- List formatting for unordered, numbered, and checklists.
- Creating and editing the structure of tables.
- Inserting and formatting code blocks with syntax highlighting.
- Live preview of Mermaid, PlantUML, and Kroki diagrams ([Introduced]<https://gitlab.com/gitlab-org/gitlab/-/merge_requests/86701> in GitLab 15.2).

### Use the Content Editor

1. [Create](#create-a-new-wiki-page) a new wiki page, or [edit](#edit-a-wiki-page) an existing one.
1. Select **Markdown** as your format.
1. Above **Content**, select **Edit rich text**.
1. Customize your page's content using the various formatting options available in the content editor.
1. Select **Create page** for a new page, or **Save changes** for an existing page.

The rich text editing mode remains the default until you switch back to
[edit the raw source](#switch-back-to-the-old-editor).

### Switch back to the old editor

1. *If you're editing the page in the content editor,* scroll to **Content**.
1. Select **Edit source**.

### GitLab Flavored Markdown support

Supporting all GitLab Flavored Markdown content types in the Content Editor is a work in progress.
For the status of the ongoing development for CommonMark and GitLab Flavored Markdown support, read:

- [Basic Markdown formatting extensions](https://gitlab.com/groups/gitlab-org/-/epics/5404) epic.
- [GitLab Flavored Markdown extensions](https://gitlab.com/groups/gitlab-org/-/epics/5438) epic.

## Related topics

- [Wiki settings for administrators](../../../administration/wikis/index.md)
- [Project wikis API](../../../api/wikis.md)
- [Group repository storage moves API](../../../api/group_repository_storage_moves.md)
- [Group wikis API](../../../api/group_wikis.md)
- [Wiki keyboard shortcuts](../../shortcuts.md#wiki-pages)
