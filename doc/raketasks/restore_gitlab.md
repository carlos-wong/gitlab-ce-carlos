---
stage: Systems
group: Geo
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Restore GitLab

GitLab provides a command line interface to restore your entire installation,
and is flexible enough to fit your needs.

The [restore prerequisites section](#restore-prerequisites) includes crucial
information. Be sure to read and test the complete restore process at least
once before attempting to perform it in a production environment.

You can restore a backup only to _the exact same version and type (CE/EE)_ of
GitLab that you created it on (for example CE 9.1.0).

If your backup is a different version than the current installation, you must
[downgrade your GitLab installation](../update/package/downgrade.md)
before restoring the backup.

## Restore prerequisites

You need to have a working GitLab installation before you can perform a
restore. This is because the system user performing the restore actions (`git`)
is usually not allowed to create or delete the SQL database needed to import
data into (`gitlabhq_production`). All existing data is either erased
(SQL) or moved to a separate directory (such as repositories and uploads).

To restore a backup, you must restore `/etc/gitlab/gitlab-secrets.json`
(for Omnibus packages) or `/home/git/gitlab/.secret` (for installations from
source). This file contains the database encryption key,
[CI/CD variables](../ci/variables/index.md), and
variables used for [two-factor authentication](../user/profile/account/two_factor_authentication.md).
If you fail to restore this encryption key file along with the application data
backup, users with two-factor authentication enabled and GitLab Runner
loses access to your GitLab server.

You may also want to restore your previous `/etc/gitlab/gitlab.rb` (for Omnibus packages)
or `/home/git/gitlab/config/gitlab.yml` (for installations from source) and
any TLS keys, certificates (`/etc/gitlab/ssl`, `/etc/gitlab/trusted-certs`), or
[SSH host keys](https://superuser.com/questions/532040/copy-ssh-keys-from-one-server-to-another-server/532079#532079).

Starting with GitLab 12.9, if an untarred backup (like the ones made with
`SKIP=tar`) is found, and no backup is chosen with `BACKUP=<timestamp>`, the
untarred backup is used.

Depending on your case, you might want to run the restore command with one or
more of the following options:

- `BACKUP=timestamp_of_backup`: Required if more than one backup exists.
  Read what the [backup timestamp is about](backup_restore.md#backup-timestamp).
- `force=yes`: Doesn't ask if the `authorized_keys` file should get regenerated,
  and assumes 'yes' for warning about database tables being removed,
  enabling the `Write to authorized_keys file` setting, and updating LDAP
  providers.

If you're restoring into directories that are mount points, you must ensure these directories are
empty before attempting a restore. Otherwise, GitLab attempts to move these directories before
restoring the new data, which causes an error.

Read more about [configuring NFS mounts](../administration/nfs.md)

## Restore for Omnibus GitLab installations

This procedure assumes that:

- You have installed the **exact same version and type (CE/EE)** of GitLab
  Omnibus with which the backup was created.
- You have run `sudo gitlab-ctl reconfigure` at least once.
- GitLab is running. If not, start it using `sudo gitlab-ctl start`.

First ensure your backup tar file is in the backup directory described in the
`gitlab.rb` configuration `gitlab_rails['backup_path']`. The default is
`/var/opt/gitlab/backups`. The backup file needs to be owned by the `git` user.

```shell
sudo cp 11493107454_2018_04_25_10.6.4-ce_gitlab_backup.tar /var/opt/gitlab/backups/
sudo chown git:git /var/opt/gitlab/backups/11493107454_2018_04_25_10.6.4-ce_gitlab_backup.tar
```

Stop the processes that are connected to the database. Leave the rest of GitLab
running:

```shell
sudo gitlab-ctl stop puma
sudo gitlab-ctl stop sidekiq
# Verify
sudo gitlab-ctl status
```

Next, restore the backup, specifying the timestamp of the backup you wish to
restore:

```shell
# This command will overwrite the contents of your GitLab database!
sudo gitlab-backup restore BACKUP=11493107454_2018_04_25_10.6.4-ce
```

Users of GitLab 12.1 and earlier should use the command `gitlab-rake gitlab:backup:restore` instead.
Some [known non-blocking error messages may appear](backup_restore.md#restoring-database-backup-using-omnibus-packages-outputs-warnings).

WARNING:
`gitlab-rake gitlab:backup:restore` doesn't set the correct file system
permissions on your Registry directory. This is a [known issue](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/62759).
In GitLab 12.2 or later, you can use `gitlab-backup restore` to avoid this
issue.

If there's a GitLab version mismatch between your backup tar file and the
installed version of GitLab, the restore command aborts with an error
message. Install the [correct GitLab version](https://packages.gitlab.com/gitlab/),
and then try again.

WARNING:
The restore command requires [additional parameters](backup_restore.md#back-up-and-restore-for-installations-using-pgbouncer) when
your installation is using PgBouncer, for either performance reasons or when using it with a Patroni cluster.

Next, restore `/etc/gitlab/gitlab-secrets.json` if necessary,
[as previously mentioned](#restore-prerequisites).

Reconfigure, restart and [check](../administration/raketasks/maintenance.md#check-gitlab-configuration) GitLab:

```shell
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart
sudo gitlab-rake gitlab:check SANITIZE=true
```

In GitLab 13.1 and later, check [database values can be decrypted](../administration/raketasks/check.md#verify-database-values-can-be-decrypted-using-the-current-secrets)
especially if `/etc/gitlab/gitlab-secrets.json` was restored, or if a different server is
the target for the restore.

```shell
sudo gitlab-rake gitlab:doctor:secrets
```

For added assurance, you can perform [an integrity check on the uploaded files](../administration/raketasks/check.md#uploaded-files-integrity):

```shell
sudo gitlab-rake gitlab:artifacts:check
sudo gitlab-rake gitlab:lfs:check
sudo gitlab-rake gitlab:uploads:check
```

## Restore for Docker image and GitLab Helm chart installations

For GitLab installations using the Docker image or the GitLab Helm chart on a
Kubernetes cluster, the restore task expects the restore directories to be
empty. However, with Docker and Kubernetes volume mounts, some system level
directories may be created at the volume roots, such as the `lost+found`
directory found in Linux operating systems. These directories are usually owned
by `root`, which can cause access permission errors since the restore Rake task
runs as the `git` user. To restore a GitLab installation, users have to confirm
the restore target directories are empty.

For both these installation types, the backup tarball has to be available in
the backup location (default location is `/var/opt/gitlab/backups`).

For Docker installations, the restore task can be run from host:

```shell
# Stop the processes that are connected to the database
docker exec -it <name of container> gitlab-ctl stop puma
docker exec -it <name of container> gitlab-ctl stop sidekiq

# Verify that the processes are all down before continuing
docker exec -it <name of container> gitlab-ctl status

# Run the restore. NOTE: "_gitlab_backup.tar" is omitted from the name
docker exec -it <name of container> gitlab-backup restore BACKUP=11493107454_2018_04_25_10.6.4-ce

# Restart the GitLab container
docker restart <name of container>

# Check GitLab
docker exec -it <name of container> gitlab-rake gitlab:check SANITIZE=true
```

Users of GitLab 12.1 and earlier should use the command `gitlab-rake gitlab:backup:create` instead.

WARNING:
`gitlab-rake gitlab:backup:restore` doesn't set the correct file system
permissions on your Registry directory. This is a [known issue](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/62759).
In GitLab 12.2 or later, you can use `gitlab-backup restore` to avoid this
issue.

The GitLab Helm chart uses a different process, documented in
[restoring a GitLab Helm chart installation](https://gitlab.com/gitlab-org/charts/gitlab/blob/master/doc/backup-restore/restore.md).

## Restore for installation from source

First, ensure your backup tar file is in the backup directory described in the
`gitlab.yml` configuration:

```yaml
## Backup settings
backup:
  path: "tmp/backups"   # Relative paths are relative to Rails.root (default: tmp/backups/)
```

The default is `/home/git/gitlab/tmp/backups`, and it needs to be owned by the `git` user. Now, you can begin the backup procedure:

```shell
# Stop processes that are connected to the database
sudo service gitlab stop

sudo -u git -H bundle exec rake gitlab:backup:restore RAILS_ENV=production
```

Example output:

```plaintext
Unpacking backup... [DONE]
Restoring database tables:
-- create_table("events", {:force=>true})
   -> 0.2231s
[...]
- Loading fixture events...[DONE]
- Loading fixture issues...[DONE]
- Loading fixture keys...[SKIPPING]
- Loading fixture merge_requests...[DONE]
- Loading fixture milestones...[DONE]
- Loading fixture namespaces...[DONE]
- Loading fixture notes...[DONE]
- Loading fixture projects...[DONE]
- Loading fixture protected_branches...[SKIPPING]
- Loading fixture schema_migrations...[DONE]
- Loading fixture services...[SKIPPING]
- Loading fixture snippets...[SKIPPING]
- Loading fixture taggings...[SKIPPING]
- Loading fixture tags...[SKIPPING]
- Loading fixture users...[DONE]
- Loading fixture users_projects...[DONE]
- Loading fixture web_hooks...[SKIPPING]
- Loading fixture wikis...[SKIPPING]
Restoring repositories:
- Restoring repository abcd... [DONE]
- Object pool 1 ...
Deleting tmp directories...[DONE]
```

Next, restore `/home/git/gitlab/.secret` if necessary, [as previously mentioned](#restore-prerequisites).

Restart GitLab:

```shell
sudo service gitlab restart
```

## Restoring only one or a few projects or groups from a backup

Although the Rake task used to restore a GitLab instance doesn't support
restoring a single project or group, you can use a workaround by restoring
your backup to a separate, temporary GitLab instance, and then export your
project or group from there:

1. [Install a new GitLab](../install/index.md) instance at the same version as
   the backed-up instance from which you want to restore.
1. [Restore the backup](#restore-gitlab) into this new instance, then
   export your [project](../user/project/settings/import_export.md)
   or [group](../user/group/settings/import_export.md). Be sure to read the
   **Important Notes** on either export feature's documentation to understand
   what is and isn't exported.
1. After the export is complete, go to the old instance and then import it.
1. After importing the projects or groups that you wanted is complete, you may
   delete the new, temporary GitLab instance.

A feature request to provide direct restore of individual projects or groups
is being discussed in [issue #17517](https://gitlab.com/gitlab-org/gitlab/-/issues/17517).

## Restore options

The command line tool GitLab provides to restore from backup can accept more
options.

### Disabling prompts during restore

During a restore from backup, the restore script may ask for confirmation before
proceeding. If you wish to disable these prompts, you can set the `GITLAB_ASSUME_YES`
environment variable to `1`.

For Omnibus GitLab packages:

```shell
sudo GITLAB_ASSUME_YES=1 gitlab-backup restore
```

For installations from source:

```shell
sudo -u git -H GITLAB_ASSUME_YES=1 bundle exec rake gitlab:backup:restore RAILS_ENV=production
```

### Excluding tasks on restore

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/19347) in GitLab 14.10.

You can exclude specific tasks on restore by adding the environment variable `SKIP`, whose values are a comma-separated list of the following options:

- `db` (database)
- `uploads` (attachments)
- `builds` (CI job output logs)
- `artifacts` (CI job artifacts)
- `lfs` (LFS objects)
- `terraform_state` (Terraform states)
- `registry` (Container Registry images)
- `pages` (Pages content)
- `repositories` (Git repositories data)
- `packages` (Packages)

For Omnibus GitLab packages:

```shell
sudo gitlab-backup restore BACKUP=timestamp_of_backup SKIP=db,uploads
```

For installations from source:

```shell
sudo -u git -H bundle exec rake gitlab:backup:restore BACKUP=timestamp_of_backup SKIP=db,uploads RAILS_ENV=production
```

### Restore specific repository storages

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/86896) in GitLab 15.0.

When using [multiple repository storages](../administration/repository_storage_paths.md),
repositories from specific repository storages can be restored separately
using the `REPOSITORIES_STORAGES` option. The option accepts a comma-separated list of
storage names.

For example, for Omnibus GitLab installations:

```shell
sudo gitlab-backup restore BACKUP=timestamp_of_backup REPOSITORIES_STORAGES=storage1,storage2
```

For example, for installations from source:

```shell
sudo -u git -H bundle exec rake gitlab:backup:restore BACKUP=timestamp_of_backup REPOSITORIES_STORAGES=storage1,storage2
```

### Restore specific repositories

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/88094) in GitLab 15.1.

You can restore specific repositories using the `REPOSITORIES_PATHS` option.
The option accepts a comma-separated list of project and group paths. If you
specify a group path, all repositories in all projects in the group and
descendent groups are included. The project and group repositories must exist
within the specified backup.

For example, to restore all repositories for all projects in **Group A** (`group-a`), and the repository for **Project C** in **Group B** (`group-b/project-c`):

- Omnibus GitLab installations:

  ```shell
  sudo gitlab-backup restore BACKUP=timestamp_of_backup REPOSITORIES_PATHS=group-a,group-b/project-c
  ```

- Installations from source:

  ```shell
  sudo -u git -H bundle exec rake gitlab:backup:restore BACKUP=timestamp_of_backup REPOSITORIES_PATHS=group-a,group-b/project-c
  ```
