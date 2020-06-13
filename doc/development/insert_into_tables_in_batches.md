---
description: "Sometimes it is necessary to store large amounts of records at once, which can be inefficient
when iterating collections and performing individual `save`s. With the arrival of `insert_all`
in Rails 6, which operates at the row level (that is, using `Hash`es), GitLab has added a set
of APIs that make it safe and simple to insert ActiveRecord objects in bulk."
---

# Insert into tables in batches

Sometimes it is necessary to store large amounts of records at once, which can be inefficient
when iterating collections and saving each record individually. With the arrival of
[`insert_all`](https://apidock.com/rails/ActiveRecord/Persistence/ClassMethods/insert_all)
in Rails 6, which operates at the row level (that is, using `Hash` objects), GitLab has added a set
of APIs that make it safe and simple to insert `ActiveRecord` objects in bulk.

## Prepare `ApplicationRecord`s for bulk insertion

In order for a model class to take advantage of the bulk insertion API, it has to include the
`BulkInsertSafe` concern first:

```ruby
class MyModel < ApplicationRecord
  # other includes here
  # ...
  include BulkInsertSafe # include this last

  # ...
end
```

The `BulkInsertSafe` concern has two functions:

- It performs checks against your model class to ensure that it does not use ActiveRecord
  APIs that are not safe to use with respect to bulk insertions (more on that below).
- It adds new class methods `bulk_insert!` and `bulk_upsert!`, which you can use to insert many records at once.

## Insert records with `bulk_insert!` and `bulk_upsert!`

If the target class passes the checks performed by `BulkInsertSafe`, you can insert an array of
ActiveRecord model objects as follows:

```ruby
records = [MyModel.new, ...]

MyModel.bulk_insert!(records)
```

Note that calls to `bulk_insert!` will always attempt to insert _new records_. If instead
you would like to replace existing records with new values, while still inserting those
that do not already exist, then you can use `bulk_upsert!`:

```ruby
records = [MyModel.new, existing_model, ...]

MyModel.bulk_upsert!(records, unique_by: [:name])
```

In this example, `unique_by` specifies the columns by which records are considered to be
unique and as such will be updated if they existed prior to insertion. For example, if
`existing_model` has a `name` attribute, and if a record with the same `name` value already
exists, its fields will be updated with those of `existing_model`.

The `unique_by` parameter can also be passed as a `Symbol`, in which case it specifies
a database index by which a column is considered unique:

```ruby
MyModel.bulk_insert!(records, unique_by: :index_on_name)
```

### Record validation

The `bulk_insert!` method guarantees that `records` will be inserted transactionally, and
will run validations on each record prior to insertion. If any record fails to validate,
an error is raised and the transaction is rolled back. You can turn off validations via
the `:validate` option:

```ruby
MyModel.bulk_insert!(records, validate: false)
```

### Batch size configuration

In those cases where the number of `records` is above a given threshold, insertions will
occur in multiple batches. The default batch size is defined in
[`BulkInsertSafe::DEFAULT_BATCH_SIZE`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/models/concerns/bulk_insert_safe.rb).
Assuming a default threshold of 500, inserting 950 records
would result in two batches being written sequentially (of size 500 and 450 respectively.)
You can override the default batch size via the `:batch_size` option:

```ruby
MyModel.bulk_insert!(records, batch_size: 100)
```

Assuming the same number of 950 records, this would result in 10 batches being written instead.
Since this will also affect the number of `INSERT`s that occur, make sure you measure the
performance impact this might have on your code. There is a trade-off between the number of
`INSERT` statements the database has to process and the size and cost of each `INSERT`.

### Handling duplicate records

NOTE: **Note:**
This parameter applies only to `bulk_insert!`. If you intend to update existing
records, use `bulk_upsert!` instead.

It may happen that some records you are trying to insert already exist, which would result in
primary key conflicts. There are two ways to address this problem: failing fast by raising an
error or skipping duplicate records. The default behavior of `bulk_insert!` is to fail fast
and raise an `ActiveRecord::RecordNotUnique` error.

If this is undesirable, you can instead skip duplicate records with the `skip_duplicates` flag:

```ruby
MyModel.bulk_insert!(records, skip_duplicates: true)
```

### Requirements for safe bulk insertions

Large parts of ActiveRecord's persistence API are built around the notion of callbacks. Many
of these callbacks fire in response to model life cycle events such as `save` or `create`.
These callbacks cannot be used with bulk insertions, since they are meant to be called for
every instance that is saved or created. Since these events do not fire when
records are inserted in bulk, we currently disallow their use.

The specifics around which callbacks are disallowed are defined in
[`BulkInsertSafe`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/models/concerns/bulk_insert_safe.rb).
Consult the module source code for details. If your class uses any of the blacklisted
functionality, and you `include BulkInsertSafe`, the application will fail with an error.

### `BulkInsertSafe` versus `InsertAll`

Internally, `BulkInsertSafe` is based on `InsertAll`, and you may wonder when to choose
the former over the latter. To help you make the decision,
the key differences between these classes are listed in the table below.

|                | Input type           | Validates input | Specify batch size | Can bypass callbacks              | Transactional |
|--------------- | -------------------- | --------------- | ------------------ | --------------------------------- | ------------- |
| `bulk_insert!` | ActiveRecord objects | Yes (optional)  | Yes (optional)     | No (prevents unsafe callback use) | Yes           |
| `insert_all!`  | Attribute hashes     | No              | No                 | Yes                               | Yes           |

To summarize, `BulkInsertSafe` moves bulk inserts closer to how ActiveRecord objects
and inserts would normally behave. However, if all you need is to insert raw data in bulk, then
`insert_all` is more efficient.

## Insert `has_many` associations in bulk

A common use case is to save collections of associated relations through the owner side of the relation,
where the owned relation is associated to the owner through the `has_many` class method:

```ruby
owner = OwnerModel.new(owned_relations: array_of_owned_relations)
# saves all `owned_relations` one-by-one
owner.save!
```

This will issue a single `INSERT`, and transaction, for every record in `owned_relations`, which is inefficient if
`array_of_owned_relations` is large. To remedy this, the `BulkInsertableAssociations` concern can be
used to declare that the owner defines associations that are safe for bulk insertion:

```ruby
class OwnerModel < ApplicationRecord
  # other includes here
  # ...
  include BulkInsertableAssociations # include this last

  has_many :my_models
end
```

Here `my_models` must be declared `BulkInsertSafe` (as described previously) for bulk insertions
to happen. You can now insert any yet unsaved records as follows:

```ruby
BulkInsertableAssociations.with_bulk_insert do
  owner = OwnerModel.new(my_models: array_of_my_model_instances)
  # saves `my_models` using a single bulk insert (possibly via multiple batches)
  owner.save!
end
```

Note that you can still save relations that are not `BulkInsertSafe` in this block; they will
simply be treated as if you had invoked `save` from outside the block.

## Known limitations

There are a few restrictions to how these APIs can be used:

- `ON CONFLICT` behavior cannot currently be configured; an error will be raised on primary key conflicts.
- `BulkInsertableAssociations` furthermore has the following restrictions:
  - only compatible with `has_many` relations.
  - does not support `has_many through: ...` relations.
- Writing [`jsonb`](https://www.postgresql.org/docs/current/datatype-json.html) content is
[not currently supported](https://gitlab.com/gitlab-org/gitlab/-/issues/210560).

Moreover, input data should either be limited to around 1000 records at most,
or already batched prior to calling bulk insert. The `INSERT` statement will run in a single
transaction, so for large amounts of records it may negatively affect database stability.
