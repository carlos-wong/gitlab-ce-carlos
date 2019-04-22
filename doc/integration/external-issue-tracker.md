# External issue tracker

GitLab has a great [issue tracker](../user/project/issues/index.md) but you can also use an external one
such as Jira, Redmine, YouTrack, or Bugzilla. External issue trackers are configurable per GitLab project.

Once configured, you can reference external issues using the format `CODE-123`, where:

- `CODE` is a unique code for the tracker.
- `123` is the issue number in the tracker.

These references in GitLab merge requests, commits, or comments are automatically converted to links to the issues.

You can keep GitLab's issue tracker enabled in parallel or disable it. When enabled, the **Issues** link in the
GitLab menu always opens the internal issue tracker. When disabled, the link is not visible in the menu.

## Configuration

The configuration is done via a project's **Services**.

### Project Service

To enable an external issue tracker you must configure the appropriate **Service**.
Visit the links below for details:

- [Redmine](../user/project/integrations/redmine.md)
- [YouTrack](../user/project/integrations/youtrack.md)
- [Jira](../user/project/integrations/jira.md)
- [Bugzilla](../user/project/integrations/bugzilla.md)
- [Custom Issue Tracker](../user/project/integrations/custom_issue_tracker.md)

### Service Template

To save you the hassle from configuring each project's service individually,
GitLab provides the ability to set Service Templates which can then be
overridden in each project's settings.

Read more on [Services Templates](../user/project/integrations/services_templates.md).
