---
type: reference, howto
stage: Create
group: Editor
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Create a Pages website by using a CI/CD template **(FREE)**

GitLab provides `.gitlab-ci.yml` templates for the most popular Static Site Generators (SSGs).
You can create your own `.gitlab-ci.yml` file from one of these templates, and run
the CI/CD pipeline to generate a Pages website.

Use a `.gitlab-ci.yml` template when you have an existing project that you want to add a Pages site to.

Your GitLab repository should contain files specific to an SSG, or plain HTML. After you complete
these steps, you may have to do additional configuration for the Pages site to generate properly.

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select the project's name.
1. From the **Add** (**{plus}**) dropdown, select **New file**.
1. From the **Select a template type** dropdown, select `.gitlab-ci.yml`.
1. From the **Apply a template** dropdown, in the **Pages** section, select the name of your SSG.
1. In the **Commit message** box, type the commit message.
1. Select **Commit changes**.

If everything is configured correctly, the site can take approximately 30 minutes to deploy.

You can watch the pipeline run by navigating to **CI/CD > Pipelines**.
When the pipeline is finished, go to **Settings > Pages** to find the link to
your Pages website.

For every change pushed to your repository, GitLab CI/CD runs a new pipeline
that immediately publishes your changes to the Pages site.
