# What requires downtime?

When working with a database certain operations can be performed without taking
GitLab offline, others do require a downtime period. This guide describes
various operations, their impact, and how to perform them without requiring
downtime.

## Adding Columns

You can safely add a new column to an existing table as long as it does **not**
have a default value. For example, this query would not require downtime:

```sql
ALTER TABLE projects ADD COLUMN random_value int;
```

Add a column _with_ a default however does require downtime. For example,
consider this query:

```sql
ALTER TABLE projects ADD COLUMN random_value int DEFAULT 42;
```

This requires updating every single row in the `projects` table so that
`random_value` is set to `42` by default. This requires updating all rows and
indexes in a table. This in turn acquires enough locks on the table for it to
effectively block any other queries.

Adding a column with a default value _can_ be done without requiring downtime
when using the migration helper method
`Gitlab::Database::MigrationHelpers#add_column_with_default`. This method works
similar to `add_column` except it updates existing rows in batches without
blocking access to the table being modified. See ["Adding Columns With Default
Values"](migration_style_guide.md#adding-columns-with-default-values) for more
information on how to use this method.

## Dropping Columns

Removing columns is tricky because running GitLab processes may still be using
the columns. To work around this you will need two separate merge requests and
releases: one to ignore and then remove the column, and one to remove the ignore
rule.

### Step 1: Ignoring The Column

The first step is to ignore the column in the application code. This is
necessary because Rails caches the columns and re-uses this cache in various
places. This can be done by including the `IgnorableColumn` module into the
model, followed by defining the columns to ignore. For example, to ignore
`updated_at` in the User model you'd use the following:

```ruby
class User < ActiveRecord::Base
  include IgnorableColumn

  ignore_column :updated_at
end
```

Once added you should create a _post-deployment_ migration that removes the
column. Both these changes should be submitted in the same merge request.

### Step 2: Removing The Ignore Rule

Once the changes from step 1 have been released & deployed you can set up a
separate merge request that removes the ignore rule. This merge request can
simply remove the `ignore_column` line, and the `include IgnorableColumn` line
if no other `ignore_column` calls remain.

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
class RenameUsersUpdatedAtToUpdatedAtTimestamp < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  disable_ddl_transaction!

  def up
    rename_column_concurrently :users, :updated_at, :updated_at_timestamp
  end

  def down
    cleanup_concurrent_column_rename :users, :updated_at_timestamp, :updated_at
  end
end
```

This will take care of renaming the column, ensuring data stays in sync, copying
over indexes and foreign keys, etc.

**NOTE:** if a column contains 1 or more indexes that do not contain the name of
the original column, the above procedure will fail. In this case you will first
need to rename these indexes.

### Step 2: Add A Post-Deployment Migration

The renaming procedure requires some cleaning up in a post-deployment migration.
We can perform this cleanup using
`Gitlab::Database::MigrationHelpers#cleanup_concurrent_column_rename`:

```ruby
# A post-deployment migration in db/post_migrate
class CleanupUsersUpdatedAtRename < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  disable_ddl_transaction!

  def up
    cleanup_concurrent_column_rename :users, :updated_at, :updated_at_timestamp
  end

  def down
    rename_column_concurrently :users, :updated_at_timestamp, :updated_at
  end
end
```

## Changing Column Constraints

Adding or removing a NOT NULL clause (or another constraint) can typically be
done without requiring downtime. However, this does require that any application
changes are deployed _first_. Thus, changing the constraints of a column should
happen in a post-deployment migration.
NOTE: Avoid using `change_column` as it produces inefficient query because it re-defines
the whole column type. For example, to add a NOT NULL constraint, prefer `change_column_null`

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
class ChangeUsersUsernameStringToText < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  disable_ddl_transaction!

  def up
    change_column_type_concurrently :users, :username, :text
  end

  def down
    cleanup_concurrent_column_type_change :users, :username
  end
end
```

### Step 2: Create A Post Deployment Migration

Next we need to clean up our changes using a post-deployment migration:

```ruby
# A post-deployment migration in db/post_migrate
class ChangeUsersUsernameStringToTextCleanup < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  disable_ddl_transaction!

  def up
    cleanup_concurrent_column_type_change :users
  end

  def down
    change_column_type_concurrently :users, :username, :string
  end
end
```

And that's it, we're done!

## Changing The Schema For Large Tables

While `change_column_type_concurrently` and `rename_column_concurrently` can be
used for changing the schema of a table without downtime, it doesn't work very
well for large tables. Because all of the work happens in sequence the migration
can take a very long time to complete, preventing a deployment from proceeding.
They can also produce a lot of pressure on the database due to it rapidly
updating many rows in sequence.

To reduce database pressure you should instead use
`change_column_type_using_background_migration` or `rename_column_using_background_migration`
when migrating a column in a large table (e.g. `issues`). These methods work
similarly to the concurrent counterparts but uses background migration to spread
the work / load over a longer time period, without slowing down deployments.

For example, to change the column type using a background migration:

```ruby
class ExampleMigration < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  disable_ddl_transaction!

  class Issue < ActiveRecord::Base
    self.table_name = 'issues'

    include EachBatch

    def self.to_migrate
      where('closed_at IS NOT NULL')
    end
  end

  def up
    change_column_type_using_background_migration(
      Issue.to_migrate,
      :closed_at,
      :datetime_with_timezone
    )
  end

  def down
    change_column_type_using_background_migration(
      Issue.to_migrate,
      :closed_at,
      :datetime
    )
  end
end
```

This would change the type of `issues.closed_at` to `timestamp with time zone`.

Keep in mind that the relation passed to
`change_column_type_using_background_migration` _must_ include `EachBatch`,
otherwise it will raise a `TypeError`.

This migration then needs to be followed in a separate release (_not_ a patch
release) by a cleanup migration, which should steal from the queue and handle
any remaining rows. For example:

```ruby
class MigrateRemainingIssuesClosedAt < ActiveRecord::Migration[4.2]
  include Gitlab::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  class Issue < ActiveRecord::Base
    self.table_name = 'issues'
    include EachBatch
  end

  def up
    Gitlab::BackgroundMigration.steal('CopyColumn')
    Gitlab::BackgroundMigration.steal('CleanupConcurrentTypeChange')

    migrate_remaining_rows if migrate_column_type?
  end

  def down
    # Previous migrations already revert the changes made here.
  end

  def migrate_remaining_rows
    Issue.where('closed_at_for_type_change IS NULL AND closed_at IS NOT NULL').each_batch do |batch|
      batch.update_all('closed_at_for_type_change = closed_at')
    end

    cleanup_concurrent_column_type_change(:issues, :closed_at)
  end

  def migrate_column_type?
    # Some environments may have already executed the previous version of this
    # migration, thus we don't need to migrate those environments again.
    column_for('issues', 'closed_at').type == :datetime # rubocop:disable Migration/Datetime
  end
end
```

The same applies to `rename_column_using_background_migration`:

1. Create a migration using the helper, which will schedule background
   migrations to spread the writes over a longer period of time.
1. In the next monthly release, create a clean-up migration to steal from the
   Sidekiq queues, migrate any missing rows, and cleanup the rename. This
   migration should skip the steps after stealing from the Sidekiq queues if the
   column has already been renamed.

For more information, see [the documentation on cleaning up background
migrations](background_migrations.md#cleaning-up).

## Adding Indexes

Adding indexes is an expensive process that blocks INSERT and UPDATE queries for
the duration. You can work around this by using the `CONCURRENTLY` option:

```sql
CREATE INDEX CONCURRENTLY index_name ON projects (column_name);
```

Migrations can take advantage of this by using the method
`add_concurrent_index`. For example:

```ruby
class MyMigration < ActiveRecord::Migration[4.2]
  def up
    add_concurrent_index :projects, :column_name
  end

  def down
    remove_index(:projects, :column_name) if index_exists?(:projects, :column_name)
  end
end
```

Note that `add_concurrent_index` can not be reversed automatically, thus you
need to manually define `up` and `down`.

## Dropping Indexes

Dropping an index does not require downtime.

## Adding Tables

This operation is safe as there's no code using the table just yet.

## Dropping Tables

Dropping tables can be done safely using a post-deployment migration, but only
if the application no longer uses the table.

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

## Data Migrations

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
migration is usually enough. If you need to change the format of data (e.g. from
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
