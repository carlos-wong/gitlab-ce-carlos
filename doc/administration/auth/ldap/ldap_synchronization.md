---
stage: Manage
group: Authentication and Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# LDAP synchronization **(PREMIUM SELF)**

If you have [configured LDAP to work with GitLab](index.md), GitLab can automatically synchronize
users and groups. This process updates user and group information.

You can change when synchronization occurs.

## User sync

Once per day, GitLab runs a worker to check and update GitLab
users against LDAP.

The process executes the following access checks:

- Ensure the user is still present in LDAP.
- If the LDAP server is Active Directory, ensure the user is active (not
  blocked/disabled state). This check is performed only if
  `active_directory: true` is set in the LDAP configuration.

In Active Directory, a user is marked as disabled/blocked if the user
account control attribute (`userAccountControl:1.2.840.113556.1.4.803`)
has bit 2 set.

<!-- vale gitlab.Spelling = NO -->

For more information, see [Bitmask Searches in LDAP](https://ctovswild.com/2009/09/03/bitmask-searches-in-ldap/).

<!-- vale gitlab.Spelling = YES -->

The user is set to an `ldap_blocked` state in GitLab if the previous conditions
fail. This means the user cannot sign in or push or pull code.

The process also updates the following user information:

- Email address
- SSH public keys (if `sync_ssh_keys` is set)
- Kerberos identity (if Kerberos is enabled)

### Adjust LDAP user sync schedule

By default, GitLab runs a worker once per day at 01:30 a.m. server time to
check and update GitLab users against LDAP.

You can manually configure LDAP user sync times by setting the
following configuration values, in cron format. If needed, you can
use a [crontab generator](http://www.crontabgenerator.com).
The example below shows how to set LDAP user
sync to run once every 12 hours at the top of the hour.

**Omnibus installations**

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['ldap_sync_worker_cron'] = "0 */12 * * *"
   ```

1. [Reconfigure GitLab](../../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

**Source installations**

1. Edit `config/gitlab.yaml`:

   ```yaml
   cron_jobs:
     ldap_sync_worker_cron:
       "0 */12 * * *"
   ```

1. [Restart GitLab](../../restart_gitlab.md#installations-from-source) for the changes to take effect.

## Group sync

If your LDAP supports the `memberof` property, when the user signs in for the
first time GitLab triggers a sync for groups the user should be a member of.
That way they don't have to wait for the hourly sync to be granted
access to their groups and projects.

A group sync process runs every hour on the hour, and `group_base` must be set
in LDAP configuration for LDAP synchronizations based on group CN to work. This allows
GitLab group membership to be automatically updated based on LDAP group members.

The `group_base` configuration should be a base LDAP 'container', such as an
'organization' or 'organizational unit', that contains LDAP groups that should
be available to GitLab. For example, `group_base` could be
`ou=groups,dc=example,dc=com`. In the configuration file it looks like the
following.

**Omnibus configuration**

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['ldap_servers'] = {
   'main' => {
     # snip...
     'group_base' => 'ou=groups,dc=example,dc=com',
     }
   }
   ```

1. [Apply your changes to GitLab](../../restart_gitlab.md#omnibus-gitlab-reconfigure).

**Source configuration**

1. Edit `/home/git/gitlab/config/gitlab.yml`:

   ```yaml
   production:
     ldap:
       servers:
         main:
           # snip...
           group_base: ou=groups,dc=example,dc=com
   ```

1. [Restart GitLab](../../restart_gitlab.md#installations-from-source) for the changes to take effect.

To take advantage of group sync, group Owners or users with the [Maintainer role](../../../user/permissions.md) must
[create one or more LDAP group links](#add-group-links).

### Add group links

For information on adding group links by using CNs and filters, refer to the
[GitLab groups documentation](../../../user/group/index.md#manage-group-memberships-via-ldap).

### Administrator sync

As an extension of group sync, you can automatically manage your global GitLab
administrators. Specify a group CN for `admin_group` and all members of the
LDAP group are given administrator privileges. The configuration looks
like the following.

NOTE:
Administrators are not synced unless `group_base` is also
specified alongside `admin_group`. Also, only specify the CN of the `admin_group`,
as opposed to the full DN.
Additionally, if an LDAP user has an `admin` role, but is not a member of the `admin_group`
group, GitLab revokes their `admin` role when syncing.

**Omnibus configuration**

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['ldap_servers'] = {
   'main' => {
     # snip...
     'group_base' => 'ou=groups,dc=example,dc=com',
     'admin_group' => 'my_admin_group',
     }
   }
   ```

1. [Apply your changes to GitLab](../../restart_gitlab.md#omnibus-gitlab-reconfigure).

**Source configuration**

1. Edit `/home/git/gitlab/config/gitlab.yml`:

   ```yaml
   production:
     ldap:
       servers:
         main:
           # snip...
           group_base: ou=groups,dc=example,dc=com
           admin_group: my_admin_group
   ```

1. [Restart GitLab](../../restart_gitlab.md#installations-from-source) for the changes to take effect.

### Global group memberships lock

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/1793) in GitLab 12.0.

"Lock memberships to LDAP synchronization" setting allows instance administrators
to lock down user abilities to invite new members to a group.

When enabled, the following applies:

- Only an administrator can manage memberships of any group including access levels.
- Users are not allowed to share a project with other groups or invite members to
  a project created in a group.

To enable it, you must:

1. [Configure LDAP](index.md#configure-ldap).
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > General**.
1. Expand the **Visibility and access controls** section.
1. Ensure the **Lock memberships to LDAP synchronization** checkbox is selected.

### Adjust LDAP group sync schedule

By default, GitLab runs a group sync process every hour, on the hour.
The values shown are in cron format. If needed, you can use a
[Crontab Generator](http://www.crontabgenerator.com).

WARNING:
Do not start the sync process too frequently as this
could lead to multiple syncs running concurrently. This concern is primarily
for installations with a large number of LDAP users. Review the
[LDAP group sync benchmark metrics](#benchmarks) to see how
your installation compares before proceeding.

You can manually configure LDAP group sync times by setting the
following configuration values. The example below shows how to set group
sync to run once every two hours at the top of the hour.

**Omnibus installations**

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['ldap_group_sync_worker_cron'] = "0 */2 * * * *"
   ```

1. [Reconfigure GitLab](../../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

**Source installations**

1. Edit `config/gitlab.yaml`:

   ```yaml
   cron_jobs:
     ldap_group_sync_worker_cron:
         "*/30 * * * *"
   ```

1. [Restart GitLab](../../restart_gitlab.md#installations-from-source) for the changes to take effect.

### External groups

Using the `external_groups` setting allows you to mark all users belonging
to these groups as [external users](../../../user/permissions.md#external-users).
Group membership is checked periodically through the `LdapGroupSync` background
task.

**Omnibus configuration**

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_rails['ldap_servers'] = {
   'main' => {
     # snip...
     'external_groups' => ['interns', 'contractors'],
     }
   }
   ```

1. [Apply your changes to GitLab](../../restart_gitlab.md#omnibus-gitlab-reconfigure).

**Source configuration**

1. Edit `config/gitlab.yaml`:

   ```yaml
   production:
     ldap:
       servers:
         main:
           # snip...
           external_groups: ['interns', 'contractors']
   ```

1. [Restart GitLab](../../restart_gitlab.md#installations-from-source) for the changes to take effect.

### Group sync technical details

This section outlines what LDAP queries are executed and what behavior you
can expect from group sync.

Group member access are downgraded from a higher level if their LDAP group
membership changes. For example, if a user the Owner role in a group and the
next group sync reveals they should only have the Developer role, their
access is adjusted accordingly. The only exception is if the user is the
last owner in a group. Groups need at least one owner to fulfill
administrative duties.

#### Supported LDAP group types/attributes

GitLab supports LDAP groups that use member attributes:

- `member`
- `submember`
- `uniquemember`
- `memberof`
- `memberuid`

This means group sync supports (at least) LDAP groups with the following object
classes:

- `groupOfNames`
- `posixGroup`
- `groupOfUniqueNames`

Other object classes should work if members are defined as one of the
mentioned attributes.

Active Directory supports nested groups. Group sync recursively resolves
membership if `active_directory: true` is set in the configuration file.

##### Nested group memberships

Nested group memberships are resolved only if the nested group
is found in the configured `group_base`. For example, if GitLab sees a
nested group with DN `cn=nested_group,ou=special_groups,dc=example,dc=com` but
the configured `group_base` is `ou=groups,dc=example,dc=com`, `cn=nested_group`
is ignored.

#### Queries

- Each LDAP group is queried a maximum of one time with base `group_base` and
  filter `(cn=<cn_from_group_link>)`.
- If the LDAP group has the `memberuid` attribute, GitLab executes another
  LDAP query per member to obtain each user's full DN. These queries are
  executed with base `base`, scope 'base object', and a filter depending on
  whether `user_filter` is set. Filter may be `(uid=<uid_from_group>)` or a
  joining of `user_filter`.

#### Benchmarks

Group sync was written to be as performant as possible. Data is cached, database
queries are optimized, and LDAP queries are minimized. The last benchmark run
revealed the following metrics:

For 20,000 LDAP users, 11,000 LDAP groups, and 1,000 GitLab groups with 10
LDAP group links each:

- Initial sync (no existing members assigned in GitLab) took 1.8 hours
- Subsequent syncs (checking membership, no writes) took 15 minutes

These metrics are meant to provide a baseline and performance may vary based on
any number of factors. This benchmark was extreme and most instances don't
have near this many users or groups. Disk speed, database performance,
network and LDAP server response time affects these metrics.

## Troubleshooting

See our [administrator guide to troubleshooting LDAP](ldap-troubleshooting.md).
