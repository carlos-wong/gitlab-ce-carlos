---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
disqus_identifier: 'https://docs.gitlab.com/ee/workflow/repository_mirroring.html'
---

# Pull from a remote repository **(PREMIUM)**

> Moved to GitLab Premium in 13.9.

You can use the GitLab interface to browse the content and activity of a repository,
even if it isn't hosted on GitLab. Create a pull [mirror](index.md) to copy the
branches, tags, and commits from an upstream repository to yours.

Unlike [push mirrors](push.md), pull mirrors retrieve changes from an upstream (remote)
repository on a scheduled basis. To prevent the mirror from diverging from the upstream
repository, don't push commits directly to the downstream mirror. Push commits to
the upstream repository instead. Changes in the remote repository are pulled into the GitLab repository, either:

- Automatically in a certain period of time. Self-managed instances can
  configure [pull mirroring intervals](../../../../administration/instance_limits.md#pull-mirroring-interval).
- When an administrator [force-updates the mirror](index.md#force-an-update).
- When an [API call triggers an update](#trigger-an-update-by-using-the-api).

By default, if any branch or tag on the downstream pull mirror diverges from the
local repository, GitLab stops updating the branch. This prevents data loss.
Deleted branches and tags in the upstream repository are not reflected in the
downstream repository.

## How pull mirroring works

After you configure a GitLab repository as a pull mirror:

1. GitLab adds the repository to a queue.
1. Once per minute, a Sidekiq cron job schedules repository mirrors to update, based on:
   - Available capacity, determined by Sidekiq settings. For GitLab.com, read
     [GitLab.com Sidekiq settings](../../../gitlab_com/index.md#sidekiq).
   - How many mirrors are already in the queue and due for updates. Being due depends
     on when the repository mirror was last updated, and how many times updates have been retried.
1. Sidekiq becomes available to process updates, mirrors are updated. If the update process:
   - **Succeeds**: An update is enqueued again with at least a 30 minute wait.
   - **Fails**: The update is attempted again later. After 14 failures, a mirror is marked as a
     [hard failure](#fix-hard-failures-when-mirroring) and is no longer enqueued for updates. A branch diverging
     from its upstream counterpart can cause failures. To prevent branches from
     diverging, configure [Overwrite diverged branches](#overwrite-diverged-branches) when
     you create your mirror.

## Configure pull mirroring

Prerequisite:

- If your remote repository is on GitHub and you have
  [two-factor authentication (2FA) configured](https://docs.github.com/en/authentication/securing-your-account-with-two-factor-authentication-2fa),
  create a [personal access token for GitHub](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
  with the `repo` scope. If 2FA is enabled, this personal access
  token serves as your GitHub password.

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Repository**.
1. Expand **Mirroring repositories**.
1. Enter the **Git repository URL**. Include the username
   in the URL, if required: `https://MYUSERNAME@github.com/GROUPNAME/PROJECTNAME.git`
1. In **Mirror direction**, select **Pull**.
1. In **Authentication method**, select your authentication method. To learn more, read
   [Authentication methods for mirrors](index.md#authentication-methods-for-mirrors).
1. Select any of the options you need:
   - [**Overwrite diverged branches**](#overwrite-diverged-branches)
   - [**Trigger pipelines for mirror updates**](#trigger-pipelines-for-mirror-updates)
   - **Only mirror protected branches**
1. To save the configuration, select **Mirror repository**.

### Overwrite diverged branches

> Moved to GitLab Premium in 13.9.

To always update your local branches with remote versions, even if they have
diverged from the remote, select **Overwrite diverged branches** when you
create a mirror.

WARNING:
For mirrored branches, enabling this option results in the loss of local changes.

### Trigger pipelines for mirror updates

> Moved to GitLab Premium in 13.9.

If this option is enabled, pipelines trigger when branches or tags are
updated from the remote repository. Depending on the activity of the remote
repository, this may greatly increase the load on your CI runners. Only enable
this feature if you know they can handle the load. CI uses the credentials
assigned when you set up pull mirroring.

## Trigger an update by using the API

> Moved to GitLab Premium in 13.9.

Pull mirroring uses polling to detect new branches and commits added upstream,
often minutes afterwards. You can notify GitLab using an
[API call](../../../../api/projects.md#start-the-pull-mirroring-process-for-a-project),
but the [minimum interval for pull mirroring limits](index.md#force-an-update) is still enforced.

For more information, read
[Start the pull mirroring process for a project](../../../../api/projects.md#start-the-pull-mirroring-process-for-a-project).

## Fix hard failures when mirroring

> Moved to GitLab Premium in 13.9.

After 14 consecutive unsuccessful retries, the mirroring process is marked as a hard failure
and mirroring attempts stop. This failure is visible in either the:

- Project's main dashboard.
- Pull mirror settings page.

To resume project mirroring, [force an update](index.md#force-an-update).

If many projects are affected by this problem, such as after a long network or
server outage, you can use the [Rails console](../../../../administration/operations/rails_console.md)
to identify and update all affected projects with this command:

```ruby
Project.find_each do |p|
  if p.import_state && p.import_state.retry_count >= 14
    puts "Resetting mirroring operation for #{p.full_path}"
    p.import_state.reset_retry_count
    p.import_state.set_next_execution_to_now(prioritized: true)
    p.import_state.save!
  end
end
```

## Related topics

- Configure [pull mirroring intervals](../../../../administration/instance_limits.md#pull-mirroring-interval)
  on self-managed instances.
- Configure [pull mirroring through the API](../../../../api/projects.md#configure-pull-mirroring-for-a-project).
