---
stage: Enablement
group: Database
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# SQL Query Guidelines

This document describes various guidelines to follow when writing SQL queries,
either using ActiveRecord/Arel or raw SQL queries.

## Using LIKE Statements

The most common way to search for data is using the `LIKE` statement. For
example, to get all issues with a title starting with "Draft:" you'd write the
following query:

```sql
SELECT *
FROM issues
WHERE title LIKE 'Draft:%';
```

On PostgreSQL the `LIKE` statement is case-sensitive. To perform a case-insensitive
`LIKE` you have to use `ILIKE` instead.

To handle this automatically you should use `LIKE` queries using Arel instead
of raw SQL fragments, as Arel automatically uses `ILIKE` on PostgreSQL.

```ruby
Issue.where('title LIKE ?', 'Draft:%')
```

You'd write this instead:

```ruby
Issue.where(Issue.arel_table[:title].matches('Draft:%'))
```

Here `matches` generates the correct `LIKE` / `ILIKE` statement depending on the
database being used.

If you need to chain multiple `OR` conditions you can also do this using Arel:

```ruby
table = Issue.arel_table

Issue.where(table[:title].matches('Draft:%').or(table[:foo].matches('Draft:%')))
```

On PostgreSQL, this produces:

```sql
SELECT *
FROM issues
WHERE (title ILIKE 'Draft:%' OR foo ILIKE 'Draft:%')
```

## LIKE & Indexes

PostgreSQL won't use any indexes when using `LIKE` / `ILIKE` with a wildcard at
the start. For example, this will not use any indexes:

```sql
SELECT *
FROM issues
WHERE title ILIKE '%Draft:%';
```

Because the value for `ILIKE` starts with a wildcard the database is not able to
use an index as it doesn't know where to start scanning the indexes.

Luckily, PostgreSQL _does_ provide a solution: trigram Generalized Inverted Index (GIN) indexes. These
indexes can be created as follows:

```sql
CREATE INDEX [CONCURRENTLY] index_name_here
ON table_name
USING GIN(column_name gin_trgm_ops);
```

