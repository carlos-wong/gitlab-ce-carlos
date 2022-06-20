---
stage: Enablement
group: Database
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Avoiding downtime in migrations

When working with a database certain operations may require downtime. Since we
cannot have downtime in migrations we need to use a set of steps to get the
same end result without downtime. This guide describes various operations that
may appear to need downtime, their impact, and how to perform them without
requiring downtime.

## Dropping Columns

Removing columns is tricky because running GitLab processes may still be using
the columns. To work around this safely, you will need three steps in three releases:

1. Ignoring the column (release M)
1. Dropping the column (release M+1)
1. Removing the ignore rule (release M+2)

The reason we spread this out across three releases is that dropping a column is
a destructive operation that can't be rolled back easily.

Following this procedure helps us to make sure there are no deployments to GitLab.com
and upgrade processes for self-managed installations that lump together any of these steps.

### Step 1: Ignoring the column (release M)

The first step is to ignore the column in the application code. This is
necessary because Rails caches the columns and re-uses this cache in various
places. This can be done by defining the columns to ignore. For example, to ignore
`updated_at` in the User model you'd use the following:

```ruby
class User < ApplicationRecord
  include IgnorableColumns
  ignore_column :updated_at, remove_with: '12.7', remove_after: '2020-01-22'
end
```

Multiple columns can be ignored, too:

```ruby
ignore_columns %i[updated_at created_at], remove_with: '12.7', remove_after: '2020-01-22'
```

If the model exists in CE and EE, the column has to be ignored in the CE model. If the
model only exists in EE, then it has to be added there.

We require indication of when it is safe to remove the column ignore with:

- `remove_with`: set to a GitLab release typically two releases (M+2) after adding the
  column ignore.
- `remove_after`: set to a date after which we consider it safe to remove the column
  ignore, typically after the M+1 release date, during the M+2 development cycle.

This information allows us to reason better about column ignores and makes sure we
don't remove column ignores too early for both regular releases and deployments to GitLab.com. For
example, this avoids a situation where we deploy a bulk of changes that include both changes
to ignore the column and subsequently remove the column ignore (which would result in a downtime).

In this example, the change to ignore the column went into release 12.5.

### Step 2: Dropping the column (release M+1)

Continuing our example, dropping the column goes into a _post-deployment_ migration in release 12.6:

```ruby
 remove_column :user, :updated_at
```

### Step 3: Removing the ignore rule (release M+2)

With the next release, in this example 12.7, we set up another merge request to remove the ignore rule.
This removes the `ignore_column` line and - if not needed anymore - also the inclusion of `IgnoreableColumns`.

This should only get merged with the release indicated with `remove_with` and once
the `remove_after` date has passed.

## Renaming Columns

Renaming columns the normal way requires downtime as an application may continue
using the old column name during/after a database migration. To rename a column
without requiring downtime we need two migrations: a regular migration, and a
post-deployment migration. Both these migration can go in the same release.

### Step 1: Add The Regular Migration

First we need to create the regular migration. This migration should use
`Gitlab::Database::MigrationHelpers#rename_column_concurrently` to perform the
renaming. For example

```ruby
# A regular migration in db/migrate
class RenameUsersUpdatedAtToUpdatedAtTimestamp < Gitlab::Database::Migration[1.0]
  disable_ddl_transaction!

  def up
    rename_column_concurrently :users, :updated_at, :updated_at_timestamp
  end

  def down
    undo_rename_column_concurrently :users, :updated_at, :updated_at_timestamp
  end
end
```

This will take care of renaming the column, ensuring data stays in sync, and
copying over indexes and foreign keys.

If a column contains one or more indexes that don't contain the name of the
original column, the previously described procedure will fail. In that case,
you'll first need to rename these indexes.

### Step 2: Add A Post-Deployment Migration

The renaming procedure requires some cleaning up in a post-deployment migration.
We can perform this cleanup using
`Gitlab::Database::MigrationHelpers#cleanup_concurrent_column_rename`:

```ruby
# A post-deployment migration in db/post_migrate
class CleanupUsersUpdatedAtRename < Gitlab::Database::Migration[1.0]
  disable_ddl_transaction!

  def up
    cleanup_concurrent_column_rename :users, :updated_at, :updated_at_timestamp
  end

  def down
    undo_cleanup_concurrent_column_rename :users, :updated_at, :updated_at_timestamp
  end
end
```

