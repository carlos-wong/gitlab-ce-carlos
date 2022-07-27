---
type: reference, dev
stage: Data Stores
group: Database
info: "See the Technical Writers assigned to Development Guidelines: https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments-to-development-guidelines"
---

# Batched background migrations

Batched Background Migrations should be used to perform data migrations whenever a
migration exceeds [the time limits](../migration_style_guide.md#how-long-a-migration-should-take)
in our guidelines. For example, you can use batched background
migrations to migrate data that's stored in a single JSON column
to a separate table instead.

## When to use batched background migrations

Use a batched background migration when you migrate _data_ in tables containing
so many rows that the process would exceed
[the time limits in our guidelines](../migration_style_guide.md#how-long-a-migration-should-take)
if performed using a regular Rails migration.

- Batched background migrations should be used when migrating data in
  [high-traffic tables](../migration_style_guide.md#high-traffic-tables).
- Batched background migrations may also be used when executing numerous single-row queries
  for every item on a large dataset. Typically, for single-record patterns, runtime is
  largely dependent on the size of the dataset. Split the dataset accordingly,
  and put it into background migrations.
- Don't use batched background migrations to perform schema migrations.

Background migrations can help when:

- Migrating events from one table to multiple separate tables.
- Populating one column based on JSON stored in another column.
- Migrating data that depends on the output of external services. (For example, an API.)

NOTE:
If the batched background migration is part of an important upgrade, it must be announced
in the release post. Discuss with your Project Manager if you're unsure if the migration falls
into this category.

## Isolation

Batched background migrations must be isolated and can not use application code (for example,
models defined in `app/models` except the `ApplicationRecord` classes).
Because these migrations can take a long time to run, it's possible
for new versions to deploy while the migrations are still running.

## Accessing data for multiple databases

Background Migration contrary to regular migrations does have access to multiple databases
and can be used to efficiently access and update data across them. To properly indicate
a database to be used it is desired to create ActiveRecord model inline the migration code.
Such model should use a correct [`ApplicationRecord`](multiple_databases.md#gitlab-schema)
depending on which database the table is located. As such usage of `ActiveRecord::Base`
is disallowed as it does not describe a explicitly database to be used to access given table.

```ruby
# good
class Gitlab::BackgroundMigration::ExtractIntegrationsUrl
  class Project < ::ApplicationRecord
    self.table_name = 'projects'
  end

  class Build < ::Ci::ApplicationRecord
    self.table_name = 'ci_builds'
  end
end

# bad
class Gitlab::BackgroundMigration::ExtractIntegrationsUrl
  class Project < ActiveRecord::Base
    self.table_name = 'projects'
  end

  class Build < ActiveRecord::Base
    self.table_name = 'ci_builds'
  end
end
```

Similarly the usage of `ActiveRecord::Base.connection` is disallowed and needs to be
replaced preferably with the usage of model connection.

```ruby
# good
Project.connection.execute("SELECT * FROM projects")

# acceptable
ApplicationRecord.connection.execute("SELECT * FROM projects")

# bad
ActiveRecord::Base.connection.execute("SELECT * FROM projects")
```

## Idempotence

Batched background migrations are executed in a context of a Sidekiq process.
The usual Sidekiq rules apply, especially the rule that jobs should be small
and idempotent. Make sure that in case that your migration job is retried, data
integrity is guaranteed.

See [Sidekiq best practices guidelines](https://github.com/mperham/sidekiq/wiki/Best-Practices)
for more details.

## Batched background migrations for EE-only features

All the background migration classes for EE-only features should be present in GitLab CE.
For this purpose, create an empty class for GitLab CE, and extend it for GitLab EE
as explained in the guidelines for
[implementing Enterprise Edition features](../ee_features.md#code-in-libgitlabbackground_migration).

Batched Background migrations are simple classes that define a `perform` method. A
Sidekiq worker then executes such a class, passing any arguments to it. All
migration classes must be defined in the namespace
`Gitlab::BackgroundMigration`. Place the files in the directory
`lib/gitlab/background_migration/`.

## Queueing

Queueing a batched background migration should be done in a post-deployment
migration. Use this `queue_batched_background_migration` example, queueing the
migration to be executed in batches. Replace the class name and arguments with the values
from your migration:

```ruby
queue_batched_background_migration(
  JOB_CLASS_NAME,
  TABLE_NAME,
  JOB_ARGUMENTS,
  JOB_INTERVAL
  )
```

Make sure the newly-created data is either migrated, or
saved in both the old and new version upon creation. Removals in
turn can be handled by defining foreign keys with cascading deletes.

### Requeuing batched background migrations

If one of the batched background migrations contains a bug that is fixed in a patch
release, you must requeue the batched background migration so the migration
repeats on systems that already performed the initial migration.

When you requeue the batched background migration, turn the original
queuing into a no-op by clearing up the `#up` and `#down` methods of the
migration performing the requeuing. Otherwise, the batched background migration is
queued multiple times on systems that are upgrading multiple patch releases at
once.

When you start the second post-deployment migration, delete the
previously batched migration with the provided code:

```ruby
delete_batched_background_migration(MIGRATION_NAME, TABLE_NAME, COLUMN, JOB_ARGUMENTS)
```

## Cleaning up

NOTE:
Cleaning up any remaining background migrations must be done in either a major
or minor release. You must not do this in a patch release.

Because background migrations can take a long time, you can't immediately clean
things up after queueing them. For example, you can't drop a column used in the
migration process, as jobs would fail. You must add a separate _post-deployment_
migration in a future release that finishes any remaining
jobs before cleaning things up. (For example, removing a column.)

To migrate the data from column `foo` (containing a big JSON blob) to column `bar`
(containing a string), you would:

1. Release A:
   1. Create a migration class that performs the migration for a row with a given ID.
   1. Update new rows using one of these techniques:
      - Create a new trigger for simple copy operations that don't need application logic.
      - Handle this operation in the model/service as the records are created or updated.
      - Create a new custom background job that updates the records.
   1. Queue the batched background migration for all existing rows in a post-deployment migration.
1. Release B:
   1. Add a post-deployment migration that checks if the batched background migration is completed.
   1. Deploy code so that the application starts using the new column and stops to update new records.
   1. Remove the old column.

Bump to the [import/export version](../../user/project/settings/import_export.md) may
be required, if importing a project from a prior version of GitLab requires the
data to be in the new format.

## Example

The `routes` table has a `source_type` field that's used for a polymorphic relationship.
As part of a database redesign, we're removing the polymorphic relationship. One step of
the work is migrating data from the `source_id` column into a new singular foreign key.
Because we intend to delete old rows later, there's no need to update them as part of the
background migration.

1. Start by defining our migration class, which should inherit
   from `Gitlab::BackgroundMigration::BatchedMigrationJob`:

   ```ruby
   class Gitlab::BackgroundMigration::BackfillRouteNamespaceId < BatchedMigrationJob
     # For illustration purposes, if we were to use a local model we could
     # define it like below, using an `ApplicationRecord` as the base class
     # class Route < ::ApplicationRecord
     #   self.table_name = 'routes'
     # end

     def perform
       each_sub_batch(
         operation_name: :update_all,
         batching_scope: -> (relation) { relation.where("source_type <> 'UnusedType'") }
       ) do |sub_batch|
         sub_batch.update_all('namespace_id = source_id')
       end
     end
   end
   ```

   NOTE:
   Job classes must be subclasses of `BatchedMigrationJob` to be
   correctly handled by the batched migration framework. Any subclass of
   `BatchedMigrationJob` is initialized with necessary arguments to
   execute the batch, as well as a connection to the tracking database.
   Additional `job_arguments` set on the migration are passed to the
   job's `perform` method.

1. Add a new trigger to the database to update newly created and updated routes,
   similar to this example:

   ```ruby
   execute(<<~SQL)
     CREATE OR REPLACE FUNCTION example() RETURNS trigger
     LANGUAGE plpgsql
     AS $$
     BEGIN
       NEW."namespace_id" = NEW."source_id"
       RETURN NEW;
     END;
     $$;
   SQL
   ```

1. Create a post-deployment migration that queues the migration for existing data:

   ```ruby
   class QueueBackfillRoutesNamespaceId < Gitlab::Database::Migration[2.0]
     MIGRATION = 'BackfillRouteNamespaceId'
     DELAY_INTERVAL = 2.minutes

     restrict_gitlab_migration gitlab_schema: :gitlab_main

     def up
       queue_batched_background_migration(
         MIGRATION,
         :routes,
         :id,
         job_interval: DELAY_INTERVAL
       )
     end

     def down
       delete_batched_background_migration(MIGRATION, :routes, :id, [])
     end
   end
   ```

   NOTE:
   When queuing a batched background migration, you need to restrict
   the schema to the database where you make the actual changes.
   In this case, we are updating `routes` records, so we set
   `restrict_gitlab_migration gitlab_schema: :gitlab_main`. If, however,
   you need to perform a CI data migration, you would set
   `restrict_gitlab_migration gitlab_schema: :gitlab_ci`.

   After deployment, our application:
   - Continues using the data as before.
   - Ensures that both existing and new data are migrated.

1. In the next release, remove the trigger. We must also add a new post-deployment migration
   that checks that the batched background migration is completed. For example:

   ```ruby
   class FinalizeBackfillRouteNamespaceId < Gitlab::Database::Migration[2.0]
     MIGRATION = 'BackfillRouteNamespaceId'
     disable_ddl_transaction!

     restrict_gitlab_migration gitlab_schema: :gitlab_main

     def up
       ensure_batched_background_migration_is_finished(
         job_class_name: MIGRATION,
         table_name: :routes,
         column_name: :id,
         job_arguments: [],
         finalize: true
       )
     end

     def down
       # no-op
     end
   end
   ```

   NOTE:
   If the batched background migration is not finished, the system will
   execute the batched background migration inline. If you don't want
   to see this behavior, you need to pass `finalize: false`.

   If the application does not depend on the data being 100% migrated (for
   instance, the data is advisory, and not mission-critical), then you can skip this
   final step. This step confirms that the migration is completed, and all of the rows were migrated.

After the batched migration is completed, you can safely depend on the
data in `routes.namespace_id` being populated.

### Batching over non-distinct columns

The default batching strategy provides an efficient way to iterate over primary key columns.
However, if you need to iterate over columns where values are not unique, you must use a
different batching strategy.

The `LooseIndexScanBatchingStrategy` batching strategy uses a special version of [`EachBatch`](../iterating_tables_in_batches.md#loose-index-scan-with-distinct_each_batch)
to provide efficient and stable iteration over the distinct column values.

This example shows a batched background migration where the `issues.project_id` column is used as
the batching column.

Database post-migration:

```ruby
class ProjectsWithIssuesMigration < Gitlab::Database::Migration[2.0]
  MIGRATION = 'BatchProjectsWithIssues'
  INTERVAL = 2.minutes
  BATCH_SIZE = 5000
  SUB_BATCH_SIZE = 500
  restrict_gitlab_migration gitlab_schema: :gitlab_main

  disable_ddl_transaction!
  def up
    queue_batched_background_migration(
      MIGRATION,
      :issues,
      :project_id,
      job_interval: INTERVAL,
      batch_size: BATCH_SIZE,
      batch_class_name: 'LooseIndexScanBatchingStrategy', # Override the default batching strategy
      sub_batch_size: SUB_BATCH_SIZE
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :issues, :project_id, [])
  end
end
```

Implementing the background migration class:

```ruby
module Gitlab
  module BackgroundMigration
    class BatchProjectsWithIssues < Gitlab::BackgroundMigration::BatchedMigrationJob
      include Gitlab::Database::DynamicModelHelpers

      def perform
        distinct_each_batch(operation_name: :backfill_issues) do |batch|
          project_ids = batch.pluck(batch_column)
          # do something with the distinct project_ids
        end
      end
    end
  end
end
```

### Adding filters to the initial batching

By default, when creating background jobs to perform the migration, batched background migrations will iterate over the full specified table. This is done using the [`PrimaryKeyBatchingStrategy`](https://gitlab.com/gitlab-org/gitlab/-/blob/c9dabd1f4b8058eece6d8cb4af95e9560da9a2ee/lib/gitlab/database/migrations/batched_background_migration_helpers.rb#L17). This means if there are 1000 records in the table and the batch size is 100, there will be 10 jobs. For illustrative purposes, `EachBatch` is used like this:

```ruby
# PrimaryKeyBatchingStrategy
Projects.all.each_batch(of: 100) do |relation|
  relation.where(foo: nil).update_all(foo: 'bar') # this happens in each background job
end
```

There are cases where we only need to look at a subset of records. Perhaps we only need to update 1 out of every 10 of those 1000 records. It would be best if we could apply a filter to the initial relation when the jobs are created:

```ruby
Projects.where(foo: nil).each_batch(of: 100) do |relation|
  relation.update_all(foo: 'bar')
end
```

In the `PrimaryKeyBatchingStrategy` example, we do not know how many records will be updated in each batch. In the filtered example, we know exactly 100 will be updated with each batch.

The `PrimaryKeyBatchingStrategy` contains [a method that can be overwritten](https://gitlab.com/gitlab-org/gitlab/-/blob/dd1e70d3676891025534dc4a1e89ca9383178fe7/lib/gitlab/background_migration/batching_strategies/primary_key_batching_strategy.rb#L38-52) to apply additional filtering on the initial `EachBatch`.

We can accomplish this by:

1. Create a new class that inherits from `PrimaryKeyBatchingStrategy` and overrides the method using the desired filter (this may be the same filter used in the sub-batch):

   ```ruby
   # frozen_string_literal: true

   module GitLab
     module BackgroundMigration
       module BatchingStrategies
         class FooStrategy < PrimaryKeyBatchingStrategy
           def apply_additional_filters(relation, job_arguments: [], job_class: nil)
             relation.where(foo: nil)
           end
         end
       end
     end
   end
   ```

1. In the post-deployment migration that queues the batched background migration, specify the new batching strategy using the `batch_class_name` parameter:

   ```ruby
   class BackfillProjectsFoo < Gitlab::Database::Migration[2.0]
     MIGRATION = 'BackfillProjectsFoo'
     DELAY_INTERVAL = 2.minutes
     BATCH_CLASS_NAME = 'FooStrategy'

     restrict_gitlab_migration gitlab_schema: :gitlab_main

     def up
       queue_batched_background_migration(
         MIGRATION,
         :routes,
         :id,
         job_interval: DELAY_INTERVAL,
         batch_class_name: BATCH_CLASS_NAME
       )
     end

     def down
       delete_batched_background_migration(MIGRATION, :routes, :id, [])
     end
   end
   ```

When applying a batching strategy, it is important to ensure the filter properly covered by an index to optimize `EachBatch` performance. See [the `EachBatch` docs for more information](../iterating_tables_in_batches.md).

## Testing

Writing tests is required for:

- The batched background migrations' queueing migration.
- The batched background migration itself.
- A cleanup migration.

The `:migration` and `schema: :latest` RSpec tags are automatically set for
background migration specs. Refer to the
[Testing Rails migrations](../testing_guide/testing_migrations_guide.md#testing-a-non-activerecordmigration-class)
style guide.

Remember that `before` and `after` RSpec hooks
migrate your database down and up. These hooks can result in other batched background
migrations being called. Using `spy` test doubles with
`have_received` is encouraged, instead of using regular test doubles, because
your expectations defined in a `it` block can conflict with what is
called in RSpec hooks. Refer to [issue #35351](https://gitlab.com/gitlab-org/gitlab/-/issues/18839)
for more details.

## Best practices

1. Know how much data you're dealing with.
1. Make sure the batched background migration jobs are idempotent.
1. Confirm the tests you write are not false positives.
1. If the data being migrated is critical and cannot be lost, the
   clean-up migration must also check the final state of the data before completing.
1. Discuss the numbers with a database specialist. The migration may add
   more pressure on DB than you expect. Measure on staging,
   or ask someone to measure on production.
1. Know how much time is required to run the batched background migration.

## Additional tips and strategies

### Viewing failure error logs

You can view failures in two ways:

- Via GitLab logs:
  1. After running a batched background migration, if any jobs fail,
     view the logs in [Kibana](https://log.gprd.gitlab.net/goto/4cb43f40-f861-11ec-b86b-d963a1a6788e).
     View the production Sidekiq log and filter for:

     - `json.new_state: failed`
     - `json.job_class_name: <Batched Background Migration job class name>`
     - `json.job_arguments: <Batched Background Migration job class arguments>`

  1. Review the `json.exception_class` and `json.exception_message` values to help
     understand why the jobs failed.

  1. Remember the retry mechanism. Having a failure does not mean the job failed.
     Always check the last status of the job.

- Via database:

  1. Get the batched background migration `CLASS_NAME`.
  1. Execute the following query in the PostgreSQL console:

     ```sql
      SELECT migration.id, migration.job_class_name, transition_logs.exception_class, transition_logs.exception_message
      FROM batched_background_migrations as migration
      INNER JOIN batched_background_migration_jobs as jobs
      ON jobs.batched_background_migration_id = migration.id
      INNER JOIN batched_background_migration_job_transition_logs as transition_logs
      ON transition_logs.batched_background_migration_job_id = jobs.id
      WHERE transition_logs.next_status = '2' AND migration.job_class_name = "CLASS_NAME";
     ```
