---
stage: Fulfillment
group: Purchase
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Features available to Starter and Bronze subscribers

Although GitLab has discontinued selling the Bronze and Starter tiers, GitLab
continues to honor the entitlements of existing Bronze and Starter tier GitLab
customers for the duration of their contracts at that level.

New paid features will not be released in Bronze and Starter tiers after GitLab 13.9.

The following features remain available to Bronze and Starter customers, even though
the tiers are no longer mentioned in GitLab documentation:

- [Activate GitLab EE with a license](../user/admin_area/license.md)
- [Add a help message to the sign-in page](../user/admin_area/settings/help_page.md#add-a-help-message-to-the-sign-in-page)
- [Burndown and burnup charts](../user/project/milestones/burndown_and_burnup_charts.md) in the [Milestone View](../user/project/milestones/index.md#burndown-charts),
- [Code owners](../user/project/code_owners.md)
- Description templates:
  - [Setting a default template for merge requests and issues](../user/project/description_templates.md#set-a-default-template-for-merge-requests-and-issues)
- [Email from GitLab](../user/admin_area/email_from_gitlab.md)
- Groups:
  - [Creating group memberships via CN](../user/group/index.md#create-group-links-via-cn)
  - [Group push rules](../user/group/index.md#group-push-rules)
  - [Managing group memberships via LDAP](../user/group/index.md#manage-group-memberships-via-ldap)
  - [Member locking](../user/group/index.md#prevent-members-from-being-added-to-projects-in-a-group)
  - [Overriding user permissions](../user/group/index.md#override-user-permissions)
  - [User contribution analytics](../user/group/contribution_analytics/index.md)
  - [Kerberos integration](../integration/kerberos.md)
- Issue boards:
  - [Configurable issue boards](../user/project/issue_board.md#configurable-issue-boards)
  - [Sum of issue weights](../user/project/issue_board.md#sum-of-issue-weights)
  - [Work In Progress limits](../user/project/issue_board.md#work-in-progress-limits)
- Issues:
  - [Multiple assignees for issues](../user/project/issues/multiple_assignees_for_issues.md)
  - [Issue weights](../user/project/issues/issue_weight.md)
  - Issue histories contain [changes to issue description](../user/discussions/index.md#view-description-change-history)
  - [Adding an issue to an iteration](../user/project/issues/managing_issues.md#add-an-issue-to-an-iteration)
- [Iterations](../user/group/iterations/index.md)
- [Kerberos integration](../integration/kerberos.md)
- LDAP:
  - Querying LDAP [from the Rails console](../administration/auth/ldap/ldap-troubleshooting.md#query-ldap), or
    [querying a single group](../administration/auth/ldap/ldap-troubleshooting.md#query-a-group-in-ldap)
  - [Sync all users](../administration/auth/ldap/ldap-troubleshooting.md#sync-all-users)
  - [Group management through LDAP](../administration/auth/ldap/ldap-troubleshooting.md#group-memberships)
  - Syncing information through LDAP:
    - Groups: [one group](../administration/auth/ldap/ldap-troubleshooting.md#sync-one-group),
      [all groups programmatically](../administration/auth/ldap/ldap_synchronization.md#group-sync),
      [group sync schedule](../administration/auth/ldap/ldap_synchronization.md#adjust-ldap-group-sync-schedule), and
      [all groups manually](../administration/auth/ldap/ldap-troubleshooting.md#sync-all-groups)
    - [Configuration settings](../administration/auth/ldap/index.md#ldap-sync-configuration-settings)
    - Users: [all users](../administration/auth/ldap/ldap_synchronization.md#user-sync),
      [administrators](../administration/auth/ldap/ldap_synchronization.md#administrator-sync),
      [user sync schedule](../administration/auth/ldap/ldap_synchronization.md#adjust-ldap-user-sync-schedule)
    - [Adding group links](../administration/auth/ldap/ldap_synchronization.md#add-group-links)
    - [Lock memberships to LDAP synchronization](../administration/auth/ldap/ldap_synchronization.md#global-group-memberships-lock)
    - Rake tasks for [LDAP tasks](../administration/raketasks/ldap.md), including
      [syncing groups](../administration/raketasks/ldap.md#run-a-group-sync)
- Logging:
  - [`audit_json.log`](../administration/logs.md#audit_jsonlog) (specific entries)
  - [`elasticsearch.log`](../administration/logs.md#elasticsearchlog)
- Merge requests:
  - [Full code quality reports in the code quality tab](../user/project/merge_requests/code_quality.md#code-quality-reports)
  - [Merge request approvals](../user/project/merge_requests/approvals/index.md)
  - [Multiple assignees](../user/project/merge_requests/getting_started.md#multiple-assignees)
  - [Approval Rule information for Reviewers](../user/project/merge_requests/reviews/index.md#approval-rule-information-for-reviewers)
  - [Required Approvals](../user/project/merge_requests/approvals/index.md#required-approvals)
  - [Code Owners as eligible approvers](../user/project/merge_requests/approvals/rules.md#code-owners-as-eligible-approvers)
  - [Approval rules](../user/project/merge_requests/approvals/rules.md) features
  - [Restricting push and merge access to certain users](../user/project/protected_branches.md)
  - [Visual Reviews](../ci/review_apps/index.md#visual-reviews)
- Metrics and analytics:
  - [Contribution Analytics](../user/group/contribution_analytics/index.md)
  - [Merge Request Analytics](../user/analytics/merge_request_analytics.md)
  - [Code Review Analytics](../user/analytics/code_review_analytics.md)
  - [Audit Events](../administration/audit_events.md), including
    [Group events](../administration/audit_events.md#group-events) and
    [Project events](../administration/audit_events.md#project-events)
- Rake tasks:
  - [Displaying GitLab license information](../administration/raketasks/maintenance.md#show-gitlab-license-information)
- Reference Architecture information:
  - [Traffic load balancers](../administration/reference_architectures/index.md#traffic-load-balancer)
  - [Zero downtime updates](../administration/reference_architectures/index.md#zero-downtime-updates)
- Repositories:
  - [Repository size limit](../user/admin_area/settings/account_and_limit_settings.md#repository-size-limit)
  - Repository mirroring:
    - [Pull mirroring](../user/project/repository/mirror/pull.md) outside repositories in a GitLab repository
    - [Overwrite diverged branches](../user/project/repository/mirror/pull.md#overwrite-diverged-branches)
    - [Trigger pipelines for mirror updates](../user/project/repository/mirror/pull.md#trigger-pipelines-for-mirror-updates)
    - [Fix hard failures when mirroring](../user/project/repository/mirror/pull.md#fix-hard-failures-when-mirroring)
    - [Trigger pull mirroring from the API](../user/project/repository/mirror/pull.md#trigger-an-update-by-using-the-api)
    - [Mirror only protected branches](../user/project/repository/mirror/index.md#mirror-only-protected-branches)
    - [Bidirectional mirroring](../user/project/repository/mirror/bidirectional.md)
    - [Mirror with Perforce Helix with Git Fusion](../user/project/repository/mirror/bidirectional.md#mirror-with-perforce-helix-with-git-fusion)
- Runners:
  - Run pipelines in the parent project [for merge requests from a forked project](../ci/pipelines/merge_request_pipelines.md#run-pipelines-in-the-parent-project)
  - [Shared runners CI/CD minutes](../ci/pipelines/cicd_minutes.md)
- [Push rules](../user/project/repository/push_rules.md)
- SAML for self-managed GitLab instance:
  - [Administrator groups](../integration/saml.md#administrator-groups)
  - [Auditor groups](../integration/saml.md#auditor-groups)
  - [External groups](../integration/saml.md#external-groups)
  - [Required groups](../integration/saml.md#required-groups)
- Search:
  - [Filtering merge requests by approvers](../user/search/index.md#filtering-merge-requests-by-approvers)
  - [Filtering merge requests by "approved by"](../user/search/index.md#filtering-merge-requests-by-approved-by)
  - [Advanced Search (Elasticsearch)](../user/search/advanced_search.md)
- [Service Desk](../user/project/service_desk.md)
- [Storage usage statistics](../user/usage_quotas.md#storage-usage-statistics)

The following developer features continue to be available to Starter and
Bronze-level subscribers:

- APIs:
  - LDAP synchronization:
    - Certain fields in the [group details API](../api/groups.md#details-of-a-group)
    - [syncing groups](../api/groups.md#sync-group-with-ldap)
    - Listing, adding, and deleting [group links](../api/groups.md#list-ldap-group-links)
    - [Push rules](../api/groups.md#push-rules)
    - [Audit events](../api/audit_events.md), including
      [group audit events](../api/groups.md#group-audit-events) and
      [project audit events](../api/audit_events.md#project-audit-events)
  - Projects API: certain fields in the [Create project API](../api/projects.md)
  - [Resource iteration events API](../api/resource_iteration_events.md)
  - Group milestones API: [Get all burndown chart events for a single milestone](../api/group_milestones.md#get-all-burndown-chart-events-for-a-single-milestone)
  - [Group iterations API](../api/group_iterations.md)
  - Project milestones API: [Get all burndown chart events for a single milestone](../api/milestones.md#get-all-burndown-chart-events-for-a-single-milestone)
  - [Project iterations API](../api/iterations.md)
  - Fields in the [Search API](../api/search.md) available only to [Advanced Search (Elasticsearch)](../integration/elasticsearch.md) users
  - Fields in the [Merge requests API](../api/merge_requests.md) for [merge request approvals](../user/project/merge_requests/approvals/index.md)
  - Fields in the [Protected branches API](../api/protected_branches.md) that specify users or groups allowed to merge
  - [Merge request approvals API](../api/merge_request_approvals.md)
  - [Visual review discussions API](../api/visual_review_discussions.md)
- Development information:
  - [Run Jenkins in a macOS development environment](../development/integrations/jenkins.md)
