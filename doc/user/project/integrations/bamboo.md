# Atlassian Bamboo CI Service

GitLab provides integration with Atlassian Bamboo for continuous integration.
When configured, pushes to a project will trigger a build in Bamboo automatically.
Merge requests will also display CI status showing whether the build is pending,
failed, or completed successfully. It also provides a link to the Bamboo build
page for more information.

Bamboo doesn't quite provide the same features as a traditional build system when
it comes to accepting webhooks and commit data. There are a few things that
need to be configured in a Bamboo build plan before GitLab can integrate.

## Setup

### Complete these steps in Bamboo

1. Navigate to a Bamboo build plan and choose 'Configure plan' from the 'Actions'
   dropdown.
1. Select the 'Triggers' tab.
1. Click 'Add trigger'.
1. Enter a description such as 'GitLab trigger'
1. Choose 'Repository triggers the build when changes are committed'
1. Check one or more repositories checkboxes
1. Enter the GitLab IP address in the 'Trigger IP addresses' box. This is a
   whitelist of IP addresses that are allowed to trigger Bamboo builds.
1. Save the trigger.
1. In the left pane, select a build stage. If you have multiple build stages
   you want to select the last stage that contains the git checkout task.
1. Select the 'Miscellaneous' tab.
1. Under 'Pattern Match Labelling' put '${bamboo.repository.revision.number}'
   in the 'Labels' box.
1. Save

Bamboo is now ready to accept triggers from GitLab. Next, set up the Bamboo
service in GitLab.

### Complete these steps in GitLab

1. Navigate to the project you want to configure to trigger builds.
1. Navigate to the [Integrations page](project_services.md#accessing-the-project-services)
1. Click 'Atlassian Bamboo CI'
1. Select the 'Active' checkbox.
1. Enter the base URL of your Bamboo server. `https://bamboo.example.com`
1. Enter the build key from your Bamboo build plan. Build keys are typically made
   up from the Project Key and Plan Key that are set on project/plan creation and
   separated with a dash (`-`), for example  **PROJ-PLAN**. This is a short, all
   uppercase identifier that is unique. When viewing a plan within Bamboo, the
   build key is also shown in the browser URL, for example `https://bamboo.example.com/browse/PROJ-PLAN`.
1. If necessary, enter username and password for a Bamboo user that has
   access to trigger the build plan. Leave these fields blank if you do not require
   authentication.
1. Save or optionally click 'Test Settings'. Please note that 'Test Settings'
   will actually trigger a build in Bamboo.

## Troubleshooting

If builds are not triggered, ensure you entered the right GitLab IP address in
Bamboo under 'Trigger IP addresses'.

> **Note:**
> - Starting with GitLab 8.14.0, builds are triggered on push events.
