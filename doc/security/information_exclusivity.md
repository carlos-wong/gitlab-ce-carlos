---
type: concepts
---
# Information exclusivity

Git is a distributed version control system (DVCS). This means that everyone
who works with the source code has a local copy of the complete repository.

In GitLab every project member that is not a guest (reporters, developers, and
maintainers) can clone the repository to create a local copy. After obtaining
a local copy, the user can upload the full repository anywhere, including to
another project that is under their control, or onto another server.

Therefore, it is impossible to build access controls that prevent the
intentional sharing of source code by users that have access to the source code.

This is an inherent feature of a DVCS. All git management systems have this
limitation.

You can take steps to prevent unintentional sharing and information
destruction. This limitation is the reason why only certain people are allowed
to [add users to a project](../user/project/members/index.md)
and why only a GitLab admin can [force push a protected
branch](../user/project/protected_branches.md).

<!-- ## Troubleshooting

Include any troubleshooting steps that you can foresee. If you know beforehand what issues
one might have when setting this up, or when something is changed, or on upgrading, it's
important to describe those, too. Think of things that may go wrong and include them here.
This is important to minimize requests for support, and to avoid doc comments with
questions that you know someone might ask.

Each scenario can be a third-level heading, e.g. `### Getting error message X`.
If you have none to add when creating a doc, leave this section in place
but commented out to help encourage others to add to it in the future. -->
