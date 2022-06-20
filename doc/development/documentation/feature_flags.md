---
info: For assistance with this Style Guide page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments-to-other-projects-and-subjects.
stage: none
group: unassigned
description: "GitLab development - how to document features deployed behind feature flags"
---

# Document features deployed behind feature flags

GitLab uses [feature flags](../feature_flags/index.md) to strategically roll
out the deployment of its own features. The way we document a feature behind a
feature flag depends on its state (enabled or disabled). When the state
changes, the developer who made the change **must update the documentation**
accordingly.

Every feature introduced to the codebase, even if it's behind a feature flag,
must be documented. For context, see the
[latest merge request that updated this guideline](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/47917#note_459984428).

When you document feature flags, you must:

- [Add version history text](#add-version-history-text).
- [Add a note at the start of the topic](#use-a-note-to-describe-the-state-of-the-feature-flag).

## Add version history text

When the state of a flag changes (for example, disabled by default to enabled by default), add the change to the version history.

Possible version history entries are:

```markdown
> - [Introduced](issue-link) in GitLab X.X [with a flag](../../administration/feature_flags.md) named <flag name>. Disabled by default.
> - [Enabled on GitLab.com](issue-link) in GitLab X.X.
> - [Enabled on GitLab.com](issue-link) in GitLab X.X. Available to GitLab.com administrators only.
> - [Enabled on self-managed](issue-link) in GitLab X.X.
> - [Generally available](issue-link) in GitLab X.Y. [Feature flag <flag name>](issue-link) removed.
```

You can combine entries if they happened in the same release:

```markdown
> - Introduced in GitLab 14.2 [with a flag](../../administration/feature_flags.md) named `ci_include_rules`. Disabled by default.
> - [Enabled on GitLab.com and self-managed](https://gitlab.com/gitlab-org/gitlab/-/issues/337507) in GitLab 14.3.
```

## Use a note to describe the state of the feature flag

Information about feature flags should be in a **Note** at the start of the topic (just below the version history).

The note has three parts, and follows this structure:

```markdown
FLAG:
<Self-managed GitLab availability information.>
<GitLab.com availability information.>
<This feature is not ready for production use.>
```

### Self-managed GitLab availability information

| If the feature is...     | Use this text |
|--------------------------|---------------|
| Available                | `On self-managed GitLab, by default this feature is available. To hide the feature, ask an administrator to [disable the feature flag](<path to>/administration/feature_flags.md) named <flag name>.` |
| Unavailable              | `On self-managed GitLab, by default this feature is not available. To make it available, ask an administrator to [enable the feature flag](<path to>/administration/feature_flags.md) named <flag name>.` |
| Available, per-group     | `On self-managed GitLab, by default this feature is available. To hide the feature per group, ask an administrator to [disable the feature flag](<path to>/administration/feature_flags.md) named <flag name>.` |
| Unavailable, per-group   | `On self-managed GitLab, by default this feature is not available. To make it available per group, ask an administrator to [enable the feature flag](<path to>/administration/feature_flags.md) named <flag name>.` |
| Available, per-project   | `On self-managed GitLab, by default this feature is available. To hide the feature per project or for your entire instance, ask an administrator to [disable the feature flag](<path to>/administration/feature_flags.md) named <flag name>.` |
| Unavailable, per-project | `On self-managed GitLab, by default this feature is not available. To make it available per project or for your entire instance, ask an administrator to [enable the feature flag](<path to>/administration/feature_flags.md) named <flag name>.` |
| Available, per-user      | `On self-managed GitLab, by default this feature is available. To hide the feature per user, ask an administrator to [disable the feature flag](<path to>/administration/feature_flags.md) named <flag name>.` |
| Unavailable, per-user    | `On self-managed GitLab, by default this feature is not available. To make it available per user, ask an administrator to [enable the feature flag](<path to>/administration/feature_flags.md) named <flag name>.` |

### GitLab.com availability information

| If the feature is...                | Use this text |
|-------------------------------------|---------------|
| Available                           | `On GitLab.com, this feature is available.` |
| Available to GitLab.com admins only | `On GitLab.com, this feature is available but can be configured by GitLab.com administrators only.`
| Unavailable                         | `On GitLab.com, this feature is not available.`|

### Optional information

If needed, you can add this sentence:

`The feature is not ready for production use.`

## Feature flag documentation examples

The following examples show the progression of a feature flag.

```markdown
> Introduced in GitLab 13.7 [with a flag](../../administration/feature_flags.md) named `forti_token_cloud`. Disabled by default.

FLAG:
On self-managed GitLab, by default this feature is not available. To make it available,
ask an administrator to [enable the feature flag](../administration/feature_flags.md) named `forti_token_cloud`.
The feature is not ready for production use.
```

When the feature is enabled in production, you can update the version history:

```markdown
> - Introduced in GitLab 13.7 [with a flag](../../administration/feature_flags.md) named `forti_token_cloud`. Disabled by default.
> - [Enabled on self-managed](https://gitlab.com/issue/etc) GitLab 13.8.

FLAG:
On self-managed GitLab, by default this feature is available. To hide the feature per user,
ask an administrator to [disable the feature flag](../administration/feature_flags.md) named `forti_token_cloud`.
```

And, when the feature is done and fully available to all users:

```markdown
> - Introduced in GitLab 13.7 [with a flag](../../administration/feature_flags.md) named `forti_token_cloud`. Disabled by default.
> - [Enabled on self-managed](https://gitlab.com/issue/etc) in GitLab 13.8.
> - [Enabled on GitLab.com](https://gitlab.com/issue/etc) in GitLab 13.9.
> - [Generally available](issue-link) in GitLab 14.0. [Feature flag <flag name>](issue-link) removed.
```
