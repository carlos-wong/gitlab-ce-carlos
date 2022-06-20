---
disqus_identifier: 'https://docs.gitlab.com/ee/workflow/notifications.html'
stage: Plan
group: Project Management
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Notification emails **(FREE)**

Stay informed about what's happening in GitLab with email notifications.
You can receive updates about activity in issues, merge requests, epics, and designs.

For the tool that GitLab administrators can use to send messages to users, read
[Email from GitLab](../admin_area/email_from_gitlab.md).

## Who receives notifications

When notifications are enabled for an issue, merge request, or epic, GitLab notifies you of actions
that happen there.

You might receive notifications for one of the following reasons:

- You participate in an issue, merge request, epic, or design. You become a participant when you comment
  or edit, or someone mentions <sup>1</sup> you.
- You've [enabled notifications in an issue, merge request, or epic](#notifications-on-issues-merge-requests-and-epics).
- You've configured notifications for the [project](#change-level-of-project-notifications) or [group](#group-notifications).
- You're subscribed to group or project pipeline notifications via the pipeline emails [integration](../project/integrations/overview.md).

1. GitLab doesn't send a notification when
   [a comment is edited to include a user mention](../discussions/index.md#editing-a-comment-to-add-a-mention).

NOTE:
Administrators can block notifications, preventing them from being sent.

## Edit notification settings

Getting many notifications can be overwhelming. You can tune the notifications you receive.
For example, you might want to be notified about all activity in a specific project.
For other projects, you only want to be notified when you are mentioned by name.

These notification settings apply only to you. They do not affect the notifications received by
anyone else.

To edit your notification settings:

1. In the top-right corner, select your avatar.
1. Select **Preferences**.
1. On the left sidebar, select **Notifications**.
1. Edit the desired global, group, or project notification settings.
   Edited settings are automatically saved.

### Notification scope

You can tune the scope of your notifications by selecting different notification levels for each
project and group.

Notification scope is applied from the broadest to most specific levels:

- Your **global**, or _default_, notification level applies if you
  have not selected a notification level for the project or group in which the activity occurred.
- Your **group** setting overrides your default setting.
- Your **project** setting overrides the group setting.

### Notification levels

For each project and group you can select one of the following levels:

| Level       | Description                                                 |
| ----------- | ----------------------------------------------------------- |
| Global      | Your global settings apply.                                 |
| Watch       | Receive notifications for any activity.                     |
| Participate | Receive notifications for threads you have participated in. |
| On mention  | Receive notifications when you are [mentioned](../discussions/index.md#mentions) in a comment. |
| Disabled    | Receive no notifications.                                   |
| Custom      | Receive notifications for selected events.                  |

### Global notification settings

Your **Global notification settings** are the default settings unless you select
different values for a project or a group.

- **Notification email**: the email address your notifications are sent to.
  Defaults to your primary email address.
- **Receive product marketing emails**: select this checkbox to receive
  [periodic emails](#opt-out-of-product-marketing-emails) about GitLab features.
- **Global notification level**: the default [notification level](#notification-levels)
  which applies to all your notifications.
- **Receive notifications about your own activity**: select this checkbox to receive
  notifications about your own activity. Not selected by default.

### Group notifications

You can select a notification level and email address for each group.

#### Change level of group notifications

To select a notification level for a group, use either of these methods:

1. In the top-right corner, select your avatar.
1. Select **Preferences**.
1. On the left sidebar, select **Notifications**.
1. Locate the project in the **Groups** section.
1. Select the desired [notification level](#notification-levels).

Or:

1. On the top bar, select **Menu > Groups** and find your group.
1. Select the notification dropdown, next to the bell icon (**{notifications}**).
1. Select the desired [notification level](#notification-levels).

#### Change email address used for group notifications

> Introduced in GitLab 12.0.

You can select an email address to receive notifications for each group you belong to.
You can use group notifications, for example, if you work freelance, and want to keep email about clients' projects separate.

1. In the top-right corner, select your avatar.
1. Select **Preferences**.
1. On the left sidebar, select **Notifications**.
1. Locate the project in the **Groups** section.
1. Select the desired email address.

### Change level of project notifications

To help you stay up to date, you can select a notification level for each project.

To select a notification level for a project, use either of these methods:

1. In the top-right corner, select your avatar.
1. Select **Preferences**.
1. On the left sidebar, select **Notifications**.
1. Locate the project in the **Projects** section.
1. Select the desired [notification level](#notification-levels).

Or:

1. On the top bar, select **Menu > Projects** and find your project.
1. Select the notification dropdown, next to the bell icon (**{notifications}**).
1. Select the desired [notification level](#notification-levels).

<i class="fa fa-youtube-play youtube" aria-hidden="true"></i>
To learn how to be notified when a new release is available, watch [Notification for releases](https://www.youtube.com/watch?v=qyeNkGgqmH4).

### Opt out of product marketing emails

You can receive emails that teach you about various GitLab features.
These emails are enabled by default.

To opt out:

1. In the top-right corner, select your avatar.
1. Select **Preferences**.
1. On the left sidebar, select **Notifications**.
1. Clear the **Receive product marketing emails** checkbox.
   Edited settings are automatically saved and enabled.

Disabling these emails does not disable all emails.
Learn how to [opt out of all emails from GitLab](#opt-out-of-all-gitlab-emails).

#### Self-managed product marketing emails **(FREE SELF)**

The self-managed installation generates and automatically sends these emails based on user actions.
Turning this on does not cause your GitLab instance or your company to send any personal information to
GitLab Inc.

An instance administrator can configure this setting for all users. If you choose to opt out, your
setting overrides the instance-wide setting, even when an administrator later enables these emails
for all users.

## Notification events

Users are notified of the following events:

<!-- The table is sorted first by recipient, then alphabetically. -->

| Event                                    | Sent to         | Settings level                                                                                                                          |
|------------------------------------------|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| New release                              | Project members | Custom notification.                                                                                                                    |
| Project moved                            | Project members | Any other than disabled.                                                                                                                |
| Email changed                            | User            | Security email, always sent.                                                                                                            |
| Group access level changed               | User            | Sent when user group access level is changed.                                                                                           |
| New email address added                  | User            | Security email, sent to primary email address. _[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/337635) in GitLab 14.9._     |
| New email address added                  | User            | Security email, sent to newly-added email address.                                                                                      |
| New SAML/SCIM user provisioned           | User            | Sent when a user is provisioned through SAML/SCIM. _[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/276018) in GitLab 13.8._ |
| New SSH key added                        | User            | Security email, always sent.                                                                                                            |
| New user created                         | User            | Sent on user creation, except for OmniAuth (LDAP).                                                                                      |
| Password changed                         | User            | Security email, always sent when user changes their own password.                                                                       |
| Password changed by administrator        | User            | Security email, always sent when an administrator changes the password of another user.                                                 |
| Personal access tokens expiring soon     | User            | Security email, always sent.                                                                                                            |
| Personal access tokens have been created | User            | Security email, always sent. _[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/337591) in GitLab 14.9._                       |
| Personal access tokens have expired      | User            | Security email, always sent.                                                                                                            |
| Project access level changed             | User            | Sent when user project access level is changed.                                                                                         |
| SSH key has expired                      | User            | Security email, always sent. _[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/322637) in GitLab 13.12._                      |
| Two-factor authentication disabled       | User            | Security email, always sent.                                                                                                            |
| User added to group                      | User            | Sent when user is added to group.                                                                                                       |
| User added to project                    | User            | Sent when user is added to project.                                                                                                     |

## Notifications on issues, merge requests, and epics

You also receive notifications for events happening on
issues, merge requests, and epics.

### Who receives notifications on issues, merge requests, and epics

In issues, merge requests, and epics, for most events, the notification is sent to:

- Participants:
  - The author and assignee.
  - Authors of comments.
  - Anyone [mentioned](../discussions/index.md#mentions) by username in the title
    or description.
  - Anyone mentioned by username in a comment if their notification level is "Participating" or higher.
- Watchers: users with notification level "Watch".
- Subscribers: anyone who manually subscribed to notifications.
- Custom: users with notification level "Custom" who turned on notifications for a fitting type of events.

NOTE:
To minimize the number of notifications that do not require any action, in
[GitLab 12.9 and later](https://gitlab.com/gitlab-org/gitlab/-/issues/616), eligible
approvers are no longer notified for all the activities in their projects. To turn on such notifications, they have
to change their user notification settings to **Watch** instead.

### Edit notification settings for issues, merge requests, and epics

To enable notifications on a specific issue, merge request, or epic, you must turn on the
**Notifications** toggle in the right sidebar.

- To subscribe, **turn on** if you are not a participant in the discussion, but want to receive
  notifications on each update.

  When you turn notifications on in an epic, you aren't automatically subscribed to the issues linked
  to the epic.

- To unsubscribe, **turn off** if you are receiving notifications for updates but no longer want to
  receive them.

  Turning this toggle off only unsubscribes you from updates related to this issue, merge request, or epic.
  Learn how to [opt out of all emails from GitLab](#opt-out-of-all-gitlab-emails).

### Notification events on issues, merge requests, and epics

The following table presents the events that generate notifications for issues, merge requests, and
epics:

| Event                  | Sent to |
|------------------------|---------|
| Change milestone issue | Subscribers and participants mentioned. |
| Change milestone merge request | Subscribers and participants mentioned. |
| Close epic             |         |
| Close issue            |         |
| Close merge request    |         |
| Failed pipeline        | The author of the pipeline. |
| Fixed pipeline         | The author of the pipeline. Enabled by default. _[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/24309) in GitLab 13.1._ |
| Issue due              | Participants and Custom notification level with this event selected. |
| Merge merge request    |         |
| Merge when pipeline succeeds | Author, Participants, Watchers, Subscribers, and Custom notification level with this event selected. Custom notification level is ignored for Author, Watchers and Subscribers. _[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/211961) in GitLab 13.4._ |
| Merge request [marked as ready](../project/merge_requests/drafts.md) | Watchers and participants. _[Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/15332) in GitLab 13.10._ |
| New epic               |         |
| New issue              |         |
| New merge request      |         |
| New note               | Participants, Watchers, Subscribers, and Custom notification level with this event selected. Also anyone mentioned by username in the comment, with notification level "Mention" or higher. |
| Push to merge request  | Participants and Custom notification level with this event selected. |
| Reassign issue         | Participants, Watchers, Subscribers, Custom notification level with this event selected, and the old assignee. |
| Reassign merge request | Participants, Watchers, Subscribers, Custom notification level with this event selected, and the old assignee. |
| Remove milestone issue | Subscribers and participants mentioned. |
| Remove milestone merge request | Subscribers and participants mentioned. |
| Reopen epic            |         |
| Reopen issue           |         |
| Reopen merge request   |         |
| Successful pipeline    | The author of the pipeline, with Custom notification level for successful pipelines. If the pipeline failed previously, a "Fixed pipeline" message is sent for the first successful pipeline after the failure, and then a "Successful pipeline" message for any further successful pipelines. |

If the title or description of an issue or merge request is
changed, notifications are sent to any **new** mentions by username as
if they had been mentioned in the original text.

If an open merge request becomes unmergeable due to conflict, its author is notified about the cause.
If a user has also set the merge request to automatically merge when pipeline succeeds,
then that user is also notified.

By default, you don't receive notifications for issues, merge requests, or epics created by yourself.
To always receive notifications on your own issues, merge requests, and so on, turn on
[notifications about your own activity](#global-notification-settings).

## Notifications on designs

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/217095) in GitLab 13.6.

Email notifications are sent to the participants when someone comments on a design.

The participants are:

- Authors of the design (can be multiple people if different authors have uploaded different versions of the design).
- Authors of comments on the design.
- Anyone that is [mentioned](../discussions/index.md#mentions) in a comment on the design.

## Opt out of all GitLab emails

If you no longer wish to receive any email notifications:

1. In the top-right corner, select your avatar.
1. Select **Preferences**.
1. On the left sidebar, select **Notifications**.
1. Clear the **Receive product marketing emails** checkbox.
1. Set your **Global notification level** to **Disabled**.
1. Clear the **Receive notifications about your own activity** checkbox.
1. If you belong to any groups or projects, set their notification setting to **Global** or
   **Disabled**.

On self-managed installations, even after doing this, your instance administrator
[can still email you](../admin_area/email_from_gitlab.md).
To unsubscribe, select the unsubscribe link in one of these emails.

## Email headers you can use to filter email

Notification email messages include GitLab-specific headers. To better manage your notifications,
you can filter the notification emails based on the content of these headers.

For example, you could filter all emails from a specific project where you are being assigned a
a merge request or an issue.

The following table lists all GitLab-specific email headers:

| Header                                                        | Description                                                                                                                                    |
|---------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| `List-Id`                                                     | The path of the project in an RFC 2919 mailing list identifier. You can use it for email organization with filters.                            |
| `X-GitLab-(Resource)-ID`                                      | The ID of the resource the notification is for. The resource, for example, can be `Issue`, `MergeRequest`, `Commit`, or another such resource. |
| `X-GitLab-Discussion-ID`                                      | The ID of the thread the comment belongs to, in notification emails for comments.                                                              |
| `X-GitLab-Group-Id`                                           | The group's ID. Only present on notification emails for [epics](../group/epics/index.md).                                                      |
| `X-GitLab-Group-Path`                                         | The group's path. Only present on notification emails for [epics](../group/epics/index.md)                                                     |
| [`X-GitLab-NotificationReason`](#x-gitlab-notificationreason) | The reason for the notification. This can be `mentioned`, `assigned`, or `own_activity`.                                                       |
| `X-GitLab-Pipeline-Id`                                        | The ID of the pipeline the notification is for, in notification emails for pipelines.                                                          |
| `X-GitLab-Project-Id`                                         | The project's ID.                                                                                                                              |
| `X-GitLab-Project-Path`                                       | The project's path.                                                                                                                            |
| `X-GitLab-Project`                                            | The name of the project the notification belongs to.                                                                                           |
| `X-GitLab-Reply-Key`                                          | A unique token to support reply by email.                                                                                                      |

### X-GitLab-NotificationReason

The `X-GitLab-NotificationReason` header contains the reason for the notification.
The value is one of the following, in order of priority:

- `own_activity`
- `assigned`
- `mentioned`

The reason for the notification is also included in the footer of the notification email.
For example, an email with the reason `assigned` has this sentence in the footer:

> You are receiving this email because you have been assigned an item on \<configured GitLab hostname>.

For example, an alert notification email can have one of
[the alert's](../../operations/incident_management/alerts.md) statuses:

- `alert_triggered`
- `alert_acknowledged`
- `alert_resolved`
- `alert_ignored`

Expanding the list of events included in the `X-GitLab-NotificationReason` header is tracked in
[issue 20689](https://gitlab.com/gitlab-org/gitlab/-/issues/20689).

## Troubleshooting

### Pull a list of recipients for notifications

If you want to pull a list of recipients to receive notifications from a project
(mainly used for troubleshooting custom notifications),
in a Rails console, run `sudo gitlab-rails c` and be sure to update the project name:

```plaintext
project = Project.find_by_full_path '<project_name>'
merge_request = project.merge_requests.find_by(iid: 1)
current_user = User.first
recipients = NotificationRecipients::BuildService.build_recipients(merge_request, current_user, action: "push_to"); recipients.count
recipients.each { |notify| puts notify.user.username }
```
