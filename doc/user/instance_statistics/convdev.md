# Conversational Development Index

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/30469) in GitLab 9.3.

NOTE: **Note:**
Your GitLab instance's [usage ping](../admin_area/settings/usage_statistics.md#usage-ping-core-only) must be activated in order to use this feature.

The [Conversational Development](http://conversationaldevelopment.com/2017/04/16/what-is-conversational-development/) Index (ConvDev Index) gives you an overview of your entire
instance's adoption of [Concurrent DevOps](https://about.gitlab.com/concurrent-devops/)
from planning to monitoring.

This displays the usage of these GitLab features over
the last 30 days, averaged over the number of active users in that time period. It also
provides a Lead score per feature, which is calculated based on GitLab's analysis
of top-performing instances based on [usage ping data](../admin_area/settings/usage_statistics.md#usage-ping-core-only) that GitLab has
collected. Your score is compared to the lead score of each feature and then expressed as a percentage at the bottom of said feature.
Your overall index score is an average of all your feature score percentages - this percentage value is presented above all the of features on the page.

![ConvDev index](img/convdev_index.png)

The page also provides helpful links to articles and GitLab docs, to help you
improve your scores.

Usage ping data is aggregated on GitLab's servers for analysis. Your usage
information is **not sent** to any other GitLab instances. If you have just started using GitLab, it may take a few weeks for data to be
collected before this feature is available.
