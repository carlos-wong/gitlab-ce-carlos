# GitLab Developers Guide to Logging

[GitLab Logs](../administration/logs.md) play a critical role for both
administrators and GitLab team members to diagnose problems in the field.

## Don't use `Rails.logger`

Currently `Rails.logger` calls all get saved into `production.log`, which contains
a mix of Rails' logs and other calls developers have inserted in the code base.
For example:

```
Started GET "/gitlabhq/yaml_db/tree/master" for 168.111.56.1 at 2015-02-12 19:34:53 +0200
Processing by Projects::TreeController#show as HTML
  Parameters: {"project_id"=>"gitlabhq/yaml_db", "id"=>"master"}

  ...

  Namespaces"."created_at" DESC, "namespaces"."id" DESC LIMIT 1 [["id", 26]]
  CACHE (0.0ms) SELECT  "members".* FROM "members"  WHERE "members"."source_type" = 'Project' AND "members"."type" IN ('ProjectMember') AND "members"."source_id" = $1 AND "members"."source_type" = $2 AND "members"."user_id" = 1  ORDER BY "members"."created_at" DESC, "members"."id" DESC LIMIT 1  [["source_id", 18], ["source_type", "Project"]]
  CACHE (0.0ms) SELECT  "members".* FROM "members"  WHERE "members"."source_type" = 'Project' AND "members".
  (1.4ms) SELECT COUNT(*) FROM "merge_requests"  WHERE "merge_requests"."target_project_id" = $1 AND ("merge_requests"."state" IN ('opened','reopened')) [["target_project_id", 18]]
  Rendered layouts/nav/_project.html.haml (28.0ms)
  Rendered layouts/_collapse_button.html.haml (0.2ms)
  Rendered layouts/_flash.html.haml (0.1ms)
  Rendered layouts/_page.html.haml (32.9ms)
Completed 200 OK in 166ms (Views: 117.4ms | ActiveRecord: 27.2ms)
```

These logs suffer from a number of problems:

1. They often lack timestamps or other contextual information (e.g. project ID, user)
1. They may span multiple lines, which make them hard to find via Elasticsearch.
1. They lack a common structure, which make them hard to parse by log
   forwarders, such as Logstash or Fluentd. This also makes them hard to
   search.