The key here is the `GIN(column_name gin_trgm_ops)` part. This creates a [GIN
index](https://www.postgresql.org/docs/current/gin.html) with the operator class set to `gin_trgm_ops`. These indexes
_can_ be used by `ILIKE` / `LIKE` and can lead to greatly improved performance.
One downside of these indexes is that they can easily get quite large (depending
on the amount of data indexed).

To keep naming of these indexes consistent please use the following naming
pattern:

```plaintext
index_TABLE_on_COLUMN_trigram
```

For example, a GIN/trigram index for `issues.title` would be called
`index_issues_on_title_trigram`.

Due to these indexes taking quite some time to be built they should be built
concurrently. This can be done by using `CREATE INDEX CONCURRENTLY` instead of
just `CREATE INDEX`. Concurrent indexes can _not_ be created inside a
transaction. Transactions for migrations can be disabled using the following
pattern:

```ruby
class MigrationName < Gitlab::Database::Migration[1.0]
  disable_ddl_transaction!
end
```

For example:

```ruby
class AddUsersLowerUsernameEmailIndexes < Gitlab::Database::Migration[1.0]
  disable_ddl_transaction!

  def up
    execute 'CREATE INDEX CONCURRENTLY index_on_users_lower_username ON users (LOWER(username));'
    execute 'CREATE INDEX CONCURRENTLY index_on_users_lower_email ON users (LOWER(email));'
  end

  def down
    remove_index :users, :index_on_users_lower_username
    remove_index :users, :index_on_users_lower_email
  end
end
```

## Reliably referencing database columns

ActiveRecord by default returns all columns from the queried database table. In some cases the returned rows might need to be customized, for example:

- Specify only a few columns to reduce the amount of data returned from the database.
- Include columns from `JOIN` relations.
- Perform calculations (`SUM`, `COUNT`).

In this example we specify the columns, but not their tables:

- `path` from the `projects` table
- `user_id` from the `merge_requests` table

The query:

```ruby
# bad, avoid
Project.select("path, user_id").joins(:merge_requests) # SELECT path, user_id FROM "projects" ...
```

Later on, a new feature adds an extra column to the `projects` table: `user_id`. During deployment there might be a short time window where the database migration is already executed, but the new version of the application code is not deployed yet. When the query mentioned above executes during this period, the query will fail with the following error message: `PG::AmbiguousColumn: ERROR: column reference "user_id" is ambiguous`

The problem is caused by the way the attributes are selected from the database. The `user_id` column is present in both the `users` and `merge_requests` tables. The query planner cannot decide which table to use when looking up the `user_id` column.

When writing a customized `SELECT` statement, it's better to **explicitly specify the columns with the table name**.

### Good (prefer)

```ruby
Project.select(:path, 'merge_requests.user_id').joins(:merge_requests)

# SELECT "projects"."path", merge_requests.user_id as user_id FROM "projects" ...
```

```ruby
Project.select(:path, :'merge_requests.user_id').joins(:merge_requests)

# SELECT "projects"."path", "merge_requests"."id" as user_id FROM "projects" ...
```

Example using Arel (`arel_table`):

```ruby
Project.select(:path, MergeRequest.arel_table[:user_id]).joins(:merge_requests)

# SELECT "projects"."path", "merge_requests"."user_id" FROM "projects" ...
```

When writing raw SQL query:

```sql
SELECT projects.path, merge_requests.user_id FROM "projects"...
```

When the raw SQL query is parameterized (needs escaping):

```ruby
include ActiveRecord::ConnectionAdapters::Quoting

"""
SELECT
  #{quote_table_name('projects')}.#{quote_column_name('path')},
  #{quote_table_name('merge_requests')}.#{quote_column_name('user_id')}
FROM ...
"""
```

### Bad (avoid)

```ruby
Project.select('id, path, user_id').joins(:merge_requests).to_sql

# SELECT id, path, user_id FROM "projects" ...
```

```ruby
Project.select("path", "user_id").joins(:merge_requests)
# SELECT "projects"."path", "user_id" FROM "projects" ...

# or

Project.select(:path, :user_id).joins(:merge_requests)
# SELECT "projects"."path", "user_id" FROM "projects" ...
```

When a column list is given, ActiveRecord tries to match the arguments against the columns defined in the `projects` table and prepend the table name automatically. In this case, the `id` column is not going to be a problem, but the `user_id` column could return unexpected data:

```ruby
Project.select(:id, :user_id).joins(:merge_requests)

# Before deployment (user_id is taken from the merge_requests table):
# SELECT "projects"."id", "user_id" FROM "projects" ...

# After deployment (user_id is taken from the projects table):
# SELECT "projects"."id", "projects"."user_id" FROM "projects" ...
```

## Plucking IDs

Never use ActiveRecord's `pluck` to pluck a set of values into memory only to
use them as an argument for another query. For example, this will execute an
extra unnecessary database query and load a lot of unnecessary data into memory:

```ruby
projects = Project.all.pluck(:id)

MergeRequest.where(source_project_id: projects)
```

Instead you can just use sub-queries which perform far better:

```ruby
MergeRequest.where(source_project_id: Project.all.select(:id))
```

The _only_ time you should use `pluck` is when you actually need to operate on
the values in Ruby itself (for example, writing them to a file). In almost all other cases
you should ask yourself "Can I not just use a sub-query?".

In line with our `CodeReuse/ActiveRecord` cop, you should only use forms like
`pluck(:id)` or `pluck(:user_id)` within model code. In the former case, you can
use the `ApplicationRecord`-provided `.pluck_primary_key` helper method instead.
In the latter, you should add a small helper method to the relevant model.

If you have strong reasons to use `pluck`, it could make sense to limit the number
of records plucked. `MAX_PLUCK` defaults to `1_000` in `ApplicationRecord`.

## Inherit from ApplicationRecord

Most models in the GitLab codebase should inherit from `ApplicationRecord`
or `Ci::ApplicationRecord` rather than from `ActiveRecord::Base`. This allows
helper methods to be easily added.

An exception to this rule exists for models created in database migrations. As
these should be isolated from application code, they should continue to subclass
from `MigrationRecord` which is available only in migration context.

## Use UNIONs

`UNION`s aren't very commonly used in most Rails applications but they're very
powerful and useful. Queries tend to use a lot of `JOIN`s to
get related data or data based on certain criteria, but `JOIN` performance can
quickly deteriorate as the data involved grows.

For example, if you want to get a list of projects where the name contains a
value _or_ the name of the namespace contains a value most people would write
the following query:

```sql
SELECT *
FROM projects
JOIN namespaces ON namespaces.id = projects.namespace_id
WHERE projects.name ILIKE '%gitlab%'
OR namespaces.name ILIKE '%gitlab%';
```

Using a large database this query can easily take around 800 milliseconds to
run. Using a `UNION` we'd write the following instead:

```sql
SELECT projects.*
FROM projects
WHERE projects.name ILIKE '%gitlab%'

UNION

SELECT projects.*
FROM projects
JOIN namespaces ON namespaces.id = projects.namespace_id
WHERE namespaces.name ILIKE '%gitlab%';
```

This query in turn only takes around 15 milliseconds to complete while returning
the exact same records.

This doesn't mean you should start using UNIONs everywhere, but it's something
to keep in mind when using lots of JOINs in a query and filtering out records
based on the joined data.

GitLab comes with a `Gitlab::SQL::Union` class that can be used to build a `UNION`
of multiple `ActiveRecord::Relation` objects. You can use this class as
follows:

```ruby
union = Gitlab::SQL::Union.new([projects, more_projects, ...])

Project.from("(#{union.to_sql}) projects")
```

### Uneven columns in the UNION sub-queries

When the UNION query has uneven columns in the SELECT clauses, the database returns an error.
Consider the following UNION query:

```sql
SELECT id FROM users WHERE id = 1
UNION
SELECT id, name FROM users WHERE id = 2
end
```

The query results in the following error message:

```plaintext
each UNION query must have the same number of columns
```

This problem is apparent and it can be easily fixed during development. One edge-case is when
UNION queries are combined with explicit column listing where the list comes from the
`ActiveRecord` schema cache.

Example (bad, avoid it):

```ruby
scope1 = User.select(User.column_names).where(id: [1, 2, 3]) # selects the columns explicitly
scope2 = User.where(id: [10, 11, 12]) # uses SELECT users.*

User.connection.execute(Gitlab::SQL::Union.new([scope1, scope2]).to_sql)
```

When this code is deployed, it doesn't cause problems immediately. When another
developer adds a new database column to the `users` table, this query breaks in
production and can cause downtime. The second query (`SELECT users.*`) includes the
newly added column; however, the first query does not. The `column_names` method returns stale
values (the new column is missing), because the values are cached within the `ActiveRecord` schema
cache. These values are usually populated when the application boots up.

At this point, the only fix would be a full application restart so that the schema cache gets
updated.

The problem can be avoided if we always use `SELECT users.*` or we always explicitly define the
columns.

Using `SELECT users.*`:

```ruby
# Bad, avoid it
scope1 = User.select(User.column_names).where(id: [1, 2, 3])
scope2 = User.where(id: [10, 11, 12])

# Good, both queries generate SELECT users.*
scope1 = User.where(id: [1, 2, 3])
scope2 = User.where(id: [10, 11, 12])

User.connection.execute(Gitlab::SQL::Union.new([scope1, scope2]).to_sql)
```

Explicit column list definition:

```ruby
# Good, the SELECT columns are consistent
columns = User.cached_column_list # The helper returns fully qualified (table.column) column names (Arel)
scope1 = User.select(*columns).where(id: [1, 2, 3]) # selects the columns explicitly
scope2 = User.select(*columns).where(id: [10, 11, 12]) # uses SELECT users.*

User.connection.execute(Gitlab::SQL::Union.new([scope1, scope2]).to_sql)
```

## Ordering by Creation Date

When ordering records based on the time they were created, you can order
by the `id` column instead of ordering by `created_at`. Because IDs are always
unique and incremented in the order that rows are created, doing so will produce the
exact same results. This also means there's no need to add an index on
`created_at` to ensure consistent performance as `id` is already indexed by
default.

## Use WHERE EXISTS instead of WHERE IN

While `WHERE IN` and `WHERE EXISTS` can be used to produce the same data it is
recommended to use `WHERE EXISTS` whenever possible. While in many cases
PostgreSQL can optimise `WHERE IN` quite well there are also many cases where
`WHERE EXISTS` will perform (much) better.

In Rails you have to use this by creating SQL fragments:

```ruby
Project.where('EXISTS (?)', User.select(1).where('projects.creator_id = users.id AND users.foo = X'))
```

This would then produce a query along the lines of the following:

```sql
SELECT *
FROM projects
WHERE EXISTS (
    SELECT 1
    FROM users
    WHERE projects.creator_id = users.id
    AND users.foo = X
)
```

## `.find_or_create_by` is not atomic

The inherent pattern with methods like `.find_or_create_by` and
`.first_or_create` and others is that they are not atomic. This means,
it first runs a `SELECT`, and if there are no results an `INSERT` is
performed. With concurrent processes in mind, there is a race condition
which may lead to trying to insert two similar records. This may not be
desired, or may cause one of the queries to fail due to a constraint
violation, for example.

Using transactions does not solve this problem.

To solve this we've added the `ApplicationRecord.safe_find_or_create_by`.

This method can be used the same way as
`find_or_create_by`, but it wraps the call in a *new* transaction (or a subtransaction) and
retries if it were to fail because of an
`ActiveRecord::RecordNotUnique` error.

To be able to use this method, make sure the model you want to use
this on inherits from `ApplicationRecord`.

In Rails 6 and later, there is a
[`.create_or_find_by`](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html#method-i-create_or_find_by)
method. This method differs from our `.safe_find_or_create_by` methods
because it performs the `INSERT`, and then performs the `SELECT` commands only if that call
fails.

If the `INSERT` fails, it will leave a dead tuple around and
increment the primary key sequence (if any), among [other downsides](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html#method-i-create_or_find_by).

We prefer `.safe_find_or_create_by` if the common path is that we
have a single record which is reused after it has first been created.
However, if the more common path is to create a new record, and we only
want to avoid duplicate records to be inserted on edge cases
(for example a job-retry), then `.create_or_find_by` can save us a `SELECT`.

Both methods use subtransactions internally if executed within the context of
an existing transaction. This can significantly impact overall performance,
especially if more than 64 live subtransactions are being used inside a single transaction.

## Monitor SQL queries in production

GitLab team members can monitor slow or canceled queries on GitLab.com
using the PostgreSQL logs, which are indexed in Elasticsearch and
searchable using Kibana.

See [the runbook](https://gitlab.com/gitlab-com/runbooks/-/blob/master/docs/patroni/pg_collect_query_data.md#searching-postgresql-logs-with-kibanaelasticsearch)
for more details.
