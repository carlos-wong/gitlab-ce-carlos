---
type: reference, concepts
---

# Cherry-pick changes

GitLab implements Git's powerful feature to
[cherry-pick any commit](https://git-scm.com/docs/git-cherry-pick "Git cherry-pick documentation")
with introducing a **Cherry-pick** button in merge requests and commit details.

## Cherry-picking a merge request

After the merge request has been merged, a **Cherry-pick** button will be available
to cherry-pick the changes introduced by that merge request.

![Cherry-pick Merge Request](img/cherry_pick_changes_mr.png)

After you click that button, a modal will appear showing a [branch filter search box](../repository/branches/index.md#branch-filter-search-box)
where you can choose to either:

- Cherry-pick the changes directly into the selected branch.
- Create a new merge request with the cherry-picked changes.

## Cherry-picking a commit

You can cherry-pick a commit from the commit details page:

![Cherry-pick commit](img/cherry_pick_changes_commit.png)

Similar to cherry-picking a merge request, you can opt to cherry-pick the changes
directly into the target branch or create a new merge request to cherry-pick the
changes.

Please note that when cherry-picking merge commits, the mainline will always be the
first parent. If you want to use a different mainline then you need to do that
from the command line.

Here is a quick example to cherry-pick a merge commit using the second parent as the
mainline:

```shell
git cherry-pick -m 2 7a39eb0
```

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
