---
stage: Manage
group: Compliance
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Compliance features **(FREE)**

These GitLab features can help ensure that your GitLab instance meets common
compliance standards. For more information about compliance management, see the
compliance management [solutions page](https://about.gitlab.com/solutions/compliance/).

The [security features](../security/index.md) in GitLab may also help you meet
relevant compliance standards.

## Policy management

Organizations have unique policy requirements, either due to organizational
standards or mandates from regulatory bodies. The following features help you
define rules and policies to adhere to workflow requirements, separation of duties,
and secure supply chain best practices:

- [**Credentials inventory**](../user/admin_area/credentials_inventory.md) (for
  instances): With a credentials inventory, GitLab administrators can keep track
  of the credentials used by all of the users in their GitLab instance.
- [**Granular user roles and flexible permissions**](../user/permissions.md)
  (for instances, groups, and projects): Manage access and permissions with five
  different user roles and settings for external users. Set permissions according
  to people's role, rather than either read or write access to a repository. Don't
  share the source code with people that only need access to the issue tracker.
- [**Merge request approvals**](../user/project/merge_requests/approvals/index.md)
  (for instances, groups, and projects): Configure approvals required for
  merge requests.
- [**Push rules**](../user/project/repository/push_rules.md) (for instances, groups, and
  projects): Control pushes to your repositories.
- Separation of duties using [**protected branches**](../user/project/protected_branches.md#require-code-owner-approval-on-a-protected-branch)
  and [**custom CI/CD configuration paths**](../ci/pipelines/settings.md#specify-a-custom-cicd-configuration-file) (for projects): Users can leverage the GitLab cross-project YAML configurations
  to define deployers of code and developers of code. See how to use this setup
  to define these roles in:
  - The [Separation of Duties deploy project](https://gitlab.com/guided-explorations/separation-of-duties-deploy/blob/master/README.md).
  - The [Separation of Duties project](https://gitlab.com/guided-explorations/separation-of-duties/blob/master/README.md).

## Compliant workflow automation

It is important for compliance teams to be confident that their controls and
requirements are set up correctly, but also that they _stay_ set up correctly.
One way of doing this is manually checking settings periodically, but this is
error prone and time consuming. A better approach is to use single-source-of-truth
settings and automation to ensure that whatever a compliance team has configured,
stays configured and working correctly. These features can help you automate
compliance:

- [**Compliance frameworks**](../user/project/settings/index.md#compliance-frameworks) (for groups): Create a custom
  compliance framework at the group level to describe the type of compliance requirements any child project needs to follow.
- [**Compliance pipelines**](../user/project/settings/index.md#compliance-pipeline-configuration) (for groups): Define a
  pipeline configuration to run for any projects with a given compliance framework.

## Audit management

An important part of any compliance program is being able to go back and understand
what happened, when it happened, and who was responsible. This is useful in audit
situations as well as for understanding the root cause of issues when they occur.
It is useful to have both low-level, raw lists of audit data as well as high-level,
summary lists of audit data. Between these two, compliance teams can quickly
identify if problems exist and then drill down into the specifics of those issues.
These features can help provide visibility into GitLab and audit what is happening:

- [**Audit events**](audit_events.md) (for instances, groups, and projects): To
  maintain the integrity of your code, audit events give administrators the
  ability to view any modifications made within the GitLab server in an advanced
  audit events system, so you can control, analyze, and track every change.
- [**Audit reports**](audit_reports.md) (for instances, groups, and projects):
  Create and access reports based on the audit events that have occurred. Use
  pre-built GitLab reports or the API to build your own.
- [**Auditor users**](auditor_users.md) (for instances): Auditor users are users
  who are given read-only access to all projects, groups, and other resources on
  the GitLab instance.
- [**Compliance report**](../user/compliance/compliance_report/index.md) (for
  groups): Quickly get visibility into the compliance posture of your organization.

## Other compliance features

These features can also help with compliance requirements:

- [**Email all users of a project, group, or entire server**](../user/admin_area/email_from_gitlab.md)
  (for instances): An administrator can email groups of users based on project
  or group membership, or email everyone using the GitLab instance. These emails
  are great for scheduled maintenance or upgrades.
- [**Enforce ToS acceptance**](../user/admin_area/settings/terms.md) (for
  instances): Enforce your users accepting new terms of service by blocking GitLab
  traffic.
- [**External Status Checks**](../user/project/merge_requests/status_checks.md)
  (for projects): Interface with third-party systems you already use during
  development to ensure you remain compliant.
- [**Generate reports on permission levels of users**](../user/admin_area/index.md#user-permission-export)
  (for instances): Administrators can generate a report listing all users' access
  permissions for groups and projects in the instance.
- [**License compliance**](../user/compliance/license_compliance/index.md) (for
  projects): Search dependencies for their licenses. This lets you determine if
  the licenses of your project's dependencies are compatible with your project's
  license.
- [**Lock project membership to group**](../user/group/index.md#prevent-members-from-being-added-to-projects-in-a-group)
  (for groups): Group owners can prevent new members from being added to projects
  within a group.
- [**LDAP group sync**](auth/ldap/ldap_synchronization.md#group-sync) (for
  instances): Gives administrators the ability to automatically sync groups and
  manage SSH keys, permissions, and authentication, so you can focus on building
  your product, not configuring your tools.
- [**LDAP group sync filters**](auth/ldap/ldap_synchronization.md#group-sync)
  (for instances): Gives more flexibility to synchronize with LDAP based on
  filters, meaning you can leverage LDAP attributes to map GitLab permissions.
- [**Omnibus GitLab package supports log forwarding**](https://docs.gitlab.com/omnibus/settings/logs.html#udp-log-forwarding)
  (for instances): Forward your logs to a central system.
- [**Restrict SSH Keys**](../security/ssh_keys_restrictions.md) (for instances):
  Control the technology and key length of SSH keys used to access GitLab.
