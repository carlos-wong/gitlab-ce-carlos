---
stage: Ecosystem
group: Integrations
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Integrations **(FREE)**

Integrations allow you to integrate GitLab with other applications. They
are a bit like plugins in that they allow a lot of freedom in adding
functionality to GitLab.

## Accessing integrations

To find the available integrations for your project:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Integrations**.

There are more than 20 integrations to integrate with. Select the one that you
want to configure.

## Integrations listing

Click on the integration links to see further configuration instructions and details.

| Integration                                               | Description                                                                                  | Integration hooks      |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ---------------------- |
| [Asana](asana.md)                                         | Add commit messages as comments to Asana tasks.                                              | **{dotted-circle}** No |
| Assembla                                                  | Manage projects.                                                                             | **{dotted-circle}** No |
| [Atlassian Bamboo CI](bamboo.md)                          | Run CI/CD pipelines with Atlassian Bamboo.                                                   | **{check-circle}** Yes |
| [Bugzilla](bugzilla.md)                                   | Use Bugzilla as the issue tracker.                                                           | **{dotted-circle}** No |
| Buildkite                                                 | Run CI/CD pipelines with Buildkite.                                                          | **{check-circle}** Yes |
| Campfire                                                  | Connect to chat.                                                                             | **{dotted-circle}** No |
| [Confluence Workspace](../../../api/integrations.md#confluence-integration) | Replace the link to the internal wiki with a link to a Confluence Cloud Workspace. | **{dotted-circle}** No |
| [Custom issue tracker](custom_issue_tracker.md)           | Use a custom issue tracker.                                                                  | **{dotted-circle}** No |
| [Datadog](../../../integration/datadog.md)                | Trace your GitLab pipelines with Datadog.                                                    | **{check-circle}** Yes |
| [Discord Notifications](discord_notifications.md)         | Send notifications about project events to a Discord channel.                                | **{dotted-circle}** No |
| Drone CI                                                  | Run CI/CD pipelines with Drone.                                                              | **{check-circle}** Yes |
| [Emails on push](emails_on_push.md)                       | Send commits and diff of each push by email.                                                 | **{dotted-circle}** No |
| [EWM](ewm.md)                                             | Use IBM Engineering Workflow Management as the issue tracker.                                | **{dotted-circle}** No |
| [External wiki](../wiki/index.md#link-an-external-wiki)   | Link an external wiki.                                          | **{dotted-circle}** No |
| [Flowdock](../../../api/integrations.md#flowdock)             | Send notifications from GitLab to Flowdock flows. | **{dotted-circle}** No |
| [GitHub](github.md)                                       | Obtain statuses for commits and pull requests.                                               | **{dotted-circle}** No |
| [Google Chat](hangouts_chat.md)                           | Send notifications from your GitLab project to a room in Google Chat.| **{dotted-circle}** No |
| [Harbor](harbor.md)                           | Use Harbor as the container registry. | **{dotted-circle}** No |
| [irker (IRC gateway)](irker.md)                           | Send IRC messages.                                                                           | **{dotted-circle}** No |
| [Jenkins](../../../integration/jenkins.md)                | Run CI/CD pipelines with Jenkins.                                                            | **{check-circle}** Yes |
| JetBrains TeamCity CI                                     | Run CI/CD pipelines with TeamCity.                                                           | **{check-circle}** Yes |
| [Jira](../../../integration/jira/index.md)                | Use Jira as the issue tracker.                                                               | **{dotted-circle}** No |
| [Mattermost notifications](mattermost.md)                 | Send notifications about project events to Mattermost channels.                              | **{dotted-circle}** No |
| [Mattermost slash commands](mattermost_slash_commands.md) | Perform common tasks with slash commands.                                                    | **{dotted-circle}** No |
| [Microsoft Teams notifications](microsoft_teams.md)       | Receive event notifications.                                                                 | **{dotted-circle}** No |
| Packagist                                                 | Keep your PHP dependencies updated on Packagist.                                             | **{check-circle}** Yes |
| [Pipelines emails](pipeline_status_emails.md)             | Send the pipeline status to a list of recipients by email.                                   | **{dotted-circle}** No |
| [Pivotal Tracker](pivotal_tracker.md)                      | Add commit messages as comments to Pivotal Tracker stories.                                                    | **{dotted-circle}** No |
| [Prometheus](prometheus.md)                               | Monitor application metrics.                                                                 | **{dotted-circle}** No |
| Pushover                                                  | Get real-time notifications on your device.                                                  | **{dotted-circle}** No |
| [Redmine](redmine.md)                                     | Use Redmine as the issue tracker.                                                            | **{dotted-circle}** No |
| [Slack application](gitlab_slack_application.md)          | Use Slack's official GitLab application.                                                     | **{dotted-circle}** No |
| [Slack notifications](slack.md)                           | Send notifications about project events to Slack.                                            | **{dotted-circle}** No |
| [Slack slash commands](slack_slash_commands.md)           | Enable slash commands in workspace.                                                          | **{dotted-circle}** No |
| [Unify Circuit](unify_circuit.md)                         | Send notifications about project events to Unify Circuit.                                    | **{dotted-circle}** No |
| [Webex Teams](webex_teams.md)                             | Receive events notifications.                                                                | **{dotted-circle}** No |
| [YouTrack](youtrack.md)                                   | Use YouTrack as the issue tracker.                                                           | **{dotted-circle}** No |
| [ZenTao](zentao.md)                                       | Use ZenTao as the issue tracker.                                                           | **{dotted-circle}** No |

## Push hooks limit

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/17874) in GitLab 12.4.

If a single push includes changes to more than three branches or tags, integrations
supported by `push_hooks` and `tag_push_hooks` events aren't executed.

The number of branches or tags supported can be changed via
[`push_event_hooks_limit` application setting](../../../api/settings.md#list-of-settings-that-can-be-accessed-via-api-calls).

## Project integration management

Project integration management lets you control integration settings across all projects
of an instance. On the project level, administrators you can choose whether to inherit the
instance configuration or provide custom settings.

Read more about [Project integration management](../../admin_area/settings/project_integration_management.md).

## SSL verification

By default, the SSL certificate for outgoing HTTP requests is verified based on
an internal list of Certificate Authorities. This means the certificate cannot
be self-signed.

You can turn off SSL verification in the configuration settings for [webhooks](webhooks.md#configure-a-webhook-in-gitlab)
and some integrations.

## Troubleshooting integrations

Some integrations use hooks for integration with external applications. To confirm which ones use integration hooks, see the [integrations listing](#integrations-listing) above. Learn more about [troubleshooting integration hooks](webhooks.md#troubleshoot-webhooks).

### Uninitialized repositories

Some integrations fail with an error `Test Failed. Save Anyway` when you attempt to set them up on
uninitialized repositories. Some integrations use push data to build the test payload,
and this error occurs when no push events exist in the project yet.

To resolve this error, initialize the repository by pushing a test file to the project and set up
the integration again.

## Contributing to integrations

Because GitLab is open source we can ship with the code and tests for all
plugins. This allows the community to keep the plugins up to date so that they
always work in newer GitLab versions.

For an overview of what integrations are available, please see the
[integrations source directory](https://gitlab.com/gitlab-org/gitlab/-/tree/master/app/models/integrations).

Contributions are welcome!
