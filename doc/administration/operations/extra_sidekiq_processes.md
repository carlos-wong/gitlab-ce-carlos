---
stage: Systems
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Run multiple Sidekiq processes **(FREE SELF)**

GitLab allows you to start multiple Sidekiq processes.
These processes can be used to consume a dedicated set
of queues. This can be used to ensure certain queues always have dedicated
workers, no matter the number of jobs to be processed.

NOTE:
The information in this page applies only to Omnibus GitLab.

## Available Sidekiq queues

For a list of the existing Sidekiq queues, check the following files:

- [Queues for both GitLab Community and Enterprise Editions](https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/workers/all_queues.yml)
- [Queues for GitLab Enterprise Editions only](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/app/workers/all_queues.yml)

Each entry in the above files represents a queue on which Sidekiq processes
can be started.

## Start multiple processes

> - [Introduced](https://gitlab.com/gitlab-org/omnibus-gitlab/-/merge_requests/4006) in GitLab 12.10, starting multiple processes with Sidekiq cluster.
> - [Sidekiq cluster moved](https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/181) to GitLab Free in 12.10.
> - [Sidekiq cluster became default](https://gitlab.com/gitlab-org/omnibus-gitlab/-/merge_requests/4140) in GitLab 13.0.

When starting multiple processes, the number of processes should
equal (and **not** exceed) the number of CPU cores you want to
dedicate to Sidekiq. Each Sidekiq process can use only 1 CPU
core, subject to the available workload and concurrency settings.

To start multiple processes:

1. Using the `sidekiq['queue_groups']` array setting, specify how many processes to
   create using `sidekiq-cluster` and which queue they should handle.
   Each item in the array equates to one additional Sidekiq
   process, and values in each item determine the queues it works on.

   For example, the following setting creates three Sidekiq processes, one to run on
   `elastic_commit_indexer`, one to run on `mailers`, and one process running on all queues:

   ```ruby
   sidekiq['queue_groups'] = [
     "elastic_commit_indexer",
     "mailers",
     "*"
   ]
   ```

   To have an additional Sidekiq process handle multiple queues, add multiple
   queue names to its item delimited by commas. For example:

   ```ruby
   sidekiq['queue_groups'] = [
     "elastic_commit_indexer, elastic_association_indexer",
     "mailers",
     "*"
   ]
   ```

   [In GitLab 12.9](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/26594) and
   later, the special queue name `*` means all queues. This starts two
   processes, each handling all queues:

   ```ruby
   sidekiq['queue_groups'] = [
     "*",
     "*"
   ]
   ```

   `*` cannot be combined with concrete queue names - `*, mailers`
   just handles the `mailers` queue.

   When `sidekiq-cluster` is only running on a single node, make sure that at least
   one process is running on all queues using `*`. This ensures a process
   automatically picks up jobs in queues created in the future,
   including queues that have dedicated processes.

   If `sidekiq-cluster` is running on more than one node, you can also use
   [`--negate`](#negate-settings) and list all the queues that are already being
   processed.

1. Save the file and reconfigure GitLab for the changes to take effect:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

To view the Sidekiq processes in GitLab:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Monitoring > Background Jobs**.

## Negate settings

To have the Sidekiq process work on every queue **except** the ones
you list. In this example, we exclude all import-related jobs from a Sidekiq node:

1. Edit `/etc/gitlab/gitlab.rb` and add:

   ```ruby
   sidekiq['negate'] = true
   sidekiq['queue_selector'] = true
   sidekiq['queue_groups'] = [
      "feature_category=importers"
   ]
   ```

1. Save the file and reconfigure GitLab for the changes to take effect:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

## Queue selector

> - [Introduced](https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/45) in GitLab 12.8.
> - [Sidekiq cluster, including queue selector, moved](https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/181) to GitLab Free in 12.10.
> - [Renamed from `experimental_queue_selector` to `queue_selector`](https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/147) in GitLab 13.6.

In addition to selecting queues by name, as above, the `queue_selector` option
allows queue groups to be selected in a more general way using a [worker matching
query](extra_sidekiq_routing.md#worker-matching-query). After `queue_selector`
is set, all `queue_groups` must follow the aforementioned syntax.

In `/etc/gitlab/gitlab.rb`:

```ruby
sidekiq['enable'] = true
sidekiq['queue_selector'] = true
sidekiq['queue_groups'] = [
  # Run all non-CPU-bound queues that are high urgency
  'resource_boundary!=cpu&urgency=high',
  # Run all continuous integration and pages queues that are not high urgency
  'feature_category=continuous_integration,pages&urgency!=high',
  # Run all queues
  '*'
]
```

## Ignore all import queues

When [importing from GitHub](../../user/project/import/github.md) or
other sources, Sidekiq might use all of its resources to perform those
operations. To set up two separate `sidekiq-cluster` processes, where
one only processes imports and the other processes all other queues:

1. Edit `/etc/gitlab/gitlab.rb` and add:

   ```ruby
   sidekiq['enable'] = true
   sidekiq['queue_selector'] = true
   sidekiq['queue_groups'] = [
     "feature_category=importers",
     "feature_category!=importers"
   ]
   ```

1. Save the file and reconfigure GitLab for the changes to take effect:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

## Number of threads

By default each process defined under `sidekiq` starts with a
number of threads that equals the number of queues, plus one spare thread.
For example, a process that handles the `process_commit` and `post_receive`
queues uses three threads in total.

These thread run inside a single Ruby process, and each process
can only use a single CPU core. The usefulness of threading depends
on the work having some external dependencies to wait on, like database queries or
HTTP requests. Most Sidekiq deployments benefit from this threading, and when
running fewer queues in a process, increasing the thread count might be
even more desirable to make the most effective use of CPU resources.

### Manage thread counts explicitly

The correct maximum thread count (also called concurrency) depends on the workload.
Typical values range from `1` for highly CPU-bound tasks to `15` or higher for mixed
low-priority work. A reasonable starting range is `15` to `25` for a non-specialized
deployment.

You can find example values used by GitLab.com by searching for `concurrency:` in
[the Helm charts](https://gitlab.com/gitlab-com/gl-infra/k8s-workloads/gitlab-com/-/blob/master/releases/gitlab/values/gprd.yaml.gotmpl).
The values vary according to the work each specific deployment of Sidekiq does.
Any other specialized deployments with processes dedicated to specific queues should
have the concurrency tuned according to:
have the concurrency tuned according to:

- The CPU usage of each type of process.
- The throughput achieved.

Each thread requires a Redis connection, so adding threads may increase Redis
latency and potentially cause client timeouts. See the [Sidekiq documentation
about Redis](https://github.com/mperham/sidekiq/wiki/Using-Redis) for more
details.

#### When running Sidekiq cluster (default)

Running Sidekiq cluster is the default in GitLab 13.0 and later.

1. Edit `/etc/gitlab/gitlab.rb` and add:

   ```ruby
   sidekiq['min_concurrency'] = 15
   sidekiq['max_concurrency'] = 25
   ```

1. Save the file and reconfigure GitLab for the changes to take effect:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

`min_concurrency` and `max_concurrency` are independent; one can be set without
the other. Setting `min_concurrency` to `0` disables the limit.

For each queue group, let `N` be one more than the number of queues. The
concurrency is set to:

1. `N`, if it's between `min_concurrency` and `max_concurrency`.
1. `max_concurrency`, if `N` exceeds this value.
1. `min_concurrency`, if `N` is less than this value.

If `min_concurrency` is equal to `max_concurrency`, then this value is used
regardless of the number of queues.

When `min_concurrency` is greater than `max_concurrency`, it is treated as
being equal to `max_concurrency`.

#### When running a single Sidekiq process

Running a single Sidekiq process is the default in GitLab 12.10 and earlier.

WARNING:
Running Sidekiq directly was removed in GitLab
[14.0](https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/240).

1. Edit `/etc/gitlab/gitlab.rb` and add:

   ```ruby
   sidekiq['cluster'] = false
   sidekiq['concurrency'] = 25
   ```

1. Save the file and reconfigure GitLab for the changes to take effect:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

This sets the concurrency (number of threads) for the Sidekiq process.

## Modify the check interval

To modify `sidekiq-cluster`'s health check interval for the additional Sidekiq processes:

1. Edit `/etc/gitlab/gitlab.rb` and add (the value can be any integer number of seconds):

   ```ruby
   sidekiq['interval'] = 5
   ```

1. Save the file and [reconfigure GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

## Troubleshoot using the CLI

WARNING:
It's recommended to use `/etc/gitlab/gitlab.rb` to configure the Sidekiq processes.
If you experience a problem, you should contact GitLab support. Use the command
line at your own risk.

For debugging purposes, you can start extra Sidekiq processes by using the command
`/opt/gitlab/embedded/service/gitlab-rails/bin/sidekiq-cluster`. This command
takes arguments using the following syntax:

```shell
/opt/gitlab/embedded/service/gitlab-rails/bin/sidekiq-cluster [QUEUE,QUEUE,...] [QUEUE, ...]
```

Each separate argument denotes a group of queues that have to be processed by a
Sidekiq process. Multiple queues can be processed by the same process by
separating them with a comma instead of a space.

Instead of a queue, a queue namespace can also be provided, to have the process
automatically listen on all queues in that namespace without needing to
explicitly list all the queue names. For more information about queue namespaces,
see the relevant section in the
[Sidekiq development documentation](../../development/sidekiq/index.md#queue-namespaces).

For example, say you want to start 2 extra processes: one to process the
`process_commit` queue, and one to process the `post_receive` queue. This can be
done as follows:

```shell
/opt/gitlab/embedded/service/gitlab-rails/bin/sidekiq-cluster process_commit post_receive
```

If you instead want to start one process processing both queues, you'd use the
following syntax:

```shell
/opt/gitlab/embedded/service/gitlab-rails/bin/sidekiq-cluster process_commit,post_receive
```

If you want to have one Sidekiq process dealing with the `process_commit` and
`post_receive` queues, and one process to process the `gitlab_shell` queue,
you'd use the following:

```shell
/opt/gitlab/embedded/service/gitlab-rails/bin/sidekiq-cluster process_commit,post_receive gitlab_shell
```

### Monitor the `sidekiq-cluster` command

The `sidekiq-cluster` command does not terminate once it has started the desired
amount of Sidekiq processes. Instead, the process continues running and
forwards any signals to the child processes. This allows you to stop all
Sidekiq processes as you send a signal to the `sidekiq-cluster` process,
instead of having to send it to the individual processes.

If the `sidekiq-cluster` process crashes or receives a `SIGKILL`, the child
processes terminate themselves after a few seconds. This ensures you don't
end up with zombie Sidekiq processes.

This allows you to monitor the processes by hooking up
`sidekiq-cluster` to your supervisor of choice (for example, runit).

If a child process died the `sidekiq-cluster` command signals all remaining
process to terminate, then terminate itself. This removes the need for
`sidekiq-cluster` to re-implement complex process monitoring/restarting code.
Instead you should make sure your supervisor restarts the `sidekiq-cluster`
process whenever necessary.

### PID files

The `sidekiq-cluster` command can store its PID in a file. By default no PID
file is written, but this can be changed by passing the `--pidfile` option to
`sidekiq-cluster`. For example:

```shell
/opt/gitlab/embedded/service/gitlab-rails/bin/sidekiq-cluster --pidfile /var/run/gitlab/sidekiq_cluster.pid process_commit
```

Keep in mind that the PID file contains the PID of the `sidekiq-cluster`
command and not the PIDs of the started Sidekiq processes.

### Environment

The Rails environment can be set by passing the `--environment` flag to the
`sidekiq-cluster` command, or by setting `RAILS_ENV` to a non-empty value. The
default value can be found in `/opt/gitlab/etc/gitlab-rails/env/RAILS_ENV`.
