---
type: reference
stage: Manage
group: Optimize
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Value stream analytics for groups **(PREMIUM)**

Value stream analytics provides metrics about each stage of your software development process.

A **value stream** is the entire work process that delivers value to customers. For example,
the [DevOps lifecycle](https://about.gitlab.com/stages-devops-lifecycle/) is a value stream that starts
with the "manage" stage and ends with the "protect" stage.

Use value stream analytics to identify:

- The amount of time it takes to go from an idea to production.
- The velocity of a given project.
- Bottlenecks in the development process.
- Long-running issues or merge requests.
- Factors that cause your software development lifecycle to slow down.

Value stream analytics is also available for [projects](../../analytics/value_stream_analytics.md).

## View value stream analytics

> - Filtering [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/13216) in GitLab 13.3
> - Horizontal stage path [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/12196) in 13.0 and [feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/323982) in 13.12

Prerequisite:

- You must have at least the Reporter role to view value stream analytics for groups.
- You must create a [custom value stream](#create-a-value-stream-with-gitlab-default-stages). Value stream analytics only shows custom value streams created for your group.

To view value stream analytics for your group:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Analytics > Value stream**.
1. To view metrics for a particular stage, select a stage below the **Filter results** text box.
1. Optional. Filter the results:
   1. Select the **Filter results** text box.
   1. Select a parameter.
   1. Select a value or enter text to refine the results.
   1. To adjust the date range:
      - In the **From** field, select a start date.
      - In the **To** field, select an end date. The charts and list show workflow items created
        during the date range.
1. Optional. Sort results by ascending or descending:
      - To sort by most recent or oldest workflow item, select the **Last event** header.
      - To sort by most or least amount of time spent in each stage, select the **Duration** header.

A badge next to the workflow items table header shows the number of workflow items that
completed during the selected stage.

The table shows a list of related workflow items for the selected stage. Based on the stage you select, this can be:

- CI/CD jobs
- Issues
- Merge requests
- Pipelines

## View DORA metrics and key metrics for a group

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/210315) in GitLab 13.0.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/323982) in GitLab 13.12.

The **Overview** dashboard in value stream analytics shows key metrics and DORA metrics of group performance. Based on the filter you select,
the dashboard automatically aggregates DORA metrics and displays the current status of the value stream. Select a DORA metric to view its chart.

