# Code Owners **[STARTER]**

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/merge_requests/6916)
in [GitLab Starter](https://about.gitlab.com/pricing/) 11.3.

You can use a `CODEOWNERS` file to specify users that are responsible
for certain files in a repository.

You can choose and add the `CODEOWNERS` file in three places:

- to the root directory of the repository
- inside the `.gitlab/` directory
- inside the `docs/` directory

The `CODEOWNERS` file is scoped to a branch, which means that with the
introduction of new files, the person adding the new content can
specify themselves as a code owner, all before the new changes
get merged to the default branch.

When a file matches multiple entries in the `CODEOWNERS` file,
the users from all entries are displayed on the blob page of
the given file.

## The syntax of Code Owners files

Files can be specified using the same kind of patterns you would use
in the `.gitignore` file followed by the `@username` or email of one
or more users that should be owners of the file.

The order in which the paths are defined is significant: the last
pattern that matches a given path will be used to find the code
owners.

Starting a line with a `#` indicates a comment. This needs to be
escaped using `\#` to address files for which the name starts with a
`#`.

Example `CODEOWNERS` file:

```
# This is an example code owners file, lines starting with a `#` will
# be ignored.

# app/ @commented-rule

# We can specify a default match using wildcards:
* @default-codeowner

# Rules defined later in the file take precedence over the rules
# defined before.
# This will match all files for which the file name ends in `.rb`
*.rb @ruby-owner

# Files with a `#` can still be accesssed by escaping the pound sign
\#file_with_pound.rb @owner-file-with-pound

# Multiple codeowners can be specified, separated by whitespace
CODEOWNERS @multiple @owners	@tab-separated

# Both usernames or email addresses can be used to match
# users. Everything else will be ignored. For example this will
# specify `@legal` and a user with email `janedoe@gitlab.com` as the
# owner for the LICENSE file
LICENSE @legal this_does_not_match janedoe@gitlab.com

# Ending a path in a `/` will specify the code owners for every file
# nested in that directory, on any level
/docs/ @all-docs

# Ending a path in `/*` will specify code owners for every file in
# that directory, but not nested deeper. This will match
# `docs/index.md` but not `docs/projects/index.md`
/docs/* @root-docs

# This will make a `lib` directory nested anywhere in the repository
# match
lib/ @lib-owner

# This will only match a `config` directory in the root of the
# repository
/config/ @config-owner

# If the path contains spaces, these need to be escaped like this:
path\ with\ spaces/ @space-owner
```
