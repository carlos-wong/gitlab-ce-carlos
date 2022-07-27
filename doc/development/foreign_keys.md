---
stage: Data Stores
group: Database
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Foreign Keys & Associations

When adding an association to a model you must also add a foreign key. For
example, say you have the following model:

```ruby
class User < ActiveRecord::Base
  has_many :posts
end
```

Add a foreign key here on column `posts.user_id`. This ensures
that data consistency is enforced on database level. Foreign keys also mean that
the database can very quickly remove associated data (for example, when removing a
user), instead of Rails having to do this.

## Adding Foreign Keys In Migrations

Foreign keys can be added concurrently using `add_concurrent_foreign_key` as
defined in `Gitlab::Database::MigrationHelpers`. See the [Migration Style
Guide](migration_style_guide.md) for more information.

Keep in mind that you can only safely add foreign keys to existing tables after
you have removed any orphaned rows. The method `add_concurrent_foreign_key`
does not take care of this so you must do so manually. See
[adding foreign key constraint to an existing column](database/add_foreign_key_to_existing_column.md).

## Updating Foreign Keys In Migrations

Sometimes a foreign key constraint must be changed, preserving the column
but updating the constraint condition. For example, moving from
`ON DELETE CASCADE` to `ON DELETE SET NULL` or vice-versa.

PostgreSQL does not prevent you from adding overlapping foreign keys. It
honors the most recently added constraint. This allows us to replace foreign keys without
ever losing foreign key protection on a column.

To replace a foreign key:

1. [Add the new foreign key without validation](database/add_foreign_key_to_existing_column.md#prevent-invalid-records)

  The name of the foreign key constraint must be changed to add a new
  foreign key before removing the old one.

  ```ruby
  class ReplaceFkOnPackagesPackagesProjectId < Gitlab::Database::Migration[2.0]
    disable_ddl_transaction!

    NEW_CONSTRAINT_NAME = 'fk_new'

    def up
      add_concurrent_foreign_key(:packages_packages, :projects, column: :project_id, on_delete: :nullify, validate: false, name: NEW_CONSTRAINT_NAME)
    end

    def down
      with_lock_retries do
        remove_foreign_key_if_exists(:packages_packages, column: :project_id, on_delete: :nullify, name: NEW_CONSTRAINT_NAME)
      end
    end
  end
  ```

1. [Validate the new foreign key](database/add_foreign_key_to_existing_column.md#validate-the-foreign-key)

  ```ruby
  class ValidateFkNew < Gitlab::Database::Migration[2.0]
    NEW_CONSTRAINT_NAME = 'fk_new'

    # foreign key added in <link to MR or path to migration adding new FK>
    def up
      validate_foreign_key(:packages_packages, name: NEW_CONSTRAINT_NAME)
    end

    def down
      # no-op
    end
  end
  ```

1. Remove the old foreign key:

  ```ruby
  class RemoveFkOld < Gitlab::Database::Migration[2.0]
    OLD_CONSTRAINT_NAME = 'fk_old'

    # new foreign key added in <link to MR or path to migration adding new FK>
    # and validated in <link to MR or path to migration validating new FK>
    def up
      remove_foreign_key_if_exists(:packages_packages, column: :project_id, on_delete: :cascade, name: OLD_CONSTRAINT_NAME)
    end

    def down
      # Validation is skipped here, so if rolled back, this will need to be revalidated in a separate migration
      add_concurrent_foreign_key(:packages_packages, :projects, column: :project_id, on_delete: :cascade, validate: false, name: OLD_CONSTRAINT_NAME)
    end
  end
  ```

## Cascading Deletes

Every foreign key must define an `ON DELETE` clause, and in 99% of the cases
this should be set to `CASCADE`.

## Indexes

When adding a foreign key in PostgreSQL the column is not indexed automatically,
thus you must also add a concurrent index. Not doing so results in cascading
deletes being very slow.

## Naming foreign keys

By default Ruby on Rails uses the `_id` suffix for foreign keys. So we should
only use this suffix for associations between two tables. If you want to
reference an ID on a third party platform the `_xid` suffix is recommended.

The spec `spec/db/schema_spec.rb` tests if all columns with the `_id` suffix
have a foreign key constraint. So if that spec fails, don't add the column to
`IGNORED_FK_COLUMNS`, but instead add the FK constraint, or consider naming it
differently.

## Dependent Removals

Don't define options such as `dependent: :destroy` or `dependent: :delete` when
defining an association. Defining these options means Rails handles the
removal of data, instead of letting the database handle this in the most
efficient way possible.

In other words, this is bad and should be avoided at all costs:

```ruby
class User < ActiveRecord::Base
  has_many :posts, dependent: :destroy
end
```

Should you truly have a need for this it should be approved by a database
specialist first.

You should also not define any `before_destroy` or `after_destroy` callbacks on
your models _unless_ absolutely required and only when approved by database
specialists. For example, if each row in a table has a corresponding file on a
file system it may be tempting to add a `after_destroy` hook. This however
introduces non database logic to a model, and means we can no longer rely on
foreign keys to remove the data as this would result in the file system data
being left behind. In such a case you should use a service class instead that
takes care of removing non database data.

In cases where the relation spans multiple databases you have even
further problems using `dependent: :destroy` or the above hooks. You can
read more about alternatives at [Avoid `dependent: :nullify` and
`dependent: :destroy` across
databases](database/multiple_databases.md#avoid-dependent-nullify-and-dependent-destroy-across-databases).

## Alternative primary keys with `has_one` associations

Sometimes a `has_one` association is used to create a one-to-one relationship:

```ruby
class User < ActiveRecord::Base
  has_one :user_config
end

class UserConfig < ActiveRecord::Base
  belongs_to :user
end
```

In these cases, there may be an opportunity to remove the unnecessary `id`
column on the associated table, `user_config.id` in this example. Instead,
the originating table ID can be used as the primary key for the associated
table:

```ruby
create_table :user_configs, id: false do |t|
  t.references :users, primary_key: true, default: nil, index: false, foreign_key: { on_delete: :cascade }
  ...
end
```

Setting `default: nil` ensures a primary key sequence is not created, and since the primary key
automatically gets an index, we set `index: false` to avoid creating a duplicate.
You also need to add the new primary key to the model:

```ruby
class UserConfig < ActiveRecord::Base
  self.primary_key = :user_id

  belongs_to :user
end
```

Using a foreign key as primary key saves space but can make
[batch counting](service_ping/implement.md#batch-counters) in [Service Ping](service_ping/index.md) less efficient.
Consider using a regular `id` column if the table is relevant for Service Ping.
