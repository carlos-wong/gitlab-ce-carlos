<!-- Title suggestion: [Feature flag] Enable description of feature -->

## Summary

This issue is to rollout [the feature](ISSUE LINK) on production,
that is currently behind the `<feature-flag-name>` feature flag.

<!-- Short description of what the feature is about and link to relevant other issues. -->

## Owners

- Team: NAME_OF_TEAM
- Most appropriate slack channel to reach out to: `#g_TEAM_NAME`
- Best individual to reach out to: NAME
- PM: NAME

## Stakeholders

<!--
Are there any other stages or teams involved that need to be kept in the loop?

- Name of a PM
- The Support Team
- The Delivery Team
-->

## Expectations

### What are we expecting to happen?

<!-- Describe the expected outcome when rolling out this feature -->

### When is the feature viable?

<!-- What are the settings we need to configure in order to have this feature viable? -->

<!-- 
Example below:
 
1. Enable service ping collection
   `ApplicationSetting.first.update(usage_ping_enabled: true)`
-->

### What might happen if this goes wrong?

<!-- Should the feature flag be turned off? Any MRs that need to be rolled back? Communication that needs to happen? What are some things you can think of that could go wrong - data loss or broken pages? -->

### What can we monitor to detect problems with this?

<!-- Which dashboards from https://dashboards.gitlab.net are most relevant? -->
_Consider mentioning checks for 5xx errors or other anomalies like an increase in redirects 
(302 HTTP response status)_

### What can we check for monitoring production after rollouts?

_Consider adding links to check for Sentry errors, Production logs for 5xx, 302s, etc._

## Rollout Steps

### Rollout on non-production environments

- Ensure that the feature MRs have been deployed to non-production environments.
    - [ ] `/chatops run auto_deploy status <merge-commit-of-your-feature>`
- [ ] Enable the feature globally on non-production environments.
    - [ ] `/chatops run feature set <feature-flag-name> true --dev --staging --staging-ref`
