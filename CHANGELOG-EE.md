Please view this file on the master branch, on stable branches it's out of date.

## 12.3.4

### Fixed (2 changes)

- Fix replies to service desk emails for projects with issue access as Only Project Members. !17401
- Geo: LFS not being synced. !17633


## 12.3.2

### Security (2 changes)

- Hide approvers if a rule has any hidden groups.
- Prevent IDOR when adding groups to protected environments.


## 12.3.1

- No changes.

## 12.3.0

### Security (3 changes)

- Limit number of jobs in running pipelines for the past hour on per plan basis. !1182
- Filter out old system notes for epics in notes api endpoint response.
- Do not allow creation of projects from group templates if project is not descendant of that group.

### Removed (1 change)

- Remove Ruby Elasticsearch indexer. !15641

### Fixed (53 changes, 5 of them are from the community)

- LDAP group sync: check parent group membership and improve performance. !13435 (Alex Lossent)
- Added a migration which fixes discussions for existing promoted epics. !14708
- Fix Docker Registry access when Group SAML session enforcement is active. !14843
- Fix missing borders between settings items. !14877
- SCIM uses fallbacks when name.formatted not present. !14878
- Fix visibility of link to dependency-list in project sidebar based on permissions. !15066
- Hide info for unlicensed projects on Ops Dashboard. !15099
- Fix focus-visibility of vulnerability-actions within security dashboard. !15115
- Resolve Design viewer does not respect version. !15119
- Fix bug to display alert menu correctly in dashboards. !15261
- Allow developer role to access group-level templates when creating a new project. !15364
- Maintain related issues after moving issue. !15391
- Fix the documentation link on the empty Dependency List page. !15402
- Fix broken docs link on security dashboard. !15404
- Change epics count in sidebar to only count open epics. !15459
- Include ancestor group labels in autocomplete for epics. !15460
- Enable target users across all feature flag environment scopes. !15500
- Change payload for comparing security reports in MR widget. !15531
- Add space between CI usage warning messages. !15563 (briankabiro)
- Make sure groups with templates finder returns subgroups. !15631
- Properly delete files when a package is removed. !15634
- Fix x-axis burndown chart offset by timezone. !15690
- Resolve SRV records for DB load balancing. !15691
- Ensure all CI minutes used are reset for all namespaces and relative projects. !15744
- Show proper error in SCIM create user endpoint. !15756
- Update permissions on Dependency List page. !15771
- Allow ancestor group milestones in issue board scope. !15858
- Show weight on new board issue. !16028 (Lee Tickett)
- Do not show 'automatically removed' suffix for manually removed labels. !16079
- Link to the embedded doc in the Geo callout about hashed storage. !16114
- Fix LFS authentication URL in EE. !16146
- Prevent project's approval rules having same name. !16216
- Fix create issue for container scanning from security dashboard. !16226
- Add current_user to security report comparison services. !16252
- Fix setting of weight of a new issue in board list. !16299
- Update ExternalPullRequest on :synchronize action to ensure source_sha is updated locally. !16318
- Fix wrong tier error message for Operations dashboard. !16319
- Perform case insensitive diff on license names. !16335
- Moves Buy additional minutes button to the pipelines tab. !16443
- Update GitHub Importer Personal Access Token field description for CI/CD projects only to reflect latest OAuth changes. !16453
- Use Pull Request number instead of internal Pull Request ID. !16504
- Fix service desk emails not creating issues intermittently. !16577
- Reinitialize metrics files on webserver master process start. !16623
- Fix the group's epic page. The Paste issue link placeholder shown as 'undefinedundefinedundefined' in Chinese environment. And the error message showed nothing. !16628 (wdmcheng)
- Fix issue redirects going to /issues/:id/designs. !16638
- Eliminate analytics feature flag requirement for /analytics routes. !16663
- Match environment names case insensitively for feature flag spec search. !16691
- Fix merge request redirects going to /commits page. !16705
- Align text color for edited with issue/mr. !16721
- Added Packages top item to the group level packages fly out navigation menu. !16791
- Restores data for assignee changes in merge request webhooks. !16812 (Jesse Hall @jessehall3)
- Fix alignment of comments count in issue and MR lists. !16829
- Wait until pipeline is completed before checking for software license violations. !16853

### Changed (27 changes, 1 of them is from the community)

-  Geo: Refactor data-sources to allow for replication of content in Object Storage. !13997
- Improve UX multi assignees in MR. !14851
- Add ability to block API pushes to protected branches when contents match CODEOWNERS rule. !14900
- Add browser notications to add/edit/delete vulnability dismissal reasons. !15015
- Geo: Add orphaned project registry cleaner. !15021
- Update Security Dashboard for improved usability. !15050
- Present SAST report comparison logic to backend. !15114
- Ensure design notifications are sent. !15250
- Apply the group setting "Restrict access by IP address" to API requests. !15282
- Hide boards-switcher on group boards. !15293 (briankabiro)
- Group Security Dashboard shows projects with security reports only. !15334
- Use GlEmptyState component for design management empty state. !15374
- DB Load Balancing: Log Prometheus current number of hosts and current index. !15440
- Clarify SSO enforcement setting behaviour. !15533
- DB Load Balancing: Support SRV lookups. !15558
- Add status checking behaviors to pipeline triggers. !15580
- Only show Service Desk email address to project members. !15676
- Use static status check names on GitHub integrations. !15737
- Display the Security Dashboard in the Security tab of the pipeline view. !15824
- Remove primary button from feature flags empty state and update text. !15841
- Extend License Compliance entity for Pipelines and MR view. !15957
- Improve DB load balancing log to log host offline due to replication lag. !15995
- Eliminating `analytics` feature flag and introduce separate feature flags for Analytics features. !16102
- Add asterisk to name field in new feature flag form. !16248
- Update Container Scanning job template, use klar image. !16342
- Improve projects list page UI. !16656
- Add user feedback to exit routine of onboarding tour.

### Performance (2 changes)

- Send only necessary fields on mr-widget auto-refresh. !15495
- Two step Routable lookup. !16621

### Added (46 changes, 1 of them is from the community)

- Public project-level approval rule API. !13895
- Support reordering issues and epics using Drag&Drop. !14565
- Add deletion support for designs. !14656
- Add Epics select dropdown to Issue sidebar. !14763
- Edit delete vuln dismissal message. !14770
- add Productivity Analytics page with basic charts. !14772
- Add License information to the Dependency List based on current license rules. !14905
- Adds an api to generate suggestions for username. !15048
- Add Upgrade button to the User Billing page. !15075
- Enable "only/except: external_pull_request" with GitHub integration when a pull request is open for the given ref. !15082
- Allow to filter epics by timeframe or state using GraphQL. !15110
- Support restricting group access by multiple IP subnets. !15142
- Merge License info to Dependency List report. !15157
- Add Licenses info into Dependencies response. !15160
- Add 'License-Check' approval rule to enforce license compliance policy. !15196
- Added a toggle to show/hide dismissed vulnerabilities in the security dashboard. !15333
- Add audit event for archiving & unarchiving projects. !15362
- Pressing the Escape key now closes designs in Design Management. !15379
- Expose a count of Notes for a Design in a new notes_count property of DesignType in GraphQL. !15433
- Implement public MR-level approval rules API. !15441
- Cancel redundant merge train pipelines. !15450
- Add vulnerabilities to Dependencies API. !15485
- Expose a new events property of DesignType in GraphQL that represents the change that happened to a Design within a given version. !15561
- Add new layout for trial. !15630
- Track repository pushes as audit events. !15667
- Create Metadata/Tags table. !15770
- Allow SmartCard authentication to use SAN extensions. !15773
- Maximum Users metric in Admin Dashboard includes current active user count. !15810
- Public MR-level approval state API endpoint. !15859
- Add secondary lag message on Git push over HTTP. !15901
- Expose epic_iid in issues API. !15998
- Refresh license approval check when a license is blacklisted. !16070
- Disable editing of the 'License-Check' approval rule name. !16149
- Implement Cluster Environments polling. !16316
- Support creating project from template via API. !16352
- Add link to additional shared minutes from pipeline quote overview. !16389
- Add audit events for protected branches. !16399
- Geo: Exit LogCursor if it has been failing for too long. !16408
- Implement design comment counts and current-version status icon indicator. !16416
- Track page view counts for Cycle Analytics and Productivity Analytics features. !16431
- Update release blocks to support association of milestones. !16562
- Set default whitespace diff behaviour. !16570 (Lee Tickett)
- Implement `/zoom` and `/remove_zoom` quick actions. !16609
- Add Snowplow click tracking for issue sidebar. !16833
- Upgrade pages to 1.9.0.
- Adds total usage information to the usage quotas page.

### Other (27 changes, 8 of them are from the community)

- Update Pipelines Minutes expiry banner to Alert Component. !14786
- Add internal API for group cluster environments. !15096
- Rename approval rule. !15140
- Productivity Analytics: Add error handling for reporting on groups which have no plan. !15291
- Convert Issue Analytics chart into ECharts. !15389
- Display group's full name when creating a project from custom group-level project templates. !15392
- Only in ee available selection entries in user settings adapted to match ce. !15452 (Marc Schwede)
- Rename Approvers field and modal title. !15461
- Add a tooltip to Add Designs button. !15471
- Show the paths for groups in groups dropdown. !15513
- Turn epic dates into one clickable block. !15722 (Lee Tickett)
- Add default route for admin/geo. !15726 (Lee Tickett)
- Improve unapproved MR merge button text. !15745 (Lee Tickett)
- Update the ES indexer to v1.3.0. !15821
- Groups dropdown: Fix group styles in dropdown. !15839
- Document SRV handling for DB load balancing. !16000
- Internationalization of shared/promotions/_promote_audit_events.html.haml. !16033 (Takuya Noguchi)
- Remove vue-resource from service_desk_service.js. !16041 (Lee Tickett)
- Remove unused classes for report comparison. !16045
- Remove vue-resource from related-issues. !16057 (Lee Tickett)
- Add CI variable for repository languages. !16477
- SAST template that doesn't rely on Docker-in-Docker. !16487
- Adding docs for Web IDE Default Commit Options. !16629
- Adding top border back to snippet files. !16709
- Remove vue-resource from drafts. (Lee Tickett)
- Changing instance of key-modern icon to key icon.
- Fixes style-lint errors and warnings for EE builds.scss file.


## 12.2.8

### Fixed (1 change)

- Geo: LFS not being synced. !17633


## 12.2.7

### Security (1 change)

- Restrict access for security reports in MR widget.


## 12.2.6

### Security (3 changes)

- Hide approvers if a rule has any hidden groups.
- Fix Gitaly SearchBlobs flag RPC injection [Gitaly v1.59.3].
- Prevent IDOR when adding groups to protected environments.


## 12.2.5

### Security (1 change)

- Do not allow creation of projects from group templates if project is not descendant of that group.


## 12.2.4

### Fixed (1 change)

- Fix group hooks not firing in PostReceive. !15598


## 12.2.3

### Security (2 changes)

- Limit number of jobs in running pipelines for the past hour on per plan basis. !1182
- Filter out old system notes for epics in notes api endpoint response.


## 12.2.2

### Security (2 changes)

- Limit number of jobs in running pipelines for the past hour on per plan basis. !1182
- Filter out old system notes for epics in notes api endpoint response.


## 12.2.1

- No changes.

## 12.2.0

### Security (5 changes)

- Gate MR head_pipeline behind read_pipeline ability.
- Queries for Upload should be scoped by model.
- Grant admin note permissions in epics for maintainers and owners.
- Fix bypass email verification when SCIM user is created via API.
- Do not allow localhost urls in GitHub Integration.

### Removed (1 change)

- Removes support for matching on app label for Kubernetes deploy boards, terminals, and pod logs. !14020

### Fixed (67 changes, 2 of them are from the community)

- Fix error when creating issues in scoped boards. !11080
- Resolve Snowplow tracking for notes does not work in Firefox. !12578
- Fix License App user count for ultimate. !14055
- Enable incremental elasticsearch index updates for wikis. !14057
- Ensure U2F javascript runs on GroupSAML callback. !14262
- Fix to allow adding multiple instance-level clusters. !14270
- Initialize chart data in same order as config. !14283
- Make side-nav expanded when on dependency list. !14314
- Add anchor to learn-more-button on the dependency list page so it links to the right location in the docs. !14316
- Un-block UI interactions while Code Quality MR widget is loading. !14323
- Enforce SSO on subgroups and projects. !14364
- Fix race condition on merge train that it cannot process merge request sometimes. !14386
- Fix MWPS/ADMTWPS system notes shows wrong sha. !14397
- Show position of merge trains in system notes. !14398
- Respect limited indexing when importing projects. !14413
- replace dropdown in project cards in Operations Dashboards with a remove icon. !14419
- Allow blank values for IP restriction setting. !14427
- Fix weight quick action to support 0 value. !14432
- Fix cluster health charts on instance level. !14440
- Fix on_environment scope to not re-order whole query. !14481
- Tick instance runner after customer purchases additional CI minutes. !14494
- Fix race condition of `refs/merge` competing overwrite. !14495
- Fix 'learn more'-link on dependency page. !14496
- Allow subgroups to use their parent group's custom project templates. !14499
- Support creating/publishing drafts with commit ID. !14520
- Do not include milestone attribute when promoting issue to epic. !14532
- Include Subgroups in Contribution Analytics calcualtions. !14536
- Fix GeoNode#name backward compatibility. !14564
- Starting a new discussion only on line without Draft note created on it. !14569
- Fix reply to discussion on promoted epic. !14576
- Fix UI breaking on forms on Bootstrap Grid system. !14581 (Takuya Noguchi)
- Geo - Show why node is unhealthy in the rake task to check the health of the secondary node. !14615
- Fix displaying feature flag names in the audit log. !14621
- Support emails as ID in SCIM. !14625
- Fix negative values in burndown charts. !14632
- Fixes #12780 by avoiding incorrect cached values. !14651
- Avoid Design Management thumbnails from being distorted/stretched. !14670
- Support 0 weight in issue sidebar. !14683
- Adds a downard chevron to Dashboards icon in the header. !14711
- Handling use case for repeat trial. !14714
- Fix suggested namespace in deploy boards help text. !14739
- Fix duplicated issues while sorting by weight. !14750 (Vasiliy Yaklushin)
- Resolve Make sure not to redirect to the onboarding welcome page on mobile devices. !14842
- Fix Jira DVCS integration not working when project name has dots. !14855
- Fix the Epics filter bar alignment. !14857
- Fix max attachment size used in CSV export email messages. !14884
- Fix issue that caused the "Merge Immediately" option not to be available when merge trains were enabled. !14894
- Fix error fetching project security dashboard data for maintainers with access to a project but not to its group & fix routing error for project security dashboard for projects not in a group. !14896
- fix: operation dashboard delete icon tooltip title. !14899
- Improve help text and docs about custom metrics. !14912
- Geo - Disable built-in Sidekiq retry for verification workers. !14946
- Remove visual review app feature flag. !14958
- Geo - Warn when reusing an existing tracking database. !14981
- Fix min approvals required for new MR rules. !14988
- Fix admin notes internationalization text. !15001
- Batching minutes reset queries to avoid query timeouts. !15002
- Only show a pull mirror if mirroring is actually enabled. !15049
- Update epic dates when creating an issue that adds the epic using commands. !15062
- Show correct historic max user count for a license. !15107
- Fix job scheduling when extra CI minutes purchased and minutes usage is above application shared Runners minutes limit. !15120
- Skip ES commit results for deleted projects. !15236
- Align "New metric" page title correctly to the rest of the page. !15259
- Bypass push rules for merge to ref service.
- Ensure LDAP Group Sync by Filter normalizes DNs.
- Add support for partial approval in chat message merge request event handler.
- Insights: Only display page config with valid values.
- Shrink empty/loading states for cluster health charts.

### Changed (33 changes, 2 of them are from the community)

- Update merge requests section description text on project settings page. !11098
- First pass at auto remediation changes. !12010
- Create incident issues by default for alerts. !12814
- Resolve Move approval user password input from inline to a modal. !14123
- Add Copy to Clipboard Button to Review App Modal. !14290
- Remove "Allow merge trains" option from project settings page. !14429
- Change epics reordering to not update timestamps. !14441
- Remove feature flag behind MR's multiple assignees. !14506
- Prioritize mirrors for CI over other mirrors. !14575
- Move external authorization service API management to EE. !14598
- Improve default title and description of issues opened from managed Prometheus alerts. !14614
- Add 'Security & Compliance' as top-level navigation item to the project-sidebar. !14628
- Add "Security" as nav-item to group-view sidebar. !14639
- MVC: Group and User Billing Page Improvement - Avatar and Name. !14660 (Ammar Alakkad)
- Geo: Increase HTTP read timeout of proxy requests to 60 s. !14671
- Show threshold in incident title for gitlab alerts. !14688
- Expose licence management reports comparison. !14723
- Move metrics alerts form to modal. !14760
- Add new documentation and link for automating Visual Review feedback. !14789
- Expose licence management report for pipeline. !14796
- Present container scanning report comparison via API. !14898
- Allow approvals_required to be lower than project. !14902
- Rename snowplow_collector_uri to snowplow_collector_hostname. !14963
- Remove duplicated 'New metric' button in prometheus configuration. !14964
- Remove validation of MR level approval rules in merge requests. !14968
- Add missing merge request committer approval setting to API. !15019 (jramsay)
- Move dependency scanning comparision logic to backend. !15023
- Update permissions for Dependency List. !15044
- Dependency List Job Failed Alert - Hide link to job if payload from API does not include 'job_path'. !15068
- Use vulnerability message on Dependency list. !15125
- Rename License Management to License Compliance. !15163
- Elasticsearch: index snippet content only up to 1 MB. !15215
- Add note count, updated timestamp, and closed tag to epics list view.

### Performance (9 changes)

- Remove support for checking legacy security reports. !14291
- Cache Geo checks for a certain time period instead of per request. !14513
- Cache vulnerability history per project. !14619
- Fix N+1 queries in vulnerabilities API. !14638
- Improve Elasticsearch database import by retrying only failed cases first. !14657
- Refactor feature flag scopes for_unleash_client. !14768
- Split MR widget into cached and non-cached serializers. !15045
- Geo: Don't wait when exiting the log cursor. !15070
- Geo: Improve performance of clean up worker for selective sync.

### Added (60 changes, 1 of them is from the community)

- Enabled setting the Security Dashboard as a default view for groups. !7889
- Paginate license management. !10983
- Allows any user to comment on a dismissed vulnerability. !12067
- Enable security gates for merge requests. !13109
- Enable deployment boards and pod logs for instance and group clusters. !13307
- Support for blocking merge requests. !13506
- Add the ability to publish and install NPM packages from groups and subgroups. !13986
- Expose saml_provider_id in the users API. !14045
- Allow adding groups to CODEOWNERS file. !14071
- Add group packages page. !14089
- Add merge train helper text to merge request widget. !14097
- Support remapping of Git repos via SSH with project aliases. !14108
- Allow bulk editing group issues. !14141
- Expose reject_unsigned_commits option via the API. !14165
- Add instance level analytics. !14173
- Show design boards at previous versions. !14292
- Build cascading train refs for parallel execution of Pipelines for merge trains. !14296
- Add notifications for CI Minutes quota limit approaching. !14328
- Require session with smartcard login for Git access. !14368
- Add analytics top navigation link. !14377
- Add Quick Actions for adding/removing epic parent relations. !14451
- Geo: Validate file transfers (attachments, LFS objects, artifacts). !14477
- Create system notes for scoped labels. !14487
- Show deploy boards for group cluster deployments. !14504
- Support feature flag gradualRolloutUserId strategy on backend. !14515
- Add percentage rollout support to feature flag UI. !14538
- Added new Design Management feature for GitLab Premium. With Design Management, you can upload design assets to issues and view them all together to easily share and collaborate with your team. !14582
- Add Ability to Enable Feature Flags by User ID. !14596
- Add ability to view different design versions. !14601
- Allow bulk editing group merge request milestones. !14616
- Add cycle analytics on group level. !14627
- Resolve Add point of interest discussions to designs. !14648
- Limit creation of the Alert Bot in usage ping. !14649
- Audit strategies for feature flag scopes. !14652
- Read and write User Admin notes via API. !14662
- Add date range dropdown for Analytics. !14681
- Allow auditors to see the group and project security dashboards. !14695
- Add `Incident` label to issues created by the Alert Bot. !14705
- Merge vulnerabilities data into Dependency List report. !14706
- Support an alert template field to allow for incident customization. !14710
- Add a rake task to run a LDAP group sync. !14735 (Harish Ramachandran and Cindy Pallares)
- Log impersonation actions in audit log. !14740
- Support feature flag userWithId strategy on backend. !14752
- Add vulnerabilities to dependency list. !14761
- Add project download & project export audit events. !14775
- Count design usage, in order to meet SMAU OKR. !14779
- Support multiple sites in DAST reports. !14787
- Allow adding email domain to group to limit users to ones with email in this particular domain. !14800
- Allow global search on comments. !14818
- Add filtering by vulnerabilities to Dependency List. !14825
- Support for bulk editing labels at a group level. !14827
- Add an Upgrade button to Group's billings page. !14849
- Add authorization to the dependency list. !14867
- Add cycle analytics on a group level - FE. !14891
- Add Dependency Scanning information to the Dependency List. !14955
- Tweak Geo node form text. !14957
- Geo: Make Object Storage synchronization in Geo Nodes configurable via Admin UI. !15000
- Enable security report approvals by default. !15087
- Add Collapse buttons to Operations settings. !15117
- Geo: Support replication for Docker container registries. !15135

### Other (19 changes, 2 of them are from the community)

- Update License Management section information under CI/CD settings. !4295
- Adds a popover to vulnerability-check approvals. !14038
- Show warning for deploy boards if legacy app label is used. !14103
- Change spelling of wildcare to wildcard on feature flag new and edit forms. !14171
- Rename `TOKEN_TYPES` to `USER_TOKEN_TYPES`. !14209 (Arun Kumar Mohan)
- Improved dependency proxy page with some small UI enhancements. !14448
- Replace 'JIRA' with 'Jira' for EE-specific code comments. !14479 (Takuya Noguchi)
- Remove unused EE::GitPushService. !14483
- Improved project level navigation for package features. !14492
- Add Ability to Remove Projects From the Envivonment Dashboard. !14563
- Increase rate at which UpdateAllMirrorsWorker schedules jobs and reschedules itself. !14573
- Cleaned up package list icons to improve consistency inside package section. !14607
- Limit width for onboarding popovers. !14641
- Updates the security dashboard documentation link. !14669
- Add counter columns to geo_node_statuses database table. !14943
- Geo - Rename recheck actions to reverify. !14979
- Remove deprecated name sast_container from licensed features. !14980
- Remove default relative_position from epic_issues. !15008
- Fix alignment of activity dropdown in epic tabs; add counter to discussion tab.


## 12.1.14

### Fixed (1 change)

- Geo: LFS not being synced. !17633


## 12.1.12

### Security (4 changes)

- Hide approvers if a rule has any hidden groups.
- Fix Gitaly SearchBlobs flag RPC injection [Gitaly v1.53.4].
- Prevent IDOR when adding groups to protected environments.
- Upgrade mermaid to prevent XSS.


## 12.1.10

- No changes.

## 12.1.5

- No changes.

## 12.1.4

### Fixed (3 changes)

- Don't send CI usage email notifications when quota is unlimited. !14810
- Fix variable mismatch in code quality widget. !14829
- Change package validation scope to fix Maven package naming functionality. !14922


## 12.1.3

### Fixed (3 changes)

- Allow bulk editing group issues for reporter access level and higher. !14744
- Initialize Application Table on Instance-wide Cluster Details. !14749
- Hide "Buy additional minutes" button for self-managed installs. !14826

### Added (4 changes)

- Add Vulnerabilities API scoping: pipeline. !14376
- Add policy for accessing dependencies. !14561
- Add filtering by package manager for dependencies. !14562
- Add dependency list public endpoint. !14612


## 12.1.2

### Security (1 change)

- Ensure the Insights configuration project is part of the group and is accessible to the current user.

### Security (6 changes)

- Don't override approval rules if not allowed.
- Grant admin note permissions in epics for maintainers and owners.
- Queries for Upload should be scoped by model.
- Fix bypass email verification when SCIM user is created via API.
- Prevent an XSS vector in the add approver email.
- Make vulnerability feedback invisible if limited access to repo.


## 12.1.1

### Fixed (1 change)

- Don't send CI usage email notifications for self-hosted instances. !14809


## 12.0.7

### Security (3 changes)

- Limit number of jobs in running pipelines for the past hour on per plan basis. !1182
- Queries for Upload should be scoped by model.
- Filter out old system notes for epics in notes api endpoint response.


## 12.0.6

- No changes.

## 12.0.2 (2019-06-25)

### Fixed (1 change)

- Take into account events created before milestone start. !14184


