---
stage: Growth
group: Product Intelligence
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Implement Service Ping

Service Ping consists of two kinds of data:

- **Counters**: Track how often a certain event happened over time, such as how many CI/CD pipelines have run.
  They are monotonic and always trend up.
- **Observations**: Facts collected from one or more GitLab instances and can carry arbitrary data.
  There are no general guidelines for how to collect those, due to the individual nature of that data.

To implement a new metric in Service Ping, follow these steps:

1. [Implement the required counter](#types-of-counters)
1. [Name and place the metric](metrics_dictionary.md#metric-key_path)
1. [Test counters manually using your Rails console](#test-counters-manually-using-your-rails-console)
1. [Generate the SQL query](#generate-the-sql-query)
1. [Optimize queries with `#database-lab`](#optimize-queries-with-database-lab)
1. [Add the metric definition to the Metrics Dictionary](#add-the-metric-definition)
1. [Add the metric to the Versions Application](#add-the-metric-to-the-versions-application)
1. [Create a merge request](#create-a-merge-request)
1. [Verify your metric](#verify-your-metric)
1. [Set up and test Service Ping locally](#set-up-and-test-service-ping-locally)

## Instrumentation classes

NOTE:
Implementing metrics directly in `usage_data.rb` is deprecated.
When you add or change a Service Ping Metric, you must migrate metrics to [instrumentation classes](metrics_instrumentation.md).
For information about the progress on migrating Service Ping metrics, see this [epic](https://gitlab.com/groups/gitlab-org/-/epics/5547).

For example, we have the following instrumentation class:
`lib/gitlab/usage/metrics/instrumentations/count_boards_metric.rb`.

You should add it to `usage_data.rb` as follows:

```ruby
boards: add_metric('CountBoardsMetric', time_frame: 'all'),
```

## Types of counters

There are several types of counters for metrics:

- **[Batch counters](#batch-counters)**: Used for counts and sums.
- **[Redis counters](#redis-counters):** Used for in-memory counts.
- **[Alternative counters](#alternative-counters):** Used for settings and configurations.

NOTE:
Only use the provided counter methods. Each counter method contains a built-in fail-safe mechanism that isolates each counter to avoid breaking the entire Service Ping process.

### Batch counters

For large tables, PostgreSQL can take a long time to count rows due to MVCC [(Multi-version Concurrency Control)](https://en.wikipedia.org/wiki/Multiversion_concurrency_control). Batch counting is a counting method where a single large query is broken into multiple smaller queries. For example, instead of a single query querying 1,000,000 records, with batch counting, you can execute 100 queries of 10,000 records each. Batch counting is useful for avoiding database timeouts as each batch query is significantly shorter than one single long running query.

For GitLab.com, there are extremely large tables with 15 second query timeouts, so we use batch counting to avoid encountering timeouts. Here are the sizes of some GitLab.com tables:

| Table                        | Row counts in millions |
|------------------------------|------------------------|
| `merge_request_diff_commits` | 2280                   |
| `ci_build_trace_sections`    | 1764                   |
| `merge_request_diff_files`   | 1082                   |
| `events`                     | 514                    |

Batch counting requires indexes on columns to calculate max, min, and range queries. In some cases,
you must add a specialized index on the columns involved in a counter.

#### Ordinary batch counters

Create a new [database metrics](metrics_instrumentation.md#database-metrics) instrumentation class with `count` operation for a given `ActiveRecord_Relation`

Method:

```ruby
add_metric('CountIssuesMetric', time_frame: 'all')
```

Examples:

Examples using `usage_data.rb` have been [deprecated](usage_data.md). We recommend to use [instrumentation classes](metrics_instrumentation.md).

#### Distinct batch counters

Create a new [database metrics](metrics_instrumentation.md#database-metrics) instrumentation class with `distinct_count` operation for a given `ActiveRecord_Relation`.

Method:

```ruby
add_metric('CountUsersAssociatingMilestonesToReleasesMetric', time_frame: 'all')
```

WARNING:
Counting over non-unique columns can lead to performance issues. For more information, see the [iterating tables in batches](../iterating_tables_in_batches.md) guide.

Examples:

Examples using `usage_data.rb` have been [deprecated](usage_data.md). We recommend to use [instrumentation classes](metrics_instrumentation.md).

#### Sum batch operation

There is no support for `sum` for database metrics.

Sum the values of a given ActiveRecord_Relation on given column and handles errors.
Handles the `ActiveRecord::StatementInvalid` error

Method:

```ruby
sum(relation, column, batch_size: nil, start: nil, finish: nil)
```

Arguments:

- `relation`: the ActiveRecord_Relation to perform the operation
- `column`: the column to sum on
- `batch_size`: if none set it uses default value 1000 from `Gitlab::Database::BatchCounter`
- `start`: custom start of the batch counting to avoid complex min calculations
- `end`: custom end of the batch counting to avoid complex min calculations

Examples:

```ruby
sum(JiraImportState.finished, :imported_issues_count)
```

#### Grouping and batch operations

The `count`, `distinct_count`, and `sum` batch counters can accept an `ActiveRecord::Relation`
object, which groups by a specified column. With a grouped relation, the methods do batch counting,
handle errors, and returns a hash table of key-value pairs.

Examples:

```ruby
count(Namespace.group(:type))
# returns => {nil=>179, "Group"=>54}

distinct_count(Project.group(:visibility_level), :creator_id)
# returns => {0=>1, 10=>1, 20=>11}

sum(Issue.group(:state_id), :weight))
# returns => {1=>3542, 2=>6820}
```

#### Add operation

Sum the values given as parameters. Handles the `StandardError`.
Returns `-1` if any of the arguments are `-1`.

Method:

```ruby
add(*args)
```

Examples:

```ruby
project_imports = distinct_count(::Project.where.not(import_type: nil), :creator_id)
bulk_imports = distinct_count(::BulkImport, :user_id)

 add(project_imports, bulk_imports)
```

#### Estimated batch counters

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/48233) in GitLab 13.7.

Estimated batch counter functionality handles `ActiveRecord::StatementInvalid` errors
when used through the provided `estimate_batch_distinct_count` method.
Errors return a value of `-1`.

WARNING:
This functionality estimates a distinct count of a specific ActiveRecord_Relation in a given column,
which uses the [HyperLogLog](http://algo.inria.fr/flajolet/Publications/FlFuGaMe07.pdf) algorithm.
As the HyperLogLog algorithm is probabilistic, the **results always include error**.
The highest encountered error rate is 4.9%.

When correctly used, the `estimate_batch_distinct_count` method enables efficient counting over
columns that contain non-unique values, which can not be assured by other counters.

##### estimate_batch_distinct_count method

Method:

```ruby
estimate_batch_distinct_count(relation, column = nil, batch_size: nil, start: nil, finish: nil)
```

The [method](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/utils/usage_data.rb#L63)
includes the following arguments:

- `relation`: The ActiveRecord_Relation to perform the count.
- `column`: The column to perform the distinct count. The default is the primary key.
- `batch_size`: From `Gitlab::Database::PostgresHll::BatchDistinctCounter::DEFAULT_BATCH_SIZE`. Default value: 10,000.
- `start`: The custom start of the batch count, to avoid complex minimum calculations.
- `finish`: The custom end of the batch count to avoid complex maximum calculations.

The method includes the following prerequisites:

- The supplied `relation` must include the primary key defined as the numeric column.
  For example: `id bigint NOT NULL`.
- The `estimate_batch_distinct_count` can handle a joined relation. To use its ability to
  count non-unique columns, the joined relation **must not** have a one-to-many relationship,
  such as `has_many :boards`.
- Both `start` and `finish` arguments should always represent primary key relationship values,
  even if the estimated count refers to another column, for example:

  ```ruby
    estimate_batch_distinct_count(::Note, :author_id, start: ::Note.minimum(:id), finish: ::Note.maximum(:id))
  ```

Examples:

1. Simple execution of estimated batch counter, with only relation provided,
   returned value represents estimated number of unique values in `id` column
   (which is the primary key) of `Project` relation:

   ```ruby
     estimate_batch_distinct_count(::Project)
   ```

1. Execution of estimated batch counter, where provided relation has applied
   additional filter (`.where(time_period)`), number of unique values estimated
   in custom column (`:author_id`), and parameters: `start` and `finish` together
   apply boundaries that defines range of provided relation to analyze:

   ```ruby
     estimate_batch_distinct_count(::Note.with_suggestions.where(time_period), :author_id, start: ::Note.minimum(:id), finish: ::Note.maximum(:id))
   ```

1. Execution of estimated batch counter with joined relation (`joins(:cluster)`),
   for a custom column (`'clusters.user_id'`):

   ```ruby
     estimate_batch_distinct_count(::Clusters::Applications::CertManager.where(time_period).available.joins(:cluster), 'clusters.user_id')
   ```

When instrumenting metric with usage of estimated batch counter please add
`_estimated` suffix to its name, for example:

```ruby
  "counts": {
    "ci_builds_estimated": estimate_batch_distinct_count(Ci::Build),
    ...
```

### Redis counters

Handles `::Redis::CommandError` and `Gitlab::UsageDataCounters::BaseCounter::UnknownEvent`.
Returns -1 when a block is sent or hash with all values and -1 when a `counter(Gitlab::UsageDataCounters)` is sent.
The different behavior is due to 2 different implementations of the Redis counter.

Method:

```ruby
redis_usage_data(counter, &block)
```

Arguments:

- `counter`: a counter from `Gitlab::UsageDataCounters`, that has `fallback_totals` method implemented
- or a `block`: which is evaluated

#### Ordinary Redis counters

Examples of implementation:

- Using Redis methods [`INCR`](https://redis.io/commands/incr), [`GET`](https://redis.io/commands/get), and [`Gitlab::UsageDataCounters::WikiPageCounter`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage_data_counters/wiki_page_counter.rb)
- Using Redis methods [`HINCRBY`](https://redis.io/commands/hincrby), [`HGETALL`](https://redis.io/commands/hgetall), and [`Gitlab::UsageCounters::PodLogs`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage_counters/pod_logs.rb)

##### `UsageData` API

You can use the `UsageData` API to track events.
To track events, the `usage_data_api` feature flag must
be enabled (set to `default_enabled: true`).
Enabled by default in GitLab 13.7 and later.

##### UsageData API tracking

1. Track events using the [`UsageData` API](#usagedata-api).

   Increment event count using an ordinary Redis counter, for a given event name.

   API requests are protected by checking for a valid CSRF token.

   To increment the values, the related feature `usage_data_<event_name>` must be enabled.

   ```plaintext
   POST /usage_data/increment_counter
   ```

   | Attribute | Type | Required | Description |
   | :-------- | :--- | :------- | :---------- |
   | `event` | string | yes | The event name to track. |

   Response:

   - `200` if the event was tracked.
   - `400 Bad request` if the event parameter is missing.
   - `401 Unauthorized` if the user is not authenticated.
   - `403 Forbidden` if an invalid CSRF token is provided.

1. Track events using the JavaScript/Vue API helper which calls the [`UsageData` API](#usagedata-api).

   To track events, `usage_data_api` and `usage_data_#{event_name}` must be enabled.

   ```javascript
   import api from '~/api';

   api.trackRedisCounterEvent('my_already_defined_event_name'),
   ```

#### Redis HLL counters

WARNING:
HyperLogLog (HLL) is a probabilistic algorithm and its **results always includes some small error**. According to [Redis documentation](https://redis.io/commands/pfcount), data from
used HLL implementation is "approximated with a standard error of 0.81%".

NOTE:
 A user's consent for usage_stats (`User.single_user&.requires_usage_stats_consent?`) is not checked during the data tracking stage due to performance reasons. Keys corresponding to those counters are present in Redis even if `usage_stats_consent` is still required. However, no metric is collected from Redis and reported back to GitLab as long as `usage_stats_consent` is required.

With `Gitlab::UsageDataCounters::HLLRedisCounter` we have available data structures used to count unique values.

Implemented using Redis methods [PFADD](https://redis.io/commands/pfadd) and [PFCOUNT](https://redis.io/commands/pfcount).

##### Add new events

1. Define events in [`known_events`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage_data_counters/known_events/).

   Example event:

   ```yaml
   - name: users_creating_epics
     category: epics_usage
     redis_slot: users
     aggregation: weekly
     feature_flag: track_epics_activity
   ```

   Keys:

   - `name`: unique event name.

     Name format for Redis HLL events `<name>_<redis_slot>`.

     [See Metric name](metrics_dictionary.md#metric-name) for a complete guide on metric naming suggestion.

     Consider including in the event's name the Redis slot to be able to count totals for a specific category.

     Example names: `users_creating_epics`, `users_triggering_security_scans`.

   - `category`: event category. Used for getting total counts for events in a category, for easier
     access to a group of events.
   - `redis_slot`: optional Redis slot. Default value: event name. Only event data that is stored in the same slot
     can be aggregated. Ensure keys are in the same slot. For example:
     `users_creating_epics` with `redis_slot: 'users'` builds Redis key
     `{users}_creating_epics-2020-34`. If `redis_slot` is not defined the Redis key will
     be `{users_creating_epics}-2020-34`.
     Recommended slots to use are: `users`, `projects`. This is the value we count.
   - `expiry`: expiry time in days. Default: 29 days for daily aggregation and 6 weeks for weekly
     aggregation.
   - `aggregation`: may be set to a `:daily` or `:weekly` key. Defines how counting data is stored in Redis.
     Aggregation on a `daily` basis does not pull more fine grained data.
   - `feature_flag`: optional `default_enabled: :yaml`. If no feature flag is set then the tracking is enabled. One feature flag can be used for multiple events. For details, see our [GitLab internal Feature flags](../feature_flags/index.md) documentation. The feature flags are owned by the group adding the event tracking.

1. Use one of the following methods to track the event:

   - In the controller using the `RedisTracking` module and the following format:

     ```ruby
     track_redis_hll_event(*controller_actions, name:, if: nil, &block)
     ```

     Arguments:

     - `controller_actions`: the controller actions to track.
     - `name`: the event name.
     - `if`: optional custom conditions. Uses the same format as Rails callbacks.
     - `&block`: optional block that computes and returns the `custom_id` that we want to track. This overrides the `visitor_id`.

     Example:

     ```ruby
     # controller
     class ProjectsController < Projects::ApplicationController
       include RedisTracking

       skip_before_action :authenticate_user!, only: :show
       track_redis_hll_event :index, :show, name: 'users_visiting_projects'

       def index
         render html: 'index'
       end

      def new
        render html: 'new'
      end

      def show
        render html: 'show'
      end
     end
     ```

   - In the API using the `increment_unique_values(event_name, values)` helper method.

     Arguments:

     - `event_name`: the event name.
     - `values`: the values counted. Can be one value or an array of values.

     Example:

     ```ruby
     get ':id/registry/repositories' do
       repositories = ContainerRepositoriesFinder.new(
         user: current_user, subject: user_group
       ).execute

       increment_unique_values('users_listing_repositories', current_user.id)

       present paginate(repositories), with: Entities::ContainerRegistry::Repository, tags: params[:tags], tags_count: params[:tags_count]
     end
     ```

   - Using `track_usage_event(event_name, values)` in services and GraphQL.

     Increment unique values count using Redis HLL, for a given event name.

     Examples:

     - [Track usage event for an incident in a service](https://gitlab.com/gitlab-org/gitlab/-/blob/v13.8.3-ee/app/services/issues/update_service.rb#L66)
     - [Track usage event for an incident in GraphQL](https://gitlab.com/gitlab-org/gitlab/-/blob/v13.8.3-ee/app/graphql/mutations/alert_management/update_alert_status.rb#L16)

     ```ruby
       track_usage_event(:incident_management_incident_created, current_user.id)
     ```

   - Using the [`UsageData` API](#usagedata-api).

     Increment unique users count using Redis HLL, for a given event name.

     API requests are protected by checking for a valid CSRF token.

     ```plaintext
     POST /usage_data/increment_unique_users
     ```

     | Attribute | Type | Required | Description |
     | :-------- | :--- | :------- | :---------- |
     | `event` | string | yes | The event name to track |

     Response:

     - `200` if the event was tracked, or if tracking failed for any reason.
     - `400 Bad request` if an event parameter is missing.
     - `401 Unauthorized` if the user is not authenticated.
     - `403 Forbidden` if an invalid CSRF token is provided.

   - Using the JavaScript/Vue API helper, which calls the [`UsageData` API](#usagedata-api).

     Example for an existing event already defined in [known events](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage_data_counters/known_events/):

     ```javascript
     import api from '~/api';

     api.trackRedisHllUserEvent('my_already_defined_event_name'),
     ```

1. Get event data using `Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(event_names:, start_date:, end_date:, context: '')`.

   Arguments:

   - `event_names`: the list of event names.
   - `start_date`: start date of the period for which we want to get event data.
   - `end_date`: end date of the period for which we want to get event data.
   - `context`: context of the event. Allowed values are `default`, `free`, `bronze`, `silver`, `gold`, `starter`, `premium`, `ultimate`.

1. Testing tracking and getting unique events

Trigger events in rails console by using `track_event` method

   ```ruby
   Gitlab::UsageDataCounters::HLLRedisCounter.track_event('users_viewing_compliance_audit_events', values: 1)
   Gitlab::UsageDataCounters::HLLRedisCounter.track_event('users_viewing_compliance_audit_events', values: [2, 3])
   ```

Next, get the unique events for the current week.

   ```ruby
   # Get unique events for metric for current_week
   Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(event_names: 'users_viewing_compliance_audit_events',
   start_date: Date.current.beginning_of_week, end_date: Date.current.next_week)
   ```

##### Recommendations

We have the following recommendations for [adding new events](#add-new-events):

- Event aggregation: weekly.
- Key expiry time:
  - Daily: 29 days.
  - Weekly: 42 days.
- When adding new metrics, use a [feature flag](../../operations/feature_flags.md) to control the impact.
- For feature flags triggered by another service, set `default_enabled: false`,
  - Events can be triggered using the `UsageData` API, which helps when there are > 10 events per change

##### Enable or disable Redis HLL tracking

Events are tracked behind optional [feature flags](../feature_flags/index.md) due to concerns for Redis performance and scalability.

For a full list of events and corresponding feature flags see, [known_events](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage_data_counters/known_events/) files.

To enable or disable tracking for specific event in <https://gitlab.com> or <https://about.staging.gitlab.com>, run commands such as the following to
[enable or disable the corresponding feature](../feature_flags/index.md).

```shell
/chatops run feature set <feature_name> true
/chatops run feature set <feature_name> false
```

We can also disable tracking completely by using the global flag:

```shell
/chatops run feature set redis_hll_tracking true
/chatops run feature set redis_hll_tracking false
```

##### Known events are added automatically in Service Data payload

Service Ping adds all events [`known_events/*.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage_data_counters/known_events) to Service Data generation under the `redis_hll_counters` key. This column is stored in [version-app as a JSON](https://gitlab.com/gitlab-services/version-gitlab-com/-/blob/master/db/schema.rb#L209).
For each event we add metrics for the weekly and monthly time frames, and totals for each where applicable:

- `#{event_name}_weekly`: Data for 7 days for daily [aggregation](#add-new-events) events and data for the last complete week for weekly [aggregation](#add-new-events) events.
- `#{event_name}_monthly`: Data for 28 days for daily [aggregation](#add-new-events) events and data for the last 4 complete weeks for weekly [aggregation](#add-new-events) events.

Redis HLL implementation calculates total metrics when both of these conditions are met:

- The category is manually included in [CATEGORIES_FOR_TOTALS](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage_data_counters/hll_redis_counter.rb#L21).
- There is more than one metric for the same category, aggregation, and Redis slot.

We add total unique counts for the weekly and monthly time frames where applicable:

- `#{category}_total_unique_counts_weekly`: Total unique counts for events in the same category for the last 7 days or the last complete week, if events are in the same Redis slot and we have more than one metric.
- `#{category}_total_unique_counts_monthly`: Total unique counts for events in same category for the last 28 days or the last 4 complete weeks, if events are in the same Redis slot and we have more than one metric.

Example of `redis_hll_counters` data:

```ruby
{:redis_hll_counters=>
  {"compliance"=>
    {"users_viewing_compliance_dashboard_weekly"=>0,
     "users_viewing_compliance_dashboard_monthly"=>0,
     "users_viewing_compliance_audit_events_weekly"=>0,
     "users_viewing_audit_events_monthly"=>0,
     "compliance_total_unique_counts_weekly"=>0,
     "compliance_total_unique_counts_monthly"=>0},
 "analytics"=>
    {"users_viewing_analytics_group_devops_adoption_weekly"=>0,
     "users_viewing_analytics_group_devops_adoption_monthly"=>0,
     "analytics_total_unique_counts_weekly"=>0,
     "analytics_total_unique_counts_monthly"=>0},
   "ide_edit"=>
    {"users_editing_by_web_ide_weekly"=>0,
     "users_editing_by_web_ide_monthly"=>0,
     "users_editing_by_sfe_weekly"=>0,
     "users_editing_by_sfe_monthly"=>0,
     "ide_edit_total_unique_counts_weekly"=>0,
     "ide_edit_total_unique_counts_monthly"=>0}
 }
```

Example:

```ruby
# Redis Counters
redis_usage_data(Gitlab::UsageDataCounters::WikiPageCounter)
redis_usage_data { ::Gitlab::UsageCounters::PodLogs.usage_totals[:total] }

# Define events in common.yml https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage_data_counters/known_events/common.yml

# Tracking events
Gitlab::UsageDataCounters::HLLRedisCounter.track_event('users_expanding_vulnerabilities', values: visitor_id)

# Get unique events for metric
redis_usage_data { Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(event_names: 'users_expanding_vulnerabilities', start_date: 28.days.ago, end_date: Date.current) }
```

### Alternative counters

Handles `StandardError` and fallbacks into -1 this way not all measures fail if we encounter one exception.
Mainly used for settings and configurations.

Method:

```ruby
alt_usage_data(value = nil, fallback: -1, &block)
```

Arguments:

- `value`: a simple static value in which case the value is simply returned.
- or a `block`: which is evaluated
- `fallback: -1`: the common value used for any metrics that are failing.

Example:

```ruby
alt_usage_data { Gitlab::VERSION }
alt_usage_data { Gitlab::CurrentSettings.uuid }
alt_usage_data(999)
```

### Add counters to build new metrics

When adding the results of two counters, use the `add` Service Data method that
handles fallback values and exceptions. It also generates a valid [SQL export](index.md#export-service-ping-sql-queries-and-definitions).

Example:

```ruby
add(User.active, User.bot)
```

### Prometheus queries

In those cases where operational metrics should be part of Service Ping, a database or Redis query is unlikely
to provide useful data. Instead, Prometheus might be more appropriate, because most GitLab architectural
components publish metrics to it that can be queried back, aggregated, and included as Service Data.

NOTE:
Prometheus as a data source for Service Ping is only available for single-node Omnibus installations
that are running the [bundled Prometheus](../../administration/monitoring/prometheus/index.md) instance.

To query Prometheus for metrics, a helper method is available to `yield` a fully configured
`PrometheusClient`, given it is available as per the note above:

```ruby
with_prometheus_client do |client|
  response = client.query('<your query>')
  ...
end
```

Refer to [the `PrometheusClient` definition](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/prometheus_client.rb)
for how to use its API to query for data.

### Fallback values for Service Ping

We return fallback values in these cases:

| Case                        | Value |
|-----------------------------|-------|
| Deprecated Metric           | -1000 |
| Timeouts, general failures  | -1    |
| Standard errors in counters | -2    |

## Test counters manually using your Rails console

```ruby
# count
Gitlab::UsageData.count(User.active)
Gitlab::UsageData.count(::Clusters::Cluster.aws_installed.enabled, :cluster_id)

# count distinct
Gitlab::UsageData.distinct_count(::Project, :creator_id)
Gitlab::UsageData.distinct_count(::Note.with_suggestions.where(time_period), :author_id, start: ::User.minimum(:id), finish: ::User.maximum(:id))
```

## Generate the SQL query

Your Rails console returns the generated SQL queries. For example:

```ruby
pry(main)> Gitlab::UsageData.count(User.active)
   (2.6ms)  SELECT "features"."key" FROM "features"
   (15.3ms)  SELECT MIN("users"."id") FROM "users" WHERE ("users"."state" IN ('active')) AND ("users"."user_type" IS NULL OR "users"."user_type" IN (6, 4))
   (2.4ms)  SELECT MAX("users"."id") FROM "users" WHERE ("users"."state" IN ('active')) AND ("users"."user_type" IS NULL OR "users"."user_type" IN (6, 4))
   (1.9ms)  SELECT COUNT("users"."id") FROM "users" WHERE ("users"."state" IN ('active')) AND ("users"."user_type" IS NULL OR "users"."user_type" IN (6, 4)) AND "users"."id" BETWEEN 1 AND 100000
```

## Optimize queries with `#database-lab`

`#database-lab` is a Slack channel that uses a production-sized environment to test your queries.
Paste the SQL query into `#database-lab` to see how the query performs at scale.

- GitLab.com's production database has a 15 second timeout.
- Any single query must stay below the [1 second execution time](../query_performance.md#timing-guidelines-for-queries) with cold caches.
- Add a specialized index on columns involved to reduce the execution time.

To understand the query's execution, we add the following information
to a merge request description:

- For counters that have a `time_period` test, we add information for both:
  - `time_period = {}` for all time periods.
  - `time_period = { created_at: 28.days.ago..Time.current }` for the last 28 days.
- Execution plan and query time before and after optimization.
- Query generated for the index and time.
- Migration output for up and down execution.

We also use `#database-lab` and [explain.depesz.com](https://explain.depesz.com/). For more details, see the [database review guide](../database_review.md#preparation-when-adding-or-modifying-queries).

### Optimization recommendations and examples

- Use specialized indexes. For examples, see these merge requests:
  - [Example 1](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/26871)
  - [Example 2](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/26445)
- Use defined `start` and `finish`, and simple queries.
  These values can be memoized and reused, as in this [example merge request](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/37155).
- Avoid joins and write the queries as simply as possible,
  as in this [example merge request](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/36316).
- Set a custom `batch_size` for `distinct_count`, as in this [example merge request](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/38000).

## Add the metric definition

See the [Metrics Dictionary guide](metrics_dictionary.md) for more information.

## Add the metric to the Versions Application

Check if the new metric must be added to the Versions Application. See the `usage_data` [schema](https://gitlab.com/gitlab-services/version-gitlab-com/-/blob/master/db/schema.rb#L147) and Service Data [parameters accepted](https://gitlab.com/gitlab-services/version-gitlab-com/-/blob/master/app/services/usage_ping.rb). Any metrics added under the `counts` key are saved in the `stats` column.

## Create a merge request

Create a merge request for the new Service Ping metric, and do the following:

- Add the `feature` label to the merge request. A metric is a user-facing change and is part of expanding the Service Ping feature.
- Add a changelog entry that complies with the [changelog entries guide](../changelog.md).
- Ask for a Product Intelligence review.
  On GitLab.com, we have DangerBot set up to monitor Product Intelligence related files and recommend a [Product Intelligence review](review_guidelines.md).

## Verify your metric

On GitLab.com, the Product Intelligence team regularly [monitors Service Ping](https://gitlab.com/groups/gitlab-org/-/epics/6000).
They may alert you that your metrics need further optimization to run quicker and with greater success.

The Service Ping JSON payload for GitLab.com is shared in the
[#g_product_intelligence](https://gitlab.slack.com/archives/CL3A7GFPF) Slack channel every week.

You may also use the [Service Ping QA dashboard](https://app.periscopedata.com/app/gitlab/632033/Usage-Ping-QA) to check how well your metric performs.
The dashboard allows filtering by GitLab version, by "Self-managed" and "SaaS", and shows you how many failures have occurred for each metric. Whenever you notice a high failure rate, you can re-optimize your metric.

Use [Metrics Dictionary](https://metrics.gitlab.com/) [copy query to clipboard feature](https://www.youtube.com/watch?v=n4o65ivta48&list=PL05JrBw4t0Krg3mbR6chU7pXtMt_es6Pb) to get a query ready to run in Sisense for a specific metric.

## Set up and test Service Ping locally

To set up Service Ping locally, you must:

1. [Set up local repositories](#set-up-local-repositories).
1. [Test local setup](#test-local-setup).
1. Optional. [Test Prometheus-based Service Ping](#test-prometheus-based-service-ping).

### Set up local repositories

1. Clone and start [GitLab](https://gitlab.com/gitlab-org/gitlab-development-kit).
1. Clone and start [Versions Application](https://gitlab.com/gitlab-services/version-gitlab-com).
   Make sure you run `docker-compose up` to start a PostgreSQL and Redis instance.
1. Point GitLab to the Versions Application endpoint instead of the default endpoint:
   1. Open [service_ping/submit_service.rb](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/services/service_ping/submit_service.rb#L5) locally and modify `STAGING_BASE_URL`.
   1. Set it to the local Versions Application URL: `http://localhost:3000/usage_data`.

### Test local setup

1. Using the `gitlab` Rails console, manually trigger Service Ping:

   ```ruby
   ServicePing::SubmitService.new.execute
   ```

1. Use the `versions` Rails console to check the Service Ping was successfully received,
   parsed, and stored in the Versions database:

   ```ruby
   UsageData.last
   ```

## Test Prometheus-based Service Ping

If the data submitted includes metrics [queried from Prometheus](#prometheus-queries)
you want to inspect and verify, you must:

- Ensure that a Prometheus server is running locally.
- Ensure the respective GitLab components are exporting metrics to the Prometheus server.

If you do not need to test data coming from Prometheus, no further action
is necessary. Service Ping should degrade gracefully in the absence of a running Prometheus server.

Three kinds of components may export data to Prometheus, and are included in Service Ping:

- [`node_exporter`](https://github.com/prometheus/node_exporter): Exports node metrics
  from the host machine.
- [`gitlab-exporter`](https://gitlab.com/gitlab-org/gitlab-exporter): Exports process metrics
  from various GitLab components.
- Other various GitLab services, such as Sidekiq and the Rails server, which export their own metrics.

### Test with an Omnibus container

This is the recommended approach to test Prometheus-based Service Ping.

To verify your change, build a new Omnibus image from your code branch using CI/CD, download the image,
and run a local container instance:

1. From your merge request, select the `qa` stage, then trigger the `package-and-qa` job. This job triggers an Omnibus
   build in a [downstream pipeline of the `omnibus-gitlab-mirror` project](https://gitlab.com/gitlab-org/build/omnibus-gitlab-mirror/-/pipelines).
1. In the downstream pipeline, wait for the `gitlab-docker` job to finish.
1. Open the job logs and locate the full container name including the version. It takes the following form: `registry.gitlab.com/gitlab-org/build/omnibus-gitlab-mirror/gitlab-ee:<VERSION>`.
1. On your local machine, make sure you are signed in to the GitLab Docker registry. You can find the instructions for this in
   [Authenticate to the GitLab Container Registry](../../user/packages/container_registry/index.md#authenticate-with-the-container-registry).
1. Once signed in, download the new image by using `docker pull registry.gitlab.com/gitlab-org/build/omnibus-gitlab-mirror/gitlab-ee:<VERSION>`
1. For more information about working with and running Omnibus GitLab containers in Docker, refer to [GitLab Docker images](https://docs.gitlab.com/omnibus/docker/README.html) in the Omnibus documentation.

### Test with GitLab development toolkits

This is the less recommended approach, because it comes with a number of difficulties when emulating a real GitLab deployment.

The [GDK](https://gitlab.com/gitlab-org/gitlab-development-kit) is not set up to run a Prometheus server or `node_exporter` alongside other GitLab components. If you would
like to do so, [Monitoring the GDK with Prometheus](https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/prometheus/index.md#monitoring-the-gdk-with-prometheus) is a good start.

The [GCK](https://gitlab.com/gitlab-org/gitlab-compose-kit) has limited support for testing Prometheus based Service Ping.
By default, it comes with a fully configured Prometheus service that is set up to scrape a number of components.
However, it has the following limitations:

- It does not run a `gitlab-exporter` instance, so several `process_*` metrics from services such as Gitaly may be missing.
- While it runs a `node_exporter`, `docker-compose` services emulate hosts, meaning that it normally reports itself as not associated
  with any of the other running services. That is not how node metrics are reported in a production setup, where `node_exporter`
  always runs as a process alongside other GitLab components on any given node. For Service Ping, none of the node data would therefore
  appear to be associated to any of the services running, because they all appear to be running on different hosts. To alleviate this problem, the `node_exporter` in GCK was arbitrarily "assigned" to the `web` service, meaning only for this service `node_*` metrics appears in Service Ping.

## Aggregated metrics

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/45979) in GitLab 13.6.

WARNING:
This feature is intended solely for internal GitLab use.

To add data for aggregated metrics to the Service Ping payload, add a corresponding definition to:

- [`config/metrics/aggregates/*.yaml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/config/metrics/aggregates/) for metrics available in the Community Edition.
- [`ee/config/metrics/aggregates/*.yaml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/config/metrics/aggregates/) for metrics available in the Enterprise Edition.

Each aggregate definition includes following parts:

- `name`: Unique name under which the aggregate metric is added to the Service Ping payload.
- `operator`: Operator that defines how the aggregated metric data is counted. Available operators are:
  - `OR`: Removes duplicates and counts all entries that triggered any of listed events.
  - `AND`: Removes duplicates and counts all elements that were observed triggering all of following events.
- `time_frame`: One or more valid time frames. Use these to limit the data included in aggregated metric to events within a specific date-range. Valid time frames are:
  - `7d`: Last seven days of data.
  - `28d`: Last twenty eight days of data.
  - `all`: All historical data, only available for `database` sourced aggregated metrics.
- `source`: Data source used to collect all events data included in aggregated metric. Valid data sources are:
  - [`database`](#database-sourced-aggregated-metrics)
  - [`redis`](#redis-sourced-aggregated-metrics)
- `events`: list of events names to aggregate into metric. All events in this list must
  relay on the same data source. Additional data source requirements are described in the
  [Database sourced aggregated metrics](#database-sourced-aggregated-metrics) and
  [Redis sourced aggregated metrics](#redis-sourced-aggregated-metrics) sections.
- `feature_flag`: Name of [development feature flag](../feature_flags/index.md#development-type)
  that is checked before metrics aggregation is performed. Corresponding feature flag
  should have `default_enabled` attribute set to `false`. The `feature_flag` attribute
  is optional and can be omitted. When `feature_flag` is missing, no feature flag is checked.

Example aggregated metric entries:

```yaml
- name: example_metrics_union
  operator: OR
  events:
    - 'users_expanding_secure_security_report'
    - 'users_expanding_testing_code_quality_report'
    - 'users_expanding_testing_accessibility_report'
  source: redis
  time_frame:
    - 7d
    - 28d
- name: example_metrics_intersection
  operator: AND
  source: database
  time_frame:
    - 28d
    - all
  events:
    - 'dependency_scanning_pipeline_all_time'
    - 'container_scanning_pipeline_all_time'
  feature_flag: example_aggregated_metric
```

Aggregated metrics collected in `7d` and `28d` time frames are added into Service Ping payload under the `aggregated_metrics` sub-key in the `counts_weekly` and `counts_monthly` top level keys.

```ruby
{
  :counts_monthly => {
    :deployments => 1003,
    :successful_deployments => 78,
    :failed_deployments => 275,
    :packages => 155,
    :personal_snippets => 2106,
    :project_snippets => 407,
    :aggregated_metrics => {
      :example_metrics_union => 7,
      :example_metrics_intersection => 2
    },
    :snippets => 2513
  }
}
```

Aggregated metrics for `all` time frame are present in the `count` top level key, with the `aggregate_` prefix added to their name.

For example:

`example_metrics_intersection`

Becomes:

`counts.aggregate_example_metrics_intersection`

```ruby
{
  :counts => {
    :deployments => 11003,
    :successful_deployments => 178,
    :failed_deployments => 1275,
    :aggregate_example_metrics_intersection => 12
  }
}
```

### Redis sourced aggregated metrics

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/45979) in GitLab 13.6.

To declare the aggregate of events collected with [Redis HLL Counters](#redis-hll-counters),
you must fulfill the following requirements:

1. All events listed at `events` attribute must come from
   [`known_events/*.yml`](#known-events-are-added-automatically-in-service-data-payload) files.
1. All events listed at `events` attribute must have the same `redis_slot` attribute.
1. All events listed at `events` attribute must have the same `aggregation` attribute.
1. `time_frame` does not include `all` value, which is unavailable for Redis sourced aggregated metrics.

### Database sourced aggregated metrics

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/52784) in GitLab 13.9.
> - It's [deployed behind a feature flag](../../user/feature_flags.md), disabled by default.
> - It's enabled on GitLab.com.

To declare an aggregate of metrics based on events collected from database, follow
these steps:

1. [Persist the metrics for aggregation](#persist-metrics-for-aggregation).
1. [Add new aggregated metric definition](#add-new-aggregated-metric-definition).

#### Persist metrics for aggregation

Only metrics calculated with [Estimated Batch Counters](#estimated-batch-counters)
can be persisted for database sourced aggregated metrics. To persist a metric,
inject a Ruby block into the
[estimate_batch_distinct_count](#estimate_batch_distinct_count-method) method.
This block should invoke the
`Gitlab::Usage::Metrics::Aggregates::Sources::PostgresHll.save_aggregated_metrics`
[method](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/usage/metrics/aggregates/sources/postgres_hll.rb#L21),
which stores `estimate_batch_distinct_count` results for future use in aggregated metrics.

The `Gitlab::Usage::Metrics::Aggregates::Sources::PostgresHll.save_aggregated_metrics`
method accepts the following arguments:

- `metric_name`: The name of metric to use for aggregations. Should be the same
  as the key under which the metric is added into Service Ping.
- `recorded_at_timestamp`: The timestamp representing the moment when a given
  Service Ping payload was collected. You should use the convenience method `recorded_at`
  to fill `recorded_at_timestamp` argument, like this: `recorded_at_timestamp: recorded_at`
- `time_period`: The time period used to build the `relation` argument passed into
  `estimate_batch_distinct_count`. To collect the metric with all available historical
  data, set a `nil` value as time period: `time_period: nil`.
- `data`: HyperLogLog buckets structure representing unique entries in `relation`.
  The `estimate_batch_distinct_count` method always passes the correct argument
  into the block, so `data` argument must always have a value equal to block argument,
  like this: `data: result`

Example metrics persistence:

```ruby
class UsageData
  def count_secure_pipelines(time_period)
    ...
    relation = ::Security::Scan.by_scan_types(scan_type).where(time_period)

    pipelines_with_secure_jobs['dependency_scanning_pipeline'] = estimate_batch_distinct_count(relation, :pipeline_id, batch_size: 1000, start: start_id, finish: finish_id) do |result|
      ::Gitlab::Usage::Metrics::Aggregates::Sources::PostgresHll
        .save_aggregated_metrics(metric_name: 'dependency_scanning_pipeline', recorded_at_timestamp: recorded_at, time_period: time_period, data: result)
    end
  end
end
```

#### Add new aggregated metric definition

After all metrics are persisted, you can add an aggregated metric definition at
[`aggregated_metrics/`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/config/metrics/aggregates/).

To declare the aggregate of metrics collected with [Estimated Batch Counters](#estimated-batch-counters),
you must fulfill the following requirements:

- Metrics names listed in the `events:` attribute, have to use the same names you passed in the `metric_name` argument while persisting metrics in previous step.
- Every metric listed in the `events:` attribute, has to be persisted for **every** selected `time_frame:` value.

Example definition:

```yaml
- name: example_metrics_intersection_database_sourced
  operator: AND
  source: database
  events:
    - 'dependency_scanning_pipeline'
    - 'container_scanning_pipeline'
  time_frame:
    - 28d
    - all
```
