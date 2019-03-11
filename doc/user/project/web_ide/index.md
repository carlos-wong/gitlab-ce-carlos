# Web IDE

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/issues/4539) in [GitLab Ultimate][ee] 10.4.
> [Brought to GitLab Core](https://gitlab.com/gitlab-org/gitlab-ce/issues/44157) in 10.7.

The Web IDE editor makes it faster and easier to contribute changes to your
projects by providing an advanced editor with commit staging.

## Open the Web IDE

The Web IDE can be opened when viewing a file, from the repository file list,
and from merge requests.

![Open Web IDE](img/open_web_ide.png)

## File finder

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/18323) in [GitLab Core][ce] 10.8.

The file finder allows you to quickly open files in the current branch by
searching. The file finder is launched using the keyboard shortcut `Command-p`,
`Control-p`, or `t` (when editor is not in focus). Type the filename or
file path fragments to start seeing results.

## Syntax highlighting

As expected from an IDE, syntax highlighting for many languages within
the Web IDE will make your direct editing even easier.

The Web IDE currently provides:

- Basic syntax colorization for a variety of programming, scripting and markup
  languages such as XML, PHP, C#, C++, Markdown, Java, VB, Batch, Python, Ruby
  and Objective-C.
- IntelliSense and validation support (displaying errors and warnings, providing
  smart completions, formatting, and outlining) for some languages. For example:
TypeScript, JavaScript, CSS, LESS, SCSS, JSON and HTML.

Because the Web IDE is based on the [Monaco Editor](https://microsoft.github.io/monaco-editor/),
you can find a more complete list of supported languages in the
[Monaco languages](https://github.com/Microsoft/monaco-languages) repository.

NOTE: **Note:**
Single file editing is based on the [Ace Editor](https://ace.c9.io).

## Stage and commit changes

After making your changes, click the Commit button in the bottom left to
review the list of changed files. Click on each file to review the changes and
click the tick icon to stage the file.

Once you have staged some changes, you can add a commit message and commit the
staged changes. Unstaged changes will not be committed.

![Commit changes](img/commit_changes.png)

## Reviewing changes

Before you commit your changes, you can compare them with the previous commit
by switching to the review mode or selecting the file from the staged files
list.

An additional review mode is available when you open a merge request, which
shows you a preview of the merge request diff if you commit your changes.

## View CI job logs

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/19279) in [GitLab Core][ce] 11.0.

The Web IDE can be used to quickly fix failing tests by opening the branch or
merge request in the Web IDE and opening the logs of the failed job. The status
of all jobs for the most recent pipeline and job traces for the current commit
can be accessed by clicking the **Pipelines** button in the top right.

The pipeline status is also shown at all times in the status bar in the bottom
left.

## Switching merge requests

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/19318) in [GitLab Core][ce] 11.0.

Switching between your authored and assigned merge requests can be done without
leaving the Web IDE. Click the dropdown in the top of the sidebar to open a list
of merge requests. You will need to commit or discard all your changes before
switching to a different merge request.

## Switching branches

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/20850) in [GitLab Core][ce] 11.2.

Switching between branches of the current project repository can be done without
leaving the Web IDE. Click the dropdown in the top of the sidebar to open a list
of branches. You will need to commit or discard all your changes before
switching to a different branch.

## Client Side Evaluation

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/19764) in [GitLab Core][ce] 11.2.

The Web IDE can be used to preview JavaScript projects right in the browser.
This feature uses CodeSandbox to compile and bundle the JavaScript used to
preview the web application.

![Web IDE Client Side Evaluation](img/clientside_evaluation.png)

Additionally, for public projects an `Open in CodeSandbox` button is available
to transfer the contents of the project into a public CodeSandbox project to
quickly share your project with others.

### Enabling Client Side Evaluation

The Client Side Evaluation feature needs to be enabled in the GitLab instances
admin settings. Client Side Evaluation is enabled for all projects on
GitLab.com

![Admin Client Side Evaluation setting](img/admin_clientside_evaluation.png)

Once it has been enabled in application settings, projects with a
`package.json` file and a `main` entry point can be previewed inside of the Web
IDE. An example `package.json` is below.

```json
{
  "main": "index.js",
  "dependencies": {
    "vue": "latest"
  }
}
```

[ce]: https://about.gitlab.com/pricing/
[ee]: https://about.gitlab.com/pricing/