Note that currently on GitLab.com, any messages in `production.log` will
NOT get indexed by Elasticsearch due to the sheer volume and noise. They
do end up in Google Stackdriver, but it is still harder to search for
logs there. See the [GitLab.com logging
documentation](https://gitlab.com/gitlab-com/runbooks/blob/master/logging/doc/README.md)
for more details.

## Use structured (JSON) logging

Structured logging solves these problems. Consider the example from an API request:

```json
{"time":"2018-10-29T12:49:42.123Z","severity":"INFO","duration":709.08,"db":14.59,"view":694.49,"status":200,"method":"GET","path":"/api/v4/projects","params":[{"key":"action","value":"git-upload-pack"},{"key":"changes","value":"_any"},{"key":"key_id","value":"secret"},{"key":"secret_token","value":"[FILTERED]"}],"host":"localhost","ip":"::1","ua":"Ruby","route":"/api/:version/projects","user_id":1,"username":"root","queue_duration":100.31,"gitaly_calls":30}
```

In a single line, we've included all the information that a user needs
to understand what happened: the timestamp, HTTP method and path, user
ID, etc.

### How to use JSON logging

Suppose you want to log the events that happen in a project
importer. You want to log issues created, merge requests, etc. as the
importer progresses. Here's what to do:

1. Look at [the list of GitLab Logs](../administration/logs.md) to see
   if your log message might belong with one of the existing log files.
1. If there isn't a good place, consider creating a new filename, but
   check with a maintainer if it makes sense to do so. A log file should
   make it easy for people to search pertinent logs in one place. For
   example, `geo.log` contains all logs pertaining to GitLab Geo.
   To create a new file:
   1. Choose a filename (e.g. `importer_json.log`).
   1. Create a new subclass of `Gitlab::JsonLogger`:

      ```ruby
      module Gitlab
        module Import
          class Logger < ::Gitlab::JsonLogger
            def self.file_name_noext
              'importer'
            end
          end
         end
      end
      ```

   1. In your class where you want to log, you might initialize the logger as an instance variable:

      ```ruby
      attr_accessor :logger

      def initialize
        @logger = Gitlab::Import::Logger.build
      end
      ```

      Note that it's useful to memoize this because creating a new logger
      each time you log will open a file, adding unnecessary overhead.

1. Now insert log messages into your code. When adding logs,
   make sure to include all the context as key-value pairs:

   ```ruby
   # BAD
   logger.info("Unable to create project #{project.id}")
   ```

   ```ruby
   # GOOD
   logger.info(message: "Unable to create project", project_id: project.id)
   ```

1. Be sure to create a common base structure of your log messages. For example,
   all messages might have `current_user_id` and `project_id` to make it easier
   to search for activities by user for a given time.

1. Do NOT mix and match types. Elasticsearch won't be able to index your
   logs properly if you [mix integer and string
   types](https://www.elastic.co/guide/en/elasticsearch/guide/current/mapping.html#_avoiding_type_gotchas):

   ```ruby
   # BAD
   logger.info(message: "Import error", error: 1)
   logger.info(message: "Import error", error: "I/O failure")
   ```

   ```ruby
   # GOOD
   logger.info(message: "Import error", error_code: 1, error: "I/O failure")
   ```

## Multi-destination Logging

GitLab is transitioning from unstructured/plaintext logs to structured/JSON logs.  During this transition period some logs will be recorded in multiple formats through multi-destination logging.

### How to use multi-destination logging

Create a new logger class, inheriting from `MultiDestinationLogger` and add an array of loggers to a `LOGGERS` constant. The loggers should be classes that descend from `Gitlab::Logger`. e.g. the user defined loggers in the following examples, could be inheriting from `Gitlab::Logger` and `Gitlab::JsonLogger`, respectively.

You must specify one of the loggers as the `primary_logger`. The `primary_logger` will be used when information about this multi-destination logger is displayed in the app, e.g. using the `Gitlab::Logger.read_latest` method.

The following example sets one of the defined `LOGGERS` as a `primary_logger`.

```ruby
module Gitlab
  class FancyMultiLogger < Gitlab::MultiDestinationLogger
    LOGGERS = [UnstructuredLogger, StructuredLogger].freeze

    def self.loggers
      LOGGERS
    end

    def primary_logger
      UnstructuredLogger
    end
  end
end
```

You can now call the usual logging methods on this multi-logger, e.g.

```ruby
FancyMultiLogger.info(message: "Information")
```

This message will be logged by each logger registered in `FancyMultiLogger.loggers`.

### Passing a string or hash for logging

When passing a string or hash to a `MultiDestinationLogger`, the log lines could be formatted differently, depending on the kinds of `LOGGERS` set.

e.g. let's partially define the loggers from the previous example:

```ruby
module Gitlab
  # Similar to AppTextLogger
  class UnstructuredLogger < Gitlab::Logger
    ...
  end

  # Similar to AppJsonLogger
  class StructuredLogger < Gitlab::JsonLogger
    ...
  end
end
```

Here are some examples of how messages would be handled by both the loggers.

1. When passing a string

```ruby
FancyMultiLogger.info("Information")

# UnstructuredLogger
I, [2020-01-13T18:48:49.201Z #5647]  INFO -- : Information

# StructuredLogger
{:severity=>"INFO", :time=>"2020-01-13T11:02:41.559Z", :correlation_id=>"b1701f7ecc4be4bcd4c2d123b214e65a", :message=>"Information"}
```

1. When passing a hash

```ruby
FancyMultiLogger.info({:message=>"This is my message", :project_id=>123})

# UnstructuredLogger
I, [2020-01-13T19:01:17.091Z #11056]  INFO -- : {"message"=>"Message", "project_id"=>"123"}

# StructuredLogger
{:severity=>"INFO", :time=>"2020-01-13T11:06:09.851Z", :correlation_id=>"d7e0886f096db9a8526a4f89da0e45f6", :message=>"This is my message", :project_id=>123}
```

### Logging context metadata (through Rails or Grape requests)

`Gitlab::ApplicationContext` stores metadata in a request
lifecycle, which can then be added to the web request
or Sidekiq logs.

Entry points can be seen at:

- [`ApplicationController`](https://gitlab.com/gitlab-org/gitlab/blob/master/app/controllers/application_controller.rb)
- [External API](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/api/api.rb)
- [Internal API](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/api/internal/base.rb)

#### Adding attributes

When adding new attributes, make sure they're exposed within the context of the entry points above and:

- Pass them within the hash to the `with_context` (or `push`) method (make sure to pass a Proc if the
method or variable shouldn't be evaluated right away)
- Change `Gitlab::ApplicationContext` to accept these new values
- Make sure the new attributes are accepted at [`Labkit::Context`](https://gitlab.com/gitlab-org/labkit-ruby/blob/master/lib/labkit/context.rb)

See our [HOWTO: Use Sidekiq metadata logs](https://www.youtube.com/watch?v=_wDllvO_IY0) for further knowledge on
creating visualizations in Kibana.

**Note:**
The fields of the context are currently only logged for Sidekiq jobs triggered
through web requests. See the
[follow-up work](https://gitlab.com/gitlab-com/gl-infra/scalability/issues/68)
for more information.

## Exception Handling

It often happens that you catch the exception and want to track it.

It should be noted that manual logging of exceptions is not allowed, as:

1. Manual logged exceptions can leak confidential data,
1. Manual logged exception very often require to clean backtrace
   which reduces the boilerplate,
1. Very often manually logged exception needs to be tracked to Sentry as well,
1. Manually logged exceptions does not use `correlation_id`, which makes hard
   to pin them to request, user and context in which this exception was raised,
1. It is very likely that manually logged exceptions will end-up across
   multiple files, which increases burden scraping all logging files.

To avoid duplicating and having consistent behavior the `Gitlab::ErrorTracking`
provides helper methods to track exceptions:

1. `Gitlab::ErrorTracking.track_and_raise_exception`: this method logs,
   sends exception to Sentry (if configured) and re-raises the exception,
1. `Gitlab::ErrorTracking.track_exception`: this method only logs
   and sends exception to Sentry (if configured),
1. `Gitlab::ErrorTracking.log_exception`: this method only logs the exception,
   and DOES NOT send the exception to Sentry,
1. `Gitlab::ErrorTracking.track_and_raise_for_dev_exception`: this method logs,
   sends exception to Sentry (if configured) and re-raises the exception
  for development and test enviroments.

It is advised to only use `Gitlab::ErrorTracking.track_and_raise_exception`
and `Gitlab::ErrorTracking.track_exception` as presented on below examples.

Consider adding additional extra parameters to provide more context
for each tracked exception.

### Example

```ruby
class MyService < ::BaseService
  def execute
    project.perform_expensive_operation

    success
  rescue => e
    Gitlab::ErrorTracking.track_exception(e, project_id: project.id)

    error('Exception occurred')
  end
end
```

```ruby
class MyService < ::BaseService
  def execute
    project.perform_expensive_operation

    success
  rescue => e
    Gitlab::ErrorTracking.track_and_raise_exception(e, project_id: project.id)
  end
end
```

## Additional steps with new log files

1. Consider log retention settings. By default, Omnibus will rotate any
   logs in `/var/log/gitlab/gitlab-rails/*.log` every hour and [keep at
   most 30 compressed files](https://docs.gitlab.com/omnibus/settings/logs.html#logrotate).
   On GitLab.com, that setting is only 6 compressed files. These settings should suffice
   for most users, but you may need to tweak them in [Omnibus GitLab](https://gitlab.com/gitlab-org/omnibus-gitlab).

1. If you add a new file, submit an issue to the [production
   tracker](https://gitlab.com/gitlab-com/gl-infra/production/issues) or
   a merge request to the [gitlab_fluentd](https://gitlab.com/gitlab-cookbooks/gitlab_fluentd)
   project. See [this example](https://gitlab.com/gitlab-cookbooks/gitlab_fluentd/merge_requests/51/diffs).

1. Be sure to update the [GitLab CE/EE documentation](../administration/logs.md) and the [GitLab.com
   runbooks](https://gitlab.com/gitlab-com/runbooks/blob/master/howto/logging.md).
