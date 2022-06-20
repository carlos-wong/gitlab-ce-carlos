---
stage: Ecosystem
group: Integrations
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Set up a development environment **(FREE)**

The following are required to install and test the app:

- A Jira Cloud instance. Atlassian provides [free instances for development and testing](https://developer.atlassian.com/platform/marketplace/getting-started/#free-developer-instances-to-build-and-test-your-app).
- A GitLab instance available over the internet. For the app to work, Jira Cloud should
  be able to connect to the GitLab instance through the internet. For this we
  recommend using Gitpod or a similar cloud development environment. For more
  information on using Gitpod with GDK, see the:

  - [GDK in Gitpod](https://www.loom.com/share/9c9711d4876a40869b9294eecb24c54d)
    video.
  - [GDK with Gitpod](https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/gitpod.md)
    documentation.

  <!-- vale gitlab.Spelling = NO -->

  You **must not** use tunneling tools such as Serveo or `ngrok`. These are
  security risks, and must not be run on developer laptops.

  <!-- vale gitlab.Spelling = YES -->

  Jira requires all connections to the app host to be over SSL. If you set up
  your own environment, remember to enable SSL and an appropriate certificate.

## Install the app in Jira

To install the app in Jira:

1. Enable Jira development mode to install apps that are not from the Atlassian
   Marketplace:

   1. In Jira, navigate to **Jira settings > Apps > Manage apps**.
   1. Scroll to the bottom of the **Manage apps** page and click **Settings**.
   1. Select **Enable development mode** and click **Apply**.

1. Install the app:

   1. In Jira, navigate to **Jira settings > Apps > Manage apps**.
   1. Click **Upload app**.
   1. In the **From this URL** field, provide a link to the app descriptor. The host and port must point to your GitLab instance.

      For example:

      ```plaintext
      https://xxxx.gitpod.io/-/jira_connect/app_descriptor.json
      ```

   1. Click **Upload**.

   If the install was successful, you should see the **GitLab.com for Jira Cloud** app under **Manage apps**.
   You can also click **Getting Started** to open the configuration page rendered from your GitLab instance.

   _Note that any changes to the app descriptor requires you to uninstall then reinstall the app._

### Troubleshooting

If the app install failed, you might need to delete `jira_connect_installations` from your database.

1. Open the [database console](https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/postgresql.md#access-postgresql).
1. Run `TRUNCATE TABLE jira_connect_installations CASCADE;`.

#### Not authorized to access the file

If you use Gitpod and you get an error about Jira not being able to access the descriptor file, you might need to make the GDK's port public by following these steps:

1. Open your GitLab workspace in Gitpod.
1. When the GDK is running, select **Ports** in the bottom-right corner.
1. On the left sidebar, select the port the GDK is listening to (typically `3000`).
1. If the port is marked as private, select the lock icon to make it public.

## Test the GitLab OAuth authentication flow

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/81126) in GitLab 14.9 [with a flag](../../administration/feature_flags.md) named `jira_connect_oauth`. Disabled by default.

GitLab for Jira users can authenticate with GitLab using GitLab OAuth.

WARNING:
This feature is not ready for production use. The feature flag should only be enabled in development.

The following steps describe setting up an environment to test the GitLab OAuth flow:

1. Start a Gitpod session and open the rails console.

    ```shell
    bundle exec rails console
    ```

1. Enable the feature flag.

    ```shell
    Feature.enable(:jira_connect_oauth)
    ```

1. On your GitLab instance, go to **Admin > Applications**.
1. Create a new application with the following settings:
    - Name: `Jira Connect`
    - Redirect URI: `YOUR_GITPOD_INSTANCE/-/jira_connect/oauth_callbacks`
    - Scopes: `api`
    - Trusted: **No**
    - Confidential: **No**
1. Copy the Application ID.
1. Go to [gitpod.io/variables](https://gitpod.io/variables).
1. Create a new variable named `JIRA_CONNECT_OAUTH_CLIENT_ID`, with a scope of `*/*`, and paste the Application ID as the value.

If you already have an active Gitpod instance, use the following command in the Gitpod terminal to set the environment variable:

```shell
eval $(gp env -e JIRA_CONNECT_OAUTH_CLIENT_ID=$YOUR_APPLICATION_ID)
```
