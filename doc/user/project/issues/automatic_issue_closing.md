# Automatic issue closing

>**Notes:**
>
> - This is the user docs. In order to change the default issue closing pattern,
>   follow the steps in the [administration docs].
> - For performance reasons, automatic issue closing is disabled for the very
>   first push from an existing repository.

When a commit or merge request resolves one or more issues, it is possible to
automatically have these issues closed when the commit or merge request lands
in the project's default branch.

If a commit message or merge request description contains a sentence matching
a certain regular expression, all issues referenced from the matched text will
be closed. This happens when the commit is pushed to a project's
[**default** branch](../repository/branches/index.md#default-branch), or when a
commit or merge request is merged into it.

## Default closing pattern value

When not specified, the default issue closing pattern as shown below will be
used:

```bash
((?:[Cc]los(?:e[sd]?|ing)|[Ff]ix(?:e[sd]|ing)?|[Rr]esolv(?:e[sd]?|ing)|[Ii]mplement(?:s|ed|ing)?)(:?) +(?:(?:issues? +)?%{issue_ref}(?:(?:, *| +and +)?)|([A-Z][A-Z0-9_]+-\d+))+)
```

Note that `%{issue_ref}` is a complex regular expression defined inside GitLab's
source code that can match references to:

- A local issue (`#123`).
- A cross-project issue (`group/project#123`).
- A link to an issue
  (`https://gitlab.example.com/group/project/issues/123`).

---

This translates to the following keywords:

- Close, Closes, Closed, Closing, close, closes, closed, closing
- Fix, Fixes, Fixed, Fixing, fix, fixes, fixed, fixing
- Resolve, Resolves, Resolved, Resolving, resolve, resolves, resolved, resolving
- Implement, Implements, Implemented, Implementing, implement, implements, implemented, implementing

---

For example the following commit message:

```
Awesome commit message

Fix #20, Fixes #21 and Closes group/otherproject#22.
This commit is also related to #17 and fixes #18, #19
and https://gitlab.example.com/group/otherproject/issues/23.
```

will close `#18`, `#19`, `#20`, and `#21` in the project this commit is pushed
to, as well as `#22` and `#23` in group/otherproject. `#17` won't be closed as
it does not match the pattern. It works with multi-line commit messages as well
as one-liners when used with `git commit -m`.

[administration docs]: ../../../administration/issue_closing_pattern.md