## 12.0.1 (2019-06-24)

- No changes.

## 12.0.0 (2019-06-22)

### Security (2 changes)

- Filter relative links in wiki for XSS.
- Fix XSS in Ancestor tooltip title.

### Removed (2 changes)

- Remove old approver system in favor of new approval rule system. !12436
- Geo: Remove deprecated wikis_count and repositories_count fields from the public API. !13025

### Fixed (36 changes, 1 of them is from the community)

- Group SAML identities cleaned up when leaving a group. !5817
- Make root relative URLs clickable in vulnerability modal. !9767
- Make burndown chart timezone aware. !10328
- Prevent files paths from overflowing in vulnerability info modal. !10606
- Fixed a bug where removing related issues could get stuck. !12316
- Fix anchor link in UI. !12737
- Add feature flag to group_scim javascript. !13078
- Geo - Enable Cron job to perform repository checks on a Geo secondary node. !13103
- Restrict child_epic and remove_child_epic quick actions when using mysql. !13152
- Disable licenses_app feature flag by default. !13291
- Fix security dashboard errors on IE11. !13319
- Respect limited indexing settings in rake tasks. !13437
- Geo - Does not redirect user to the custom home page URL on a Geo secondary. !13447
- Use quarantine size to check push size against repository size limit. !13460
- Fix SSO Enforcement when used with 2FA. !13473
- Fix Git over HTTP when using SAML SSO Enforcement. !13485
- Only use elasticsearch when it is enabled. !13495
- Add referenced-commands in no overflow list. !13550
- Hide action buttons while security dashboard is loading. !13576
- Fix alignment of label for admin notes on admin. !13592 (Takuya Noguchi)
- Use elasticsearch go indexer for wikis. !13743
- Handle case where site property is an array in DAST report. !13775
- Fix dast report parsing regression caused by change in zaproxy. !13789
- Fix port validation in .gitlab-webide.yml. !13846
- Fix "rule_type does not exist" error during consume_remaining_migrate_approver_to_approval_rules_in_batch_jobs migration. !13947
- Hide operations nav icon for small screens. !13960
- Remove free user info from non-ultimate license. !14010
- Use fallback approval rule if no eligible rules exist. !14042
- Fix 'Group > Usage Quota' menu item. !14043
- Fix incorrect epic ancestor links. !14092
- Show Usage Quotas regardless of namespace subscription. !14135
- Fix calculation of used extra CI minutes. !14217
- Remove class hiding spinner in board switcher.
- Fix broken filter by approvers.
- Remove extra spaces in MR list view approval counts.
- Remove extra border on tracing empty state page.

### Changed (18 changes)

- Allow merge requests to be merged even when it does not have up-to-date pipeline when merge request pipeline is enabled. !12309
- Migrate code_owners to rule_type enum on approval_merge_request_rules. !13036
- Avoid failing pull mirroring if LFS import fails. !13133
- Updates Pipeline Quota page to accomodate for Storage Quotas. !13139
- Align group and project level security dashboard UX. !13180
- Remove shared_runner_minutes_on_root_namespace feature flag. !13208
- Enable dependency proxy per group by default. !13574
- Move dependencies API endpoint to "security" namespace. !13897
- Allow developers to configure dependency proxy. !13899
- Use real data in `:project/security/dependencies` endpoint. !13906
- Use bulk-indexing API for project associations. !13917
- Update response schema for DependencyList endpoint and add status. !13918
- Geo - Make foreign data wrapper a hard requirement. !13940
- Polish SAML SSO configuration page. !13982
- Make Insights Generally Available. !14067
- Automatically index wikis in elasticsearch. !14095
- Require Hashed Storage to be enabled to create new Geo Nodes. !14102
- Changes to default insights charts.

### Performance (7 changes)

- Omit page counts in admin audit logs. !1306
- Improve scheduling of mirror updates to reduce frequency of database queries. !11217
- Limit count to improve query performance. !12231
- Avoid loading database objects for Elasticsearch results. !12691
- Avoid hitting Elasticsearch more than once on search. !13120
- Add index to count pending mirror updates. !13901
- Performance improvement when loading epics list. !13904

### Added (34 changes, 1 of them is from the community)

- Provide application-wide LDAP membership lock setting. !4354
- Added a "Require user password to approve" option on projects for merge request approvals to enable compliance in FDA regulated fields". !10364 (James Davila, Paul Knopf, Greg Smethells)
- Add "Allow merge trains" option to project settings page. !10803
- Add optional reason when dismissing vulnerabilities. !11226
- System notes for adding and removing epic relationships. !11416
- Show if user is using a license seat on admin user page. !11449
- Allow merge requests to block other MRs from being merged. !11600
- SSO enforement redirects to group sign in when not using SAML. !12246
- When a merge request is blocked by other unmerged merge requests, display them on the show page of a merge request. !12357
- Group SAML can be used to sign into a GitLab instance. !12660
- IP address restriction for groups. !12669
- Make the number of Elasticsearch shards and replicas configurable. !12713
- Add quick actions for adding and removing child epic relations to epic. !12772
- Adds a confidence filter to the Group Security Dashboard. !12805
- Expose Design blobs through GraphQL. !13037
- Expand pipeline variables passed downstream. !13197
- Add support for querying epics with GraphQL. !13248
- Add Merge Train auto merge strategy. !13278
- Adds Storage Counter. !13294
- Allow design blobs to be stored in Git LFS. !13389
- JIT users provisioning for group SAML. !13552
- Add Ability for Maintainers to Rotate Instance Id in Feature Flags. !13722
- Notify users when their CI minutes quota has run out. !13735
- Use Flipper as an A/B testing framework. !13755
- [New Auto Merge Strategy] Add To Merge Train When Pipeline Succeeds. !13767
- Add `dependency_list` report. !13900
- Add admin form to enforce a pipeline on an instance. !13923
- Count usage of DependencyList endpoint. !13962
- Add preliminary Dependency List frontend implementation. !13968
- Add Admin settings to disable project deletion. !14002
- Usage ping: Track amount of incident issues. !14013
- Sync file changes from Web IDE to Web Terminal. !14035
- Add report_approver to approval_merge_request_rules. !14050
- Add merge train position message under pipeline in merge request widget. !14064

### Other (9 changes, 2 of them are from the community)

- New user flow for SSOing into a GitLab.com group. !10338
- Improve vulnerability API. !12760 (Robert Schilling)
- Add action popover component for user onboarding. !13346
- Add help content popover component for user onboarding. !13363
- Expose services in the web ide terminal entity. !13665
- Rename boards spec name. !13725 (George Tsiolis)
- Fix typos in i18n strings for onboarding tour. !14153
- Externalize strings of chat page in user profile. !28632
- Remove commit count from storage quotass.


## 11.11.8

- No changes.

## 11.11.7

### Security (5 changes)

- Don't override approval rules if not allowed.
- Grant admin note permissions in epics for maintainers and owners.
- Prevent an XSS vector in the add approver email.
- Ensure the Insights configuration project is part of the group and is accessible to the current user.
- Make vulnerability feedback invisible if limited access to repo.


## 11.11.4 (2019-06-26)

### Fixed (1 change)

- Use quarantine size to check push size against repository size limit. !14269


## 11.11.3 (2019-06-10)

### Fixed (1 change)

- Fix create mr from vuln modal regression. !13524


## 11.11.2 (2019-06-04)

### Performance (1 change)

- Geo - Does not apply selective sync restrictions while counting registries on the tracking database. !13257


## 11.11.0 (2019-05-22)

### Security (1 change)

- Destroy project remote pull mirrors instead of disabling. !10355

### Fixed (26 changes)

- Add missing endpoint for user information to GitHub API. !10482
- Remove slack slash commands double up. !10555
- Display Scoped Labels on Issue Board. !10669
- Ensure custom group template feature is available only for groups on gold and silver. !10678
- Fix removing and updating insights config, and foreign key constraints. !11030
- Geo: Fix broken button to delete orphaned upload registries through Admin. !11156
- Resolve: Epic labels in system notes point to the epic itself. !11234
- Geo: Fix: Project sync failures usually double-increment *_retry_count. !11381
- Fix unauthenticated GET of public Epics API. !11485
- Hide ScopedBadge overflow notes. !11548
- Fixes a CI failure in jest. !11586
- Fix error when reordering/deleting subgroup epics. !11837
- Fix some filter bar tokens not showing up when multiple assignees are enabled. !11939
- Geo: Fix OAuth authentication with relative URLs. !11976
- Fix for not being able to remove the last namespace/project from elasticsearch limited namespaces/projects. !11989
- Fix approvals project settings section when merge requests disabled. !12070
- Enable alert bot to use quick actions. !12127
- Geo: Remove counts over geo_event_log table. !12146
- Geo: Prevent RegistryFinder calls on the primary. !12183
- Fix placement of LDAP icon in members list. !12304
- Use path instead of a URL for accessing approval settings. !12414
- Remove non-semantic use of `.row` in member listing controls. !12466
- Force tag overwrite on mirror update. !12491
- Fixes the feedback paths on the project security dashboard. !12849
- Fixed starting a review on images.
- Fix updating board attributes through API.

### Changed (13 changes)

- Group SAML enforcement requires active SSO session for group access. !10034
- Geo: Rename "Disable" to "Pause|Resume" (Admin > Geo Nodes). !10297
- Upgrade group security dashboard to use gitlab-ui line chart. !10479
- Geo - Implement selective sync support for the LFS objects FDW queries. !10757
- Documentation : Improve selective sync documentation. !11072
- Geo: Implement selective sync support for the FDW queries to count the number of attachments to sync. !11107
- Allowing Elasticsearch indexing gap recovering. !11408
- Geo - Implement selective sync support for the FDW queries to count attachments. !11518
- Geo - Implement selective sync support for the FDW queries to find attachments. !11544
- Geo - Add selective sync support for the job artifacts FDW queries. !11892
- Fetch all available groups when creating MR approval rule. !12096
- SSO enforcement requires active SAML session for web access to project resources. !12109
- Perform LDAP group sync on sign in only for new users.

### Performance (3 changes)

- Swap conditions to reduce frequency of database query. !11217
- Add index for mirror_user_id to projects table. !11422
- Geo - Improve performance of the selective sync cleanup worker. !11998

### Added (27 changes, 2 of them are from the community)

- Proxy websocket requests to build services. !9723
- Add dependency proxy for containers. !9750
- Added gitlab:elastic:projects_not_indexed rake task. !9854 (Jason Colyer)
- Added Snowplow tracking to notes. !10104
- Support multiple assignees for merge requests. !10161
- Add UI to enable/disable a dependency proxy on a group level. !10386
- Let the GitLab Alert bot open incident issues. !10460
- Remove feature flag `:incident_management`. !10569
- Allow multiple secondary nodes behind a load balancer. !10755
- Copy LFS objects from pull mirror. !10779
- Geo: Inform users about current replication lag in the UI on secondaries. !10807
- Autosave description in epics. !10844
- Keep track of packages_file in ProjectStatistics. !11020
- Adds a dismissal item to the vulnerability modal. !11028
- Add project level config for merge train. !11065
- Support pie charts in Insights. !11186
- Create ActiveRecordModel and table for Merge Train feature. !11204
- Allow adding GitLab license at installation time. !11244
- Added ZAP Full Scan support for DAST. !11269
- Add created_at and updated_at filters to Epics API. !11315 (jramsay)
- Add API to retrieve security vulnerabilities. !11539
- Basic Rails implementation for BOM. !11613
- Add Frontend Store and UI For Environments Dashboard MVC. !11702
- Track clicks on uninstall button for kubernetes implementation. !12048
- Add Vulnerabilities API scoping: severity, confidence, and dismissal. !12076
- Alert users that protected environments affects feature flags. !12168
- Support creating a new child epic from the API.

### Other (8 changes, 1 of them is from the community)

- Improve project settings page layout and UX. !10388
- Uses the more explicit vulnerability feedback endpoints on the front end. !10461
- Automatically enable multiple MR assignees feature flag. !10558
- Move geo_log_cursor binary to the ee folder. !10821
- Move sidekiq-cluster to ee/bin. !11001
- Move ee-specific code from boards/components/issue_card_inner.vue. !11032 (Roman Rodionov)
- Make all billing cards fit in view. !11602
- Extracted EE specific lines for spec/javascripts/vue_mr_widget/mock_data.js. !11847


## 11.10.8 (2019-06-27)

- No changes.
### Security (2 changes)

- Gate MR head_pipeline behind read_pipeline ability.
- Do not allow localhost urls in GitHub Integration.


## 11.10.7 (2019-06-26)

### Fixed (1 change)

- Use quarantine size to check push size against repository size limit. !14271


## 11.10.6 (2019-06-04)

### Fixed (5 changes, 1 of them is from the community)

- Fix removing and updating insights config, and foreign key constraints. !11030
- Fix the group's epic page. The Paste issue link placeholder shown as 'undefinedundefinedundefined' in Chinese environment. And the error message showed nothing. !11312 (wdmcheng)
- Fix approvals project settings section when merge requests disabled. !12070
- Use path instead of a URL for accessing approval settings. !12414
- Fix relative url root issues with license management. !12488


## 11.10.4 (2019-05-01)

### Fixed (1 change, 1 of them is from the community)

- Fix error retrieving licenses when relative URL in use. !11717 (Hiroyuki Sato)

### Changed (1 change)

- [Insights] Change the default weeks period limit to 12. !11498


## 11.10.3 (2019-04-30)

- No changes.

## 11.10.2 (2019-04-25)

### Security (1 change)

- Handle race condition when creating an MR approval.


## 11.10.1 (2019-04-23)

### Fixed (4 changes)

- Fix approval rules when used with relative url root. !10819
- Fix add/remove pipeline dashboard issue. !11029
- Fix JWT token check when repository does not exist. !11033
- Fix preventing approval of merge requests by an author. !11263

### Changed (2 changes)

- Improve SAML settings with validation, design, and help text. !10450
- Use a single color for the Insights time series bar charts. !11076


## 11.10.0 (2019-04-22)

### Security (3 changes)

- Check label_ids parent when updating issue board.
- Geo - Improve security while redirecting user back to the secondary after a logout & re-login via the primary.
- Expose only basic group attributes in boards API.

### Fixed (25 changes)

- User Statistics in Admin Dashboard now a button. !8807
- Fix misalignment of dropdowns in edit board modal of issue boards. !9909
- Geo: Support archive recovery or streaming replication types in health check. !9935
- Geo: Only display Geo-specific clone instructions button on a Geo Secondary node. !10007
- Resolve Deletion of vulnerability-associated issuables prevents security report from loading. !10016
- Elasticsearch API: Fix project_id showing as 0 for all blobs. A reindex will be required. !10020
- Make editing the filters in the Group Security Dashboard easier. !10138
- Geo - Reset the verification checksum after deployment refs are created. !10160
- Search snippets via elasticsearch. !10325
- Fixed bug preventing users from adding child epics with multiple children. !10331
- Fix merge requests being added to Jira Development Panel. !10342
- Fix authors of merge commits being excluded from approving an MR. !10359
- Fix ChatOps Slack responder for gitlab.com. !10416
- Fix sorting by priority with filtering by approvers. !10446
- Make UpdateRepositoryStorageService idempotent. !10457
- Fix broken links to protected environments on the CI/CD settings page. !10470
- Notify owner that group is invalid when LDAP "Sync now" fails. !10509
- Fix user agent string for Hosted Jira. !10545
- Fix query used to calculate number of users over license. !10556
- Fix pipeline bridge serialization error. !10565
- Correct path to cluster health partial. !10638
- Ensure Insights charts show all periods even if there are no data. !10733
- Hide scoped labels help text without corresponding license. !10737
- Fix merge request operation failure (e.g. assigning user) when project approvers required increases. !10766
- Include subgroups when finding Insights issuables. !10801

### Changed (27 changes)

- Move project search bar into modal dialog on Operations Dashboard page. !9260
- Geo - Add selective sync support for the FDW queries to count synced registries. !9445
- Geo - Add selective sync support for the FDW queries to count failed registries. !9527
- Convert enable group authentication checkbox to toggle button. !9816
- Geo: Limit max backoff time by 1 hour, instead of 7 days. !9893
- Documented Guide to using Geo in HA with RDS cross-region replicas. !9985
- Dynamically resize security group dashboard vuln graph. !10028
- Add self approval of merge requests setting to merge requests approvals API. !10050
- elasticsearch: Switch from LZ4 to DEFLATE compression. !10072
- Geo - Store the invalid checksum when we have a mismatch. !10101
- Add requested resources to cluster health metrics. !10135
- Allow self-approvals in fallback approval rules. !10218
- Geo - Add selective sync support for FDW queries to find verified registries. !10255
- Add file line number to vuln modal. !10265
- Geo - Add selective sync support for FDW queries to find registries where verification has failed. !10266
- Enforce Geo JWT tokens scope for repository sync. !10303
- Display link to review note in text email, similar to HTML email. !10401
- Geo - Add selective sync support for the FDW queries to find mismatch registries. !10434
- Geo - Add selective sync support for queries to find registries retrying verification. !10436
- Geo - Add selective sync support for the FDW queries to find registries to verify. !10438
- Improve DAST location fingerprints. !10487
- Change order in dast location fingerprint. !10487
- Geo: Add selective sync support for the FDW queries to find unsynced projects. !10522
- Enrich container scanning with more data on the frontend. !10526
- [Geo] Don't mark sync as successful if repo does not exist because of some problems. !10578
- Move operations dashboard from Ultimate to Premium. !10586
- Support multiple chart per page for Insights.

### Performance (3 changes)

- Avoid a Gitaly N+1 when loading commits for Elasticsearch search results. !9760
- Geo: Optimize repository and wiki verification counts. !9939
- Avoid N+1 when loading Code search results with Elasticsearch enabled. !10394

### Added (31 changes, 1 of them is from the community)

- Add approval and unapproval webhooks. !8742
- Adding pipelines to the operations dashboard. !9197
- Add operations dashboard usage counts to usage data. !9291
- Automatically deprovision and update users from a configured identity via SCIM. !9388
- Add SCIM Token section to SAML SSO Settings. !9619
- Use merge request MERGE ref for attached merge request pipelines. !9622
- Geo: Support syncing over non-publicly accessible URLs. !9634
- Prevent merge if the merge request pipeline is stale. !9643
- Block possibility to change email for users with group managed account. !9712
- Geo admin panel for upload verification. !9720
- Geo: Create separate models for different registries. !9755
- Add ability to purchase extra CI minutes. !9815
- Update Web IDE config to accept ports. !9818
- Allow per-project and per-group enabling of Elasticsearch indexing. !9861
- Geo: Help admins diagnose configuration problems. !9988
- Added MAVEN_CLI_OPTS env var support to License Management CI job. !10012
- Show DAST vulnerabilities in the Group Security Dashboard. !10271
- Show DAST in Group Security Dashboard Back-End. !10277
- Removing pipeline dashboard feature flag. !10302
- Update user name upon LDAP sync. !10316 (@icode1)
- Collect usage of pod logs feature. !10370
- Added metrics reports widget to merge request page. !10380
- IP whitelisting for Geo-enabling functionality in the primary. !10383
- Persist in the URL the page and day range of vulnerabilities viewed in the Group Security Dashboard. !10402
- Add 'Metrics' job artifact report type. !10452
- Create a user via SCIM. !10456
- Geo: Display secondary replication lag on console (if lag > 0 seconds). !10471
- Add Roadmap to Epic page. !10488
- Expose merge request pipeline parameters for MR widget. !10502
- Allow instance admins to link all projects to Jira DVCS. !10541
- Added mutually exclusive key value labels.

### Other (4 changes)

- Simplify admin instance licenses page. !9785
- Extract EE specific files and externalize strings in admin application settings. !9930
- Add specs for coerced labels parameter in Epics API. !9932
- Improve project service desk settings. !10381


## 11.9.12 (2019-05-30)

### Security (3 changes, 1 of them is from the community)

- Filter relative links in wiki for XSS. (kerrizor)
- Fix XSS in Ancestor tooltip title.
- Ignore out of range epic IDs.


## 11.9.10 (2019-04-26)

### Security (1 change)

- Handle race condition when creating an MR approval.

### Fixed (1 change, 1 of them is from the community)

- Fix the group's epic page. The Paste issue link placeholder shown as 'undefinedundefinedundefined' in Chinese environment. And the error message showed nothing. !11312 (wdmcheng)


## 11.9.9 (2019-04-23)

### Fixed (1 change)

- Fix approval rules when used with relative url root. !10819


## 11.9.8 (2019-04-11)

### Fixed (1 change)

- Fix sorting by priority with filtering by approvers. !10446


## 11.9.7 (2019-04-09)

### Security (1 change)

- Expose only basic group attributes in boards API.


## 11.9.6 (2019-04-04)

### Fixed (3 changes)

- Fix project approval rule with only private group being considered as approved when override is allowed. !10356
- Fix approval rule sourcing from forked MR. !10474
- Guard against ldap_sync_last_sync_at being nil. !10505

### Added (1 change)

- Add Insights frontend to retrieve and render chart. !9856


## 11.9.5 (2019-04-03)

### Fixed (3 changes)

- Fix project approval rule with only private group being considered as approved when override is allowed. !10356
- Fix approval rule sourcing from forked MR. !10474
- Guard against ldap_sync_last_sync_at being nil. !10505

### Added (1 change)

- Add Insights frontend to retrieve and render chart. !9856


## 11.9.3 (2019-03-27)

### Security (1 change)

- Check label_ids parent when updating issue board.


## 11.9.2 (2019-03-26)

### Security (2 changes)

- Geo - Improve security while redirecting user back to the secondary after a logout & re-login via the primary.
- Check label_ids parent when updating issue board.


## 11.9.1 (2019-03-25)

### Fixed (1 change)

- Fix date save for Epic to reflect on UI immediately after save. !10321


## 11.9.0 (2019-03-22)

### Security (4 changes)

- Prevent Group SAML authorizing sign in without prior user approval.
- Respect group membership lock when importing a member from another group.
- Remove the possibility to share a project with a group that a user is not a member of.
- Prevent SAML access when disabled by group admin on GitLab.com.

### Fixed (22 changes)

- Allow assigning Prometheus alerts to multiple environments. !7361
- Fix repo pushes while initial Elasticsearch indexing not permitting initial indexing to complete. !9478
- Fix vulnerability occurrence scope to trailing 30 days. !9494
- Skip whitelisted vulnerabilities in Container Scanning reports. !9528
- Fix npm registry for yarn. !9599
- Renders inline downstream & upstream pipelines. !9627
- Prunes whole Geo event when there's only a primary. !9630
- Fix alert notifications for non-public projects. !9636
- Fix 500 error when visiting merged merge request. !9648
- Allow plus symbol in maven package version. !9657
- Show commands applied message when promoting issues to epics. !9669
- Ensure comments from merge request review is displayed in the same order as user commenting order. !9684
- Geo - Fix selective sync by namespace. !9732
- Fix bridge jobs than can be hidden keys too. !9796
- Fix approval-related UI showing up in free plan. !9819
- Add 'No approvals required' view to approval rules (behind feature flag). !9899
- Fix npm package install with a dot in the name. !9900
- GroupSAML for GitLab.com prevents blank NameID. !9907
- Fix protected environment initializer. !10150
- Fix SSH pull mirrors not working. !10272
- Fix HTML spew in Locked Files page.
- Fixes Broken new/edit feature flag form.

### Changed (9 changes, 1 of them is from the community)

- Remove authorization from /managed_licenses. !8541
- Consider dismissed items in security reports summary. !9275
- Add backend for cross-project pipeline dashboard MVC. !9396
- Create merge request approval rule for each code owner entry. !9455
- Split severity and confidence values for vulnerabilities. !9495
- Enforce Geo JWT tokens scope for file uploads and Geo API. !9502
- Update cluster health empty state. !9540 (George Tsiolis)
- Add extra graph spacing on the Security Dashboard Group Vulnerability Chart. !9780
- Add Kerberos URL back to clone panel. !9840

### Performance (1 change)

- Eliminate N+1 queries in Epics API. !9897

### Added (23 changes, 1 of them is from the community)

- Enabled setting the Security Dashboard as a default view for groups. !7889
- Add reordering of child epics. !9283
- Create MR from Vulnerability Solution. !9326
- Create pool repositories on Geo secondaries. !9428
- Add date range for security dashboard graph. !9446
- Add filtering merge requests by approvers. !9468
- Add audit log for managing feature flags. !9487
- Add DELETE package API endpoint. !9623
- Enrich container scanning report. !9641
- Adapt feedback for Container Scanning vulnerabilities. !9655
- Enforce merge request approvals from code owners. !9656
- Added vendored CI/CD template for Dependency Scanning job. !9660
- Add Insights config behind the "group_insights" feature flag. !9665
- Add single package API endpoint. !9667
- Added GET /licenses and DELETE /license/:id endpoints. !9733
- Add container scanning results to group security dashboard. !9736
- Add an incident management settings form and create issues from alertmanager alerts. !9773
- Add API for reordering child epics. !9781
- Allow guests to comment on epics. !9783
- Display Recent Boards in Board switcher. !9808
- Add Ancestors in Epic Sidebar. !9817
- Add vendored templates for SAST, DAST, Container Scanning and License Management job definitions. !9921
- Add realtime validation for user fullname and username on validation. !25017 (Ehsan Abdulqader @EhsanZ)

