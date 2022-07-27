---
stage: Verify
group: Pipeline Insights
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Accessibility testing **(FREE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/25144) in GitLab 12.8.

If your application offers a web interface, you can use
[GitLab CI/CD](../index.md) to determine the accessibility
impact of pending code changes.

[Pa11y](https://pa11y.org/) is a free and open source tool for
measuring the accessibility of web sites. GitLab integrates Pa11y into a
[CI job template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Verify/Accessibility.gitlab-ci.yml).
The `a11y` job analyzes a defined set of web pages and reports
accessibility violations, warnings, and notices in a file named
`accessibility`.

As of [GitLab 14.5](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/73309), Pa11y uses
[WCAG 2.1 rules](https://www.w3.org/TR/WCAG21/#new-features-in-wcag-2-1).

## Accessibility merge request widget

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/39425) in GitLab 13.0 behind the disabled [feature flag](../../administration/feature_flags.md) `:accessibility_report_view`.
> - [Feature Flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/217372) in GitLab 13.1.

GitLab displays an **Accessibility Report** in the merge request widget area:

![Accessibility merge request widget](img/accessibility_mr_widget_v13_0.png)

## Configure accessibility testing

You can run Pa11y with GitLab CI/CD using the
[GitLab Accessibility Docker image](https://gitlab.com/gitlab-org/ci-cd/accessibility).

To define the `a11y` job for GitLab 12.9 and later:

1. [Include](../yaml/index.md#includetemplate) the
   [`Accessibility.gitlab-ci.yml` template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Verify/Accessibility.gitlab-ci.yml)
   from your GitLab installation.
1. Add the following configuration to your `.gitlab-ci.yml` file.

   ```yaml
   stages:
     - accessibility

   variables:
     a11y_urls: "https://about.gitlab.com https://gitlab.com/users/sign_in"

   include:
     - template: "Verify/Accessibility.gitlab-ci.yml"
   ```

1. Customize the `a11y_urls` variable to list the URLs of the web pages to test with Pa11y.

The `a11y` job in your CI/CD pipeline generates these files:

- One HTML report per URL listed in the `a11y_urls` variable.
- One file containing the collected report data. In GitLab versions 12.11 and later, this
  file is named `gl-accessibility.json`. In GitLab versions 12.10 and earlier, this file
  is named [`accessibility.json`](https://gitlab.com/gitlab-org/ci-cd/accessibility/-/merge_requests/9).

You can [view job artifacts in your browser](../pipelines/job_artifacts.md#download-job-artifacts).

NOTE:
For GitLab versions earlier than 12.9, use `include:remote` and
link to the [current template in the default branch](https://gitlab.com/gitlab-org/gitlab/-/raw/master/lib/gitlab/ci/templates/Verify/Accessibility.gitlab-ci.yml)

NOTE:
The job definition provided by the template does not support Kubernetes.

You cannot pass configurations into Pa11y via CI configuration.
To change the configuration, edit a copy of the template in your CI file.
