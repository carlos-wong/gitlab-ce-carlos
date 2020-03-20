# Foreign Keys & Associations

When adding an association to a model you must also add a foreign key. For
example, say you have the following model:

```ruby
class User < ActiveRecord::Base
  has_many :posts
end
```

Here you will need to add a foreign key on column `posts.user_id`. This ensures
that data consistency is enforced on database level. Foreign keys also mean that
the database can very quickly remove associated data (e.g. when removing a
user), instead of Rails having to do this.

## Adding Foreign Keys In Migrations

Foreign keys can be added concurrently using `add_concurrent_foreign_key` as
defined in `Gitlab::Database::MigrationHelpers`. See the [Migration Style
Guide](migration_style_guide.md) for more information.

Keep in mind that you can only safely add foreign keys to existing tables after
you have removed any orphaned rows. The method `add_concurrent_foreign_key`
does not take care of this so you'll need to do so manually.

## Cascading Deletes

Every foreign key must define an `ON DELETE` clause, and in 99% of the cases
this should be set to `CASCADE`.

## Indexes

When adding a foreign key in PostgreSQL the column is not indexed automatically,
thus you must also add a concurrent index. Not doing so will result in cascading
deletes being very slow.

## Dependent Removals

Don't define options such as `dependent: :destroy` or `dependent: :delete` when
defining an association. Defining these options means Rails will handle the
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
foreign keys to remove the data as this would result in the filesystem data
being left behind. In such a case you should use a service class instead that
takes care of removing non database data.

## Alternative primary keys with has_one associations

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
