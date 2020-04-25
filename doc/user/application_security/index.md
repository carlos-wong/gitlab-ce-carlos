---
type: reference, howto
---

# GitLab Secure **(ULTIMATE)**

GitLab can check your application for security vulnerabilities that may lead to unauthorized access,
data leaks, denial of services, and more. GitLab reports vulnerabilities in the merge request so you
can fix them before merging. The [Security Dashboard](security_dashboard/index.md) provides a
high-level view of vulnerabilities detected in your projects, pipeline, and groups. With the
information provided, you can immediately begin risk analysis and remediation.

For an overview of application security with GitLab, see
[Security Deep Dive](https://www.youtube.com/watch?v=k4vEJnGYy84).

## Security scanning tools

GitLab uses the following tools to scan and report known vulnerabilities found in your project.

| Secure scanning tool                                                         | Description                                                            |
|:-----------------------------------------------------------------------------|:-----------------------------------------------------------------------|
| [Compliance Dashboard](compliance_dashboard/index.md) **(ULTIMATE)**         | View the most recent Merge Request activity in a group.                |
| [Container Scanning](container_scanning/index.md) **(ULTIMATE)**             | Scan Docker containers for known vulnerabilities.                      |
| [Dependency List](dependency_list/index.md) **(ULTIMATE)**                   | View your project's dependencies and their known vulnerabilities.      |
| [Dependency Scanning](dependency_scanning/index.md) **(ULTIMATE)**           | Analyze your dependencies for known vulnerabilities.                   |
| [Dynamic Application Security Testing (DAST)](dast/index.md) **(ULTIMATE)**  | Analyze running web applications for known vulnerabilities.            |
| [License Compliance](license_compliance/index.md) **(ULTIMATE)**             | Search your project's dependencies for their licenses.                 |
| [Security Dashboard](security_dashboard/index.md) **(ULTIMATE)**             | View vulnerabilities in all your projects and groups.                  |
| [Static Application Security Testing (SAST)](sast/index.md) **(ULTIMATE)**   | Analyze source code for known vulnerabilities.                         |

## Maintenance and update of the vulnerabilities database

The scanning tools and vulnerabilities database are updated regularly.

| Secure scanning tool                                         | Vulnerabilities database updates          |
|:-------------------------------------------------------------|-------------------------------------------|
| [Container Scanning](container_scanning/index.md)            | Uses `clair`. The latest `clair-db` version is used for each job by running the [`latest` docker image tag](https://gitlab.com/gitlab-org/gitlab/blob/438a0a56dc0882f22bdd82e700554525f552d91b/lib/gitlab/ci/templates/Security/Container-Scanning.gitlab-ci.yml#L37). The `clair-db` database [is updated daily according to the author](https://github.com/arminc/clair-local-scan#clair-server-or-local). |
| [Dependency Scanning](dependency_scanning/index.md)          | Relies on `bundler-audit` (for Rubygems), `retire.js` (for NPM packages), and `gemnasium` (GitLab's own tool for all libraries). Both `bundler-audit` and `retire.js` fetch their vulnerabilities data from GitHub repositories, so vulnerabilities added to `ruby-advisory-db` and `retire.js` are immediately available. The tools themselves are updated once per month if there's a new version. The [Gemnasium DB](https://gitlab.com/gitlab-org/security-products/gemnasium-db) is updated at least once a week. |
| [Dynamic Application Security Testing (DAST)](dast/index.md) | The scanning engine is updated on a periodic basis. See the [version of the underlying tool `zaproxy`](https://gitlab.com/gitlab-org/security-products/dast/blob/master/Dockerfile#L1). The scanning rules are downloaded at scan runtime. |
| [Static Application Security Testing (SAST)](sast/index.md)  | Relies exclusively on [the tools GitLab wraps](sast/index.md#supported-languages-and-frameworks). The underlying analyzers are updated at least once per month if a relevant update is available. The vulnerabilities database is updated by the upstream tools. |

Currently, you do not have to update GitLab to benefit from the latest vulnerabilities definitions.
The security tools are released as Docker images. The vendored job definitions to enable them use
the `x-y-stable` image tags that get overridden each time a new release of the tools is pushed. The
Docker images are updated to match the previous GitLab releases, so users automatically get the
latest versions of the scanning tools without having to do anything. There are some known issues
with this approach, however, and there is a
[plan to resolve them](https://gitlab.com/gitlab-org/gitlab/issues/9725).

## Interacting with the vulnerabilities

> Introduced in [GitLab Ultimate](https://about.gitlab.com/pricing/) 10.8.

CAUTION: **Warning:**
This feature is currently [Alpha](https://about.gitlab.com/handbook/product/#alpha-beta-ga) and while you can start using it, it may receive important changes in the future.

Each security vulnerability in the merge request report or the
[Security Dashboard](security_dashboard/index.md) is actionable. Click an entry to view detailed
information with several options:

- [Dismiss vulnerability](#dismissing-a-vulnerability): Dismissing a vulnerability styles it in
  strikethrough.
- [Create issue](#creating-an-issue-for-a-vulnerability): Create a new issue with the title and
  description prepopulated with information from the vulnerability report. By default, such issues
  are [confidential](../project/issues/confidential_issues.md).
- [Solution](#solutions-for-vulnerabilities-auto-remediation): For some vulnerabilities,
  a solution is provided for how to fix the vulnerability.

![Interacting with security reports](img/interactive_reports.png)

### Dismissing a vulnerability

You can dismiss vulnerabilities by clicking the **Dismiss vulnerability** button.
This will dismiss the vulnerability and re-render it to reflect its dismissed state.
If you wish to undo this dismissal, you can click the **Undo dismiss** button.

#### Adding a dismissal reason

> Introduced in [GitLab Ultimate](https://about.gitlab.com/pricing/) 12.0.

When dismissing a vulnerability, it's often helpful to provide a reason for doing so.
If you press the comment button next to **Dismiss vulnerability** in the modal,
a text box appears for you to add a comment with your dismissal.
Once added, you can edit or delete it. This allows you to add and update
context for a vulnerability as you learn more over time.

![Dismissed vulnerability comment](img/dismissed_info_v12_3.png)

### Creating an issue for a vulnerability

You can create an issue for a vulnerability by selecting the **Create issue**
button from within the vulnerability modal, or by using the action buttons to the right of
a vulnerability row in the group security dashboard.

This creates a [confidential issue](../project/issues/confidential_issues.md) in the project the
vulnerability came from, and prepopulates it with some useful information taken from the vulnerability
report. Once the issue is created, you are redirected to it so you can edit, assign, or comment on
it.

Upon returning to the group security dashboard, the vulnerability now has an associated issue next
to the name.

![Linked issue in the group security dashboard](img/issue.png)

### Solutions for vulnerabilities (auto-remediation)

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/5656) in [GitLab Ultimate](https://about.gitlab.com/pricing/) 11.7.

Some vulnerabilities can be fixed by applying the solution that GitLab
automatically generates. The following scanners are supported:

- [Dependency Scanning](dependency_scanning/index.md):
  Automatic Patch creation is only available for Node.js projects managed with
  `yarn`.
- [Container Scanning](container_scanning/index.md)

#### Manually applying the suggested patch

Some vulnerabilities can be fixed by applying a patch that is automatically
generated by GitLab. To apply the fix:

1. Click the vulnerability.
1. Download and review the patch file `remediation.patch`.
1. Ensure your local project has the same commit checked out that was used to generate the patch.
1. Run `git apply remediation.patch`.
1. Verify and commit the changes to your branch.

![Apply patch for dependency scanning](img/vulnerability_solution.png)

#### Creating a merge request from a vulnerability

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/9224) in [GitLab Ultimate](https://about.gitlab.com/pricing/) 11.9.

In certain cases, GitLab allows you to create a merge request that automatically remediates the
vulnerability. Any vulnerability that has a
[solution](#solutions-for-vulnerabilities-auto-remediation) can have a merge
request created to automatically solve the issue.

If this action is available, the vulnerability modal contains a **Create merge request** button.
Click this button to create a merge request to apply the solution onto the source branch.

![Create merge request from vulnerability](img/create_issue_with_list_hover.png)

## Security approvals in merge requests

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/9928) in [GitLab Ultimate](https://about.gitlab.com/pricing/) 12.2.

Merge Request Approvals can be configured to require approval from a member of your
security team when a merge request would introduce one of the following security issues:

- A security vulnerability
- A software license compliance violation

This threshold is defined as `high`, `critical`, or `unknown` severity. When any vulnerabilities are
present within a merge request, an approval is required from the `Vulnerability-Check` approver
group.

### Enabling Security Approvals within a project

To enable Security Approvals, a [project approval rule](../project/merge_requests/merge_request_approvals.md#multiple-approval-rules-premium)
must be created with the case-sensitive name `Vulnerability-Check`. This approval group must be set
with the number of approvals required greater than zero.

Once this group is added to your project, the approval rule is enabled for all merge requests.

Any code changes cause the approvals required to reset.

An approval is required when a security report:

- Contains a new vulnerability of `high`, `critical`, or `unknown` severity.
- Is not generated during pipeline execution.

An approval is optional when a security report:

- Contains no new vulnerabilities.
- Contains only new vulnerabilities of `low` or `medium` severity.

### Enabling License Approvals within a project

To enable License Approvals, a [project approval rule](../project/merge_requests/merge_request_approvals.md#multiple-approval-rules-premium)
must be created with the case-sensitive name `License-Check`. This approval group must be set
with the number of approvals required greater than zero.

Once this group is added to your project, the approval rule is enabled for all Merge Requests. To
configure how this rule behaves, you can choose which licenses to `approve` or `blacklist` in the
[project policies for License Compliance](license_compliance/index.md#project-policies-for-license-compliance)
section.

Any code changes cause the approvals required to reset.

An approval is required when a license report:

- Contains a dependency that includes a software license that is `blacklisted`.
- Is not generated during pipeline execution.

An approval is optional when a license report:

- Contains no software license violations.
- Contains only new licenses that are `approved` or unknown.

## Troubleshooting

### Getting error message `sast job: stage parameter should be [some stage name here]`

When including a security job template like [`SAST`](sast/index.md#configuration),
the following error may occur, depending on your GitLab CI/CD configuration:

```plaintext
Found errors in your .gitlab-ci.yml:

* sast job: stage parameter should be unit-tests
```

This error appears when the included job's stage (named `test`) isn't declared in `.gitlab-ci.yml`.
To fix this issue, you can either:

- Add a `test` stage in your `.gitlab-ci.yml`.
- Change the default stage of the included security jobs. For example, with `SAST`:

  ```yaml
  include:
    template: SAST.gitlab-ci.yml

  sast:
    stage: unit-tests
  ```

[Learn more on overriding the SAST template](sast/index.md#overriding-the-sast-template).
All the security scanning tools define their stage, so this error can occur with all of them.