- [ ] Verify that the feature works as expected. Posting the QA result in this issue is preferable.
      The best environment to validate the feature in is [staging-canary](https://about.gitlab.com/handbook/engineering/infrastructure/environments/#staging-canary)
      as this is the first environment deployed to. Note you will need to make sure you are configured to use canary as outlined [here](https://about.gitlab.com/handbook/engineering/infrastructure/environments/canary-stage/)
      when accessing the staging environment in order to make sure you are testing appropriately.

### Specific rollout on production

- Ensure that the feature MRs have been deployed to both production and canary.
    - [ ] `/chatops run auto_deploy status <merge-commit-of-your-feature>`
- If you're using [project-actor](https://docs.gitlab.com/ee/development/feature_flags/#feature-actors), you must enable the feature on these entries:
    - [ ] `/chatops run feature set --project=gitlab-org/gitlab,gitlab-org/gitlab-foss,gitlab-com/www-gitlab-com <feature-flag-name> true`
- If you're using [group-actor](https://docs.gitlab.com/ee/development/feature_flags/#feature-actors), you must enable the feature on these entries:
    - [ ] `/chatops run feature set --group=gitlab-org,gitlab-com <feature-flag-name> true`
- If you're using [user-actor](https://docs.gitlab.com/ee/development/feature_flags/#feature-actors), you must enable the feature on these entries:
    - [ ] `/chatops run feature set --user=<your-username> <feature-flag-name> true`
- [ ] Verify that the feature works on the specific entries. Posting the QA result in this issue is preferable.

### Preparation before global rollout

- [ ] Check if the feature flag change needs to be accompanied with a
  [change management issue](https://about.gitlab.com/handbook/engineering/infrastructure/change-management/#feature-flags-and-the-change-management-process).
  Cross link the issue here if it does.
- [ ] Ensure that you or a representative in development can be available for at least 2 hours after feature flag updates in production.
  If a different developer will be covering, or an exception is needed, please inform the oncall SRE by using the `@sre-oncall` Slack alias.
- [ ] Ensure that documentation has been updated ([More info](https://docs.gitlab.com/ee/development/documentation/feature_flags.html#features-that-became-enabled-by-default)).
- [ ] Announce on [the feature issue](ISSUE LINK) an estimated time this will be enabled on GitLab.com. 
- [ ] Ensure that any breaking changes have been announced following the [release post process](https://about.gitlab.com/handbook/marketing/blog/release-posts/#deprecations-removals-and-breaking-changes) to ensure GitLab customers are aware.
- [ ] Notify `#support_gitlab-com` and your team channel ([more guidance when this is necessary in the dev docs](https://docs.gitlab.com/ee/development/feature_flags/controls.html#communicate-the-change)).

### Global rollout on production

For visibility, all `/chatops` commands that target production should be executed in the `#production` slack channel and cross-posted (with the command results) to the responsible team's slack channel (`#g_TEAM_NAME`).

- [ ] [Incrementally roll out](https://docs.gitlab.com/ee/development/feature_flags/controls.html#process) the feature.
  - If the feature flag in code has [an actor](https://docs.gitlab.com/ee/development/feature_flags/#feature-actors), perform **actor-based** rollout.
    - [ ] `/chatops run feature set <feature-flag-name> <rollout-percentage> --actors`
  - If the feature flag in code does **NOT** have [an actor](https://docs.gitlab.com/ee/development/feature_flags/#feature-actors), perform time-based rollout (**random** rollout).
    - [ ] `/chatops run feature set <feature-flag-name> <rollout-percentage> --random`
  - Enable the feature globally on production environment.
    - [ ] `/chatops run feature set <feature-flag-name> true`
- [ ] Announce on [the feature issue](ISSUE LINK) that the feature has been globally enabled.
- [ ] Wait for [at least one day for the verification term](https://about.gitlab.com/handbook/product-development-flow/feature-flag-lifecycle/#including-a-feature-behind-feature-flag-in-the-final-release).

### (Optional) Release the feature with the feature flag

If you're still unsure whether the feature is [deemed stable](https://about.gitlab.com/handbook/product-development-flow/feature-flag-lifecycle/#including-a-feature-behind-feature-flag-in-the-final-release)
but want to release it in the current milestone, you can change the default state of the feature flag to be enabled.
To do so, follow these steps:

- [ ] Create a merge request with the following changes. Ask for review and merge it.
    - [ ] Set the `default_enabled` attribute in [the feature flag definition](https://docs.gitlab.com/ee/development/feature_flags/#feature-flag-definition-and-validation) to `true`.
    - [ ] Create [a changelog entry](https://docs.gitlab.com/ee/development/feature_flags/#changelog).
- [ ] Ensure that the default-enabling MR has been included in the release package.
      If the merge request was deployed before [the monthly release was tagged](https://about.gitlab.com/handbook/engineering/releases/#self-managed-releases-1),
      the feature can be officially announced in a release blog post.
    - [ ] `/chatops run release check <merge-request-url> <milestone>`
- [ ] Consider cleaning up the feature flag from all environments by running these chatops command in `#production` channel. Otherwise these settings may override the default enabled.
    - [ ] `/chatops run feature delete <feature-flag-name> --dev --staging --staging-ref --production`
- [ ] Close [the feature issue](ISSUE LINK) to indicate the feature will be released in the current milestone.
- [ ] Set the next milestone to this rollout issue for scheduling [the flag removal](#release-the-feature).
- [ ] (Optional) You can [create a separate issue](https://gitlab.com/gitlab-org/gitlab/-/issues/new?issuable_template=Feature%20Flag%20Cleanup) for scheduling the steps below to [Release the feature](#release-the-feature).
    - [ ] Set the title to "[Feature flag] Cleanup `<feature-flag-name>`".
    - [ ] Execute the `/copy_metadata <this-rollout-issue-link>` quick action to copy the labels from this rollout issue.
    - [ ] Link this rollout issue as a related issue.
    - [ ] Close this rollout issue.

**WARNING:** This approach has the downside that it makes it difficult for us to
[clean up](https://docs.gitlab.com/ee/development/feature_flags/controls.html#cleaning-up) the flag.
For example, on-premise users could disable the feature on their GitLab instance. But when you
remove the flag at some point, they suddenly see the feature as enabled and they can't roll it back
to the previous behavior. To avoid this potential breaking change, use this approach only for urgent
matters.

### Release the feature

After the feature has been [deemed stable](https://about.gitlab.com/handbook/product-development-flow/feature-flag-lifecycle/#including-a-feature-behind-feature-flag-in-the-final-release),
the [clean up](https://docs.gitlab.com/ee/development/feature_flags/controls.html#cleaning-up)
should be done as soon as possible to permanently enable the feature and reduce complexity in the
codebase.

You can either [create a follow-up issue for Feature Flag Cleanup](https://gitlab.com/gitlab-org/gitlab/-/issues/new?issuable_template=Feature%20Flag%20Cleanup) or use the checklist below in this same issue.

<!-- The checklist here is to help stakeholders keep track of the feature flag status -->
- [ ] Create a merge request to remove `<feature-flag-name>` feature flag. Ask for review and merge it.
    - [ ] Remove all references to the feature flag from the codebase.
    - [ ] Remove the YAML definitions for the feature from the repository.
    - [ ] Create [a changelog entry](https://docs.gitlab.com/ee/development/feature_flags/#changelog).
- [ ] Ensure that the cleanup MR has been included in the release package.
      If the merge request was deployed before [the monthly release was tagged](https://about.gitlab.com/handbook/engineering/releases/#self-managed-releases-1),
      the feature can be officially announced in a release blog post.
    - [ ] `/chatops run release check <merge-request-url> <milestone>`
- [ ] Close [the feature issue](ISSUE LINK) to indicate the feature will be released in the current milestone.
- [ ] If not already done, clean up the feature flag from all environments by running these chatops command in `#production` channel:
    - [ ] `/chatops run feature delete <feature-flag-name> --dev --staging --staging-ref --production`
- [ ] Close this rollout issue.

## Rollback Steps

- [ ] This feature can be disabled by running the following Chatops command:

```
/chatops run feature set <feature-flag-name> false
```

/label ~"feature flag" ~"type::feature" ~"feature::addition"
