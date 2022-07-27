---
stage: none
group: unassigned
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Sidekiq Compatibility across Updates

The arguments for a Sidekiq job are stored in a queue while it is
scheduled for execution. During a online update, this could lead to
several possible situations:

1. An older version of the application publishes a job, which is executed by an
   upgraded Sidekiq node.
1. A job is queued before an upgrade, but executed after an upgrade.
1. A job is queued by a node running the newer version of the application, but
   executed on a node running an older version of the application.

## Adding new workers

On GitLab.com, we [do not currently have a Sidekiq deployment in the
canary stage](https://gitlab.com/gitlab-org/gitlab/-/issues/19239). This
means that a new worker than can be scheduled from an HTTP endpoint may
be scheduled from canary but not run on Sidekiq until the full
production deployment is complete. This can be several hours later than
scheduling the job. For some workers, this will not be a problem. For
others - particularly [latency-sensitive
jobs](worker_attributes.md#latency-sensitive-jobs) - this will result in a poor user
experience.

This only applies to new worker classes when they are first introduced.
As we recommend [using feature flags](../feature_flags/) as a general
development process, it's best to control the entire change (including
scheduling of the new Sidekiq worker) with a feature flag.

## Changing the arguments for a worker

Jobs need to be backward and forward compatible between consecutive versions
of the application. Adding or removing an argument may cause problems
during deployment before all Rails and Sidekiq nodes have the updated code.

### Deprecate and remove an argument

**Before you remove arguments from the `perform_async` and `perform` methods.**, deprecate them. The
following example deprecates and then removes `arg2` from the `perform_async` method:

1. Provide a default value (usually `nil`) and use a comment to mark the
   argument as deprecated in the coming minor release. (Release M)

    ```ruby
    class ExampleWorker
      # Keep arg2 parameter for backwards compatibility.
      def perform(object_id, arg1, arg2 = nil)
        # ...
      end
    end
    ```

1. One minor release later, stop using the argument in `perform_async`. (Release M+1)

    ```ruby
    ExampleWorker.perform_async(object_id, arg1)
    ```

1. At the next major release, remove the value from the worker class. (Next major release)

    ```ruby
    class ExampleWorker
      def perform(object_id, arg1)
        # ...
      end
    end
    ```

### Add an argument

There are two options for safely adding new arguments to Sidekiq workers:

1. Set up a [multi-step deployment](#multi-step-deployment) in which the new argument is first added to the worker.
1. Use a [parameter hash](#parameter-hash) for additional arguments. This is perhaps the most flexible option.

#### Multi-step deployment

This approach requires multiple releases.

1. Add the argument to the worker with a default value (Release M).

    ```ruby
    class ExampleWorker
      def perform(object_id, new_arg = nil)
        # ...
      end
    end
    ```

1. Add the new argument to all the invocations of the worker (Release M+1).

    ```ruby
    ExampleWorker.perform_async(object_id, new_arg)
    ```

1. Remove the default value (Release M+2).

    ```ruby
    class ExampleWorker
      def perform(object_id, new_arg)
        # ...
      end
    end
    ```

#### Parameter hash

This approach doesn't require multiple releases if an existing worker already
uses a parameter hash.

1. Use a parameter hash in the worker to allow future flexibility.

    ```ruby
    class ExampleWorker
      def perform(object_id, params = {})
        # ...
      end
    end
    ```

## Removing workers

Try to avoid removing workers and their queues in minor and patch
releases.

During online update instance can have pending jobs and removing the queue can
lead to those jobs being stuck forever. If you can't write migration for those
Sidekiq jobs, please consider removing the worker in a major release only.

## Renaming queues

For the same reasons that removing workers is dangerous, care should be taken
when renaming queues.

When renaming queues, use the `sidekiq_queue_migrate` helper migration method
in a **post-deployment migration**:

```ruby
class MigrateTheRenamedSidekiqQueue < Gitlab::Database::Migration[2.0]
  restrict_gitlab_migration gitlab_schema: :gitlab_main
  disable_ddl_transaction!

  def up
    sidekiq_queue_migrate 'old_queue_name', to: 'new_queue_name'
  end

  def down
    sidekiq_queue_migrate 'new_queue_name', to: 'old_queue_name'
  end
end

```

You must rename the queue in a post-deployment migration not in a normal
migration. Otherwise, it runs too early, before all the workers that
schedule these jobs have stopped running. See also [other examples](../database/post_deployment_migrations.md#use-cases).