If you're renaming a [large table](https://gitlab.com/gitlab-org/gitlab/-/blob/master/rubocop/rubocop-migrations.yml#L3), please carefully consider the state when the first migration has run but the second cleanup migration hasn't been run yet.
With [Canary](https://gitlab.com/gitlab-com/gl-infra/readiness/-/tree/master/library/canary/) it is possible that the system runs in this state for a significant amount of time.

## Changing Column Constraints

Adding or removing a `NOT NULL` clause (or another constraint) can typically be
done without requiring downtime. However, this does require that any application
changes are deployed _first_. Thus, changing the constraints of a column should
happen in a post-deployment migration.

Avoid using `change_column` as it produces an inefficient query because it re-defines
the whole column type.

You can check the following guides for each specific use case:

- [Adding foreign-key constraints](../migration_style_guide.md#adding-foreign-key-constraints)
- [Adding `NOT NULL` constraints](not_null_constraints.md)
- [Adding limits to text columns](strings_and_the_text_data_type.md)

## Changing Column Types

Changing the type of a column can be done using
`Gitlab::Database::MigrationHelpers#change_column_type_concurrently`. This
method works similarly to `rename_column_concurrently`. For example, let's say
we want to change the type of `users.username` from `string` to `text`.

### Step 1: Create A Regular Migration

A regular migration is used to create a new column with a temporary name along
with setting up some triggers to keep data in sync. Such a migration would look
as follows:

```ruby
# A regular migration in db/migrate
class ChangeUsersUsernameStringToText < Gitlab::Database::Migration[1.0]
  disable_ddl_transaction!

  def up
    change_column_type_concurrently :users, :username, :text
  end

  def down
    undo_change_column_type_concurrently :users, :username
  end
end
```

### Step 2: Create A Post Deployment Migration

Next we need to clean up our changes using a post-deployment migration:

```ruby
# A post-deployment migration in db/post_migrate
class ChangeUsersUsernameStringToTextCleanup < Gitlab::Database::Migration[1.0]
  disable_ddl_transaction!

  def up
    cleanup_concurrent_column_type_change :users, :username
  end

  def down
    undo_cleanup_concurrent_column_type_change :users, :username, :string
  end
end
```

And that's it, we're done!

### Casting data to a new type

Some type changes require casting data to a new type. For example when changing from `text` to `jsonb`.
In this case, use the `type_cast_function` option.
Make sure there is no bad data and the cast will always succeed. You can also provide a custom function that handles
casting errors.

Example migration:

```ruby
  def up
    change_column_type_concurrently :users, :settings, :jsonb, type_cast_function: 'jsonb'
  end
```

## Changing The Schema For Large Tables

While `change_column_type_concurrently` and `rename_column_concurrently` can be
used for changing the schema of a table without downtime, it doesn't work very
well for large tables. Because all of the work happens in sequence the migration
can take a very long time to complete, preventing a deployment from proceeding.
They can also produce a lot of pressure on the database due to it rapidly
updating many rows in sequence.

To reduce database pressure you should instead use a background migration
when migrating a column in a large table (for example, `issues`). This will
spread the work / load over a longer time period, without slowing down deployments.

For more information, see [the documentation on cleaning up background
migrations](background_migrations.md#cleaning-up).

## Adding Indexes

Adding indexes does not require downtime when `add_concurrent_index`
is used.

See also [Migration Style Guide](../migration_style_guide.md#adding-indexes)
for more information.

## Dropping Indexes

Dropping an index does not require downtime.

## Adding Tables

This operation is safe as there's no code using the table just yet.

## Dropping Tables

Dropping tables can be done safely using a post-deployment migration, but only
if the application no longer uses the table.

## Renaming Tables

Renaming tables requires downtime as an application may continue
using the old table name during/after a database migration.

If the table and the ActiveRecord model is not in use yet, removing the old
table and creating a new one is the preferred way to "rename" the table.

Renaming a table is possible without downtime by following our multi-release
[rename table process](rename_database_tables.md#rename-table-without-downtime).

## Adding Foreign Keys

Adding foreign keys usually works in 3 steps:

1. Start a transaction
1. Run `ALTER TABLE` to add the constraint(s)
1. Check all existing data

Because `ALTER TABLE` typically acquires an exclusive lock until the end of a
transaction this means this approach would require downtime.

GitLab allows you to work around this by using
`Gitlab::Database::MigrationHelpers#add_concurrent_foreign_key`. This method
ensures that no downtime is needed.

## Removing Foreign Keys

This operation does not require downtime.

## Migrating `integer` primary keys to `bigint`

To [prevent the overflow risk](https://gitlab.com/groups/gitlab-org/-/epics/4785) for some tables
with `integer` primary key (PK), we have to migrate their PK to `bigint`. The process to do this
without downtime and causing too much load on the database is described below.

### Initialize the conversion and start migrating existing data (release N)

To start the process, add a regular migration to create the new `bigint` columns. Use the provided
`initialize_conversion_of_integer_to_bigint` helper. The helper also creates a database trigger
to keep in sync both columns for any new records ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/migrate/20210608072312_initialize_conversion_of_ci_stages_to_bigint.rb)):

```ruby
class InitializeConversionOfCiStagesToBigint < ActiveRecord::Migration[6.1]
  include Gitlab::Database::MigrationHelpers

  TABLE = :ci_stages
  COLUMNS = %i(id)

  def up
    initialize_conversion_of_integer_to_bigint(TABLE, COLUMNS)
  end

  def down
    revert_initialize_conversion_of_integer_to_bigint(TABLE, COLUMNS)
  end
end
```

Ignore the new `bigint` columns:

```ruby
module Ci
  class Stage < Ci::ApplicationRecord
    include IgnorableColumns
    ignore_column :id_convert_to_bigint, remove_with: '14.2', remove_after: '2021-08-22'
  end
```

To migrate existing data, we introduced new type of _batched background migrations_.
Unlike the classic background migrations, built on top of Sidekiq, batched background migrations
don't have to enqueue and schedule all the background jobs at the beginning.
They also have other advantages, like automatic tuning of the batch size, better progress visibility,
and collecting metrics. To start the process, use the provided `backfill_conversion_of_integer_to_bigint`
helper ([example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/migrate/20210608072346_backfill_ci_stages_for_bigint_conversion.rb)):

```ruby
class BackfillCiStagesForBigintConversion < ActiveRecord::Migration[6.1]
  include Gitlab::Database::MigrationHelpers

  TABLE = :ci_stages
  COLUMNS = %i(id)

  def up
    backfill_conversion_of_integer_to_bigint(TABLE, COLUMNS)
  end

  def down
    revert_backfill_conversion_of_integer_to_bigint(TABLE, COLUMNS)
  end
end
```

### Monitor the background migration

Check how the migration is performing while it's running. Multiple ways to do this are described below.

#### High-level status of batched background migrations

See how to [check the status of batched background migrations](../../update/index.md#checking-for-background-migrations-before-upgrading).

#### Query the database

We can query the related database tables directly. Requires access to read-only replica.
Example queries:

```sql
-- Get details for batched background migration for given table
SELECT * FROM batched_background_migrations WHERE table_name = 'namespaces'\gx

-- Get count of batched background migration jobs by status for given table
SELECT
  batched_background_migrations.id, batched_background_migration_jobs.status, COUNT(*)
FROM
  batched_background_migrations
  JOIN batched_background_migration_jobs ON batched_background_migrations.id = batched_background_migration_jobs.batched_background_migration_id
WHERE
  table_name = 'namespaces'
GROUP BY
  batched_background_migrations.id, batched_background_migration_jobs.status;

-- Batched background migration progress for given table (based on estimated total number of tuples)
SELECT
  m.table_name,
  LEAST(100 * sum(j.batch_size) / pg_class.reltuples, 100) AS percentage_complete
FROM
  batched_background_migrations m
  JOIN batched_background_migration_jobs j ON j.batched_background_migration_id = m.id
  JOIN pg_class ON pg_class.relname = m.table_name
WHERE
  j.status = 3 AND m.table_name = 'namespaces'
GROUP BY m.id, pg_class.reltuples;
```

#### Sidekiq logs

We can also use the Sidekiq logs to monitor the worker that executes the batched background
migrations:

1. Sign in to [Kibana](https://log.gprd.gitlab.net) with a `@gitlab.com` email address.
1. Change the index pattern to `pubsub-sidekiq-inf-gprd*`.
1. Add filter for `json.queue: cronjob:database_batched_background_migration`.

#### PostgreSQL slow queries log

Slow queries log keeps track of low queries that took above 1 second to execute. To see them
for batched background migration:

1. Sign in to [Kibana](https://log.gprd.gitlab.net) with a `@gitlab.com` email address.
1. Change the index pattern to `pubsub-postgres-inf-gprd*`.
1. Add filter for `json.endpoint_id.keyword: Database::BatchedBackgroundMigrationWorker`.
1. Optional. To see only updates, add a filter for `json.command_tag.keyword: UPDATE`.
1. Optional. To see only failed statements, add a filter for `json.error_severity.keyword: ERROR`.
1. Optional. Add a filter by table name.

#### Grafana dashboards

To monitor the health of the database, use these additional metrics:

- [PostgreSQL Tuple Statistics](https://dashboards.gitlab.net/d/000000167/postgresql-tuple-statistics?orgId=1&refresh=1m): if you see high rate of updates for the tables being actively converted, or increasing percentage of dead tuples for this table, it might mean that autovacuum cannot keep up.
- [PostgreSQL Overview](https://dashboards.gitlab.net/d/000000144/postgresql-overview?orgId=1): if you see high system usage or transactions per second (TPS) on the primary database server, it might mean that the migration is causing problems.

### Prometheus metrics

Number of [metrics](https://gitlab.com/gitlab-org/gitlab/-/blob/294a92484ce4611f660439aa48eee4dfec2230b5/lib/gitlab/database/background_migration/batched_migration_wrapper.rb#L90-128)
for each batched background migration are published to Prometheus. These metrics can be searched for and
visualized in Thanos ([see an example](https://thanos-query.ops.gitlab.net/graph?g0.expr=sum%20(rate(batched_migration_job_updated_tuples_total%7Benv%3D%22gprd%22%7D%5B5m%5D))%20by%20(migration_id)%20&g0.tab=0&g0.stacked=0&g0.range_input=3d&g0.max_source_resolution=0s&g0.deduplicate=1&g0.partial_response=0&g0.store_matches=%5B%5D&g0.end_input=2021-06-13%2012%3A18%3A24&g0.moment_input=2021-06-13%2012%3A18%3A24)).

### Swap the columns (release N + 1)

After the background is completed and the new `bigint` columns are populated for all records, we can
swap the columns. Swapping is done with post-deployment migration. The exact process depends on the
table being converted, but in general it's done in the following steps:

1. Using the provided `ensure_batched_background_migration_is_finished` helper, make sure the batched
migration has finished ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L13-18)).
If the migration has not completed, the subsequent steps fail anyway. By checking in advance we
aim to have more helpful error message.
1. Create indexes using the `bigint` columns that match the existing indexes using the `integer`
column ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L28-34)).
1. Create foreign keys (FK) using the `bigint` columns that match the existing FKs using the
`integer` column. Do this both for FK referencing other tables, and FKs that reference the table
that is being migrated ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L36-43)).
1. Inside a transaction, swap the columns:
    1. Lock the tables involved. To reduce the chance of hitting a deadlock, we recommended to do this in parent to child order ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L47)).
    1. Rename the columns to swap names ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L49-54))
    1. Reset the trigger function ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L56-57)).
    1. Swap the defaults ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L59-62)).
    1. Swap the PK constraint (if any) ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L64-68)).
    1. Remove old indexes and rename new ones ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L70-72)).
    1. Remove old FKs (if still present) and rename new ones ([see an example](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb#L74)).

See example [merge request](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/66088), and [migration](https://gitlab.com/gitlab-org/gitlab/-/blob/41fbe34a4725a4e357a83fda66afb382828767b2/db/post_migrate/20210707210916_finalize_ci_stages_bigint_conversion.rb).

### Remove the trigger and old `integer` columns (release N + 2)

Using post-deployment migration and the provided `cleanup_conversion_of_integer_to_bigint` helper,
drop the database trigger and the old `integer` columns ([see an example](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/69714)).

### Remove ignore rules (release N + 3)

In the next release after the columns were dropped, remove the ignore rules as we do not need them
anymore ([see an example](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/71161)).

## Data migrations

Data migrations can be tricky. The usual approach to migrate data is to take a 3
step approach:

1. Migrate the initial batch of data
1. Deploy the application code
1. Migrate any remaining data

Usually this works, but not always. For example, if a field's format is to be
changed from JSON to something else we have a bit of a problem. If we were to
change existing data before deploying application code we'll most likely run
into errors. On the other hand, if we were to migrate after deploying the
application code we could run into the same problems.

If you merely need to correct some invalid data, then a post-deployment
migration is usually enough. If you need to change the format of data (for example, from
JSON to something else) it's typically best to add a new column for the new data
format, and have the application use that. In such a case the procedure would
be:

1. Add a new column in the new format
1. Copy over existing data to this new column
1. Deploy the application code
1. In a post-deployment migration, copy over any remaining data

In general there is no one-size-fits-all solution, therefore it's best to
discuss these kind of migrations in a merge request to make sure they are
implemented in the best way possible.