### Other (12 changes, 1 of them is from the community)

- Use export-import svg from gitlab-svgs. !9453
- Renames 'revert dismissal' to 'undo dismiss' on the Group security dashboard. !9500
- Using positional arguments in request specs have been deprecated. !9506 (Jasper Maes)
- Splits the severity and confidence constants in the group security dashboard frontend. !9535
- Add Gitlab.com gold trial callout to /billings. !9611
- Update project settings section titles and info. !9614
- Improve visual consistency of values in vulnerability modal. !9616
- Limit Group Security Dashboard to selected types of report. !9626
- Make related issues components reusable. !9730
- sidekiq-cluster: put each sidekiq in a new pgroup. !9775
- License Management: Load up to a 100 licenses per default. !9913
- Adds documentation for autoremediation. !10054


## 11.8.10 (2019-04-30)

- No changes.

## 11.8.3 (2019-03-19)

- No changes.

## 11.8.2 (2019-03-13)

### Fixed (4 changes)

- Fix 500 error when visiting merged merge request. !9648
- Fix bridge jobs than can be hidden keys too. !9796
- Fix approval-related UI showing up in free plan. !9819
- Add 'No approvals required' view to approval rules (behind feature flag). !9899


## 11.8.0 (2019-02-22)

### Security (2 changes)

- Sanitize user full name to clean up any URL to prevent mail clients from auto-linking URLs. !790
- Hide personal access tokens from other maintainers.

### Fixed (28 changes, 1 of them is from the community)

- Add keyboard navigation to issue board switcher and remove duplicate scroll bar. !8591
- Geo: Always update the default branch on the secondary. !9064
- Fix public group milestones not shown in epics autocomplete. !9068
- Check hosts file for nameserver IP. !9071
- Fixes the icon for fixed vulnerability in Container Scanning report. !9120
- Return 400 error instead of 500 when upload maven package with invalid version. !9125
- Fix mirrors that have invalid SSH public auth mode set. !9135
- Hide packages without version from UI. !9151
- Remove duplicate "Operations Dashboard" header/breadcrumb. !9152 (Nathan Friend)
- Create UTC date in subscription table. !9166
- Display epic icon in related epics list. !9166
- Don't validate Jenkins username if password is blank. !9198
- Don't show Alert widget for non-licensed users. !9224
- Group security dashboard: Fix overflow for Vulnerabilities with long titles. !9271
- Geo - Respect shard restriction while loading new resources to verify on the Geo secondary node. !9343
- When cleaning up repositories, ensure orphaned entries do not remain in the tracking database. !9344
- Geo - Make sure project does not meet selective sync rule before deleting it. !9345
- Fix alert notification emails are not being sent. !9393
- Fix alert notifications for managed Prometheus. !9402
- Replacing old blob methods in ElasticSerach module. !9418
- Add checks to prevent cycling hierarchy in epics structure. !9438
- Fix bug where users could not be added in protected branch rules. !9474
- Avoid SAML required_groups indiscriminately unblocking users on login. !9489
- Resolve Cannot scroll forwards in time for roadmap view. !9530
- Fix unleash server side cannot return feature flags. !9532
- Show alerts settings only for manual configuration. !9538
- Fix access to constant Gitlab::RepositorySizeError. !9579
- Clear our import data credentials when adding new mirrors. !24339

### Deprecated (1 change)

- Geo: Show hashed storage warnings on geo nodes page. !8433

### Changed (14 changes)

- Prevent commit authors from self approvaling merge requests. !9007
- Add docs link to explain legacy and new email format. !9020
- Recursively expands upstream and downstream pipelines. !9073
- Geo: Don't show external link icon on current node. !9130
- Issues created from vulnerabilities are now confidential by default. !9157
- Validate custom metrics. !9178
- Change paginate number to 20. !9213
- Convert buttons to button group on Group Security Dashboard. !9220
- Make it possible to edit Geo primary through API. !9328
- Geo: Handle repository and wiki sync separately in Geo::ProjectSyncWorker. !9360
- Geo: Add settings page empty state. !9415
- Renders New and Edit forms for feature flag in Vue and allow to define scopes.
- Improves title in feature flags empty states.
- Adds environment column to the feature flags page.

### Performance (5 changes)

- Solve a N+1 issue in Groups::AnalyticsController. !4508
- Refactored Epic app in Vuex for better performance and maintenance. !9361
- Optimize slow pipelines.js response. !9387
- Disable commit checks when no push rules are active. !9569
- Enable some frozen string in ee/lib.

### Added (22 changes, 1 of them is from the community)

- Elasticsearch: Support for Gitaly. !7434
- Canary deployment callout on the environments page. !8457
- Allow to filter notes in epics. !8978
- Multiple blocking merge request approval rules (behind feature flag). !9001
- Add support for auto-expanding Roadmap timeline on horizontal scroll. !9018
- Added Snowplow tracking to issues import. !9067
- Persist Group Level Security Dashboard state in URL. !9108
- Multiple environments support for feature flags (Unleash API standpoint). !9110
- Shows the approval given/required counts and its status for each MR when viewing the Merge Requests page. !9142 (Glavin Wiechert, Andy Steele)
- Support CURD operation for feature flag scopes. !9182
- Add epic links API endpoints. !9188
- Store DAST scan results in the database. !9192
- Add LDAP integration to smartcard authentication. !9235
- Allow SSO enforcement in group settings for GitLab.com. !9240
- Add API endpoint for project packages. !9259
- Add upvote/downvote information to epics API. !9264
- Resolve Implement access controls when SSO enforcement enabled. !9270
- Add package files API endpoint. !9305
- Support alerts from external Prometheus servers. !9334
- Cross-project pipelines support in .gitlab-ci.yml. !9374
- Enable mails for external alerts. !9457
- Moving repository across shards leaves the pool.

### Other (13 changes, 7 of them are from the community)

- Gather JIRA DVCS integration usage data. !8949
- ActiveRecord::Migration -> ActiveRecord::Migration[5.0] for AddAlertManagerTokenToClustersApplicationPrometheus and EnqueuePrometheusUpdates. !9049 (Jasper Maes)
- Track navbar links in Snowplow. !9059
- Adds snowplough tracking for the group security dashboard filters. !9119
- Support Ajax endpoints for FeatureFlagsController. !9127
- Fix deprecation: Passing an argument to force an association to reload is now deprecated. !9140 (Jasper Maes)
- Fix deprecation: #original_exception is deprecated. Use #cause instead. !9141 (Jasper Maes)
- Uses GLDropdown for licence management. !9237
- Replace deprecated render text. !9346 (Jasper Maes)
- Fix several ActionController::Parameters deprecations. !9347 (Jasper Maes)
- Fix deprecation: uniq is deprecated and will be removed from Rails 5.1. !9348 (Jasper Maes)
- Turn on rubocop for frozen string in ee/. (gfyoung)
- Creates an EE component for the pipeline graph.


## 11.7.12 (2019-04-23)

- No changes.

## 11.7.11 (2019-04-09)

### Security (1 change)

- Expose only basic group attributes in boards API.


## 11.7.10 (2019-03-28)

### Security (1 change)

- Check label_ids parent when updating issue board.


## 11.7.8 (2019-03-26)

### Security (2 changes)

- Geo - Improve security while redirecting user back to the secondary after a logout & re-login via the primary.
- Check label_ids parent when updating issue board.


## 11.7.7 (2019-03-19)

- No changes.

## 11.7.5 (2019-02-05)

### Fixed (2 changes)

- Fix Kerberos authentication. !9390
- Fix background migration error when project repository is missing. !9392


## 11.7.2 (2019-01-29)

### Security (6 changes)

- Avoid leaking unauthorized approver group members. !766
- Sanitize user full name to clean up any URL to prevent mail clients from auto-linking URLs. !791
- Check access rights when creating/updating ProtectedRefs.
- Fix locked file visibility issue for private repositories.
- Filter out non-project member approvers.
- Remove HTTP POST in JIRA OAuth access_token endpoint.


## 11.7.1 (2019-01-28)

### Security (6 changes)

- Avoid leaking unauthorized approver group members. !766
- Sanitize user full name to clean up any URL to prevent mail clients from auto-linking URLs. !791
- Check access rights when creating/updating ProtectedRefs.
- Fix locked file visibility issue for private repositories.
- Filter out non-project member approvers.
- Remove HTTP POST in JIRA OAuth access_token endpoint.


## 11.7.0 (2019-01-22)

### Security (1 change)

- Add a shared secret to prevent abuse of the alert endpoint.

### Fixed (27 changes, 2 of them are from the community)

- Defaults to feature flags link for Operations entry. !8622
- Fix error on explore page when logged out due to gold trial callout. !8674
- Prevents the empty state from showing when the dashboard errors. !8703
- Allow matching only the repo-root for CODEOWNERS. !8708
- Fix adding labels to epics using quick actions. !8772
- Geo: Keep the minimum cursor last event. !8832
- Reinstate sorting issuable by weight. !8834
- Geo - Show the proper label for the last repository check run on Geo projects page. !8844
- Resolve Reorder gitlab:elastic:index rake tasks to ensure wikis and database are completed even if projects error out. !8852
- Remove dash on issue weight for unauthorized users. !8882 (George Tsiolis)
- Dismiss epic promotion and persist it across reloads. !8885
- Fix JIRA Development Panel links with subgroups. !8908
- Remove epic field in sidebar for projects without groups. !8919
- Remove duplicate padding from issue board switcher. !8928
- Resolve Ctrl+Enter immediately adds MR comment. !8932
- Geo: Ignore invalid attributes when updating Geo node status. !8957
- Fix border-radius for related issues. !8958 (Johann Hubert Sonntagbauer)
- Fix Security Dashboard Header font size. !9011
- Fix title and description for issue created from a vulnerability. !9022
- Pseudonymizer: Gracefully handle empty pseudo entries. !9044
- Fix permission check when creating an issue from a vulnerability. !9055
- Docfix - broken doc links for Secure/Autodevops features. !9058
- Fix Error 500 when deleting a pipeline via the API. !9104
- Uses project_id instead of project on the group security dashboard. !9109
- Recursively get all of a groups projects. !9205
- Fix data migration failure if approvals_before_merge is set to too high. !9217
- Don't remove milestones when moving issues to board backlog from non-milestone list.

### Changed (5 changes, 1 of them is from the community)

- Update Geo nodes empty state. !8576 (George Tsiolis)
- Add search field to issue board switcher. !8862
- Allow downloading package files from UI. !8888
- Changes to the data model for counts on the Group Security Dashboard. !9035
- Fix packages UI mentioned only Maven packages support. !9132

### Performance (2 changes, 1 of them is from the community)

- Fix timeout loading Open list when board contains assignee lists.
- Enable some frozen string in ee/lib. (gfyoung)

### Added (17 changes)

- Add an instance-level endpoint for downloading maven packages. !8274
- Add NPM registry support to GitLab packages. !8673
- Store container scanning CI jobs results into the database. !8797
- Add a group-level endpoint for downloading maven packages. !8798
- Add Filtering vulnerabilities in the Group Security Dashboard. !8817
- Allow to filter Feature Flags. !8821
- Geo - Show last verification time on Geo projects page. !8845
- Adds basic filtering to the Group Security Dashboard frontend. !8886
- Autocomplete issues and MRs in epics. !8936
- Adds project filtering to the GSD. !8944
- Allow using TCP for DB load balancing DNS lookups. !8961
- Add filtering for summary and history on security dashboard. !8972
- Add solution card to the vulnerability modal. !9030
- Allows the Group Security Dashboard to select multiple filters. !9031
- Added Snowplow tracking to issues export. !9045
- Add support for relationship between epics. !9051
- Added pagination to epics API endpoint.

### Other (13 changes, 3 of them are from the community)

- Promote starting a GitLab.com Gold trial on the dashboard. !6947
- Adds event tracking to navbar. !7787
- Update tracing settings to match error tracking settings. !8786
- Adapt subscriptions page for free plans and trials. !8838
- Support for new SAST and dependency scanning report format. !8869
- Remove deprecated ActionDispatch::ParamsParser. !8897 (Jasper Maes)
- Fix deprecation: Comparing equality between ActionController::Parameters and a Hash is deprecated. !8914 (Jasper Maes)
- Removes Notes from GitLab Pseudonymizer config. !8923
- Add count of projects with tracing enabled to usage ping data. !8940
- Adds dependency scanning to the report type filters on GSD. !9034
- Fix deprecation: Using positional arguments in specs for EE spes in spec/. !9040 (Jasper Maes)
- Pass issuable-type in AddIssuableForm. !9111
- Gather deepest epic relationship data.


## 11.6.11 (2019-04-23)

- No changes.

## 11.6.10 (2019-02-28)

### Security (5 changes)

- Remove the possibility to share a project with a group that a user is not a member of.
- Prevent Group SAML authorizing sign in without prior user approval.
- Prevent SAML access when disabled by group admin on GitLab.com.
- Respect group membership lock when importing a member from another group.
- Ignore out of range epic IDs.


## 11.6.9 (2019-02-04)

- No changes.

## 11.6.8 (2019-01-30)

- No changes.

## 11.6.5 (2019-01-17)

### Fixed (1 change)

- Fix Error 500 when deleting a pipeline via the API. !9104


## 11.6.4 (2019-01-15)

- No changes.

## 11.6.3 (2019-01-04)

### Fixed (1 change)

- Fix instance project templates no longer working. !9019


## 11.6.2 (2019-01-02)

### Fixed (1 change)

- Fix issue ID wrapping and avatar counter shrinking in Related Issues list. !8854


## 11.6.1 (2018-12-28)

### Security (1 change)

- Add a shared secret to prevent abuse of the alert endpoint.


## 11.6.0 (2018-12-22)

### Security (7 changes)

- Switch from CBC to GCM for Geo logout tokens. !8518
- Prevent reporter roles from viewing the Jaeger tracing settings page.
- Sanitize tracing external_urls before saving to DB and when displaying the URL to prevent XSS issues.
- Fix IDOR at /drafts/publish.
- Authorize users when listing board users and milestones.
- Resolve: Guest can set weight of a new issue.
- Fixes XSS with merge request approvers selection.

### Fixed (27 changes, 2 of them are from the community)

- Ensure that avatars in approvals have correct tooltip. !6269
- Geo: Fix push to secondary over SSH for LFS. !8044
- Don't show packages tab and settings for starter license. !8270
- Makes the vulnerability name on the Group Security Dashboard a button for better A11y. !8341
- Used the iid instead of the id for linked issues on the Group Security Dashboard. !8357
- Show navigation line separator when instance etrics is disabled. !8379 (George Tsiolis)
- Fix project deploy key creation and deletion as admin. !8432
- Changes initial state for disabled prometheus integrations. !8434
- Fix a typo in Admin: intergration -> integration. !8444 (Vincent AUBERT)
- Geo: Moving registry deletion into the job that deletes the files and project record. !8480
- Parameterize alerting rules with variables. !8481
- Fix PostReceive failing for project mirrors missing local branch. !8495
- Rails 5: Fix the check whether the database is in read-only mode. !8594
- Raisl 5: Fix Gitlab::Database::LoadBalancing#caught_up? check. !8595
- Renders upstream and downstream pipelines in the main pipeline graph. !8607
- Fix issue board api with special milestones. !8653
- fix pod dropdown not switching pod logs. !8660
- Geo - Respect the next retry time when re-verifying failed repositories. !8661
- Update elasticsearch system check to check for new supported versions. !8683
- Handle null start or due dates for dates sourcing milestone in Epics. !8689
- Fixed license managment path in MR widget for fork cases. !8700
- Fix gitlab:geo:check rake task. !8714
- Fix ability to choose shards for selective sync. !8717
- Add Rails.version to the Geo cache keys. !8775
- Support older NGINX version forwarding the client certificate for smartcard auth. !8784
- Remove duplicated smartcard login button. !8793
- Disable password autocomplete in mirror form fill.

### Deprecated (1 change)

- Deprecate non-hashed repository storage for Geo installations. !8739

### Changed (17 changes, 1 of them is from the community)

- Adds Group SAML metadata endpoint. !5782
- Group SAML SSO page warns when linking account. !8295
- Change the delete custom metric alert. !8430
- Replace weight icon. !8448 (George Tsiolis)
- Switch snowplows stateStorageStrategy to cookie. !8461
- Move merge request approval settings. !8493
- Geo: Constantly reverify repositories. !8550
- Add file and line numbers to issues created from SAST vulnerabilities. !8578
- Redesign MR header sections and approvals (EE). !8593
- Add packages_enabled attribute to Projects API. !8604
- Run geo check task from gitlab check. !8616
- Change issue create weight dropdown to an input. !8648
- Add epics state filtering in roadmap view. !8658
- Users can unlink Group SAML from accounts page. !8682
- Update casing in Built-in on project templates tab. !8688
- Epic issue list and related issue list re-design.
- Add sort direction button with sort dropdown for Epics and Roadmap.

### Performance (5 changes, 3 of them are from the community)

- Remove partial index for projects on mirror and mirror_last_update_at. !8585
- Enable some frozen string in ee/app. !8667 (gfyoung)
- Remove redundant indices for is_sample on push_rules and next_execution_timestamp on project_mirror_data. !8695
- Enable some frozen string in ee/app. (gfyoung)
- Enable some frozen string in ee/app. (gfyoung)

### Added (10 changes)

- Add support for Group-level project templates. !6878
- Added web terminals to Web IDE. !7386
- Promote an Issue to an Epic using quick action. !8051
- Smartcard authentication. !8120
- Adds Security dashboard empty state. !8443
- Add vulnerability history at group level. !8603
- Adds group security dashboard metrics chart. !8631
- Add milestones autocomplete for epics. !8632
- Parse and store dependency scanning reports in database. !8642
- Adds EE store to handle upstream & downstream pipelines.

### Other (13 changes, 4 of them are from the community)

- Add subscription table to GitLab.com billing areas. !7885
- UX improvements for the group security dashboard. !8217
- Restyles the dismissed vulnerabilities. !8401
- Adds PHILOSOPHY.md and references GitLab Product Handbook. !8515
- Make sidekiq-cluster play well with Sidekiq 5.2.2+. !8522
- Rails5: Passing a class as a value in an Active Record query is deprecated. !8540 (Jasper Maes)
- render :nothing option is deprecated, Use head method to respond with empty response body. !8560 (Jasper Maes)
- Add help page link for licence management in CI/CD settings. !8561 (George Tsiolis)
- Re-orders the Group Security Dashboard. !8624
- Move EE only differences for finders. !8629 (George Tsiolis)
- Add count of projects with at least one package to a usage ping data. !8641
- Added recommendations for handling deleted documents in Elasticsearch.
- Use new information-o icon for Security Dashboard.


## 11.5.11 (2019-04-23)

### Security (1 change)

- Respect group membership lock when importing a member from another group.


## 11.5.8 (2019-01-28)

### Security (6 changes)

- Avoid leaking unauthorized approver group members. !766
- Sanitize user full name to clean up any URL to prevent mail clients from auto-linking URLs. !793
- Check access rights when creating/updating ProtectedRefs.
- Fix locked file visibility issue for private repositories.
- Filter out non-project member approvers.
- Remove HTTP POST in JIRA OAuth access_token endpoint.


## 11.5.5 (2018-12-20)

- No changes.

## 11.5.3 (2018-12-06)

- No changes.

## 11.5.2 (2018-12-03)

### Fixed (2 changes)

- Fix inability to scroll dashboard. !8459
- Fix issues analytics query when ordering issues by priority. !8509


## 11.5.1 (2018-11-26)

### Security (6 changes)

- Sanitize tracing external_urls before saving to DB and when displaying the URL to prevent XSS issues.
- Prevent reporter roles from viewing the Jaeger tracing settings page.
- Fix IDOR at /drafts/publish.
- Authorize users when listing board users and milestones.
- Resolve: Guest can set weight of a new issue.
- Fixes XSS with merge request approvers selection.


## 11.5.0 (2018-11-22)

### Security (2 changes)

- Escape entity title while autocomplete template rendering to prevent XSS. !696
- Prevent templated services from being imported.

### Removed (1 change)

- Remove security report summary from pipelines view. !7844

### Fixed (25 changes, 3 of them are from the community)

- Geo: Remove connectivity check from primary to secondary from gitlab:geo:check rake task. !7821
- Include (closed) for closed epics in parsed text. !7946
- Add new state to the cluster application vue app. !7954
- Do not allow to assign an issue to an epic twice. !8004
- [Geo] Fix: Deleting a project leaves orphaned LFS objects and CI Job artifacts around. !8031
- Support `/client/features` Unleash endpoint. !8045
- Fix button rendering in license management in FF. !8046
- Geo: Handle orphaned Uploads records. !8054
- Geo - Redirect user back to the secondary after a logout & re-login via the primary. !8157
- Fix approver removal still being conducted even when "Cancel" is clicked in confirmation prompt. !8178
- Link project short SHA to commit url. !8214
- Update ops dashboard remove dropdown button. !8236 (George Tsiolis)
- Clear ops dashboard project search input on submit. !8239 (George Tsiolis)
- Fixes a dismissed vulnerability bug on the group security dashboard. !8343
- Fixes missing fields on the group security dashboard. !8360
- Fixes the view issue button in the Group Security Dashboard. !8385
- Ops Dashboard should be available for public projects on GitLab.com. !8399
- Update draft comments design to match new design. !8405
- Change issues analytics breadcrumb. !8414 (George Tsiolis)
- Include classification label in project API. !8426
- Fix Pod Log topbar position when perf bar is disabled.
- Always proxy reports downloads.
- Removes extra rigth margin from job page.
- Geo: Rails console message display primary/secondary state incorrectly.
- Disable Feature Flags and Packages if repository is disabled.

### Changed (13 changes, 1 of them is from the community)

- Add test button to Group SAML settings. !5622
- Group SAML status badges on members page. !5807
- Update related issues list styling to be more space efficient. !7784
- Refactor test reports to use new artifact architecture. !7827
- Add timeline icon for issue weights. !7847 (George Tsiolis)
- Added a search bar to `Admin > Geo > Projects`. !8079
- Geo: Deprecate source installations instructions. !8134
- Does not synchronize default branch for pull mirrors. !8138
- Adds split error states for the group security dashboard. !8208
- Geo: Improve read-only message in secondary nodes for actionable screens. !8238
- Improve error messages for operations dashboard. !8244
- Add documentation link to ops dashboard. !8296
- Issue board card design. !21229

### Added (24 changes, 1 of them is from the community)

- Group-level file templates. !7391
- Adds group-level Security Dashboard counts. !7564
- Parse SAST reports and store vulnerabilities in database. !7578
- elasticsearch 6 support - migrate from parent/child relationships to join. !7618
- Geo: Admin > Geo > Projects support for batch operations. !7806
- Create system notes for epic close and reopen. !7850
- Add Tracing landing and settings page. !7903
- Add modals and actions to the vulnerabilities in the Group security dashboard. !7910
- Assign code owner as approver. !7933
- Enable previewing of draft review comments. !7936
- Audit log: Add logging for project feature changes. !7962
- Add project operations dashboard. !7973
- Audit log: Add audit events for group setting changes. !7987
- Add approve quick action. !7989
- Show actual Milestone dates within tooltips for Milestones in Epics sidebar. !8048
- Allow filtering by weight in issues API. !8140 (Heinrich Lee Yu)
- Filter epics by state in API. !8179
- Support epics autocomplete for project objects. !8180
- Add 'l', 'r' and 'e' keyboard shortcuts support in Epic. !8203
- Configurable GitHub static context for statuses integration. !8235
- Send notifications for epic status change. !8247
- Support license management and performance using new reports syntax.
- Support reports: for project security dashboard.
- Add chart of issues created per month.

### Other (17 changes, 11 of them are from the community)

- Update boards list selector specs. !6266 (George Tsiolis)
- Write some Geo development documentation. !7452
- Connects the Group Security Dashboard API and Frontend. !7793
- Rails5: Fix epics finder count_key method In Rails5, the state enum value is passed instead of the database integer. !7822 (Jasper Maes)
- Rails 5: fix presence message validation for prometheus_alert. !7823 (Jasper Maes)
- Rails 5: fix mysql milliseconds problem in prometheus alert event spec. !7828 (Jasper Maes)
- Rails5: fix VulnerabilitySummaryEntity. !7893 (Jasper Maes)
- Update feature flags empty state. !7967 (George Tsiolis)
- Adds the security dashboard link. !7974
- Remove tooltip on sidebar text buttons. !8021 (George Tsiolis)
- Add a metric to the usage ping data to track the number of projects with at least one alert. !8058
- Remove unneeded permission checks from the mirror repositories partial. !8077
- Rails5: fix flaky mysql reset pipeline minutes spec. !8122 (Jasper Maes)
- Move `prepend` outside the `class` block for finders. !8192 (George Tsiolis)
- Rails5: fix operations controller spec nil parameter. !8209 (Jasper Maes)
- Update related issues title typography. !8267 (George Tsiolis)
- Geo: Clarify Geo HA documentation.


