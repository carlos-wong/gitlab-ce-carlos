---
type: reference, howto
---

# Accessibility Testing

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/25144) in GitLab 12.8.

If your application offers a web interface and you are using
[GitLab CI/CD](../../../ci/README.md), you can quickly determine the accessibility
impact of pending code changes.

## Overview

GitLab uses [pa11y](https://pa11y.org/), a free and open source tool for
measuring the accessibility of web sites, and has built a simple
[CI job template](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Verify/Accessibility.gitlab-ci.yml).
This job outputs accessibility violations, warnings, and notices for each page
analyzed to a file called `accessibility`.

## Configure Accessibility Testing

This example shows how to run [pa11y](https://pa11y.org/)
on your code with GitLab CI/CD using the [GitLab Accessibility Docker image](https://gitlab.com/gitlab-org/ci-cd/accessibility).

For GitLab 12.9 and later, to define the `a11y` job, you must
[include](../../../ci/yaml/README.md#includetemplate) the
[`Accessibility.gitlab-ci.yml` template](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/gitlab/ci/templates/Verify/Accessibility.gitlab-ci.yml)
included with your GitLab installation, as shown below.

Add the following to your `.gitlab-ci.yml` file:

```yaml
variables:
  a11y_urls: "https://about.gitlab.com https://gitlab.com/users/sign_in"

include:
  - template: "Verify/Accessibility.gitlab-ci.yml"
```

creates an `a11y` job in your CI/CD pipeline, runs
Pa11y against the webpages defined in `a11y_urls`, and builds an HTML report for each.

The report for each URL is saved as an artifact that can be [viewed directly in your browser](../../../ci/pipelines/job_artifacts.md#browsing-artifacts).

A single `accessibility.json` artifact is created and saved along with the individual HTML reports.
It includes report data for all URLs scanned.

NOTE: **Note:**
For GitLab versions earlier than 12.9, you can use `include:remote` and use a
link to the [current template in `master`](https://gitlab.com/gitlab-org/gitlab/-/raw/master/lib/gitlab/ci/templates/Verify/Accessibility.gitlab-ci.yml)

NOTE: **Note:**
The job definition provided by the template does not support Kubernetes yet.

It is not yet possible to pass configurations into Pa11y via CI configuration. To change anything,
copy the template to your CI file and make the desired edits.
