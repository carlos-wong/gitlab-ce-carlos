# QueryRecorder

QueryRecorder is a tool for detecting the [N+1 queries problem](https://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations) from tests.

> Implemented in [spec/support/query_recorder.rb](https://gitlab.com/gitlab-org/gitlab/blob/master/spec/support/helpers/query_recorder.rb) via [9c623e3e](https://gitlab.com/gitlab-org/gitlab-foss/commit/9c623e3e5d7434f2e30f7c389d13e5af4ede770a)

As a rule, merge requests [should not increase query counts](merge_request_performance_guidelines.md#query-counts). If you find yourself adding something like `.includes(:author, :assignee)` to avoid having `N+1` queries, consider using QueryRecorder to enforce this with a test. Without this, a new feature which causes an additional model to be accessed will silently reintroduce the problem.

## How it works

This style of test works by counting the number of SQL queries executed by ActiveRecord. First a control count is taken, then you add new records to the database and rerun the count. If the number of queries has significantly increased then an `N+1` queries problem exists.

```ruby
it "avoids N+1 database queries" do
  control_count = ActiveRecord::QueryRecorder.new { visit_some_page }.count
  create_list(:issue, 5)
  expect { visit_some_page }.not_to exceed_query_limit(control_count)
end
```

As an example you might create 5 issues in between counts, which would cause the query count to increase by 5 if an N+1 problem exists.

> **Note:** In some cases the query count might change slightly between runs for unrelated reasons. In this case you might need to test `exceed_query_limit(control_count + acceptable_change)`, but this should be avoided if possible.

## Cached queries

By default, QueryRecorder will ignore cached queries in the count. However, it may be better to count
all queries to avoid introducing an N+1 query that may be masked by the statement cache. To do this,
pass the `skip_cached` variable to `QueryRecorder` and use the `exceed_all_query_limit` matcher:

```ruby
it "avoids N+1 database queries" do
  control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) { visit_some_page }.count
  create_list(:issue, 5)
  expect { visit_some_page }.not_to exceed_all_query_limit(control_count)
end
```

## Use request specs instead of controller specs

Use a [request spec](https://gitlab.com/gitlab-org/gitlab-foss/tree/master/spec/requests) when writing a N+1 test on the controller level.

Controller specs should not be used to write N+1 tests as the controller is only initialized once per example.
This could lead to false successes where subsequent "requests" could have queries reduced (e.g. because of memoization).

## Finding the source of the query

There are multiple ways to find the source of queries.

1. The `QueryRecorder` `data` attribute stores queries by `file_name:line_number:method_name`.
   Each entry is a `hash` with the following fields:

   - `count`: the number of times a query from this `file_name:line_number:method_name` was called
   - `occurrences`: the actual `SQL` of each call
   - `backtrace`: the stack trace of each call (if either of the two following options were enabled)

   `QueryRecorder#find_query` allows filtering queries by their `file_name:line_number:method_name` and
   `count` attributes. For example:

   ```ruby
   control = ActiveRecord::QueryRecorder.new(skip_cached: false) { visit_some_page }
   control.find_query(/.*note.rb.*/, 0, first_only: true)
   ```

   `QueryRecorder#occurrences_by_line_method` returns a sorted array based on `data`, sorted by `count`.

1. You can output the call backtrace for the specific `QueryRecorder` instance you want
   by using `ActiveRecord::QueryRecorder.new(query_recorder_debug: true)`. The output
   will be in `test.log`

1. Using the environment variable `QUERY_RECORDER_DEBUG`, the call backtrace will be output for all tests.

   To enable this, run the specs with the `QUERY_RECORDER_DEBUG` environment variable set. For example:

   ```shell
   QUERY_RECORDER_DEBUG=1 bundle exec rspec spec/requests/api/projects_spec.rb
   ```

   This will log calls to QueryRecorder into the `test.log` file. For example:

   ```plaintext
    QueryRecorder SQL: SELECT COUNT(*) FROM "issues" WHERE "issues"."deleted_at" IS NULL AND "issues"."project_id" = $1 AND ("issues"."state" IN ('opened')) AND "issues"."confidential" = $2
       --> /home/user/gitlab/gdk/gitlab/spec/support/query_recorder.rb:19:in `callback'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/notifications/fanout.rb:127:in `finish'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/notifications/fanout.rb:46:in `block in finish'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/notifications/fanout.rb:46:in `each'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/notifications/fanout.rb:46:in `finish'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/notifications/instrumenter.rb:36:in `finish'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/notifications/instrumenter.rb:25:in `instrument'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/abstract_adapter.rb:478:in `log'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/postgresql_adapter.rb:601:in `exec_cache'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/postgresql_adapter.rb:585:in `execute_and_clear'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/postgresql/database_statements.rb:160:in `exec_query'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/abstract/database_statements.rb:356:in `select'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/abstract/database_statements.rb:32:in `select_all'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/abstract/query_cache.rb:68:in `block in select_all'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/abstract/query_cache.rb:83:in `cache_sql'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/connection_adapters/abstract/query_cache.rb:68:in `select_all'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/relation/calculations.rb:270:in `execute_simple_calculation'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/relation/calculations.rb:227:in `perform_calculation'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/relation/calculations.rb:133:in `calculate'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activerecord-4.2.8/lib/active_record/relation/calculations.rb:48:in `count'
       --> /home/user/gitlab/gdk/gitlab/app/services/base_count_service.rb:20:in `uncached_count'
       --> /home/user/gitlab/gdk/gitlab/app/services/base_count_service.rb:12:in `block in count'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/cache.rb:299:in `block in fetch'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/cache.rb:585:in `block in save_block_result_to_cache'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/cache.rb:547:in `block in instrument'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/notifications.rb:166:in `instrument'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/cache.rb:547:in `instrument'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/cache.rb:584:in `save_block_result_to_cache'
       --> /home/user/.rbenv/versions/2.3.5/lib/ruby/gems/2.3.0/gems/activesupport-4.2.8/lib/active_support/cache.rb:299:in `fetch'
       --> /home/user/gitlab/gdk/gitlab/app/services/base_count_service.rb:12:in `count'
       --> /home/user/gitlab/gdk/gitlab/app/models/project.rb:1296:in `open_issues_count'
   ```

## See also

- [Bullet](profiling.md#Bullet) For finding `N+1` query problems
- [Performance guidelines](performance.md)
- [Merge request performance guidelines](merge_request_performance_guidelines.md#query-counts)