## 11.4.9 (2018-12-03)

- No changes.

## 11.4.8 (2018-11-27)

### Security (5 changes)

- Escape entity title while autocomplete template rendering to prevent XSS. !707
- Authorize users when listing board users and milestones.
- Fix IDOR at /drafts/publish.
- Resolve: Guest can set weight of a new issue.
- Fixes XSS with merge request approvers selection.


## 11.4.7 (2018-11-20)

### Fixed (1 change)

- Fix code owner as merge request suggestion not available under Starter plan. !8248


## 11.4.6 (2018-11-18)

### Security (1 change)

- Prevent templated services from being imported.


## 11.4.5 (2018-11-04)

### Fixed (1 change)

- Stops showing review actions on commit discussions in merge requests. !8007

### Performance (1 change)

- Add indexes to all geo event foreign keys. !7990


## 11.4.4 (2018-10-30)

- No changes.

## 11.4.3 (2018-10-26)

- No changes.

## 11.4.2 (2018-10-25)

### Security (1 change)

- Escape entity title while autocomplete template rendering to prevent XSS. !707


## 11.4.1 (2018-10-23)

- No changes.

## 11.4.0 (2018-10-22)

### Security (3 changes)

- Properly filter private references from system notes.
- Project groups approvers no longer leak private groups info.
- Protect against CSRF attacks when adding Slack app.

### Removed (1 change)

- remove unnecessary help text from container scanning results. !7304

### Fixed (18 changes, 1 of them is from the community)

- Prune all the Geo event log tables correctly. !6175
- Synchronize the default branch when updating a pull mirror. !7242
- Pushing to a merge request clears the approvals list even if the respective project setting is enabled and there is no fixed required number of approvals configured. !7328
- Align epics and roadmap empty state buttons to the center. !7358 (George Tsiolis)
- Add link to issue on epic. !7407
- Check for force env var when rebuilding auth_keys. !7419
- Update popover URL to point to help page of same domain. !7446
- Geo - Does not raise error 500 on Geo projects list page for orphaned entries. !7565
- Show promotion for epics on issues. !7602
- Fix Epic subscription toggle behaviour. !7723
- Geo - Send a cache invalidation event via the log cursor whenever features are changed on the primary. !7738
- Fix epic milestone dates incorrect after issue is linked to another epic. !7809
- Fixes warning for used minutes in runner showing when user still has minutes. !7843
- Fix disappearing weight input in Firefox. !7869
- Don't synchronize default branch when updating a SSH mirror. !7891
- Fix broken tokenization for filtered search bar in Epics. !7972
- Fix bug when resolving a discussion via a batch comment published right away.
- Fix wrong color in resolve/unresolve checkbox when using MR reviews.

### Changed (14 changes)

- Geo: Decrease frequency of project shard schedulers when few projects to schedule. !7287
- Added placeholder to weight input for issue sidebar. !7346
- updated icons used in filtered search dropdowns. !7356
- Geo: Display helpful feedback when proxying an SSH git push to secondary request. !7357
- Geo - Include keep-around and other Gitlab-specific references in the checksum calculation. !7367
- Polish security report externalizations. !7373
- Listen for resolved Prometheus alerts. !7382
- Rename date related labels for Epics. !7447
- Add reports CI syntax for Code Quality reports. !7465
- Support short reference to epics from project entities. !7475
- Geo: Downgrade Exclusive Lease warnings from Log Cursor to debug. !7476
- Geo: Allow nodes to be editable in more scenarios. !7832
- Account for issues created in the middle of a milestone in burndown chart.
- [Geo] Add CI job artifact numbers to rake geo:status.

### Performance (1 change)

- Update DB model for security reports.

### Added (20 changes, 1 of them is from the community)

- Batch comments on merge requests. !4213
- Use Geo log to remove files when migrated to object storage. !5966
- Add support for closing epics. !7302
- Add `auditor_groups` configuration so Audit users can be specified using SAML groups. !7340 (St. John Johnson)
- Geo - Add an event to reset checksums on Geo secondary nodes. !7394
- Starts adding the dashboard page view. !7400
- Add `Manage licenses` button to MR widget and pipelines view. !7411
- Add Open/Closed epics tabs in list view. !7424
- Add Feature Flags MVC. !7433
- Suggest approvers based on code owners. !7437
- Geo: Add a backoff time to few Geo workers to save resources. !7470
- Persist Prometheus alert events. !7493
- Geo: Added a button to Admin UI > Geo Nodes to open Geo Projects screen of any secondary node. !7512
- Show Alert Thresholds on monitoring dashboards. !7538
- Support autocomplete for commands in epics. !7588
- Add form to enter licenses manually. !7603
- Geo: Added `All` tab in Geo Nodes > Projects. !7745
- Geo: Add a Geo Status Widget to Admin > Projects. !7789
- Add data model and migration for vulnerabilities.
- Adds Batch Comments to Merge Requests [EEP].

### Other (8 changes, 1 of them is from the community)

- Add runner quota information to job API. !7233
- Resolve "ee:geo QA specs are failing as of !7210". !7315
- remove readme checkbox from "create project" page. !7332
- Create a generic JS function that we can apply to being able to track arbitrary events. !7403
- Rename Admin Area Geo Nodes nav item to Geo. !7466
- Group weight icon and text on issue list and issue boards. !7484 (George Tsiolis)
- Adds expandable/collapsable section for Snowplow. !7798
- API: Allow issue weight parameter to be greater than or equal to zero.


## 11.3.14 (2018-12-20)

- No changes.

## 11.3.13 (2018-12-13)

- No changes.

## 11.3.11 (2018-11-26)

### Security (7 changes)

- Escape entity title while autocomplete template rendering to prevent XSS. !697
- Properly filter private references from system notes.
- Authorize users when listing board users and milestones.
- Project groups approvers no longer leak private groups info.
- Resolve: Guest can set weight of a new issue.
- Fixes XSS with merge request approvers selection.
- Protect against CSRF attacks when adding Slack app.


## 11.3.10 (2018-11-18)

- No changes.

## 11.3.9 (2018-10-31)

- No changes.

## 11.3.8 (2018-10-27)

- No changes.

## 11.3.7 (2018-10-26)

### Security (1 change)

- Escape entity title while autocomplete template rendering to prevent XSS. !697


## 11.3.6 (2018-10-17)

### Fixed (1 change)

- Don't reset the default branch when repository mirroring is enabled. !7944


## 11.3.5 (2018-10-15)

### Fixed (1 change)

- Fix epic milestone dates incorrect after issue is linked to another epic. !7809


## 11.3.4 (2018-10-05)

### Security (1 change)

- Properly filter private references from system notes.


## 11.3.3 (2018-10-04)

- No changes.

## 11.3.2 (2018-10-03)

### Fixed (1 change)

- Geo: repository shard verification job should have unique lease keys per shard name. !7474


## 11.3.1 (2018-09-26)

### Security (2 changes)

- Project groups approvers no longer leak private groups info.
- Protect against CSRF attacks when adding Slack app.


## 11.3.0 (2018-09-22)

### Security (1 change)

- Prevent regular users from moving projects to different storage shards.

### Fixed (29 changes, 11 of them are from the community)

- don't add empty query params to boards. !4441
- Geo: sync disabled wikis. !6420
- Rails 5 fix alerts controller spec for post json parameters. !6795 (Jasper Maes)
- Fixes 500 error on user creation from admin panel with spaced username. !6804 (Jacopo Beschi @jacopo-beschi)
- Don't show search results for projects that have been deleted when using elastic search. !6830
- Geo: Use database-cached status if redis-cached status is unavailable. !6854
- [Geo] Fix: Custom favicons not being replicated by Geo. !6860
- Rails5 fix AddMilestoneToLists migration rollback deleting wrong foreign key. !6865 (Jasper Maes)
- Rails5 fix passing Group objects array into for_projects_and_groups milestone scope. !6873 (Jasper Maes)
- Rails5: fix mysql milliseconds problem in project_import_state_spec. !6874 (Jasper Maes)
- Fix Jira integration duplicating branches and MRs. !6876
- Rails5: fix mysql milliseconds problem in project_spec. !6880 (Jasper Maes)
- Remove https from Snowplow Collector URI placeholder in Admin Areawq. !6886
- Geo: Replicate keep around refs. !6922
- Fixes bug that prevented a user from seeing the system header and footer settings on the admin dashboard. !6926
- Rails5 fix duplicate gpg signature in path lock spec. !6939 (Jasper Maes)
- Rails5: Fix audit event spec. !6940 (Jasper Maes)
- Rails5: fix mysql milliseconds problem in project registry spec. !6943 (Jasper Maes)
- LDAP - Does not update permissions on a read-only database. !6965
- Rails5 fix project import spec. !6981 (Jasper Maes)
- Geo: Resolve sticky failures when attachments are missing on primary. !6991
- Geo: LFS batch downloads are OK to be handled by secondary. !7209
- Geo - Synchronize the default branch in secondary nodes. !7218
- Handle fixed dates seperately from selected dates in Epics. !7227
- Fix tooltip string to support dynamic date type in Epic sidebar. !7243
- Fix an error in docs about fetching artifacts using API. !7244
- Return proper status code when creation of an alert fails. !7360 (Peter Leitzen)
- Geo - Find the remote root ref using a JWT header for authentication. !7405
- Add weight to issue hook.

### Changed (3 changes, 1 of them is from the community)

- Allow push_code when auth'd via Geo JWT. !6455
- Prefer From address over Sender for Service Desk emails. !7006 (Andreas Josephson)
- Add CI Job token support to Maven packages API. !7249

### Performance (3 changes)

- Reduce queries needed for CI artifacts on merge request widget. !6978
- Use limited count approach on Protected Environments view. !6987
- Limit sidekiq-cluster concurrency to a maximum of 50. !7025

### Added (15 changes, 2 of them are from the community)

- Allow custom notification for new epic event. !5863
- Geo: SSH git push to secondary -> proxy to Primary. !6456
- Allow epic start/due dates to be sourceable from issue milestones. !6470
- Add ability to upload and download maven packages from/to GitLab. !6607
- Added an instance-level license template project. !6631 (Dan Barker)
- Add backend structure for ProtectedEnvironments. !6672
- Add UI for GitLab private Maven repository feature. !6781
- Add support for sorting epics. !6885
- Allow specifying code owners in a CODEOWNERS file. !6916
- Quick action for adding/removing epic to issues. !6934
- Show total and completed instances deployed on deploy boards. !6955
- Show security analysis status on the environments page. !6987
- Add Instance Review for Core users. !6995
- Introduce custom instance-level templates for Dockerfile, .gitignore, and .gitlab-ci.yml files. !7000
- Adds Rubocop rule to enforce class_methods over module ClassMethods. !7044 (Jacopo Beschi @jacopo-beschi)

### Other (4 changes)

- Removes feature flag code surrounding Protected Environments feature. !7338
- Creates vue component for shared runner limit.
- Allow MR authors to approve their MRs.
- Remove differences between CE and EE settings panel component.


## 11.2.8 (2018-10-31)

- No changes.

## 11.2.7 (2018-10-27)

- No changes.

## 11.2.6 (2018-10-26)

### Security (1 change)

- Escape entity title while autocomplete template rendering to prevent XSS. !698


## 11.2.5 (2018-10-05)

### Security (1 change)

- Properly filter private references from system notes.


## 11.2.4 (2018-09-26)

### Security (2 changes)

- Project groups approvers no longer leak private groups info.
- Protect against CSRF attacks when adding Slack app.


## 11.2.3 (2018-08-28)

- No changes.

## 11.2.2 (2018-08-27)

### Security (1 change)

- Prevent regular users from moving projects to different storage shards.


## 11.2.1 (2018-08-22)

- No changes.

## 11.2.0 (2018-08-22)

### Security (1 change)

- Don't expose project names in EE counters.

### Fixed (32 changes, 11 of them are from the community)

- Allow Geo node to be edited once the database is failed over. !6248
- Fix a bug where user was unable to delete a branch when repo size was above the limit. !6373
- Rails5 fix AttachmentRegistryFinder arel queries. !6396 (Jasper Maes)
- Add Premium license checks for system messages. !6460
- Fixes arrow-icon color and alignment in linked pipeline in merge request widget. !6479
- Rails 5 fix the matcher expected the ApplicationSetting to be invalid, but it was valid instead. !6488 (Jasper Maes)
- Geo: Gracefully handle deleted events from Geo event log. !6506
- Rails5 fix NoMethodError: undefined method 'message' for nil:NilClass. !6507 (Jasper Maes)
- Fix billing card title colors. !6563
- Rails5 fix undefined method 'namespace_project_settings_repository_path'. !6581 (Jasper Maes)
- Rails5 fix no implicit conversion of Symbol into Integer. !6582 (Jasper Maes)
- Rails 5 fix NoMethodError: undefined method 'message' for nil:NilClass in host_spec.rb. !6589 (Jasper Maes)
- Fix mobile view of pod logs. !6597
- Add left-padding to diverged-from-upstream label. !6647
- List groups with developer maintainer access on project creation. !6678
- no longer fail when setting up Geo database with GDK. !6680
- Allow Pseudonymizer to write to a bucket without having permissions to see all buckets. !6682
- Hide Expand button on empty MR widget Performance section. !6685
- Ensure that Create issue button is shown in vulnerability dialog. !6708
- Use same gem versions for Rails 5 as for Rails 4. !6712 (Jasper Maes)
- Rails5 correct wrong geo job name. !6713 (Jasper Maes)
- Elasticsearch: Fix a bug causing some types of note to miss being indexed. !6736
- Rails 5 fix product array method delagation by manually calling .to_a in NotificationService. !6753 (Jasper Maes)
- Adjust self-hosted Jira development panel integration. !6756
- Ensure that push size checks only count the size of newly-pushed files. !6767
- Fix the UI for listing system-level labels. !6805
- Rails5: fix slice in burndown fixture. !6813 (Jasper Maes)
- Rails5: fix Arel::UpdateManager in MigrateOldElasticsearchSettings migration. !6815 (Jasper Maes)
- Corrected URL for snowplow client side JS. !6899
- [Geo] Fix the Storage config parameter in Geo nodes admin page.
- Fix exporting issues to CSV when sorting by label priority is used.
- Fix handling of annotated tags when Gitaly is not in use.

### Changed (9 changes, 2 of them are from the community)

- Add related issues loading icon top margin. !6527 (George Tsiolis)
- Add security products to usage ping. !6602
- Changed copy for "Approved" state in merge request widget. !6635 (Constance Okoghenun)
- Track the Geo event log gaps in redis and handle them later. !6640
- Replace clipboard icon in Service Desk settings. !6643
- Removes "show all" on security reports and adds a button to take you to the pipeline page. !6675
- Shows license reports when there are no reports in the source branch. !6720
- Removes status text from licence reports. !6802
- Opens "view full report" links in a new window. !6806

### Performance (2 changes)

- Geo: Improve Geo Status API performance with cached counters in SiteStatistic. !6328
- Geo: Improve performance in Log Cursor gap tracking. !6754

### Added (19 changes)

- Geo: Add repository verification failures to API. !6137
- Add support for todos on epics. !6142
- Summed issue weights in board columns. !6218
- Add an API endpoint for managed licenses of a project. !6246
- Implement custom project templates. !6436
- Projects page under Admin > Geo Nodes to display detailed synchronization information. !6452
- Enables configuration of pull mirroring through API. !6485
- Adds SLI alerts to custom prometheus metrics. !6590
- Add support for milestones lists on the issue boards. !6615
- Persist Epic Roadmap timescale choice. !6637
- Add license management frontend. !6638
- Add Snowplow integration. !6642
- Add Security Dashboard to project quick links. !6652
- Show License Management at pipeline level. !6688
- Add Frontend for Instance-level project templates. !6740
- Geo - Actively try to correct verification failures on the secondary. !6759
- Add Prometheus metrics to track Geo autocorrect numbers. !6778
- Link the License Management report in the MR widget with the pipeline level one. !6800
- Allow creating assignee lists via API.

### Other (8 changes, 1 of them is from the community)

- Move merge requests EE helper methods. !6461 (George Tsiolis)
- Add additional logging for Geo Log Cursor. !6513
- Ensure no weight change system notes end with a superfluous comma. !6571
- Track registries marked as synced when repository does not found. !6694
- Removes EE specific CSS that was moved to CE. !6723
- Geo: Add rake task to resync projects where verification has failed. !6727
- updates column sizes in licence and security modals. !6808
- Geo: Log to geo.log when the Log Cursor skips an event.


## 11.1.7 (2018-09-26)

### Security (2 changes)

- Project groups approvers no longer leak private groups info.
- Protect against CSRF attacks when adding Slack app.


## 11.1.6 (2018-08-28)

- No changes.

## 11.1.5 (2018-08-27)

- No changes.
### Security (1 change)

- Prevent regular users from moving projects to different storage shards.


## 11.1.4 (2018-07-30)

- No changes.

## 11.1.3 (2018-07-27)

### Fixed (1 change)

- Resolve Environments dropdown is showing on the cluster health page. !6528


## 11.1.2 (2018-07-26)

### Security (1 change)

- Don't expose project names in EE counters.


## 11.1.1 (2018-07-23)

### Fixed (2 changes)

- Fix geo download service ImportExportDownloader unitialized constant. !6567
- Geo - Allow repository verification to be disabled on a secondary node. !6599


## 11.1.0 (2018-07-22)

### Removed (1 change)

- Drop ignored Geo repository_storage_path columns. !5468

### Fixed (19 changes, 7 of them are from the community)

