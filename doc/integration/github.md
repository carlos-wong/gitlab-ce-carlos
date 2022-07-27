---
stage: Manage
group: Authentication and Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Use GitHub as an authentication provider **(FREE SELF)**

You can integrate your GitLab instance with GitHub.com and GitHub Enterprise.
You can import projects from GitHub, or sign in to GitLab
with your GitHub credentials.

## Create an OAuth app in GitHub

To enable the GitHub OmniAuth provider, you need an OAuth 2.0 client ID and client
secret from GitHub:

1. Sign in to GitHub.
1. [Create an OAuth App](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app)
   and provide the following information:
   - The URL of your GitLab instance, such as `https://gitlab.example.com`.
   - The authorization callback URL, such as, `https://gitlab.example.com/users/auth`.
     Include the port number if your GitLab instance uses a non-default port.

### Check for security vulnerabilities

For some integrations, the [OAuth 2 covert redirect](https://oauth.net/advisories/2014-1-covert-redirect/)
vulnerability can compromise GitLab accounts.
To mitigate this vulnerability, append `/users/auth` to the authorization
callback URL.

However, as far as we know, GitHub does not validate the subdomain part of the `redirect_uri`.
Therefore, a subdomain takeover, an XSS, or an open redirect on any subdomain of
your website could enable the covert redirect attack.

## Enable GitHub OAuth in GitLab

1. [Configure the initial settings](omniauth.md#configure-initial-settings) in GitLab.

1. Edit the GitLab configuration file using the following information:

   | GitHub setting | Value in the GitLab configuration file | Description             |
   |----------------|----------------------------------------|-------------------------|
   | Client ID      | `YOUR_APP_ID`                          | OAuth 2.0 client ID     |
   | Client secret  | `YOUR_APP_SECRET`                      | OAuth 2.0 client secret |
   | URL            | `https://github.example.com/`          | GitHub deployment URL   |

   - **For Omnibus installations**

     1. Open the `/etc/gitlab/gitlab.rb` file.

        For GitHub.com, update the following section:

        ```ruby
        gitlab_rails['omniauth_providers'] = [
          {
            name: "github",
            # label: "Provider name", # optional label for login button, defaults to "GitHub"
            app_id: "YOUR_APP_ID",
            app_secret: "YOUR_APP_SECRET",
            args: { scope: "user:email" }
          }
        ]
        ```

        For GitHub Enterprise, update the following section and replace
        `https://github.example.com/` with your GitHub URL:

        ```ruby
        gitlab_rails['omniauth_providers'] = [
          {
            name: "github",
            # label: "Provider name", # optional label for login button, defaults to "GitHub"
            app_id: "YOUR_APP_ID",
            app_secret: "YOUR_APP_SECRET",
            url: "https://github.example.com/",
            args: { scope: "user:email" }
          }
        ]
        ```

     1. Save the file and [reconfigure](../administration/restart_gitlab.md#omnibus-gitlab-reconfigure)
        GitLab.

   - **For installations from source**

     1. Open the `config/gitlab.yml` file.

        For GitHub.com, update the following section:

        ```yaml
        - { name: 'github',
            # label: 'Provider name', # optional label for login button, defaults to "GitHub"
            app_id: 'YOUR_APP_ID',
            app_secret: 'YOUR_APP_SECRET',
            args: { scope: 'user:email' } }
        ```

        For GitHub Enterprise, update the following section and replace
        `https://github.example.com/` with your GitHub URL:

        ```yaml
        - { name: 'github',
            # label: 'Provider name', # optional label for login button, defaults to "GitHub"
            app_id: 'YOUR_APP_ID',
            app_secret: 'YOUR_APP_SECRET',
            url: "https://github.example.com/",
            args: { scope: 'user:email' } }
        ```

     1. Save the file and [restart](../administration/restart_gitlab.md#installations-from-source)
        GitLab.

1. Refresh the GitLab sign-in page. A GitHub icon should display below the
   sign-in form.

1. Select the icon. Sign in to GitHub and authorize the GitLab application.

## Troubleshooting

### Imports from GitHub Enterprise with a self-signed certificate fail

When you import projects from GitHub Enterprise using a self-signed
certificate, the imports fail.

To fix this issue, you must disable SSL verification:

1. Set `verify_ssl` to `false` in the configuration file.

   - **For Omnibus installations**

     ```ruby
     gitlab_rails['omniauth_providers'] = [
       {
         name: "github",
         # label: "Provider name", # optional label for login button, defaults to "GitHub"
         app_id: "YOUR_APP_ID",
         app_secret: "YOUR_APP_SECRET",
         url: "https://github.example.com/",
         verify_ssl: false,
         args: { scope: "user:email" }
       }
     ]
     ```

   - **For installations from source**

     ```yaml
     - { name: 'github',
         # label: 'Provider name', # optional label for login button, defaults to "GitHub"
         app_id: 'YOUR_APP_ID',
         app_secret: 'YOUR_APP_SECRET',
         url: "https://github.example.com/",
         verify_ssl: false,
         args: { scope: 'user:email' } }
     ```

1. Change the global Git `sslVerify` option to `false` on the GitLab server.

   - **For Omnibus installations**

     ```ruby
     omnibus_gitconfig['system'] = { "http" => ["sslVerify = false"] }
     ```

   - **For installations from source**

     ```shell
     git config --global http.sslVerify false
     ```

1. [Reconfigure GitLab](../administration/restart_gitlab.md#omnibus-gitlab-reconfigure)
   if you installed using Omnibus, or [restart GitLab](../administration/restart_gitlab.md#installations-from-source)
   if you installed from source.

### Signing in using GitHub Enterprise returns a 500 error

This error can occur because of a network connectivity issue between your
GitLab instance and GitHub Enterprise.

To check for a connectivity issue:

1. Go to the [`production.log`](../administration/logs.md#productionlog)
   on your GitLab server and look for the following error:

   ``` plaintext
   Faraday::ConnectionFailed (execution expired)
   ```

1. [Start the rails console](../administration/operations/rails_console.md#starting-a-rails-console-session)
   and run the following commands. Replace `<github_url>` with the URL of your
   GitHub Enterprise instance:

   ```ruby
   uri = URI.parse("https://<github_url>") # replace `GitHub-URL` with the real one here
   http = Net::HTTP.new(uri.host, uri.port)
   http.use_ssl = true
   http.verify_mode = 1
   response = http.request(Net::HTTP::Get.new(uri.request_uri))
   ```

1. If a similar `execution expired` error is returned, this confirms the error is
   caused by a connectivity issue. Make sure the GitLab server can reach
   your GitHub Enterprise instance.

### Signing in using your GitHub account without a pre-existing GitLab account is not allowed

When you sign in to GitLab, you get the following error:

```plaintext
Signing in using your GitHub account without a pre-existing
GitLab account is not allowed. Create a GitLab account first,
and then connect it to your GitHub account
```

To fix this issue, you must activate GitHub sign-in in GitLab:

1. On the top bar, in the top right corner, select your avatar.
1. Select **Edit profile**.
1. On the left sidebar, select **Account**.
1. In the **Service sign-in** section, select **Connect to GitHub**.
