---
stage: Ecosystem
group: Integrations
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Asana integration **(FREE)**

This integration adds commit messages as comments to Asana tasks.
Once enabled, commit messages are checked for Asana task URLs (for example,
`https://app.asana.com/0/123456/987654`) or task IDs starting with `#`
(for example, `#987654`). Every task ID found gets the commit comment added to it.

You can also close a task with a message containing: `fix #123456`.
You can use either of these words:

- `fix`
- `fixed`
- `fixes`
- `fixing`
- `close`
- `closes`
- `closed`
- `closing`

See also the [Asana integration API documentation](../../../api/integrations.md#asana).

## Setup

In Asana, create a Personal Access Token.
[Learn about Personal Access Tokens in Asana](https://developers.asana.com/docs/personal-access-token).

Complete these steps in GitLab:

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > Integrations**.
1. Select **Asana**.
1. Ensure that the **Active** toggle is enabled.
1. Paste the token you generated in Asana.
1. Optional. To restrict this setting to specific branches, list them in the **Restrict to branch**
   field, separated with commas.
1. Select **Save changes** or optionally select **Test settings**.

<!-- ## Troubleshooting -->