- Log audit and Geo events within a project destroy transaction. !6059
- Do not pre-select previous user(s) when creating protected branches. !6112
- Group SAML settings link hidden when unlicensed. !6147
- Geo: Fix repository/wiki sync race condition with multiple updates, especially in quick succession. !6161
- [Rails5] Fix error on missed :authenticate_user callback. !6257 (@blackst0ne)
- Rails5 fix  expected: ({...}) got: (<ActionController::Parameters {...}). !6271 (Jasper Maes)
- Rails5 fix ArgumentError: wrong number of arguments (given 1, expected 2). !6272 (Jasper Maes)
- Rails5 fix NoMethodError: undefined method `join' for "":String. !6278 (Jasper Maes)
- [Rails5] fix Boards::ListsController expected the response to have status code 200 but it was 403. !6318 (Jasper Maes)
- [Rails5] fix NoMethodError: undefined method 'downcase' for Hash. !6319 (Jasper Maes)
- [Rails5] fix Projects::VulnerabilityFeedbackController didn't match the schema. !6320 (Jasper Maes)
- Fix CI/CD pipelines when repository HEAD points to an invalid branch. !6325
- Geo - Recalculates the checksum for projects up to date. !6333
- Fixes an issue with security reports footers. !6450
- Add missing sourceBranchLink prop to CI widget. !6493
- Resync project repositories on secondaries nodes when import finishes. !6529
- Adds permission checks to dismiss issue in security reports.
- Allow all but "/" chars for groups and projects paths on Jira dev panel integration.
- Fix weight system notes ending in commas.

### Changed (6 changes)

- [Geo] Invert the direction of Geo metrics acquisition. !5934
- Update read-only message banner styling for Geo secondary node. !6135
- Removes action buttons from resolved vulnerability modal. !6155
- Redesign contribution analytics graphs. !6194
- Geo - Retry checksum calculation for failures on the primary node. !6295
- Don't show 'Contribute to GitLab' link on self-hosted Enterprise Edition instances. !6297

### Performance (5 changes, 1 of them is from the community)

- Geo - Optimize query to return outdated projects that need to be reverified. !5879
- Boost Geo prune worker to run every 2 hours instead of 6. !6074
- Use tooltip component in MrWidgetSecondaryGeoNode vue component. !6078 (George Tsiolis)
- Eliminate N+1 queries in path lock checks during a push.
- Memoize the global default for push rules within the request.

### Added (13 changes, 1 of them is from the community)

- Add a new push rule to allow negative matching of commit messages. !5453 (Hannes Rosenögger)
- Pseudonymizer to safely export data for analytics. !5532
- Add filename filtering to code search with Elasticsearch. !5590
- Add API endpoint for viewing and editing board config. !5954
- Log repository check and failed count to Prometheus. !5984
- Allow repository verification concurrency to be controlled on primary and secondary. !6102
- Geo: HTTP git-lfs push (upload) and locks (verify, lock and unlock) to secondary now redirects to the primary. !6109
- Adds pod selection dropdown to pod logs screen. !6111
- Add support for autocompleting Epics and Labels within Epics. !6195
- Add project Security Dashboard. !6197
- Support GitLab subgroups in Jira development panel. !6290
- Render container scanning and dast reports in pipeline view.
- Add link to Jenkins documentation within integration and service template.

### Other (2 changes)

- Enable Geo snapshot synchronization for everyone. !6286
- Geo - Make Geo repository verification flag opt-out by default. !6369


## 11.0.6 (2018-08-27)

### Security (1 change)

- Prevent regular users from moving projects to different storage shards.


## 11.0.5 (2018-07-26)

### Security (1 change)

- Don't expose project names in EE counters.


## 11.0.4 (2018-07-17)

- No changes.

## 11.0.3 (2018-07-05)

- No changes.

## 11.0.2 (2018-06-26)

- No changes.

## 11.0.1 (2018-06-21)

- No changes.

## 11.0.0 (2018-06-22)

### Security (2 changes)

- Escape name in merge request approvers dropdown.
- Fixes include directive to not allow SSRF requests.

### Fixed (15 changes)

- Hide Lock button if File Locking feature is not available in license. !5656
- Geo - Move out the replication slots items from verification section in Geo admin screen. !5723
- Fix approvers API not accepting empty form-encoded params. !5784
- Fix error when locking/unlocking directories. !5862
- Geo: Formatting fix for geo:status rake task. !6020
- Geo: Automatically clean up stale lock files on Geo secondary. !6034
- Remove LFS object warning from import UI. !6083
- Fix Web IDE status bar if System Footer message is present.
- [Geo] Fix: Deleted project events may be skipped on the secondary when selective sync is used.
- [Geo] Fix: Unauthenticated rate limits should not block Geo requests.
- Perform gitlab-ci-token authentication always using primary.
- Geo: Gracefully handle a non-JSON response from the node status.
- Geo: Fix FDW schema check when tables and columns are not in the same order.
- Fix sticking of runner to primary if new job is scheduled.
- When last Geo::EventLog is not available, geo:status rake task fails.

### Deprecated (2 changes)

- Rename Container Scanning job and artifact. !5770
- Rename Code Quality job and artifact. !5773

### Changed (7 changes)

- Removed "(Beta)" from "Auto DevOps" messages. !5583
- Make issue weight promotion in issuable sidebar dismissable. !5601
- Remove the comma from the weight system notes. !5854
- Enrich Security Reports with more data. !5878
- Truncate Geo event log with a delay. !5897
- Add support for non-negative integer weight values in issuable sidebar.
- Improve Failed Jobs tab in the Pipeline detail page.

### Performance (5 changes, 2 of them are from the community)

- Reorder LinkToMemberAvatar vue component props values. !5692 (George Tsiolis)
- Rename merge request widget author component. !5693 (George Tsiolis)
- Geo - Fix index for outdated projects on the project_repository_states table. !5986
- Preload Group plans in EpicsFinder.
- Only process Geo::EventLog events if associated shard is queryable and healthy.

### Added (12 changes)

- Allows the review of kubernetes pod logs within GitLab. !4752
- Geo: Rake task to force housekeeping on next sync. !5623
- Add ability to have zero approvers. !5635
- Show status information stale icon in Geo admin dashboard. !5653
- Add assignee board list type. !5743
- Geo: HTTP git push to secondary now redirects to the primary. !5785
- Add presets for navigating Epic Roadmap. !5798
- Guest users will not consume seats quote in Ultimate plan. !5816
- Create system note on epic date change.
- Add License Management results in the MR widget.
- Extract EE specific files.
- Add service discovery for the DB load balancer.

### Other (4 changes, 1 of them is from the community)

- Add promotion for epics to issuable sidebar. !5601
- Remove confusing statement in the message shown for Epics list empty state when filters are applied. !5630
- Fixed illustration alignment for group milestones promotion. !5677 (Constance Okoghenun)
- Allow viewing only one when multiple issue boards is not enabled.


## 10.8.6 (2018-07-17)

- No changes.

## 10.8.5 (2018-06-21)

- No changes.

## 10.8.4 (2018-06-06)

### Fixed (4 changes)

- Render a 403 when showing an access denied message. !5964
- Validate classification label on create & update. !5976
- Fix breadcrumbs being covered by System Header message.
- Treat external authorization service response status 403 as failure.


## 10.8.3 (2018-05-30)

- No changes.
- No changes.
### Fixed (1 change)

- Geo - Calculate the wiki checksum even when wiki is disabled. !5772

### Performance (1 change)

- Make Geo::PruneEventLogWorker delete rows more gently. !5835


## 10.8.2 (2018-05-28)

### Security (3 changes)

- Fixed XSS in protected branches & tags access dropdown.
- Escape name in merge request approvers dropdown.
- Fixes include directive to not allow SSRF requests.


## 10.8.1 (2018-05-23)

### Fixed (4 changes)

- Geo: Fix repo, wiki, and upload replication when renaming a namespace that has subgroups. !5704
- Shows the correct data in the verification information section for the primary node in Geo admin screen. !5722
- [Geo] Don't remove project registry records.
- Geo: Exclude tables that start with pg_ from FDW check.


## 10.8.0 (2018-05-22)

### Removed (1 change)

- Use of ENV['USE_SYSTEM_GIT_FOR_FETCH'] is no longer supported.

### Fixed (22 changes)

- Add missing fields to the API documentation for the status of Geo Nodes. !3865
- Large pushes were failing when max file size push rule was active. !4989
- Fix GITLAB_FEATURES CI/CD env var for public projects. !5242
- Reveal labels dropdown when labels icon is clicked on collapsed Epic sidebar. !5298
- Geo: Propagate broadcast messages to secondaries. !5303
- Geo: Exclude expired job artifacts from syncing and counts. !5380
- Exclude GroupSAML from sign in buttons. !5449
- Per-Group SAML (for GitLab.com) strips LRM chars from ADFS certificate fingerprints. !5466
- Refactor the Geo LogCursor Logger to make class more descriptive. !5483
- Geo - Returns a dummy checksum when there is no valid repository on disk. !5486
- ShaAttribute no longer stops startup if database is missing. !5502
- Fix network error message styling on Geo admin dashboard. !5530
- Fixes invalid link in html version of mirror was hard failed email. !5546
- During repository verification, ignore repositories/wikis that need to be resynced. !5568
- Group SAML skips forgery protection in production. !5621
- Does not log failed sign-in attempts when in a GitLab read-only instance. !5643
- [Geo] Fix rake geo:status when event_log is not found.
- Geo: Use a pre-built node status in admin area.
- [Geo] Mentioned in custom hooks doc that they won't be replicated to secondary.
- Fix: Geo: BaseSyncService should prune the @geo-temporary directory before fetching.
- Stop presenting burndown charts promotion for grouped by title milestones.
- Geo: When a repository or Wiki sync has failed, mark resync flag as true.

### Changed (13 changes, 1 of them is from the community)

- Shorten protected branch / tag access level dropdown text. !5091
- Improve tooltips on collapsible right sidebars. !5212
- Allow easier customization of included CI configurations. !5288 (King Chung Huang)
- Unprotect and update disabled in UI when prevented by branch unprotect rules. !5296
- Issues export CSV includes 'Weight' and 'Locked'. !5300
- Update item titles and add help text in Geo nodes admin dashboard. !5306
- Geo - Improve metrics for the checksum/verification feature. !5367
- Adds push mirrors to GitLab Community Edition. !5484
- Adds SSO page for GitLab.com per group SAML beta. !5508
- Adds authentication flow for GitLab.com per group SAML beta. !5575
- Add Geo information to console message. !5588
- Ability to edit, disable or remove Geo Nodes is now always available.
- Show pod name for each instance on deploy boards.

### Performance (4 changes)

- Port Group member contribution analytics table to Vue. !5269
- Improve performance of repository size limit check. !5476
- Improves database performance of mirrors, forks and imports. !5522
- Prevent Geo from unnecessarily syncing expired CI job artifacts.

### Added (11 changes)

- Geo: schedule a git repack after initial clone. !4266
- Present Burndown charts for group milestones. !5354
- Filtered search bar support for Roadmap view. !5417
- Allow user to dismiss a vulnerability or create an issue out of it. !5452
- Geo: enable housekeeping functionality when syncing repositories. !5461
- Enable username autocomplete inside Epics. !5475
- Present MRs on Jira development panel integration. !5534
- Run repository verification on Geo secondary. !5550
- Email notifications for epics.
- Add Epic count to usage pings.
- Add system note for weight change.

### Other (6 changes, 6 of them are from the community)

- Replace the `admin/license.feature` spinach test with an rspec analog. !5477 (@blackst0ne)
- Replace the `admin/push_rules.feature` spinach test with an rspec analog. !5512 (@blackst0ne)
- Replace the `admin/emails.feature` spinach test with an rspec analog. !5513 (@blackst0ne)
- Replace the `group_hooks.feature` spinach test with an rspec analog. !5515 (@blackst0ne)
- Replace the `groups_management.feature` spinach test with an rspec analog. !5516 (@blackst0ne)
- Remove `features/group_active_tab.feature`. !5554 (@blackst0ne)


## 10.7.7 (2018-07-17)

- No changes.

## 10.7.6 (2018-06-21)

- No changes.

## 10.7.5 (2018-05-28)

### Security (3 changes)

- Fixed XSS in protected branches & tags access dropdown.
- Escape name in merge request approvers dropdown.
- Fixes include directive to not allow SSRF requests.


## 10.7.4 (2018-05-21)

### Fixed (2 changes)

- Does not log failed sign-in attempts when in a GitLab read-only instance. !5643
- Fix: Geo: BaseSyncService should prune the @geo-temporary directory before fetching.


## 10.7.3 (2018-05-02)

### Fixed (3 changes)

- Geo - Fix undefined method pending_delete for nil class. !5470
- Geo: Admin page will not crash with 500 because of InvalidSignatureTimeError. !5495
- Fix DB LB errors when escaping input.


## 10.7.2 (2018-04-25)

- No changes.

## 10.7.1 (2018-04-23)

### Fixed (4 changes)

- Geo: Fix enabled wiki counts with FDW (impacts synced and verified counts). !5352
- Fix Epic timeline bar misalignment when start date is in last timeframe month and end date is out of range. !5360
- Adds border top to codeclimate report in MR widget.
- Avoid wrong closing dates being caught by the query on Burndown charts.

### Performance (1 change)

- Geo - Improve the query performance to find unverified projects on primary node. !5348


## 10.7.0 (2018-04-22)

### Fixed (25 changes)

- Issue Boards: Ensure that horizontal scroll bars are shown on overflow. !4944
- Fix validation error message when historical data is empty. !4961
- Fixes incorrect assignation of cluster details. !5047
- Fixed personal snippets uploads when background upload is enabled. !5049
- Fixed incorrect count of verified wikis on a Geo secondary node. !5084
- Fix unapproved unassigned merge request emails failing to send. !5092
- Geo secondary repository verification messages now appear in geo.log. !5095
- Geo: Sync wiki when it is enabled. !5139
- Geo: Make synced/failed scopes more consistent. !5171
- Updates style of arrown in downstream pipeline. !5172
- Add better LDAP connection handling in EE and fixing some LDAP group syncing problems. !5173
- Fix an exception in the Geo repository sync worker. !5223
- Geo - Fix wiki repository verification on a secondary node. !5315
- Show repository checksum UI elements only when feature is enabled. !5341
- Fix a bug migrating CI job artifact registry entries to a separate table. !5345
- Render show all report for sast and dependency scanning. !5363
- Fix label and issuable referencing in epics and epic notes.
- Add icons to epic system notes issue actions.
- [Geo] Fix project rename when wiki does not exist.
- Catch errors in LoadBalancing::Host#online?.
- Fix Scoped Boards bug filtering by No Milestone.
- Skip repository-changing events on Geo secondaries if the repository hasn't been backfilled yet.
- Ensure Geo secondary nodes only run cron jobs appropriate for secondaries.
- Geo - Returns a dummy checksum when there is no repository on disk.
- Fix Elasticsearch missing terms with special characters.

### Deprecated (1 change)

- Rename SAST:container to Container Scannning.

### Changed (9 changes)

- Geo - Perform the repository verification per shard on a secondary node. !5068
- Allow enabling classification policy control without external authorization service. !5083
- Update Geo nodes layout for better usability. !5199
- Document manual disaster recovery process for systems with multiple secondaries.
- Don't send schedule confirmations for chat jobs.
- Geo - Switch from time-based checking of outdated checksums to the nil-checksum-based approach.
- Make /-/ delimiter optional for epics and search endpoints.
- Order boards dropdown alphabetically.
- Renders grouped security reports in MR widget & split security reports in CI view.

### Performance (3 changes)

- Geo - Improve the query performance to find unsynced job artifacts. !5350
- Reimplement Roadmap timeline rendering for better performance.
- Geo: Migrate CI job artifacts into their own registry table.

### Added (11 changes)

- Geo ensure files moved to object storage are cleaned up. !4689
- Timeout for external authorization is now configurable. !4971
- Add system header and footer as new appearance options. !4972
- Authenticate using TLS certificate for requests to external authorization service. !5028
- Add admin setting for custom additional text in emails. !5031
- Mark files missing on primary as synced, but retry them. !5050
- Log every access when external authorization is enabled. !5117
- Add total CPU/Memory metrics, adds weighting for proper sorting. !5260
- Add comment thread to Epics.
- Render dependency scanning in MR widget and CI view.
- Add a Go back button to WebIDE to allow returning to where it was launched from.

### Other (4 changes, 1 of them is from the community)

- Move default group project creation level to Starter. !5148
- Replace the `project/issues/weight.feature` spinach test with an rspec analog. !5194 (blackst0ne)
- [Geo] Log JID for sync related jobs.
- Breaks utils function to parse codeclimate and sast into separate functions.


## 10.6.6 (2018-05-28)

### Security (3 changes)

- Fixed XSS in protected branches & tags access dropdown.
- Escape name in merge request approvers dropdown.
- Fixes include directive to not allow SSRF requests.


## 10.6.5 (2018-04-24)

- No changes.

## 10.6.4 (2018-04-09)

### Fixed (4 changes)

- Fixes incorrect assignation of cluster details. !5047
- Geo: Make synced/failed scopes more consistent. !5171
- [Geo] Fix project rename when wiki does not exist.
- Fix Scoped Boards bug filtering by No Milestone.

### Other (1 change)

- [Geo] Log JID for sync related jobs.


## 10.6.3 (2018-04-03)

- No changes.

## 10.6.2 (2018-03-29)

- No changes.

## 10.6.1 (2018-03-27)

### Fixed (8 changes)

- Fix LDAP group sync permission override UI. !5003
- Hard failing a mirror no longer fails for a blocked user's personal project. !5063
- Geo - Avoid rescheduling the same project again in a backfill condition. !5069
- Mark disabled wikis as fully synced. !5104
- Fix excessive updates to file_registry when wiki is disabled. !5119
- Geo: Recovery from temporary directory doesn't work if the namespace directory doesn't exist.
- Define a chat responder for the Slack app.
- Resolve "undefined method 'log_transfer_error'".

### Added (1 change)

- Also log Geo Prometheus metrics from primary. !5058

### Other (1 change)

- Update Epic documentation to include labels.


## 10.6.0 (2018-03-22)

### Security (2 changes)

- Prevent new push rules from using non-RE2 regexes.
- Project can no longer be shared between groups when both member and group locks are active.

### Fixed (47 changes)

- Geo - Add a rake task to update Geo primary node URL. !4097
- Capture push rule regex errors and present them to user. !4102
- Fixed membership Lock should propagate from parent group to sub-groups. !4111
- Fix Epic sidebar toggle button icon positioning. !4138
- Update the Geo documentation to replicate all secrets to the secondary. !4188
- Update Geo documentation to reuse the primary node SSH host key on secondary node. !4198
- Improve Geo Disaster Recovery docs for systems in multi-secondary configurations. !4285
- Fix 500 errors caused by large replication slot wal retention. !4347
- Report the correct version and revision for Geo node status requests. !4353
- Don't show Member Lock setting for unlicensed system. !4355
- Fix the background_upload configuration being ignored. !4507
- Fix canary legends for single series charts. !4522
- Fixes and enhancements for Geo admin dashboard. !4536
- Fix license expiration duration to show trial info only for trial license. !4573
- File uploads in remote storage now support project renaming. !4597
- Use unique keys for token inputs while add same value twice to an epic. !4618
- Fix multiple assignees avatar alignment in issues list. !4664
- Improve security reports to handle big links and to work on mobile devices. !4671
- Supresses error being raised due to async remote removal being run outside a transaction. !4747
- Mark empty repos as synced in Geo. !4757
- Mirror owners now get assigned as mirror users when the assigned mirror users disable their accounts. !4827
- Geo: Ignore remote stored objects when calculating counts. !4864
- Fix Epics not getting created in a Group with existing Epics. !4865
- Generate ObjectStorage URL based on user provided schema. !4932
- Make Epic start and finish dates on Roadmap to be timezone neutral. !4964
- Support SendURL for performing indirect download of artifacts if clients does not specify that it supports that.
- Fix LDAP group sync no longer configurable for regular users.
- [Geo] Skip attachments that is stored in the object storage.
- Fix: Geo WikiSyncService attempts to sync projects that have no Wiki.
- Fix broken CSS in modal for DAST report.
- Improve SAST description for no new vulnerabilities.
- Fix 'Geo: Don't attempt to expire the cache after a failed clone'.
- Geo - Remove duplicated message on on geo:update_primary_node_url rake task.
- Fix the geo::db:seeds rake task.
- Geo - Fix repository synchronization order for projects updated recently.
- Geo - Respect backoff time when repository have never been synced successfully.
- Ensure mirror can transition out of the started state when last_update_started_at is nil.
- Fix bug causing 'Import in progress' to be shown while a mirror is updating.
- Include epics from subgroups on Epic index page.
- Fix proxy_download support for lfs controller.
- Fixed IDE command palette options being hidden.
- Fixed IDE file list when multiple files have same name but different paths.
- Fixed IDE not showing the correct changes and diff markers.
- Update epic issue reference when moving an issue.
- Fix Geo Log Cursor not reconnecting after pgbouncer dies.
- Fix audit and Geo project deletion events not being logged under certain conditions.
- Geo: Fix Wiki resync when Wiki repository does not exist.

### Changed (15 changes)

- Geo Logger will use the same log level defined in Rails. !4066
- Approve merge requests additionally. !4134
- Geo: sync .gitattributes to info/attributes in secondary nodes. !4159
- Update behavior of MR widgets that require pipeline artifacts to allow jobs with multiple artifacts. !4203
- Add details on how to disable GitLab to the DR documentation. !4239
- Add users stats page for admin area with per role amount. !4539
- Group Roadmap enhancements. !4651
- Adds support to show added, fixed and all vulnerabilties for SAST in merge request widget.
- Ports remote removal to a background job.
- Update UI for merge widget reports.
- Geo: Improve formatting of can't push to secondary warning message.
- Replace check_name key with description in codeclimate results for a more human readable description.
- Add license ID number to usage ping.
- Schedule mirror updates in parallel.
- Geo: Don't attempt to schedule a repository sync for downed Gitaly shards.

### Performance (8 changes, 3 of them are from the community)

- Move Assignees vue component. !4467 (George Tsiolis)
- Speed up approvals calculations. !4492
- Move BoardNewIssue vue component. !16947 (George Tsiolis)
- Move RecentSearchesDropdownContent vue component. !16951 (George Tsiolis)
- Bump Geo JWT timeout from 1 minute to 10 minutes.
- Cache column_exists? for Elasticsearch columns.
- FIx N+1 queries with /api/v4/groups endpoint.
- Properly memoize ChangeAccess#validate_path_locks? to avoid excessive queries.

### Added (39 changes, 1 of them is from the community)

- Add ability to add Custom Metrics to environment and deployment metrics dashboards. !3799
- Add object storage support for uploads. !3867
- Add support within Browser Performance Testing for metrics where smaller is better. !3891 (joshlambert)
- Add more endpoints for Geo Nodes API. !3923
- (EEP) Allow developers to create projects in group. !4046
- Integrate current File Locking feature with LFS File Locking. !4091
- Add Epic information for selected issue in Issue boards sidebar. !4104
- Update CI/CD secret variables list to be dynamic and save without reloading the page. !4110
- Add object storage migration task for uploads. !4215
- Filtered search support for Epics list page. !4223
- Add multi-file editor usage metrics. !4226
- Dry up CI/CD gitlab-ci.yml configuration by allowing inclusion of external files. !4262
- Geo: FDW issues are displayed in the Geo Node Admin UI. !4266
- Implement selective synchronization by repository shard for Geo. !4286
- Show Group level Roadmap. !4361
- Add Geo Prometheus metrics about the various number of events. !4413
- Geo - Calculate repositories checksum on primary node. !4428
- If admin note exists, display it in admin user view. !4546
- Add option to overwrite diverged branches for pull mirrors. !4559
- Adds GitHub Service to send status updates for pipelines. !4591
- Projects and MRs Approvers API. !4636
- Add CI/CD for external repositories. !4642
- Authorize project access with an external service. !4675
- GitHub CI/CD import sets up pipeline notification integration. !4687
- Add GitHub support to CI/CD for external repositories. !4688
- Repository mirroring notifies when hard failed. !4699
- Query cluster status. !4701
- Geo - Verify repository checksums on the secondary node. !4749
- Move support of external gitlab-ci files from Premium to Starter. !4841
- Geo - Improve node status report by adding one more indicator of health: last time when primary pulled the status of the secondary.
- Render SAST report in Pipeline page.
- Add system notes when moving issues between epics.
- Add rake task to print Geo node status.
- Add basic searching and sorting to Epics API.
- gitlab:geo:check checks connection to the Geo tracking DB.
- Added basic implementation of GitLab Chatops.
- Add discussions API for Epics.
- Add proxy_download to enable passing all data through Workhorse.
- Add support for direct uploading of LFS artifacts.

### Other (8 changes)

- Geo: Improve replication status. Using pg_stat_wal_receiver.
- Remove unaproved typo check in sast:container report.
- Allow clicking on Staged Files in WebIDE to open them in the Editor.
- Translate Locked files page.
- Increase minimum mirror update interval from 15 to 30 minutes.
- Geo - add documentation about using shared a S3 bucket with GitLab Container Registry.
- Allow use of system git for git fetch if USE_SYSTEM_GIT_FOR_FETCH is defined.
- Rename "Approve Additionally" to "Add approval".


## 10.5.8 (2018-04-24)

- No changes.

## 10.5.7 (2018-04-03)

- No changes.

## 10.5.6 (2018-03-16)

- No changes.

## 10.5.5 (2018-03-15)

### Fixed (1 change)

- Geo: Fix Wiki resync when Wiki repository does not exist.


## 10.5.4 (2018-03-08)

### Fixed (4 changes)

- Supresses error being raised due to async remote removal being run outside a transaction. !4747
- Mark empty repos as synced in Geo. !4757
- Fix: Geo WikiSyncService attempts to sync projects that have no Wiki.
- Geo - Fix repository synchronization order for projects updated recently.

### Other (1 change)

- Rename "Approve Additionally" to "Add approval".


## 10.5.3 (2018-03-01)

### Security (2 changes)

- Project can no longer be shared between groups when both member and group locks are active.
- Prevent new push rules from using non-RE2 regexes.

### Fixed (1 change)

- Fix LDAP group sync no longer configurable for regular users.


## 10.5.2 (2018-02-25)

- No changes.

## 10.5.1 (2018-02-22)

- No changes.

## 10.5.0 (2018-02-22)

### Fixed (23 changes, 1 of them is from the community)

- Geo - Add a rake task to update Geo primary node URL. !4097
- Capture push rule regex errors and present them to user. !4102
- Fixed membership Lock should propagate from parent group to sub-groups. !4111
- Fix Epic sidebar toggle button icon positioning. !4138
- Update the Geo documentation to replicate all secrets to the secondary. !4188
- Update Geo documentation to reuse the primary node SSH host key on secondary node. !4198
- Override group sidebar links. !4234 (George Tsiolis)
- Improve Geo Disaster Recovery docs for systems in multi-secondary configurations. !4285
- Fix 500 errors caused by large replication slot wal retention. !4347
- Report the correct version and revision for Geo node status requests. !4353
- Don't show Member Lock setting for unlicensed system. !4355
- Fix the background_upload configuration being ignored. !4507
- Geo: Reset force_redownload flag after successful sync.
- [Geo] Skip attachments that is stored in the object storage.
- [Geo] Fix redownload repository recovery when there is not local repo at all.
- Fix broken CSS in modal for DAST report.
- Improve SAST description for no new vulnerabilities.
- Geo - Remove duplicated message on on geo:update_primary_node_url rake task.
- Fix the geo::db:seeds rake task.
- Allow project to be set up to push to and pull from same mirror.
- Include epics from subgroups on Epic index page.
- Fix validation of environment scope of variables.
- Support SendURL for performing indirect download of artifacts if clients does not specify that it supports that.

### Changed (9 changes)

- Geo Logger will use the same log level defined in Rails. !4066
- Approve merge requests additionally. !4134
- Geo: sync .gitattributes to info/attributes in secondary nodes. !4159
- Update behavior of MR widgets that require pipeline artifacts to allow jobs with multiple artifacts. !4203
- Add details on how to disable GitLab to the DR documentation. !4239
- Ports remote removal to a background job.
- Adds support to show added, fixed and all vulnerabilties for SAST in merge request widget.
- Geo: Don't attempt to schedule a repository sync for downed Gitaly shards.
- Update UI for merge widget reports.

### Performance (3 changes)

- Bump Geo JWT timeout from 1 minute to 10 minutes.
- FIx N+1 queries with /api/v4/groups endpoint.
- Properly memoize ChangeAccess#validate_path_locks? to avoid excessive queries.

### Added (17 changes, 1 of them is from the community)

- Add object storage support for uploads. !3867
- Add support within Browser Performance Testing for metrics where smaller is better. !3891 (joshlambert)
- Add more endpoints for Geo Nodes API. !3923
- (EEP) Allow developers to create projects in group. !4046
- Integrate current File Locking feature with LFS File Locking. !4091
- Add Epic information for selected issue in Issue boards sidebar. !4104
- Update CI/CD secret variables list to be dynamic and save without reloading the page. !4110
- Add object storage migration task for uploads. !4215
- Filtered search support for Epics list page. !4223
- Add multi-file editor usage metrics. !4226
- Dry up CI/CD gitlab-ci.yml configuration by allowing inclusion of external files. !4262
- Implement selective synchronization by repository shard for Geo. !4286
- Show Group level Roadmap. !4361
- Add Geo Prometheus metrics about the various number of events. !4413
- Geo - Improve node status report by adding one more indicator of health: last time when primary pulled the status of the secondary.
- Add rake task to print Geo node status.
- Add system notes when moving issues between epics.

### Other (3 changes)

- Activated the Web IDE Button also on the main project page. !4250
- Geo - add documentation about using shared a S3 bucket with GitLab Container Registry.
- Geo: Improve replication status. Using pg_stat_wal_receiver.
- Remove unaproved typo check in sast:container report.


## 10.4.7 (2018-04-03)

- No changes.

## 10.4.6 (2018-03-16)

- No changes.

## 10.4.5 (2018-03-01)

### Security (2 changes)

- Project can no longer be shared between groups when both member and group locks are active.
- Prevent new push rules from using non-RE2 regexes.

### Fixed (1 change)

- Fix LDAP group sync no longer configurable for regular users.


## 10.4.4 (2018-02-16)

### Fixed (4 changes)

- Handle empty event timestamp and larger memory units. !4206
- Geo: Reset force_redownload flag after successful sync.
- [Geo] Fix redownload repository recovery when there is not local repo at all.
- Allow project to be set up to push to and pull from same mirror.


## 10.4.3 (2018-02-05)

### Security (1 change)

- Restrict LDAP API to admins only.


## 10.4.2 (2018-01-30)

### Fixed (7 changes)

- Fix Epic issue item reordering to handle different scenarios. !4142
- Fix visually broken admin dashboard until license is added. !4196
- Handle empty event timestamp and larger memory units. !4206
- Use a fixed remote name for Geo mirrors. !4249
- Preserve updated issue order to store when reorder is completed. !4278
- Geo - Fix OPENSSH_EXPECTED_COMMAND in the geo:check rake task.
- Execute group hooks after-commit when moving an issue.


## 10.4.1 (2018-01-24)

### Fixed (1 change)

- Fix failed LDAP logins when sync_ssh_keys is included in config.


## 10.4.0 (2018-01-22)

### Security (2 changes)

- Fix LDAP external user/group bug on first sign in.
- Deny persisting milestones from outside project/group scope on boards.

### Fixed (19 changes, 1 of them is from the community)

- Issue count now refreshes quicker on geo secondary. !3639
- Prevent adding same role multiple times on repeated clicks. !3700
- Geo - Fix difference in FDW / non-FDW queries for Geo::FileRegistry queries. !3714
- Fix successful rebase throwing flash error message. !3727
- Fix Merge Rquest widget rebase action in Internet Explorer. !3732
- Geo - Use relative path for avatar images on a secondary node. !3857
- Add missing wiki counts to prometheus metrics. !3875
- Adjust content width for User Settings, Pipeline quota. !3895 (George Tsiolis)
- Fix a bug where branch could not be delete due to a push rule config. !3900
- Fix a few doc links to fast ssh key lookup. !3937
- Handle node details load failure gracefully on UI. !3992
- Use the fastest available method for various Geo status counts. !4024
- Fix neutralCount computation to prevent negative values. !4044
- Fix reordering of items when moved to top or bottom. !4050
- Geo - Fix repository clean up when selective replication changes with hashed storage enabled. !4059
- Fix JavaScript bundle running on Cluster update/destroy pages. !4112
- Record EE instances without a license correctly in usage ping.
- Fix export to CSV if a filter with multiple labels is used.
- Stop authorization attempts with instance profile when static credentials are provided for AWS Elasticsearch.

### Changed (6 changes)

- Change MR widget failed icons to warning icons. !3669
- Show clear message when set-geo-primary-node was successful. !3768
- More descriptive error when clocks between Geo nodes are out of sync. !3860
- Allow sidekiq to react to becoming a Geo primary or secondary without a restart. !3878
- Geo admin screen enhancements. !3902
- Geo UI polish.

### Added (13 changes)

- Split project repository and wiki repository status in Geo node status. !3560
- Add reset pipeline minutes button to admin overview of groups and users. !3656
- Show results from docker image scan in the merge request widget. !3672
- Geo: Added Authorized Keys specific checks. !3728
- Add some extra fields to Geo API node and status. !3858
- Show results from DAST scan in the merge request widget. !3885
- Add Geo support for CI job artifacts. !3935
- Make it possible to enable/disable PostgreSQL FDW for Geo. !4020
- Add support for reordering issues in epics.
- Check if shard configuration is same across Geo nodes.
- Add API for epics.
- Add group boards API endpoint.
- Add api for epic_issue associations.

### Other (6 changes)

- Document GitLab Geo with Object Storage. !3760
- Update disaster recovery documentation with detailed steps. !3845
- Fix broken alignment of database password in geo docs. !3939
- Remove unnecessary NTP checks now included in gitlab:geo:check. !3940
- Move geo status check after db replication to avoid anticipated failures. !3941
- Make scoped issue board specs more reliable.


## 10.3.9 (2018-03-16)

- No changes.

## 10.3.8 (2018-03-01)

### Security (2 changes)

- Project can no longer be shared between groups when both member and group locks are active.
- Prevent new push rules from using non-RE2 regexes.

### Fixed (1 change)

- Fix LDAP group sync no longer configurable for regular users.


## 10.3.7 (2018-02-05)

### Security (1 change)

- Restrict LDAP API to admins only.

### Fixed (1 change)

- Fix JavaScript bundle running on Cluster update/destroy pages.


## 10.3.6 (2018-01-22)

### Fixed (3 changes)

- Geo - Fix repository clean up when selective replication changes with hashed storage enabled. !4059
- Fix JavaScript bundle running on Cluster update/destroy pages. !4112
- Fix export to CSV if a filter with multiple labels is used.


## 10.3.5 (2018-01-18)

- No changes.

## 10.3.4 (2018-01-10)

### Security (2 changes)

- Fix LDAP external user/group bug on first sign in.
- Deny persisting milestones from outside project/group scope on boards.


## 10.3.3 (2018-01-02)

- No changes.

## 10.3.2 (2017-12-28)

- No changes.

## 10.3.1 (2017-12-27)

### Changed (1 change)

- Geo: Show sync percent on bar graph and count within tooltips. !3794


## 10.3.0 (2017-12-22)

### Removed (2 changes)

- Remove the full-scan option from the Geo log cursor. !3412
- Remove Geo SSH repo sync support. !3553

### Fixed (14 changes)

- Hide Approvals section when Merge Request Widget is showing the empty state. !3376
- Fix error when entering an invalid url to push to or pull from a remote repository. !3389
- Update gitlab.yml.example to match the default settings for Geo sync workers. !3488
- Remove duplicate read-only flash message on admin pages. !3495
- Strip leading & trailing whitespaces in CI/CD secret variable's environment scope. !3563
- Fix Advanced Search Syntax documentation. !3571
- Fix Git message when pushing to Geo secondary. !3616
- Fix a bug in the Geo metrics update service. !3623
- Fix validation of environment scope for Ci::Variable. !3641
- Fix an exception in Geo scheduler workers. !3740
- Fix Merge Request Widget Approvals responsiveness on mobile.
- Geo - Does not sync repositories on unhealthy shards in non-backfill conditions.
- Record EE Ultimate usage pings correctly.
- Fix board filter for predefined milestones.

### Changed (4 changes)

- Improve Geo logging of repository errors. !3402
- ProtectedBranches API allows individual users and group to be specified. !3516
- EE Protected Branches API access levels include user_id/group_id where relevant. !3535
- Enhancements for Geo admin screen. !3545

### Performance (1 change)

- Geo - Improve performance when calculating the node status. !3595

### Added (20 changes)

- Show SAST results in MR widget. !3207
- Add option for projects to only mirror protected branches. !3326
- Add option to remote mirrors to only push protected branches. !3350
- Add warning when Geo is configured insecurely. !3368
- Added enpoint that triggers the pull mirroring process. !3453
- Add performance metrics to the merge request widget. !3507
- Geo: replicate Attachments migration to Hashed Storage in secondary node. !3544
- View, add, and edit weight on Issue from the Issue Board contextual sidebar. !3566
- Decrease scheduling delay and add rate limiting to push mirror. !3575
- Allow admins to disable mirroring. !3586
- Support multiple Kubernetes cluster per project. !3603
- Geo: Increase parallelism by scheduling project repositories by shard. !3606
- Geo: rake task to refresh foreign table schema (FDW support). !3626
- Support mentioning epics.
- Handle outdated replicas in the DB load balancer.
- Add geo:set_secondary_as_primary rake task.
- Transfer job archives to object storage after creation.
- Geo - Show GitLab version for each node in the Geo status page.
- Add epic information to issue sidebar.
- Add system notes for issue - epic association.

### Other (3 changes)

- Add fade mask to the bottom of the boards selector dropdown list if it can be scrolled down. !3384
- Document how to set up GitLab Geo for HA. !3468
- Add border for epic edit button.


## 10.2.8 (2018-02-07)

### Security (1 change)

- Restrict LDAP API to admins only.


## 10.2.7 (2018-01-18)

- No changes.

## 10.2.6 (2018-01-11)

### Security (2 changes)

- Fix LDAP external user/group bug on first sign in.
- Deny persisting milestones from outside project/group scope on boards.


## 10.2.5 (2017-12-15)

### Fixed (1 change)

- Fix board filter for predefined milestones.


## 10.2.4 (2017-12-07)

- No changes.

## 10.2.3 (2017-11-30)

### Fixed (5 changes)

- Fix viewing default push rules on a Geo secondary. !3559
- Disable autocomplete for epics.
- Fix epic fullscreen editing.
- Fix tasklist for epics.
- Fix Geo wiki sync error not increasing retry count.


## 10.2.2 (2017-11-23)

### Fixed (6 changes)

- Fix in-progress repository syncs counting as failed. !3424
- Don't user issuable_sort cookie for epics collection.
- Enable scoped boards for Early Adopters.
- Account shared runner minutes to top-level namespace.
- Geo - Ensure that LFS object deletions are communicated to the secondary.
- Disable file attachments for epics.

### Other (1 change)

- Document a failure mode for large repositories in Geo. !3500


## 10.2.1 (2017-11-22)

- No changes.

## 10.2.0 (2017-11-22)

### Fixed (17 changes)

- Geo - Does not move projects backed by hashed storage when handling renamed events. !3066
- Geo: Don't sync disabled project wikis. !3109
- Reconfigure the Geo tracking database pool size when running as Sidekiq. !3181
- Geo - Ensures that leases were returned. !3241
- Fix (un)approver names not being shown in plaintext emails. !3266
- Add post-migration to drain all Geo related redis queues. !3289
- Prevent the Geo log cursor from running on primary nodes. !3411
- Reduce the number of Elasticsearch client instances that are created. !3432
- Fix generated clone URLs for wikis on Geo secondaries. !3448
- Remove duplicate delete button in epic.
- Fix: Failed to rebase MR from forked repo.
- Fix: Geo API bug. Statistic is not collected when prometheus is disabled.
- Geo - Ensure that repository deletions in a primary node are correctly deleted in a secondary node.
- Geo: Fix handling of nil values on advanced section in admin screen.
- Redirect to existing group boards using old URL if there is no subgroup called 'boards'.
- Geo - Allow Sidekiq to retry failed jobs to rename project repositories.
- Geo: Ensure database is connected before attempting to check for secondary status.

### Changed (4 changes)

- Add project actions in Audit events. !3160
- Add group actions in Audit events. !3176
- Geo: Don't retry repositories or files until everything has been backfilled. !3182
- Improve Codeclimate UI.

### Performance (1 change)

- Reduce the quiet times between scheduler runs on Geo secondaries. !3185

### Added (20 changes, 1 of them is from the community)

- Add new push rule to enforce that only the author of a commit can push to the repository. !3086
- Make the maximum capacity of Geo backfill operations configurable. !3107
- Mirrors can now hard fail, keeping them from being retried until a project admin takes action. !3117
- View/edit epic at group level. !3126
- Add worker to prune the Geo Event Log. !3172
- julian7 Add required_groups option to SAML config, to restrict access to GitLab to specific SAML groups. !3223 (Balazs Nagy)
- Geo: Expire and resync attachments from renamed projects in secondary nodes when using legacy storage. !3259
- On Secondary read-only Geo Nodes now a flash banner is shown on all pages. !3260
- Make GeoLogCursor Highly Available. !3305
- Allow Geo repository sync over HTTPS. !3341
- Allow persisting board configuration in order to automatically filter issues.
- Improve error handling.
- Add epics list and add epics to nav sidebar.
- Introduce EEU lincese with epics as the first feature.
- Add ability to create new epics.
- Add sidebar for epic.
- Add delete epic button.
- Allow admins to globally disable all remote mirrors from application settings page.
- Add support for logging Prometheus metrics for Geo.
- Use PostgreSQL FDW for Geo downloads.

### Other (2 changes, 1 of them is from the community)

- Suppress MergeableSelector warning candidates in EE-only files. !3225 (Takuya Noguchi)
- Enhance the documentation for gitlab-ctl replicate-geo-database. !3268


## 10.1.7 (2018-01-18)

- No changes.

## 10.1.6 (2018-01-11)

### Security (2 changes)

- Fix LDAP external user/group bug on first sign in.
- Deny persisting milestones from outside project/group scope on boards.


## 10.1.5 (2017-12-07)

- No changes.

## 10.1.4 (2017-11-14)

- No changes.

## 10.1.3 (2017-11-10)

- [FIXED] Fix: Failed to rebase MR from forked repo.

## 10.1.2 (2017-11-08)

- [SECURITY] Fix vulnerability that could allow any user of a Geo instance to clone any repository on the secondary instance.
- [SECURITY] Geo JSON web tokens now expire after two minutes to reduce risk of compromise.

## 10.1.1 (2017-10-31)

- [FIXED] Fix LDAP group sync for nested groups e.g. when base has uppercase or extraneous spaces. !3217
- [FIXED] Geo: read-only safeguards was not working on Secondary node. !3227
- [FIXED] fix height of rebase and approve buttons.
- [FIXED] Move group boards routes under - and remove "boards" from reserved paths.

## 10.1.0 (2017-10-22)

- [SECURITY] Prevent Related Issues from leaking confidential issues. !541
- [FIXED] Geo - Selective replication allows admins to select any groups. !2779
- [FIXED] Fix CSV export when filtering issues by multiple labels. !2852
- [FIXED] Impersonation no longer gets stuck on password change. !2904
- [FIXED] Mirroring to remote repository no longer fails after a force push. !2919
- [FIXED] Fix a merge request validation error on forked projects. !2932
- [FIXED] Fix an error reporting some failures in the elasticsearch indexer. !2998
- [FIXED] Fix a Geo node validation, preventing admins from locking themselves out. !3040
- [FIXED] Find stuck scheduled import jobs and also mark them as failed. !3055
- [FIXED] Fix removing the username from the git repository URL for pull mirroring. !3060
- [FIXED] Prevent failed file syncs from stalling Geo backfill. !3101
- [FIXED] Fix reading the status of a secondary Geo node from the primary. !3140
- [FIXED] Always allow the default branch as a branch name. !3154
- [FIXED] Show errors when rebase onto target branch fails in the UI.
- [FIXED] Fix base link for issues on group boards.
- [FIXED] Don't create todos for old issue assignees.
- [FIXED] Geo: Fix attachments/avatars saving to the wrong directory.
- [FIXED] Save Geo files to a temporary file and rename after success.
- [FIXED] Fix personal snippets not downloading in Geo secondaries.
- [FIXED] Geo: Limit the huge cross-database pluck for LFS objects and attachments.
- [CHANGED] Schedule repository synchronization when processing events on a Geo secondary node. !2838
- [CHANGED] Create idea of read-only database and add method to check for it. !2954
- [CHANGED] Remove the backoff delay from Geo repository sync. !3009
- [CHANGED] Improves visibility of deploy boards.
- [CHANGED] Improve performance of rebasing by using worktree.
- [ADDED] Add suport for CI/CD pipeline policy management. !2986
- [ADDED] Add LDAP synchronization based on filter for GitLab groups.
- [OTHER] Add Geo rake task descriptions. !2925
- [OTHER] Improve logging output for several Geo background workers. !2961
- [OTHER] Add partial index on push_rules.is_sample.
- Add new push rule to reject unsigned commits. !2913

## 10.0.7 (2017-12-07)

- No changes.

## 10.0.5 (2017-11-03)

- [FIXED] Find stuck scheduled import jobs and also mark them as failed. !3055
- [FIXED] Fix removing the username from the git repository URL for pull mirroring. !3060
- [FIXED] Fix base link for issues on group boards.
- [FIXED] Move group boards routes under - and remove "boards" from reserved paths.
- [FIXED] Geo: Fix attachments/avatars saving to the wrong directory.

## 10.0.4 (2017-10-16)

- [SECURITY] Prevent Related Issues from leaking confidential issues. !541
- [SECURITY] Escape user name in filtered search bar.

## 10.0.3 (2017-10-05)

- [FIXED] Rewrite Geo database rake tasks so they operate on the correct database. !3052
- [FIXED] Show group tab if member lock is enabled.
- [FIXED] File uploaders do not perform hard check, only soft check.
- [FIXED] Only show Turn on Service Desk button when user has permissions.
- [FIXED] Fix EE delta size check handling with annotated tags.

## 10.0.2 (2017-09-27)

- [FIXED] Send valid project path as name for Jira dev panel.
- [FIXED] Fix delta size check to handle commit or nil objects.

## 10.0.1 (2017-09-23)

- No changes.

## 10.0.0 (2017-09-22)

- [SECURITY] Check if LDAP users are in external groups on login. !2720
- [FIXED] Fix typo for `required` attribute. !2659
- [FIXED] Fix global code search when using negation queries. !2709
- [FIXED] Fixes activation of project mirror when new project is created. !2756
- [FIXED] Geo - Whitelist LFS requests to download objects on a secondary node. !2758
- [FIXED] Fix Geo::RepositorySyncWorker so attempts to sync all projects if some are failing. !2796
- [FIXED] Fix unsetting credentials data for pull mirrors. !2810
- [FIXED] Geo: Gracefully catch incorrect db key on primary. !2819
- [FIXED] Fix a regression breaking projects with an empty import URL. !2824
- [FIXED] Fix a 500 error in the SSH host keys lookup action. !2827
- [FIXED] Handle Geo DB replication lag as 24h/day & 7d/week. !2833
- [FIXED] Geo - Add a unique index on project_id to the Geo project_registry table. !2850
- [FIXED] Improve Geo repository sync performance for larger databases. !2887
- [FIXED] Ensure #route_setting is available before calling it. !2908
- [FIXED] Fix searching by assignee in the service desk. !2969
- [FIXED] Fix approvals before merge error while importing projects.
- [FIXED] Fix the gap in approvals in merge request widget.
- [FIXED] Fix branch name regex not saving in /admin/push_rule config.
- [FIXED] Fix merges not working when project is not licensed for squash.
- [CHANGED] Add Time estimate and Time spend fields in csv export. !2627 (g3dinua, LockiStrike)
- [CHANGED] Improve copy so users will set up SSH from DB for Geo. !2644
- [CHANGED] Support `codequality` job name for Code Quality feature. !2704
- [CHANGED] Support Elasticsearch v5.1 - v5.5. !2751
- [CHANGED] Geo primary nodes no longer require SSH keys. !2861
- [CHANGED] Show Geo event log and cursor data in node status page.
- [CHANGED] Use a logger for the artifacts migration rake task.
- [ADDED] LFS files can be stored in remote object storage such as S3. !2760
- [ADDED] Add LDAP sync endpoint to Groups API. !2785
- [ADDED] Geo - Log a repository created event when a project is created. !2807
- [ADDED] Show geo.log in the Admin area. !2845
- [ADDED] Commits integration with Jira development panel.
- [OTHER] Add missing indexes to geo_event_log table. !2836
- [OTHER] Geo - Ignore S3-backed LFS objects on secondary nodes. !2889
- Fix a bug searching private projects with Elasticsearch as an admin or auditor. !2613
- Don't put the password in the SSH remote if using public-key authentication. !2837
- Support handling of rename events in Geo Log Cursor.
- Update delete board button text color to red and fix hover color.
- Search for issues with multiple assignees.
- Fix: When MR approvals are disabled, but approvers were previously assigned, all approvers receive a notification on every MR.
- Add group issue boards.
- Ports style changes fixed in a conflict in ce to ee upstream to master for new projects page.

## 9.5.10 (2017-11-08)

- [SECURITY] Ensure GitLab Geo JSON web tokens expire after 2 minutes.

## 9.5.9 (2017-10-16)

- [SECURITY] Prevent Related Issues from leaking confidential issues.
- Escape user name in filtered search bar.

## 9.5.8 (2017-10-04)

- [FIXED] Fix EE delta size check handling with annotated tags.
- [FIXED] Fix delta size check to handle commit or nil objects.

## 9.5.7 (2017-10-03)

- No changes.

## 9.5.6 (2017-09-29)

- [FIXED] Show group tab if member lock is enabled.

## 9.5.5 (2017-09-18)

- [FIXED] Fixes activation of project mirror when new project is created. !2756
- [FIXED] Geo - Whitelist LFS requests to download objects on a secondary node. !2758
- [FIXED] Fix unsetting credentials data for pull mirrors. !2810
- [FIXED] Fix a regression breaking projects with an empty import URL. !2824
- [FIXED] Fix a 500 error in the SSH host keys lookup action. !2827
- [FIXED] Ensure #route_setting is available before calling it. !2908
- [FIXED] Fix branch name regex not saving in /admin/push_rule config.
- [FIXED] Fix the gap in approvals in merge request widget.
- [FIXED] Fix merges not working when project is not licensed for squash.
- Don't put the password in the SSH remote if using public-key authentication. !2837

## 9.5.4 (2017-09-06)

- [FIXED] Validate branch name push rule when pushing branch without commits. !2685

## 9.5.3 (2017-09-03)

- [FIXED] Check if table exists before loading the current license. !2783
- [FIXED] Extend early adopters feature set.

## 9.5.2 (2017-08-28)

- [FIXED] Fix LDAP backwards-compatibility when using "method" or when "verify_certificates" is not defined. !2690
- [FIXED] Geo - Count projects where wiki sync failed in node status page.

## 9.5.1 (2017-08-23)

- [FIXED] Fix url for object store artifacts.
- [CHANGED] Ensure all database queries are routed through the database load balancer when load balancing is enabled
. !2707

## 9.5.0 (2017-08-22)

- [FIXED] Fix Copy to Clipboard for SSH Public Key on Pull Repository settings. !2692
- [FIXED] Enable mirror repository button.
- [FIXED] Create system notes only if issue was successfully related.
- [FIXED] Fix issue boards focus button not being visible to guest users.
- Namespace license checks Audit Events & Admin Audit Log. !2326
- Namespace license checks for Repository Mirrors. !2328
- Automatically link kerberos users to LDAP people. !2405
- Implement SSH public-key support for repository mirroring. !2423
- Shows project names for commits in elasticsearch global search. !2434
- Add admin application setting to allow group owners to manage LDAP. !2529
- Geo - Selectively choose which namespaces to replicate in DR. !2533
- Support variables on Trigger API for Cross-project pipeline. !2557
- Allow excluding sidekiq queues from execution in sidekiq-cluster. !2571
- Ensure artifacts are moved locally within the filesystem to prevent timeouts. !2572
- Audit failed login events. !2587
- Spread load across all nodes in an elasticsearch cluster. !2625
- Improves handling of stuck imports. !2628
- Improves handling of the mirror threshold. !2671
- Allow artifacts access with job_token parameter or CI_JOB_TOKEN header.
- Add initial Groups/Billing and Profile/Billing routing and template.
- Fix rebase from fork when upstream has protected branches.
- Present Related Issues add badge only when user can manage related issues (previously when user could edit issue).
- clean up merge request widget UI.
- Make contextual sidebar collapsible.
- Fix accessing individual files on Object Storage.
- Fix rebase button when merge request is created from a fork.
- Skip oAuth authorization for trusted applications.

## 9.4.7 (2017-10-16)

- [SECURITY] Prevent Related Issues from leaking confidential issues.
- Fix when pushing without a branch name. !2879
- Escape user name in filtered search bar.

## 9.4.6 (2017-09-06)

- [FIXED] Validate branch name push rule when pushing branch without commits. !2685

## 9.4.5 (2017-08-14)

- Ensure artifacts are moved locally within the filesystem to prevent timeouts. !2572
- Fix rebase from fork when upstream has protected branches.
- Present Related Issues add badge only when user can manage related issues (previously when user could edit issue).
- Fix accessing individual files on Object Storage.

## 9.4.4 (2017-08-09)

- No changes.

## 9.4.3 (2017-07-31)

- Present Related Issues widget for logged-out users when available.

## 9.4.2 (2017-07-28)

- Adds lower bound to pull mirror scheduling feature. !2366
- Add warning and option toggle when rebuilding authorized_keys. !2508
- Fix CSS for mini graph with downstream pipeline.
- Renamed board to boards in new project sidebar.
- Fix Rebasing not working with Merge Requests.
- Fixed issue boards focus mode when new navigation is turned on.

## 9.4.1 (2017-07-25)

- Cleans up mirror capacity in project destroy service if project is a scheduled mirror. !2445
- Fixes unscoping of imposed capacity limit by find_each method on Mirror scheduler. !2460
- Remove text underline from suggested approvers.

## 9.4.0 (2017-07-22)

- GeoLogCursor is part of a new experimental Geo replication system. !1988
- Add explicit licensing for Elasticsearch. !2108
- Add namespace license checks for Service Desk (EEP). !2109
- Add environment scope to secret variables to specify environments. !2112
- Namespace license checks for exporting issues (EES). !2164
- Retry Elasticsearch queries on failure. !2181
- Introduce namespace license checks for rebase before merge. !2200
- Geo: fix removal of repositories from disk on secondary nodes. !2210
- Add license checks for brundown charts. !2219
- Add namespace license checks for squash before merge. !2249
- Namespace license checks for fast-forward merge (EES). !2272
- Empty repository mirror no longer creates master branch with README automatically. !2276
- Introduce namespace licensing for issue weights (EES). !2291
- Add namespace license checks for Contribution Analytics. !2302
- Add license checks for focus mode on the issue board. !2303
- Add license checks for issue boards with milestones. !2315
- Add license checks for multiple issue boards. !2317
- Geo: Fix clone instructions in a secondary node for SSH protocol. !2319
- Namespace license checks Issue & MR template. !2321
- Introduce namespace license checks for merge request approvers (EES). !2324
- Introduce namespace license checks for Push Rules (EES). !2335
- Geo: Implement alternative to geo_{primary|secondary}_role in gitlab.yml. !2352
- Geo: Added extra SystemCheck checks. !2354
- Implement progressive elasticsearch indexing for project mirrors. !2393
- Fix undefined method quote when database load balancing is used. !2430
- Improve the performance of the project list API. !12679
- fix approver placeholder icon in ie11.
- Add public API for listing, creating and deleting Related Issues.
- All artifacts are now browsable.
- Escape symbols in exported CSV columns to prevent command execution in Microsoft Excel.
- Geo - Fix RepositorySyncService when cannot obtain a lease to sync a repository.
- Prevent mirror user to be assigned to users other than the current one.
- Geo - Makes the projects synchronization faster on secondaries nodes.
- Only show the LDAP sync banner on first login.
- Enable service desk be default.
- Fix creation of push rules via POST API.
- Fix Geo middleware to work properly with multiple requests.
- [GitLab.com only] Add Slack applicationq service.
- Speed up checking for approvers when approvers are specified on the MR.
- Allows manually adding bi-directional relationships between issues in the issue page (EES feature).
- Add Geo repository renamed event log.
- Merge states to allow realtime with deploy boards.
- Fix 500 error when approvals are enabled and editing an MR conflicts with another edit.
- add toggle for overriding approvers per MR.
- Add optional sha param when approving a merge request through the API.
- Allow updating shared_runners_minutes_limit on admin Namespace API.
- Allow to Store Artifacts on Object Storage.
- Adding support for AWS ec2 instance profile credentials with elasticsearch. (Matt Gresko)
- Fixed edit issue boards milestone action buttons not sticking to bottom of dropdown.
- Respect the external user setting in Elasticsearch.

## 9.3.11 (2017-09-06)

- [FIXED] Validate branch name push rule when pushing branch without commits. !2685
- Prevent mirror user to be assigned to users other than the current one.

## 9.3.10 (2017-08-09)

- No changes.

## 9.3.9 (2017-07-20)

- No changes.

## 9.3.8 (2017-07-19)

- Escape symbols in exported CSV columns to prevent command execution in Microsoft Excel.
- Prevent mirror user to be assigned to users other than the current one.

## 9.3.7 (2017-07-18)

- No changes.

## 9.3.6 (2017-07-12)

- Geo: Fix clone instructions in a secondary node for SSH protocol. !2319
- Implement progressive elasticsearch indexing for project mirrors. !2393

## 9.3.5 (2017-07-05)

- Make admin mirror application setting GitLab.com exclusive. !2307
- Make Geo::RepositorySyncService force create a repo.

## 9.3.4 (2017-07-03)

- Update gitlab-shell to 5.1.1 to fix Post Recieve errors

## 9.3.3 (2017-06-30)

- Add metrics to both remote and non remote mirroring. !2118
- Forces import worker with mirror to insert mirror in front of queue. !2231
- Fix locked and stale SSH keys file from 9.3.0 upgrade. !2240
- Fix crash in LDAP sync when user was removed. !2289
- allow rebase for unapproved merge requests.
- Geo - Fix path_with_namespace for instances of Geo::DeletedProject.

## 9.3.2 (2017-06-27)

- Fix GitLab check: Problem with Elastic Search. !2278

## 9.3.1 (2017-06-26)

- Geo: fix removal of repositories from disk on secondary nodes. !2210
- Fix Geo middleware to work properly with multiple requests.

## 9.3.0 (2017-06-22)

- Per user/group access levels for Protected Tags. !1629
- Add a user's memberships when logging in through LDAP. !1819
- Add server-wide Audit Log admin screen. !1852
- Move pull mirroring to adaptive scheduling. !1853
- Create a push rule to check the branch name. !1896 (Riccardo Padovani)
- Add shared_runners_minutes_limit to groups and users API. !1942
- Compare codeclimate artifacts on the merge request page. !1984
- Lookup users by email in LDAP if lookup by DN fails during sync. !2003
- Update mirror_user for project when mirror_user is deleted. !2013 (Athar Hameed)
- Geo: persist clone url prefix in the database. !2015
- Geo: prevent Gitlab::Git::Repository::NoRepository from stucking replication. !2115
- Geo: fixed Dynamic Backoff strategy that was not being used by workers. !2128
- [Elasticsearch] Improve code search for camel case.
- Fixed header being over issue boards when in focus mode.
- Fix: Approvals not reset if changing target branch.
- Fix bug where files over 2 GB would not be saved in Geo tracking DB.
- Add primary node clone URL to Geo secondary 'How to work faster with Geo' popover.
- Fix broken time sync leeway with Geo.
- Gracefully handle case when Geo secondary does not have the right db_key_base.
- Use the current node configuration to populate suggested new URL for Geo node.
- Check if a merge request is approved when merging from API or slash command.
- Add closed_at field to issue CSV export.
- Geo - Properly set tracking database connection and cron jobs on secondary nodes.
- Add push events to Geo event log.
- fix Rebase being disabled for unapproved MRs.
- Fix approvers dropdown when creating a merge request from a fork.
- Add relation between Pipelines.
- Allow to Trigger Pipeline using CI Job Token.
- Allow to view Personal pipelines quota.
- Geo - Use GeoNode#clone_url_prefix for the Geo::RepositorySyncService.
- Elasticsearch searches through the project description.
- Fix: /unassign by default unassigns everyone. Implement /reassign command.
- Speed up checking for approvers remaining.

## 9.2.10 (2017-08-09)

- No changes.

## 9.2.9 (2017-07-20)

- No changes.

## 9.2.8 (2017-07-19)

- Escape symbols in exported CSV columns to prevent command execution in Microsoft Excel.
- Prevent mirror user to be assigned to users other than the current one.

## 9.2.7 (2017-06-21)

- Geo: fixed Dynamic Backoff strategy that was not being used by workers. !2128
- fix Rebase being disabled for unapproved MRs.

## 9.2.6 (2017-06-16)

- Geo: backported fix from 9.3 for big repository sync issues. !2000
- Geo - Properly set tracking database connection and cron jobs on secondary nodes.
- Fix approvers dropdown when creating a merge request from a fork.
- Fixed header being over issue boards when in focus mode.
- Fix bug where files over 2 GB would not be saved in Geo tracking DB.

## 9.2.5 (2017-06-07)

- No changes.

## 9.2.4 (2017-06-02)

- No changes.
- No changes.

## 9.2.3 (2017-05-31)

- No changes.
- No changes.
- Respect the external user setting in Elasticsearch.

## 9.2.2 (2017-05-25)

- No changes.

## 9.2.1 (2017-05-23)

- No changes.

## 9.2.0 (2017-05-22)

- Stop using sidekiq cron for push mirrors. !1616
- Inline RSS button with Export Issues button for mobile. !1637
- Highlight Contribution Analytics tab under groups when active, remove sub-nav items. !1677
- Uses etag polling for deployboards. !1713
- Support more elasticsearch versions. !1716
- Support advanced search queries using elasticsearch. !1770
- Remove superfluous wording on push rules. !1811
- Geo - Fix signing out from secondary node when "Remember me" option is checked. !1903
- Add global wiki search using Elasticsearch.
- Remove warning about protecting Service Desk email from form.
- Geo: Resync repositories that have been updated recently.
- Respect project features when searching alternative branches with elasticsearch enabled.
- Backfill projects where the last attempt to backfill failed.
- Fix MR approvals sentence when all approvers need to approve the MR.
- Fix for XSS in project mirror errors caused by Hamlit filter usage.
- Feature availability check using feature list AND license addons.
- Disable mirror workers for Geo secondaries.

## 9.1.10 (2017-08-09)

- No changes.

## 9.1.9 (2017-07-20)

- No changes.

## 9.1.8 (2017-07-19)

- Escape symbols in exported CSV columns to prevent command execution in Microsoft Excel.
- Prevent mirror user to be assigned to users other than the current one.

## 9.1.7 (2017-06-07)

- No changes.

## 9.1.6 (2017-06-02)

- No changes.

## 9.1.5 (2017-05-31)

- Respect the external user setting in Elasticsearch.

## 9.1.4 (2017-05-12)

- Remove warning about protecting Service Desk email from form.
- Backfill projects where the last attempt to backfill failed.

## 9.1.3 (2017-05-05)

- No changes.
- No changes.
- No changes.
- Respect project features when searching alternative branches with elasticsearch enabled.
- Fix for XSS in project mirror errors caused by Hamlit filter usage.

## 9.1.2 (2017-05-01)

- No changes.
- No changes.
- No changes.
- Fix commit search on some elasticsearch indexes. !1745
- Fix emailing issues to projects when Service Desk is enabled.
- Fix bug where Geo secondary Sidekiq cron jobs would not be activated if settings changed.

## 9.1.1 (2017-04-26)

- No changes.

## 9.1.0 (2017-04-22)

- Fix rake gitlab:env:info elasticsearch datum. !1422
- Fix 500 errors caused by elasticsearch results referencing garbage-collected commits. !1430
- Adds timeout option to push mirrors. !1439
- elasticsearch: Add support for an experimental repository indexer. !1483
- Update color palette to a more harmonious and consistent one. !1500
- Cache Gitlab::Geo queries. !1507
- Add Service Desk feature. !1508
- Fix pre-receive hooks when using Git 2.11 or later. !1525
- Geo: Add support to sync avatars and attachments. !1562
- Fix Elasticsearch not working when URL ends with a forward slash. !1566
- Allow admins to perform global searches with Elasticsearch. !1578
- Periodically persists users activity to users.last_activity_on. !1597
- Removes duplicate count of LFS objects from repository_and_lfs_size method. !1599
- Fix searching notes and snippets as an auditor. !1674
- Fix searching for notes with elasticsearch when a user is a member of many projects. !1675
- Fix type declarations for spend/estimate values.
- Speed up suggested approvers on MR creation.
- Fix squashing MRs when the repository contains a ref named HEAD.
- Fix approver count reset when editing assignee or labels.
- Geo: handle git failures on GeoRepositoryFetchWorker.
- Give each elasticsearch worker its own sidekiq queue.
- Fixes broken link to pipeline quota.
- Prevent filtering issues by multiple Milestones or Authors.
- Fix 500 error when selecting a mirror user.
- Add index to approvals.merge_request_id.
- Added mock data for Deployboard.
- Add uuid to usage ping.
- Expose board project and milestone on boards API.
- Fix active user count to ignore internal users.
- Add warning when burndown data is not accurate.
- Check if incoming emails and email key are available for service desk.
- Add burndown chart to milestones.
- Make deployboard to be visible by default.
- Add a Rake task to make the current node the primary Geo node.
- Return 404 instead of a 500 error on API status endpoint if Geo tracking DB is not enabled.
- Remove N+1 queries for Groups::AnalyticsController.
- Show user cohorts data when usage ping is enabled.
- Visualise Canary Deployments.

## 9.0.13 (2017-08-09)

- No changes.

## 9.0.12 (2017-07-20)

- No changes.

## 9.0.11 (2017-07-19)

- Escape symbols in exported CSV columns to prevent command execution in Microsoft Excel.
- Prevent mirror user to be assigned to users other than the current one.

## 9.0.10 (2017-06-07)

- No changes.

## 9.0.9 (2017-06-02)

- No changes.

## 9.0.8 (2017-05-31)

- Respect the external user setting in Elasticsearch.

## 9.0.7 (2017-05-05)

- Respect project features when searching alternative branches with elasticsearch enabled.
- Fix for XSS in project mirror errors caused by Hamlit filter usage.

## 9.0.6 (2017-04-21)

- Cache Gitlab::Geo queries. !1507
- Fix searching for notes with elasticsearch when a user is a member of many projects. !1675
- Fix 500 error when selecting a mirror user.
- Fix active user count to ignore internal users.

## 9.0.5 (2017-04-10)

- Return 404 instead of a 500 error on API status endpoint if Geo tracking DB is not enabled.

## 9.0.4 (2017-04-05)

- No changes.

## 9.0.3 (2017-04-05)

- Allow to edit pipelines quota for user.
- Fixed label resetting when sorting by weight. (James Clark)
- Fixed issue boards milestone toggle text not updating when filtering.
- Fixed mirror user dropdown not displaying.

## 9.0.2 (2017-03-29)

- No changes.

## 9.0.1 (2017-03-28)

- No changes.

## 9.0.0 (2017-03-22)

- Geo: Replicate repository creation in Geo secondary node. !952
- Make approval system notes lowercase. !1125
- Issues can be exported as CSV, via email. !1126
- Try to update mirrors again after 15 minutes if the previous update failed. !1183
- Adds abitlity to render deploy boards in the frontend side. !1233
- Add filtered search to MR page. !1243
- Update project list API returns with approvals_before_merge attribute. !1245 (Geoff Webster)
- Catch Net::LDAP::DN exceptions in EE::Gitlab::Auth::LDAP::Group. !1260
- API: Use `post ":id/#{type}/:subscribable_id/subscribe"` to subscribe and `post ":id/#{type}/:subscribable_id/unsubscribe"` to unsubscribe from a resource. !1274 (Robert Schilling)
- API: Remove deprecated fields Notes#upvotes and Notes#downvotes. !1275 (Robert Schilling)
- Deploy board backend. !1278
- API: Remove the ProjectGitHook API. !1301 (Robert Schilling)
- Expose elasticsearch client params for AWS signing and HTTPS. !1305 (Matt Gresko)
- Fix LDAP DN case-mismatch bug in LDAP group sync. !1337
- Remove es6 file extension from JavaScript files. !1344 (winniehell)
- Geo: Don't load dependent models when fetching an existing GeoNode from the database. !1348
- Parallelise the gitlab:elastic:index_database Rake task. !1361
- Robustify reading attributes for elasticsearch. !1365
- Introduce one additional thread into bin/elastic_repo_indexer. !1372
- Show hook errors for fast-forward merges. !1375
- Allow all parameters of group webhooks to be set through the UI. !1376
- Fix Elasticsearch queries when a group_id is specified. !1423
- Check the right index mapping based on Rails environment for rake gitlab:elastic:add_feature_visiblity_levels_to_project. !1473
- Fix issues with another milestone that has a matching list label could not be added to a board.
- Only admins or group owners can set LDAP overrides.
- Add support for load balancing database queries.
- Only replace non-approval mr-widget-footer on getMergeStatus.
- Remove repository_storage from V4 "/application/settings" settings API.
- Added headers to protected branches access dropdowns.
- Remove support for Git Annex.
- Repositioned multiple issue boards selector.
- Added back weight in issue rows on issue list.
- Add basic support for GitLab Geo file transfers over HTTP.
- Added weight slash command.
- Set deployment status invalid when the environments does not match a k8s label.
- Combined deploy keys, push rules, protect branches and mirror repository settings options into a single one called Repository.
- Rebase - fix commiter email & name.
- Adds a EE specific dev favicon.
- Elastic security fix: Respect feature visibility level.
- Update Elasticsearch to 5.1.
- [Elasticsearch] More efficient search.
- Get Geo secondaries nodes statuses over AJAX.

## 8.17.8 (2017-08-09)

- No changes.

## 8.17.7 (2017-07-19)

- Prevent mirror user to be assigned to users other than the current one.

## 8.17.6 (2017-05-05)

- Respect project features when searching alternative branches with elasticsearch enabled.

## 8.17.5 (2017-04-05)

- No changes.

## 8.17.4 (2017-03-19)

- Elastic security fix: Respect feature visibility level.

## 8.17.3 (2017-03-07)

- No changes.

## 8.17.2 (2017-03-01)

- No changes.

## 8.17.1 (2017-02-28)

- Fix admin email notification recipient group select list.
- Add repository_storage field back to projects API for admin users.
- Don't try to update a project's external service caches on a secondary Geo node.
- Fixed merge request state not updating when approvals feature is active.
- Improve error messages when squashing fails.

## 8.17.0 (2017-02-22)

- Read-only "auditor" user role. !998
- Also reset approvals on push when merge request is closed. !1051
- Copy commit SHA to clipboard. !1066
- Pull EE specific Gitlab::Auth code in to its own module. !1112
- Geo: Added `gitlab:geo:check` and improved `gitlab:envinfo` rake tasks. !1120
- Geo: send the new event type with the backfill function. !1157
- Re-add removed params from projects and issues V3 API. !1209
- Add configurable minimum mirror sync time in admin section. !1217
- Move RepositoryUpdateRemoteMirrorWorker jobs to project_mirror Sidekiq queue. !1234
- Change Builds word to Pipelines in Mirror settings page.
- Fix bundle tag in anaytics page.
- Support v4 API for GitLab Geo endpoints.
- Fixed merge request environment link not displaying.
- Reduce queries needed to check if node is a primary or secondary Geo node.
- Allow squashing merge requests into a single commit.

## 8.16.9 (2017-04-05)

- No changes.

## 8.16.8 (2017-03-19)

- No changes.
- No changes.
- No changes.
- Elastic security fix: Respect feature visibility level.

## 8.16.7 (2017-02-27)

- Fixed merge request state not updating when approvals feature is active.

## 8.16.6 (2017-02-17)

- Geo: send the new event type with the backfill function. !1157
- Move RepositoryUpdateRemoteMirrorWorker jobs to project_mirror Sidekiq queue. !1234
- Fixed merge request environment link not displaying.
- Reduce queries needed to check if node is a primary or secondary Geo node.
- Read true-up info from license and validate it. !1159

## 8.16.5 (2017-02-14)

- No changes.

## 8.16.4 (2017-02-02)

- Disable all merge acceptance buttons pending MR approval.

## 8.16.3 (2017-01-27)

- Fix sidekiq cluster mishandling of queue names. !1117

## 8.16.2 (2017-01-25)

- Track Mattermost usage in usage ping. !1071
- Fix count of required approvals displayed on MR edit form. !1082
- Fix updating approvals count when editing an MR. !1106
- Don't try to show assignee in approved_merge_request_email if there's no assignee.

## 8.16.1 (2017-01-23)

- No changes.

## 8.16.0 (2017-01-22)

- Allow to limit shared runners minutes quota for group. !965
- About GitLab link in sidebar that links to help page. !1008
- Prevent 500 error when uploading/entering a blank license. !1016
- Add more push rules to the API. !1022 (Robert Schilling)
- Expose issue weight in the API. !1023 (Robert Schilling)
- Copy <some text> to clipboard. !1048

## 8.15.8 (2017-03-19)

- No changes.
- No changes.
- Elastic security fix: Respect feature visibility level.

## 8.15.7 (2017-02-15)

- No changes.

## 8.15.6 (2017-02-14)

- No changes.

## 8.15.5 (2017-01-20)

- No changes.

## 8.15.4 (2017-01-09)

- No changes.

## 8.15.3 (2017-01-06)

- Disable LDAP permission override in project members edit list.
- Perform only one fetch per push on Geo secondary nodes.

## 8.15.2 (2016-12-27)

- No changes.
- Fix ES search for non-default branches.

## 8.15.1 (2016-12-23)

- Fix 404/500 error while navigating to the 'show/destroy' pages. !993

## 8.15.0 (2016-12-22)

- Adds a check ensure only active, ie. non-blocked users can be emailed from the admin panel.
- Add user activities API.
- Add milestone total weight to the milestone summary.
- Allow master/owner to change permission levels when LDAP group sync is enabled. !822
- Geo: Improve project view UI to teach users how to clone from a secondary Geo node and push to a primary. !905
- Technical debt follow-up from restricting pushes / merges by group. !927
- Geo: Enables nodes to be removed even without proper license. !978
- Update validates_hostname to 1.0.6 to fix a bug in parsing hexadecimal-looking domain names. !982

## 8.14.10 (2017-02-15)

- No changes.

## 8.14.9 (2017-02-14)

- No changes.

## 8.14.8 (2017-01-25)

- No changes.

## 8.14.7 (2017-01-21)

- No changes.

## 8.14.6 (2017-01-10)

- No changes.

## 8.14.5 (2016-12-14)

- Add milestone total weight to the milestone summary.

## 8.14.4 (2016-12-08)

- No changes.

## 8.14.3 (2016-12-02)

- No changes.

## 8.14.2 (2016-12-01)

- No changes.

## 8.14.1 (2016-11-28)

- Fix: MergeRequestSerializer breaks on MergeRequest#rebase_dir_path when source_project doesn't exist anymore.

## 8.14.0 (2016-11-22)

- Added Backfill service for Geo. !861
- Fix for autosuggested approvers(https://gitlab.com/gitlab-org/gitlab/issues/1273).
- Gracefully recover from previously failed rebase.
- Disable retries for remote mirror update worker. !848
- Fix Approvals API documentation.
- Add ability to set approvals_before_merge for project through the API.
- gitlab:check rake task checks ES version according to requirements
- Convert ASCII-8BIT LDAP DNs to UTF-8 to avoid unnecessary user deletions
- [Fix] Only owner can see "Projects" button in group edit menu

## 8.13.12 (2017-01-21)

- No changes.

## 8.13.11 (2017-01-10)

- No changes.

## 8.13.10 (2016-12-14)

- No changes.

## 8.13.9 (2016-12-08)

- No changes.

## 8.13.8 (2016-12-02)

- No changes.

## 8.13.7 (2016-11-28)

- No changes.

## 8.13.6 (2016-11-17)

- Disable retries for remote mirror update worker. !848
- Fixed cache clearing on secondary Geo nodes. !869
- Geo: fix a problem that prevented git cloning from secondary node. !873

## 8.13.5 (2016-11-08)

- No changes

## 8.13.4 (2016-11-07)

- Weight dropdown in issue filter form does not stay selected. !826

## 8.13.3 (2016-11-02)

- No changes

## 8.13.2 (2016-10-31)

- Don't pass a current user to Member#add_user in LDAP group sync. !830

## 8.13.1 (2016-10-25)

- Hide multiple board actions if user doesnt have permissions. !816
- Fix Elasticsearch::Transport::Transport::Errors::BadRequest when ES is enabled. !818

## 8.13.0 (2016-10-22)

- Cache the last usage data to avoid unicorn timeouts
- Add user activity table and service to query for active users
- Fix 500 error updating mirror URLs for projects
- Restrict protected branch access to specific groups !645
- Fix validations related to mirroring settings form. !773
- Add multiple issue boards. !782
- Fix Git access panel for Wikis when Kerberos authentication is enabled (Borja Aparicio)
- Decrease maximum time that GitLab waits for a mirror to finish !791 (Borja Aparicio)
- User groups (that can be assigned as approvers)
- Fix a search for non-default branches when ES is enabled
- Re-organized the Sidekiq queues for EE specific workers

## 8.12.12 (2016-12-08)

- No changes.

## 8.12.11 (2016-12-02)

- No changes.

## 8.12.10 (2016-11-28)

- No changes.

## 8.12.9 (2016-11-07)

- No changes

## 8.12.8 (2016-11-02)

- No changes

## 8.12.7

  - No EE-specific changes

## 8.12.6

  - No EE-specific changes

## 8.12.5

  - No EE-specific changes

## 8.12.4

  - [ES] Indexer works with smaller batches of repositories to not exceed NOFILE limit. !774

## 8.12.3

  - Fix prevent_secrets checkbox on admin view

## 8.12.2

  - Fix bug when protecting a branch due to missing url paramenter in request !760
  - Ignore unknown project ID in RepositoryUpdateMirrorWorker

## 8.12.1

  - Prevent secrets to be pushed to the repository
  - Prevent secrets to be pushed to the repository

## 8.12.0 (2016-09-22)

  - Include more data in EE usage ping
  - Reduce UPDATE queries when moving between import states on projects
  - [ES] Instrument Elasticsearch::Git::Repository
  - Request only the LDAP attributes we need
  - Add 'Sync now' to group members page !704
  - Add repository size limits and enforce them !740
  - [ES] Instrument other Gitlab::Elastic classes
  - [ES] Fix: Elasticsearch does not find partial matches in project names
  - Faster Active Directory group membership resolution !719
  - [ES] Global code search
  - [ES] Improve logging
  - Fix projects with remote mirrors asynchronously destruction

## 8.11.11 (2016-11-07)

- No changes

## 8.11.10 (2016-11-02)

- No changes

## 8.11.9

  - No EE-specific changes

## 8.11.8

  - No EE-specific changes

## 8.11.7

  - Refactor Protected Branches dropdown. !687
  - Fix mirrored projects allowing empty import urls. !700

## 8.11.6

  - Exclude blocked users from potential MR approvers.

## 8.11.5

  - API: Restore backward-compatibility for POST /projects/:id/members when membership is locked

## 8.11.4

  - No EE-specific changes

## 8.11.3

  - [ES] Add logging to indexer
  - Fix missing EE-specific service parameters for Jenkins CI
  - Set the correct `GL_PROTOCOL` when rebasing !691
  - [ES] Elasticsearch workers checks ES settings before running

## 8.11.2

  - Additional documentation on protected branches for EE
  - Change slash commands docs location

## 8.11.1

  - Pulled due to packaging error.

## 8.11.0 (2016-08-22)

  - Allow projects to be moved between repository storages
  - Add rake task to remove old repository copies from repositories moved to another storage
  - Performance improvement of push rules
  - Temporary fix for #825 - LDAP sync converts access requests to members. !655
  - Optimize commit and diff changes access check to reduce git operations
  - Allow syncing a group against all providers at once
  - Change LdapGroupSyncWorker to use new LDAP group sync classes
  - Allow LDAP `sync_ssh_keys` setting to be set to `true`
  - Removed unused GitLab GEO database index
  - Restrict protected branch access to specific users !581
  - Enable monitoring for ES classes
  - [Elastic] Improve code search
  - [Elastic] Significant improvement of global search performance
  - [Fix] Push rules check existing commits in some cases
  - [ES] Limit amount of retries for sidekiq jobs
  - Fix Projects::UpdateMirrorService to allow tags pointing to blob objects

## 8.10.12

  - No EE-specific changes

## 8.10.11

  - No EE-specific changes

## 8.10.10

  - No EE-specific changes

## 8.10.9

  - Exclude blocked users from potential MR approvers.

## 8.10.8

  - No EE-specific changes

## 8.10.7

  - No EE-specific changes

## 8.10.6

  - Fix race condition with UpdateMirrorWorker Lease. !641

## 8.10.5

  - Used cached value of project count in `Elastic::RepositoriesSearch` to reduce DB load. !637

## 8.10.4

  - Fix available users in userselect dropdown when there is more than one userselect on the page. !604 (Rik de Groot)
  - Fix updating skipped approvers in search list on removal. !604 (Rik de Groot)

## 8.10.3

  - Fix regression in Git Annex permission check. !599
  - [Elastic] Fix commit search for some URLs. !605
  - [Elastic][Fix] Commit search breaks for some URLs on gitlab-ce project

## 8.10.2

  - Fix pagination on search result page when ES search is enabled. !592
  - Decouple an ES index update from `RepositoryUpdateMirrorWorker`. !593
  - Fix broken `user_allowed?` check in Git Annex push. !597

## 8.10.1

  - No EE-specific changes

## 8.10.0 (2016-07-22)

  - Add EE license usage ping !557
  - Rename Git Hooks to Push Rules
  - Fix EE keys fingerprint add index migration if came from CE
  - Add todos for MR approvers !547
  - Replace LDAP group sync exclusive lease with state machine
  - Prevent the author of an MR from being on the approvers list
  - Isolate EE LDAP library code in EE module (Part 1) !511
  - Make Elasticsearch indexer run as an async task
  - Fix of removing wiki data from index when project is deleted
  - Ticket-based Kerberos authentication (SPNEGO)
  - [Elastic] Suppress ActiveRecord::RecordNotFound error in ElasticIndexWorker

## 8.9.10

  - No EE-specific changes

## 8.9.9

  - No EE-specific changes

## 8.9.8

  - No EE-specific changes

## 8.9.7

  - No EE-specific changes

## 8.9.6

  - Avoid adding index for key fingerprint if it already exists. !539

## 8.9.5

  - Fix of quoted text in lock tooltip. !518

## 8.9.4

  - Improve how File Lock feature works with nested items. !497

## 8.9.3

  - Fix encrypted data backwards compatibility after upgrading attr_encrypted gem. !502
  - Fix creating MRs on forks of deleted projects. !503
  - Roll back Grack::Auth to fix Git HTTP SPNEGO. !504

## 8.9.2

  - [Elastic] Fix visibility of snippets when searching.

## 8.9.1

  - Improve Geo documentation. !431
  - Fix remote mirror stuck on started issue. !491
  - Fix MR creation from forks where target project has approvals enabled. !496
  - Fix MR edit where target project has approvals enabled. !496
  - Fix vertical alignment of git-hooks page. !499

## 8.9.0 (2016-06-22)

  - Fix JenkinsService test button
  - Fix nil user handling in UpdateMirrorService
  - Allow overriding the number of approvers for a merge request
  - Allow LDAP to mark users as external based on their group membership. !432
  - Instrument instance methods of Gitlab::InsecureKeyFingerprint class
  - Add API endpoint for Merge Request Approvals !449
  - Send notification email when merge request is approved
  - Distribute RepositoryUpdateMirror jobs in time and add exclusive lease on them by project_id
  - [Elastic] Move ES settings to application settings
  - Always allow merging a merge request whenever fast-forward is possible. !454
  - Disable mirror flag for projects without import_url
  - UpdateMirror service return an error status when no mirror
  - Don't reset approvals when rebasing an MR from the UI
  - Show flash notice when Git Hooks are updated successfully
  - Remove explicit Gitlab::Metrics.action assignments, are already automatic.
  - [Elastic] Project members with guest role can't access confidential issues
  - Ability to lock file or folder in the repository
  - Fix: Git hooks don't fire when committing from the UI

## 8.8.9

  - No EE-specific changes

## 8.8.8

  - No EE-specific changes

## 8.8.7

  - No EE-specific changes

## 8.8.6

  - [Elastic] Fix visibility of snippets when searching.

## 8.8.5

  - Make sure OAuth routes that we generate for Geo matches with the ones in Rails routes !444

## 8.8.4

  - Remove license overusage message

## 8.8.3

  - Add standard web hook headers to Jenkins CI post. !374
  - Gracefully handle malformed DNs in LDAP group sync. !392
  - Reduce load on DB for license upgrade check. !421
  - Make it clear the license overusage message is visible only to admins. !423
  - Fix Git hook validations for fast-forward merges. !427
  - [Elastic] In search results, only show notes on confidential issues that the user has access to.

## 8.8.2

  - Fix repository mirror updates for new imports stuck in started
  - [Elastic] Search through the filenames. !409
  - Fix repository mirror updates for new imports stuck in "started" state. !416

## 8.8.1

  - No EE-specific changes

## 8.8.0 (2016-05-22)

  - [Elastic] Database indexer prints its status
  - [Elastic][Fix] Database indexer skips projects with invalid HEAD reference
  - Fix skipping pages when restoring backups
  - Add EE license via API !400
  - [Elastic] More efficient snippets search
  - [Elastic] Add rake task for removing all indexes
  - [Elastic] Add rake task for clearing indexing status
  - [Elastic] Improve code search
  - [Elastic] Fix encoding issues during indexing
  - Warn admin if current active count exceeds license
  - [Elastic] Search through the filenames
  - Set KRB5 as default clone protocol when Kerberos is enabled and user is logged in (Borja Aparicio)
  - Add support for Admin Groups to SAML
  - Reduce emails-on-push HTML size by using a simple monospace font
  - API requests to /internal/authorized_keys are now tagged properly
  - Geo: Single Sign Out support !380

## 8.7.9

  - No EE-specific changes

## 8.7.8

  - [Elastic] Fix visibility of snippets when searching.

## 8.7.7

  - No EE-specific changes

## 8.7.6

  - Bump GitLab Pages to 0.2.4 to fix Content-Type for predefined 404

## 8.7.5

  - No EE-specific changes

## 8.7.4

  - Delete ProjectImportData record only if Project is not a mirror !370
  - Fixed typo in GitLab GEO license check alert !379
  - Fix LDAP access level spillover bug !499

## 8.7.3

  - No EE-specific changes

## 8.7.2

  - Fix MR notifications for slack and hipchat when approvals are fullfiled. !325
  - GitLab Geo: Merge requests on Secondary should not check mergeable status

## 8.7.1

  - No EE-specific changes

## 8.7.0 (2016-04-22)

  - Update GitLab Pages to 0.2.1: support user-defined 404 pages
  - Refactor group sync to pull access level logic to its own class. !306
  - [Elastic] Stabilize database indexer if database is inconsistent
  - Add ability to sync to remote mirrors. !249
  - GitLab Geo: Many replication improvements and fixes !354

## 8.6.9

  - No EE-specific changes

## 8.6.8

  - No EE-specific changes

## 8.6.7

  - No EE-specific changes

## 8.6.6

  - Concat AD group recursive member results with regular member results. !333
  - Fix LDAP group sync regression for groups with member value `uid=<username>`. !335
  - Don't attempt to include too large diffs in e-mail-on-push messages (Stan Hu). !338

## 8.6.5

  - No EE-specific changes

## 8.6.4

  - No EE-specific changes

## 8.6.3

  - Fix other cases where git hooks would fail due to old commits. !310
  - Exit ElasticIndexerWorker's job happily if record cannot be found. !311
  - Fix "Reload with full diff" button not working (Stan Hu). !313

## 8.6.2

  - Fix old commits triggering git hooks on new branches branched off another branch. !281
  - Fix issue with deleted user in audit event (Stan Hu). !284
  - Mark pending todos as done when approving a merge request. !292
  - GitLab Geo: Display Attachments from Primary node. !302

## 8.6.1

  - Only rename the `light_logo` column in the `appearances` table if its not there yet. !290
  - Fix diffs in text part of email-on-push messages (Stan Hu). !293
  - Fix an issue with methods not accessible in some controllers. !295
  - Ensure Projects::ApproversController inherits from Projects::ApplicationController. !296

## 8.6.0 (2016-03-22)

  - Handle duplicate appearances table creation issue with upgrade from CE to EE
  - Add confidential issues
  - Improve weight filter for issues
  - Update settings and documentation for per-install LDAP sync time
  - Fire merge request webhooks when a merge request is approved
  - Add full diff highlighting to Email on push
  - Clear "stuck" mirror updates before periodically updating all mirrors
  - LDAP: Don't render Linked LDAP groups forms when LDAP is disabled
  - [Elastic] Add elastic checker to gitlab:check
  - [Elastic] Added UPDATE_INDEX option to rake task
  - [Elastic] Removing repository and wiki index after removing project
  - [Elastic] Update index on push to wiki
  - [Elastic] Use subprocesses for ElasticSearch index jobs
  - [Elastic] More accurate as_indexed_json (More stable database indexer)
  - [Elastic] Fix: Don't index newly created system messages and awards
  - [Elastic] Fixed exception on branch removing
  - [Elastic] Fix bin/elastic_repo_indexer to follow config
  - GitLab Geo: OAuth authentication
  - GitLab Geo: Wiki synchronization
  - GitLab Geo: ReadOnly Middleware improvements
  - GitLab Geo: SSH Keys synchronization
  - Allow SSL verification to be configurable when importing GitHub projects
  - Disable git-hooks for git annex commits

## 8.5.13

  - No EE-specific changes

## 8.5.12

  - No EE-specific changes

## 8.5.11

  - Fix vulnerability that made it possible to enumerate private projects belonging to group

## 8.5.10

  - No EE-specific changes

## 8.5.9

  - No EE-specific changes

## 8.5.8

  - GitLab Geo: Documentation

## 8.5.7

  - No EE-specific changes

## 8.5.6

  - No EE-specific changes

## 8.5.5

  - GitLab Geo: Repository synchronization between primary and secondary nodes
  - Add documentation for GitLab Pages
  - Fix importing projects from GitHub Enterprise Edition
  - Fix syntax error in init file
  - Only show group member roles if explicitly requested
  - GitLab Geo: Improve GeoNodes Admin screen
  - GitLab Geo: Avoid locking yourself out when adding a GeoNode

## 8.5.4

  - [Elastic][Security] Notes exposure

## 8.5.3

  - Prevent LDAP from downgrading a group's last owner
  - Update gitlab-elastic-search gem to 0.0.11

## 8.5.2

  - Update LDAP groups asynchronously
  - Fix an issue when weight text was displayed in Issuable collapsed sidebar
## 8.5.2

  - Fix importing projects from GitHub Enterprise Edition.

## 8.5.1

  - Fix adding pages domain to projects in groups

## 8.5.0 (2016-02-22)

  - Fix Elasticsearch blob results linking to the wrong reference ID (Stan Hu)
  - Show warning when mirror repository default branch could not be updated because it has diverged from upstream.
  - More reliable wiki indexer
  - GitLab Pages gets support for custom domain and custom certificate
  - Fix of Elastic indexer. It should not trigger record validation for projects
  - Fix of Elastic indexer. Stabilze indexer when serialized data is corrupted
  - [Elastic] Don't index unnecessary data into elastic

## 8.4.11

  - No EE-specific changes

## 8.4.10

  - No EE-specific changes

## 8.4.9

  - Fix vulnerability that made it possible to enumerate private projects belonging to group

## 8.4.8

  - No EE-specific changes

## 8.4.7

  - No EE-specific changes

## 8.4.6

  - No EE-specific changes

## 8.4.5

  - Update LDAP groups asynchronously

## 8.4.4

  - Re-introduce "Send email to users" link in Admin area
  - Fix category values for Jenkins and JenkinsDeprecated services
  - Fix Elasticsearch indexing for newly added snippets
  - Make Elasticsearch indexer more stable
  - Update gitlab-elasticsearch-git to 0.0.10 which contain a few important fixes

## 8.4.3

  - Elasticsearch: fix partial blob indexing on push
  - Elasticsearch: added advanced indexer for repositories
  - Fix Mirror User dropdown

## 8.4.2

  - Elasticsearch indexer performance improvements
  - Don't redirect away from Mirror Repository settings when repo is empty
  - Fix updating of branches in mirrored repository
  - Fix a 500 error preventing LDAP users with 2FA enabled from logging in
  - Rake task gitlab:elastic:index_repositories handles errors and shows progress
  - Partial indexing of repo on push (indexing changes only)

## 8.4.1

  - No EE-specific changes

## 8.4.0 (2016-01-22)

  - Add ability to create a note for user by admin
  - Fix "Commit was rejected by git hook", when max_file_size was set null in project's Git hooks
  - Fix "Approvals are not reset after a new push is made if the request is coming from a fork"
  - Fix "User is not automatically removed from suggested approvers list if user is deleted"
  - Add option to enforce a semi-linear history by only allowing merge requests to be merged that have been rebased
  - Add option to trigger builds when branches or tags are updated from a mirrored upstream repository
  - Ability to use Elasticsearch as a search engine

## 8.3.10

  - No EE-specific changes

## 8.3.9

  - No EE-specific changes

## 8.3.8

  - Fix vulnerability that made it possible to enumerate private projects belonging to group

## 8.3.7

  - No EE-specific changes

## 8.3.6

  - No EE-specific changes

## 8.3.5

  - No EE-specific changes

## 8.3.4

  - No EE-specific changes

## 8.3.3

  - Fix undefined method call in Jenkins integration service

## 8.3.2

  - No EE-specific changes

## 8.3.1

  - Rename "Group Statistics" to "Contribution Analytics"

## 8.3.0 (2015-12-22)

  - License information can now be retrieved via the API
  - Show Kerberos clone url when Kerberos enabled and url different than HTTP url (Borja Aparicio)
  - Fix bug with negative approvals required
  - Add group contribution analytics page
  - Add GitLab Pages
  - Add group contribution statistics page
  - Automatically import Kerberos identities from Active Directory when Kerberos is enabled (Alex Lossent)
  - Canonicalization of Kerberos identities to always include realm (Alex Lossent)

## 8.2.6

  - No EE-specific changes

## 8.2.5

  - No EE-specific changes

## 8.2.4

  - No EE-specific changes

## 8.2.3

  - No EE-specific changes

## 8.2.2

  - Fix 404 in redirection after removing a project (Stan Hu)
  - Ensure cached application settings are refreshed at startup (Stan Hu)
  - Fix Error 500 when viewing user's personal projects from admin page (Stan Hu)
  - Fix: Raw private snippets access workflow
  - Prevent "413 Request entity too large" errors when pushing large files with LFS
  - Ensure GitLab fires custom update hooks after commit via UI

## 8.2.1

  - Forcefully update builds that didn't want to update with state machine
  - Fix: saving GitLabCiService as Admin Template

## 8.2.0 (2015-11-22)

  - Invalidate stored jira password if the endpoint URL is changed
  - Fix: Page is not reloaded periodically to check if rebase is finished
  - When someone as marked as a required approver for a merge request, an email should be sent
  - Allow configuring the Jira API path (Alex Lossent)
  - Fix "Rebase onto master"
  - Ensure a comment is properly recorded in JIRA when a merge request is accepted
  - Allow groups to appear in the `Share with group` share if the group owner allows it
  - Add option to mirror an upstream repository.

## 8.1.4

  - Fix bug in JIRA integration which prevented merge requests from being accepted when using issue closing pattern

## 8.1.3

  - Fix "Rebase onto master"

## 8.1.2

  - Prevent a 500 error related to the JIRA external issue tracker service

## 8.1.1

  - Removed, see 8.1.2

## 8.1.0 (2015-10-22)

  - Add documentation for "Share project with group" API call
  - Added an issues template (Hannes Rosenögger)
  - Add documentation for "Share project with group" API call
  - Ability to disable 'Share with Group' feature (via UI and API)

## 8.0.6

  - No EE-specific changes

## 8.0.5

  - "Multi-project" and "Treat unstable builds as passing" parameters for
    the Jenkins CI service are now correctly persisted.
  - Correct the build URL when "Multi-project" is enabled for the Jenkins CI
    service.

## 8.0.4

  - Fix multi-project setup for Jenkins

## 8.0.3

  - No EE-specific changes

## 8.0.2

  - No EE-specific changes

## 8.0.1

  - Correct gem dependency versions
  - Re-add the "Help Text" feature that was inadvertently removed

## 8.0.0 (2015-09-22)

  - Fix navigation issue when viewing Group Settings pages
  - Guests and Reporters can approve merge request as well
  - Add fast-forward merge option in project settings
  - Separate rebase & fast-forward merge features

## 7.14.3

  - No changes

## 7.14.2

  - Fix the rebase before merge feature

## 7.14.1

  - Fix sign in form when just Kerberos is enabled

## 7.14.0 (2015-08-22)

  - Disable adding, updating and removing members from a group that is synced with LDAP
  - Don't send "Added to group" notifications when group is LDAP synched
  - Fix importing projects from GitHub Enterprise Edition.
  - Automatic approver suggestions (based on an authority of the code)
  - Add support for Jenkins unstable status
  - Automatic approver suggestions (based on an authority of the code)
  - Support Kerberos ticket-based authentication for Git HTTP access

## 7.13.3

  - Merge community edition changes for version 7.13.3
  - Improved validation for an approver
  - Don't resend admin email to everyone if one delivery fails
  - Added migration for removing of invalid approvers

## 7.13.2

  - Fix group web hook
  - Don't resend admin email to everyone if one delivery fails

## 7.13.1

  - Merge community edition changes for version 7.13.1
  - Fix: "Rebase before merge" doesn't work when source branch is in the same project

## 7.13.0 (2015-07-22)

  - Fix git hook validation on initial push to master branch.
  - Reset approvals on push
  - Fix 500 error when the source project of an MR is deleted
  - Ability to define merge request approvers

## 7.12.2

  - Fixed the alignment of project settings icons

## 7.12.1

  - No changes specific to EE

## 7.12.0 (2015-06-22)

  - Fix error when viewing merge request with a commit that includes "Closes #<issue id>".
  - Enhance LDAP group synchronization to check also for member attributes that only contain "uid=<username>"
  - Enhance LDAP group synchronization to check also for submember attributes
  - Prevent LDAP group sync from removing a group's last owner
  - Add Git hook to validate maximum file size.
  - Project setting: approve merge request by N users before accept
  - Support automatic branch jobs created by Jenkins in CI Status
  - Add API support for adding and removing LDAP group links

## 7.11.4

  - no changes specific to EE

## 7.11.3

  - Fixed an issue with git annex

## 7.11.2

  - Fixed license upload and verification mechanism

## 7.11.0 (2015-05-22)

  - Skip git hooks commit validation when pushing new tag.
  - Add Two-factor authentication (2FA) for LDAP logins

## 7.10.1

  - Check if comment exists in Jira before sending a reference

## 7.10.0 (2015-04-22)

  - Improve UI for next pages: Group LDAP sync, Project git hooks, Project share with groups, Admin -> Appearance settigns
  - Default git hooks for new projects
  - Fix LDAP group links page by using new group members route.
  - Skip email confirmation when updated via LDAP.

## 7.9.0 (2015-03-22)

  - Strip prefixes and suffixes from synced SSH keys:
    `SSHKey:ssh-rsa keykeykey` and `ssh-rsa keykeykey (SSH key)` will now work
  - Check if LDAP admin group exists before querying for user membership
  - Use one custom header logo for all GitLab themes in appearance settings
  - Escape wildcards when searching LDAP by group name.
  - Group level Web Hooks
  - Don't allow project to be shared with the group it is already in.

## 7.8.0 (2015-02-22)

  - Improved Jira issue closing integration
  - Improved message logging for Jira integration
  - Added option of referencing JIRA issues from GitLab
  - Update Sidetiq to 0.6.3
  - Added Github Enterprise importer
  - When project has MR rebase enabled, MR will have rebase checkbox selected by default
  - Minor UI fixes for sidebar navigation
  - Manage large binaries with git annex

## 7.7.0 (2015-01-22)

  - Added custom header logo support (Drew Blessing)
  - Fixed preview appearance bug
  - Improve performance for selectboxes: project share page, admin email users page

## 7.6.2

  - Fix failing migrations for MySQL, LDAP

## 7.6.1

  - No changes

## 7.6.0 (2014-12-22)

  - Added Audit events related to membership changes for groups and projects
  - Added option to attempt a rebase before merging merge request
  - Dont show LDAP groups settings if LDAP disabled
  - Added member lock for groups to disallow membership additions on project level
  - Rebase on merge request. Introduced merge request option to rebase before merging
  - Better message for failed pushes because of git hooks
  - Kerberos support for web interface and git HTTP

## 7.5.3

  - Only set up Sidetiq from a Sidekiq server process (fixes Redis::InheritedError)

## 7.5.0 (2014-11-22)

  - Added an ability to check each author commit's email by regex
  - Added an ability to restrict commit authors to existing GitLab users
  - Add an option for automatic daily LDAP user sync
  - Added git hook for preventing tag removal to API
  - Added git hook for setting commit message regex to API
  - Added an ability to block commits with certain filenames by regex expression
  - Improved a jenkins parser

## 7.4.4

  - Fix broken ldap migration

## 7.4.0 (2014-10-22)

  - Support for multiple LDAP servers
  - Skip AD specific LDAP checks
  - Do not show ldap users in dropdowns for groups with enabled ldap-sync
  - Update the JIRA integration documentation
  - Reset the homepage to show the GitLab logo by deleting the custom logo.

## 7.3.0 (2014-09-22)

  - Add an option to change the LDAP sync time from default 1 hour
  - User will receive an email when unsubscribed from admin notifications
  - Show group sharing members on /my/project/team
  - Improve explanation of the LDAP permission reset
  - Fix some navigation issues
  - Added support for multiple LDAP groups per GitLab group

## 7.2.0 (2014-08-22)

  - Improve Redmine integration
  - Better logging for the JIRA issue closing service
  - Administrators can now send email to all users through the admin interface
  - JIRA issue transition ID is now customizable
  - LDAP group settings are now visible in admin group show page and group members page

## 7.1.0 (2014-07-22)

  - Synchronize LDAP-enabled GitLab administrators with an LDAP group (Marvin Frick, sponsored by SinnerSchrader)
  - Synchronize SSH keys with LDAP (Oleg Girko (Jolla) and Marvin Frick (SinnerSchrader))
  - Support Jenkins jobs with multiple modules (Marvin Frick, sponsored by SinnerSchrader)

## 7.0.0 (2014-06-22)

  - Fix: empty brand images are displayed as empty image_tag on login page (Marvin Frick, sponsored by SinnerSchrader)

## 6.9.4

  - Fix bug in JIRA Issue closing triggered by commit messages
  - Fix JIRA issue reference bug

## 6.9.3

  - Fix check CI status only when CI service is enabled(Daniel Aquino)

## 6.9.2

  - Merge community edition changes for version 6.9.2

## 6.9.1

  - Merge community edition changes for version 6.9.1

## 6.9.0 (2014-05-22)

  - Add support for closing Jira tickets with commits and MR
  - Template for Merge Request description can be added in project settings
  - Jenkins CI service
  - Fix LDAP email upper case bug

## 6.8.0 (2014-04-22)

  - Customise sign-in page with custom text and logo

## 6.7.1

  - Handle LDAP errors in Adapter#dn_matches_filter?

## 6.7.0 (2014-03-22)

  - Improve LDAP sign-in speed by reusing connections
  - Add support for Active Directory nested LDAP groups
  - Git hooks: Commit message regex
  - Git hooks: Deny git tag removal
  - Fix group edit in admin area

## 6.6.0 (2014-02-22)

  - Permission reset button for LDAP groups
  - Better performance with large numbers of users with access to one project

## 6.5.0 (2014-01-22)

  - Add reset permissions button to Group#members page

## 6.4.0 (2013-12-22)

  - Respect existing group permissions during sync with LDAP group (d3844662ec7ce816b0a85c8b40f66ee6c5ae90a1)

## 6.3.0 (2013-11-22)

  - When looking up a user by DN, use single scope (bc8a875df1609728f1c7674abef46c01168a0d20)
  - Try sAMAccountName if omniauth nickname is nil (9b7174c333fa07c44cc53b80459a115ef1856e38)

## 6.2.0 (2013-10-22)

  - API: expose ldap_cn and ldap_access group attributes
  - Use omniauth-ldap nickname attribute as GitLab username
  - Improve group sharing UI for installation with many groups
  - Fix empty LDAP group raises exception
  - Respect LDAP user filter for git access