To view deployment metrics, you must have a
[production environment configured](../../../ci/environments/index.md#deployment-tier-of-environments).

To view the DORA metrics and key metrics:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Analytics > Value stream**.
1. Optional. Filter the results:
   1. Select the **Filter results** text box.
   1. Select a parameter.
   1. Select a value or enter text to refine the results.
   1. To adjust the date range:
      - In the **From** field, select a start date.
      - In the **To** field, select an end date.
Key metrics and DORA metrics display below the **Filter results** text box.

### Key metrics in the value stream

The **Overview** dashboard shows the following key metrics that measure team performance:

- Lead time: Median time from when the issue was created to when it was closed.
- Cycle time: Median time from first commit to issue closed. GitLab measures cycle time from the earliest commit of a
  [linked issue's merge request](../../project/issues/crosslinking_issues.md#from-commit-messages) to when that issue is closed.
  The cycle time approach underestimates the lead time because merge request creation is always later than commit time.
- New issues: Number of new issues created.
- Deploys: Total number of deployments to production.

### DORA metrics **(ULTIMATE)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/340150) lead time for changes DORA metric in GitLab 14.5.
> - DORA API-based deployment metrics for value stream analytics for groups were [moved](https://gitlab.com/gitlab-org/gitlab/-/issues/337256) from GitLab Ultimate to GitLab Premium in GitLab 14.3.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/355304) time to restore service tile in GitLab 15.0.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/357071) change failure rate tile in GitLab 15.0.

The value stream analytics **Overview** dashboard displays the following [DORA](../../../user/analytics/index.md) metrics:

- Deployment Frequency.
- Lead time for changes.
- Time to restore service.
- Change failure rate.

DORA metrics are calculated based on data from the
[DORA API](../../../api/dora/metrics.md#devops-research-and-assessment-dora-key-metrics-api).

NOTE:
In GitLab 13.9 and later, deployment frequency metrics are calculated based on when the deployment was finished.
In GitLab 13.8 and earlier, deployment frequency metrics are calculated based on when the deployment was created.

<div class="video-fallback">
  See the video: <a href="https://www.youtube.com/embed/wQU-mWvNSiI">DORA metrics and value stream analytics</a>.
</div>
<figure class="video-container">
  <iframe src="https://www.youtube.com/embed/wQU-mWvNSiI" frameborder="0" allowfullscreen="true"> </iframe>
</figure>

### How value stream analytics aggregates data

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/335391) in GitLab 14.5 [with a flag](../../../administration/feature_flags.md) named `use_vsa_aggregated_tables`. Disabled by default.
> - Filter by stop date toggle [added](https://gitlab.com/gitlab-org/gitlab/-/issues/352428) in GitLab 14.9
> - Data refresh badge [added](https://gitlab.com/gitlab-org/gitlab/-/issues/341739) in GitLab 14.9
> - Filter by stop date toggle [removed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/84356) in GitLab 14.9
> - Enable filtering by stop date [added](https://gitlab.com/gitlab-org/gitlab/-/issues/355000) in GitLab 15.0

Value stream analytics uses a backend process to collect and aggregate stage-level data, which
ensures it can scale for large groups with a high number of issues and merge requests. Due to this process,
there may be a slight delay between when an action is taken (for example, closing an issue) and when the data
displays on the value stream analytics page.

It may take up to 10 minutes to process the data and display results. Data collection may take
longer than 10 minutes in the following cases:

- If this is the first time you are viewing value stream analytics and have not yet [created a value stream](#create-a-value-stream-with-gitlab-default-stages).
- If the group hierarchy has been re-arranged.
- If there have been bulk updates on issues and merge requests.

To view when the data was most recently updated, in the right corner next to **Edit**, hover over the **Last updated** badge.

## View metrics for each development stage

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/210315) in GitLab 13.0.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/323982) in GitLab 13.12.

Value stream analytics shows the median time spent by issues or merge requests in each development stage.

To view the median time spent in each stage by a group:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Analytics > Value stream**.
1. Optional. Filter the results:
   1. Select the **Filter results** text box.
   1. Select a parameter.
   1. Select a value or enter text to refine the results.
   1. To adjust the date range:
      - In the **From** field, select a start date.
      - In the **To** field, select an end date.
1. To view the metrics for each stage, above the **Filter results** text box, hover over a stage.

NOTE:
The date range selector filters items by the event time. The event time is when the
selected stage finished for the given item.

## How value stream analytics measures stages

Value stream analytics measures each stage from its start event to its end event.

For example, a stage might start when a user adds a label to an issue, and ends when they add another label.
Items aren't included in the stage time calculation if they have not reached the end event.

Value stream analytics allows you to customize your stages based on pre-defined events. To make the
configuration easier, GitLab provides a pre-defined list of stages that can be used as a template

Each pre-defined stages of value stream analytics is further described in the table below.

| Stage   | Measurement method   |
| ------- | -------------------- |
| Issue     | The median time between creating an issue and taking action to solve it, by either labeling it or adding it to a milestone, whichever comes first. The label is tracked only if it already has an [issue board list](../../project/issue_board.md) created for it. |
| Plan      | The median time between the action you took for the previous stage, and pushing the first commit to the branch. The first commit on the branch triggers the separation between **Plan** and **Code**. At least one of the commits in the branch must contain the related issue number (for example, `#42`). If none of the commits in the branch mention the related issue number, it is not considered in the measurement time of the stage. |
| Code      | The median time between pushing a first commit (previous stage) and creating a merge request (MR) related to that commit. The key to keep the process tracked is to include the [issue closing pattern](../../project/issues/managing_issues.md#default-closing-pattern) in the description of the merge request. For example, `Closes #xxx`, where `xxx` is the number of the issue related to this merge request. If the closing pattern is not present, then the calculation uses the creation time of the first commit in the merge request as the start time. |
| Test      | The median time to run the entire pipeline for that project. It's related to the time GitLab CI/CD takes to run every job for the commits pushed to that merge request. It is basically the start->finish time for all pipelines. |
| Review    | The median time taken to review a merge request that has a closing issue pattern, between its creation and until it's merged. |
| Staging   | The median time between merging a merge request that has a closing issue pattern until the very first deployment to a [production environment](#how-value-stream-analytics-identifies-the-production-environment). If there isn't a production environment, this is not tracked. |

For information about how value stream analytics calculates each stage, see the [Value stream analytics development guide](../../../development/value_stream_analytics.md).

### Example workflow

This example shows a workflow through all seven stages in one day.

If a stage does not include a start and a stop time, its data is not included in the median time.
In this example, milestones have been created and CI/CD for testing and setting environments is configured.

- 09:00: Create issue. **Issue** stage starts.
- 11:00: Add issue to a milestone, start work on the issue, and create a branch locally.
  **Issue** stage stops and **Plan** stage starts.
- 12:00: Make the first commit.
- 12:30: Make the second commit to the branch that mentions the issue number.
  **Plan** stage stops and **Code** stage starts.
- 14:00: Push branch and create a merge request that contains the
  [issue closing pattern](../../project/issues/managing_issues.md#closing-issues-automatically).
  **Code** stage stops and **Test** and **Review** stages start.
- GitLab CI/CD takes 5 minutes to run scripts defined in [`.gitlab-ci.yml`](../../../ci/yaml/index.md).
- 19:00: Merge the merge request. **Review** stage stops and **Staging** stage starts.
- 19:30: Deployment to the `production` environment finishes. **Staging** stops.

Value stream analytics records the following times for each stage:

- **Issue**: 09:00 to 11:00: 2 hrs
- **Plan**: 11:00 to 12:00: 1 hr
- **Code**: 12:00 to 14:00: 2 hrs
- **Test**: 5 minutes
- **Review**: 14:00 to 19:00: 5 hrs
- **Staging**: 19:00 to 19:30: 30 minutes

There are some additional considerations for this example:

- This example demonstrates that it doesn't matter if your first
  commit doesn't mention the issue number, you can do this later in any commit
  on the branch you are working on.
- The **Test** stage is used in the calculation for the overall time of
  the cycle. It is included in the **Review** process, as every MR should be
  tested.
- This example illustrates only **one cycle** of the seven stages. The value stream analytics dashboard
  shows the median time for multiple cycles.

## How value stream analytics identifies the production environment

Value stream analytics identifies production environments by looking for project
[environments](../../../ci/yaml/index.md#environment) with a name matching any of these patterns:

- `prod` or `prod/*`
- `production` or `production/*`

These patterns are not case-sensitive.

You can change the name of a project environment in your GitLab CI/CD configuration.

## Create a value stream with GitLab default stages

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/221202) in GitLab 13.3

When you create a value stream, you can use GitLab default stages and hide or re-order them to customize. You can also
create custom stages in addition to those provided in the default template.

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Analytics > Value Stream**.
1. Select **Create new Value Stream**.
1. Enter a name for the value stream.
1. Select **Create from default template**.
1. Customize the default stages:
   - To re-order stages, select the up or down arrows.
   - To hide a stage, select **Hide** (**{eye-slash}**).
1. To add a custom stage, select **Add another stage**.
   - Enter a name for the stage.
   - Select a **Start event** and a **Stop event**.
1. Select **Create value stream**.

NOTE:
If you have recently upgraded to GitLab Premium, it can take up to 30 minutes for data to collect and display.

## Create a value stream with custom stages

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/50229) in GitLab 13.7.
> - [Enabled by default](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/55572) in GitLab 13.10.
> - [Feature flag removed](https://gitlab.com/gitlab-org/gitlab/-/issues/294190) in GitLab 13.11.

When you create a value stream, you can create and add custom stages that align with your own development workflows.

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Analytics > Value Stream**.
1. Select **Create value stream**.
1. For each stage:
   - Enter a name for the stage.
   - Select a **Start event** and a **Stop event**.
1. To add another stage, select **Add another stage**.
1. To re-order the stages, select the up or down arrows.
1. Select **Create value stream**.

### Label-based stages for custom value streams

To measure complex workflows, you can use [scoped labels](../../project/labels.md#scoped-labels). For example, to measure deployment
time from a staging environment to production, you could use the following labels:

- When the code is deployed to staging, the `workflow::staging` label is added to the merge request.
- When the code is deployed to production, the `workflow::production` label is added to the merge request.

![Label-based value stream analytics stage](img/vsa_label_based_stage_v14_0.png "Creating a label-based value stream analytics stage")

## Edit a value stream

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/267537) in GitLab 13.10.

After you create a value stream, you can customize it to suit your purposes. To edit a value stream:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Analytics > Value Stream**.
1. In the top right, select the dropdown list, and select a value stream.
1. Next to the value stream dropdown list, select **Edit**.
1. Optional:
    - Rename the value stream.
    - Hide or re-order default stages.
    - Remove existing custom stages.
    - To add new stages, select **Add another stage**.
    - Select the start and end events for the stage.
1. Optional. To undo any modifications, select **Restore value stream defaults**.
1. Select **Save Value Stream**.

## Delete a value stream

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/221205) in GitLab 13.4.

To delete a custom value stream:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Analytics > Value Stream**.
1. In the top right, select the dropdown list and then select the value stream you would like to delete.
1. Select **Delete (name of value stream)**.
1. To confirm, select **Delete**.

![Delete value stream](img/delete_value_stream_v13_12.png "Deleting a custom value stream")

## View number of days for a cycle to complete

> - Chart median line [removed](https://gitlab.com/gitlab-org/gitlab/-/issues/235455) in GitLab 13.4.
> - Totals [replaced](https://gitlab.com/gitlab-org/gitlab/-/issues/262070) with averages in GitLab 13.12.

The **Total time chart** shows the average number of days it takes for development cycles to complete.
The chart shows data for the last 500 workflow items.

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Analytics > Value stream**.
1. Above the **Filter results** box, select a stage:
   - To view a summary of the cycle time for all stages, select **Overview**.
   - To view the cycle time for specific stage, select a stage.
1. Optional. Filter the results:
   1. Select the **Filter results** text box.
   1. Select a parameter.
   1. Select a value or enter text to refine the results.
   1. To adjust the date range:
      - In the **From** field, select a start date.
      - In the **To** field, select an end date.

## Tasks by type chart

This chart shows a cumulative count of issues and merge requests per day.

This chart uses the global page filters for displaying data based on the selected
group, projects, and time frame. The chart defaults to showing counts for issues but can be
toggled to show data for merge requests and further refined for specific group-level labels.

By default the top group-level labels (max. 10) are pre-selected, with the ability to
select up to a total of 15 labels.
