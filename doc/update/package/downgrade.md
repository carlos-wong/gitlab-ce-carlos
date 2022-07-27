---
stage: Systems
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Downgrade **(FREE SELF)**

This section contains general information on how to revert to an earlier version
of a package.

WARNING:
You must at least have a database backup created under the version you are
downgrading to. Ideally, you should have a
[full backup archive](../../raketasks/backup_restore.md)
on hand.

The example below demonstrates the downgrade procedure when downgrading between minor
and patch versions (for example, from 13.0.6 to 13.0.5).

When downgrading between major versions, take into account the
[specific version changes](index.md#version-specific-changes) that occurred when you upgraded
to the major version you are downgrading from.

These steps consist of:

- Stopping GitLab
- Removing the current package
- Installing the old package
- Reconfiguring GitLab
- Restoring the backup
- Starting GitLab

Steps:

1. Stop GitLab and remove the current package:

   ```shell
   # If running Puma
   sudo gitlab-ctl stop puma

   # Stop sidekiq
   sudo gitlab-ctl stop sidekiq

   # If on Ubuntu: remove the current package
   sudo dpkg -r gitlab-ee

   # If on Centos: remove the current package
   sudo yum remove gitlab-ee
   ```

1. Identify the GitLab version you want to downgrade to:

   ```shell
   # (Replace with gitlab-ce if you have GitLab FOSS installed)

   # Ubuntu
   sudo apt-cache madison gitlab-ee

   # CentOS:
   sudo yum --showduplicates list gitlab-ee
   ```

1. Downgrade GitLab to the desired version (for example, to GitLab 13.0.5):

   ```shell
   # (Replace with gitlab-ce if you have GitLab FOSS installed)

   # Ubuntu
   sudo apt install gitlab-ee=13.0.5-ee.0

   # CentOS:
   sudo yum install gitlab-ee-13.0.5-ee.0.el8
   ```

1. Reconfigure GitLab:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

1. [Restore GitLab](../../raketasks/restore_gitlab.md#restore-for-omnibus-gitlab-installations)
   to complete the downgrade.
