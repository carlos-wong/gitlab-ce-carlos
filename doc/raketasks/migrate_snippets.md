---
stage: Create
group: Editor
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Migration to versioned snippets **(FREE SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/215861) in GitLab 13.0.

In GitLab 13.0, [GitLab Snippets are backed by Git repositories](../user/snippets.md#versioned-snippets).
Snippet content is stored in the repository, and users can update it directly through Git.

Nevertheless, existing GitLab Snippets must be migrated to this new feature.
For each snippet:

- A new repository is created.
- A file is created in the repository, using the snippet filename.
- The snippet is committed to the repository.

GitLab performs this migration through a [Background Migration](../development/database/background_migrations.md)
when the GitLab instance is upgraded to 13.0 or a higher version.
However, if the migration fails for any of the snippets, they must be migrated individually.
The following Rake tasks help with that process.

## Migrate specific snippets to Git

In case you want to migrate a range of snippets, run the tasks as described below.

For Omnibus installations, run:

```shell
sudo gitlab-rake gitlab:snippets:migrate SNIPPET_IDS=1,2,3,4
```

For installations from source code, run:

```shell
bundle exec rake gitlab:snippets:migrate SNIPPET_IDS=1,2,3,4
```

There is a default limit (100) to the number of ids supported in the migration
process. You can modify this limit by using the environment variable `LIMIT`.

```shell
sudo gitlab-rake gitlab:snippets:migrate SNIPPET_IDS=1,2,3,4 LIMIT=50
```

For installations from source code, run:

```shell
bundle exec rake gitlab:snippets:migrate SNIPPET_IDS=1,2,3,4 LIMIT=50
```

## Show whether the snippet background migration is running

In case you want to check the status of the snippet background migration,
whether it is running or not, you can use the following task.

For Omnibus installations, run:

```shell
sudo gitlab-rake gitlab:snippets:migration_status
```

For installations from source code, run:

```shell
bundle exec rake gitlab:snippets:migration_status RAILS_ENV=production
```

## List non-migrated snippets

With the following task, you can get the ids of all of the snippets
that haven't been migrated yet or failed to migrate.

For Omnibus installations, run:

```shell
sudo gitlab-rake gitlab:snippets:list_non_migrated
```

For installations from source code, run:

```shell
bundle exec rake gitlab:snippets:list_non_migrated RAILS_ENV=production
```

As the number of non-migrated snippets can be large, we limit
by default the size of the number of ids returned to 100. You can
modify this limit by using the environment variable `LIMIT`.

```shell
sudo gitlab-rake gitlab:snippets:list_non_migrated LIMIT=200
```

For installations from source code, run:

```shell
bundle exec rake gitlab:snippets:list_non_migrated RAILS_ENV=production LIMIT=200
```
