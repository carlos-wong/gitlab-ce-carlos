# GitLab Prometheus metrics

>**Note:**
Available since [Omnibus GitLab 9.3][29118]. For
installations from source you'll have to configure it yourself.

To enable the GitLab Prometheus metrics:

1. Log into GitLab as an administrator, and go to the Admin area.
1. Click on the gear, then click on Settings.
1. Find the `Metrics - Prometheus` section, and click `Enable Prometheus Metrics`
1. [Restart GitLab][restart] for the changes to take effect

## Collecting the metrics

GitLab monitors its own internal service metrics, and makes them available at the
`/-/metrics` endpoint. Unlike other [Prometheus] exporters, in order to access
it, the client IP needs to be [included in a whitelist][whitelist].

For Omnibus and Chart installations, these metrics are automatically enabled and collected as of [GitLab 9.4](https://gitlab.com/gitlab-org/omnibus-gitlab/merge_requests/1702). For source installations or earlier versions, these metrics will need to be enabled manually and collected by a Prometheus server.

## Unicorn Metrics available

The following metrics are available:

| Metric                            | Type      | Since | Description |
|:--------------------------------- |:--------- |:----- |:----------- |
| db_ping_timeout                   | Gauge     | 9.4   | Whether or not the last database ping timed out |
| db_ping_success                   | Gauge     | 9.4   | Whether or not the last database ping succeeded |
| db_ping_latency_seconds           | Gauge     | 9.4   | Round trip time of the database ping |
| filesystem_access_latency_seconds | Gauge     | 9.4   | Latency in accessing a specific filesystem |
| filesystem_accessible             | Gauge     | 9.4   | Whether or not a specific filesystem is accessible |
| filesystem_write_latency_seconds  | Gauge     | 9.4   | Write latency of a specific filesystem |
| filesystem_writable               | Gauge     | 9.4   | Whether or not the filesystem is writable |
| filesystem_read_latency_seconds   | Gauge     | 9.4   | Read latency of a specific filesystem |
| filesystem_readable               | Gauge     | 9.4   | Whether or not the filesystem is readable |
| http_requests_total               | Counter   | 9.4   | Rack request count |
| http_request_duration_seconds     | Histogram | 9.4   | HTTP response time from rack middleware |
| pipelines_created_total           | Counter   | 9.4   | Counter of pipelines created |
| rack_uncaught_errors_total        | Counter   | 9.4   | Rack connections handling uncaught errors count |
| redis_ping_timeout                | Gauge     | 9.4   | Whether or not the last redis ping timed out |
| redis_ping_success                | Gauge     | 9.4   | Whether or not the last redis ping succeeded |
| redis_ping_latency_seconds        | Gauge     | 9.4   | Round trip time of the redis ping |
| user_session_logins_total         | Counter   | 9.4   | Counter of how many users have logged in |
| upload_file_does_not_exist        | Counter   | 10.7 in EE, 11.5 in CE  | Number of times an upload record could not find its file |
| failed_login_captcha_total        | Gauge     | 11.0  | Counter of failed CAPTCHA attempts during login |
| successful_login_captcha_total    | Gauge     | 11.0  | Counter of successful CAPTCHA attempts during login |
| unicorn_active_connections        | Gauge     | 11.0  | The number of active Unicorn connections (workers) |
| unicorn_queued_connections        | Gauge     | 11.0  | The number of queued Unicorn connections |
| unicorn_workers                   | Gauge     | 12.0  | The number of Unicorn workers |

## Sidekiq Metrics available for Geo **[PREMIUM]**

Sidekiq jobs may also gather metrics, and these metrics can be accessed if the Sidekiq exporter is enabled (e.g. via
the `monitoring.sidekiq_exporter` configuration option in `gitlab.yml`.

| Metric                                       | Type    | Since | Description | Labels |
|:-------------------------------------------- |:------- |:----- |:----------- |:------ |
| geo_db_replication_lag_seconds               | Gauge   | 10.2  | Database replication lag (seconds) | url
| geo_repositories                             | Gauge   | 10.2  | Total number of repositories available on primary | url
| geo_repositories_synced                      | Gauge   | 10.2  | Number of repositories synced on secondary | url
| geo_repositories_failed                      | Gauge   | 10.2  | Number of repositories failed to sync on secondary | url
| geo_lfs_objects                              | Gauge   | 10.2  | Total number of LFS objects available on primary | url
| geo_lfs_objects_synced                       | Gauge   | 10.2  | Number of LFS objects synced on secondary | url
| geo_lfs_objects_failed                       | Gauge   | 10.2  | Number of LFS objects failed to sync on secondary | url
| geo_attachments                              | Gauge   | 10.2  | Total number of file attachments available on primary | url
| geo_attachments_synced                       | Gauge   | 10.2  | Number of attachments synced on secondary | url
| geo_attachments_failed                       | Gauge   | 10.2  | Number of attachments failed to sync on secondary | url
| geo_last_event_id                            | Gauge   | 10.2  | Database ID of the latest event log entry on the primary | url
| geo_last_event_timestamp                     | Gauge   | 10.2  | UNIX timestamp of the latest event log entry on the primary | url
| geo_cursor_last_event_id                     | Gauge   | 10.2  | Last database ID of the event log processed by the secondary | url
| geo_cursor_last_event_timestamp              | Gauge   | 10.2  | Last UNIX timestamp of the event log processed by the secondary | url
| geo_status_failed_total                      | Counter | 10.2  | Number of times retrieving the status from the Geo Node failed | url
| geo_last_successful_status_check_timestamp   | Gauge   | 10.2  | Last timestamp when the status was successfully updated | url
| geo_lfs_objects_synced_missing_on_primary    | Gauge   | 10.7  | Number of LFS objects marked as synced due to the file missing on the primary | url
| geo_job_artifacts_synced_missing_on_primary  | Gauge   | 10.7  | Number of job artifacts marked as synced due to the file missing on the primary | url
| geo_attachments_synced_missing_on_primary    | Gauge   | 10.7  | Number of attachments marked as synced due to the file missing on the primary | url
| geo_repositories_checksummed_count           | Gauge   | 10.7  | Number of repositories checksummed on primary | url
| geo_repositories_checksum_failed_count       | Gauge   | 10.7  | Number of repositories failed to calculate the checksum on primary | url
| geo_wikis_checksummed_count                  | Gauge   | 10.7  | Number of wikis checksummed on primary | url
| geo_wikis_checksum_failed_count              | Gauge   | 10.7  | Number of wikis failed to calculate the checksum on primary | url
| geo_repositories_verified_count              | Gauge   | 10.7  | Number of repositories verified on secondary | url
| geo_repositories_verification_failed_count   | Gauge   | 10.7  | Number of repositories failed to verify on secondary | url
| geo_repositories_checksum_mismatch_count     | Gauge   | 10.7  | Number of repositories that checksum mismatch on secondary | url
| geo_wikis_verified_count                     | Gauge   | 10.7  | Number of wikis verified on secondary | url
| geo_wikis_verification_failed_count          | Gauge   | 10.7  | Number of wikis failed to verify on secondary | url
| geo_wikis_checksum_mismatch_count            | Gauge   | 10.7  | Number of wikis that checksum mismatch on secondary | url
| geo_repositories_checked_count               | Gauge   | 11.1  | Number of repositories that have been checked via `git fsck` | url
| geo_repositories_checked_failed_count        | Gauge   | 11.1  | Number of repositories that have a failure from `git fsck` | url
| geo_repositories_retrying_verification_count | Gauge   | 11.2  | Number of repositories verification failures that Geo is actively trying to correct on secondary  | url
| geo_wikis_retrying_verification_count        | Gauge   | 11.2  | Number of wikis verification failures that Geo is actively trying to correct on secondary | url

### Ruby metrics

Some basic Ruby runtime metrics are available:

| Metric                                 | Type      | Since | Description |
|:-------------------------------------- |:--------- |:----- |:----------- |
| ruby_gc_duration_seconds_total         | Counter   | 11.1  | Time spent by Ruby in GC |
| ruby_gc_stat_...                       | Gauge     | 11.1  | Various metrics from [GC.stat] |
| ruby_file_descriptors                  | Gauge     | 11.1  | File descriptors per process |
| ruby_memory_bytes                      | Gauge     | 11.1  | Memory usage by process |
| ruby_sampler_duration_seconds_total    | Counter   | 11.1  | Time spent collecting stats |
| ruby_process_cpu_seconds_total         | Gauge     | 12.0  | Total amount of CPU time per process |
| ruby_process_max_fds                   | Gauge     | 12.0  | Maximum number of open file descriptors per process |
| ruby_process_resident_memory_bytes     | Gauge     | 12.0  | Memory usage by process, measured in bytes |
| ruby_process_start_time_seconds        | Gauge     | 12.0  | The elapsed time between system boot and the process started, measured in seconds |

[GC.stat]: https://ruby-doc.org/core-2.3.0/GC.html#method-c-stat

## Puma Metrics **[EXPERIMENTAL]**

When Puma is used instead of Unicorn, following metrics are available:

| Metric                                       | Type    | Since | Description |
|:-------------------------------------------- |:------- |:----- |:----------- |
| puma_workers                                 | Gauge   | 12.0  | Total number of workers |
| puma_running_workers                         | Gauge   | 12.0  | Number of booted workers |
| puma_stale_workers                           | Gauge   | 12.0  | Number of old workers |
| puma_phase                                   | Gauge   | 12.0  | Phase number (increased during phased restarts) |
| puma_running                                 | Gauge   | 12.0  | Number of running threads |
| puma_queued_connections                      | Gauge   | 12.0  | Number of connections in that worker's "todo" set waiting for a worker thread |
| puma_active_connections                      | Gauge   | 12.0  | Number of threads processing a request |
| puma_pool_capacity                           | Gauge   | 12.0  | Number of requests the worker is capable of taking right now |
| puma_max_threads                             | Gauge   | 12.0  | Maximum number of worker threads |
| puma_idle_threads                            | Gauge   | 12.0  | Number of spawned threads which are not processing a request |
| rack_state_total                             | Gauge   | 12.0  | Number of requests in a given rack state |
| puma_killer_terminations_total               | Gauge   | 12.0  | Number of workers terminated by PumaWorkerKiller |

## Metrics shared directory

GitLab's Prometheus client requires a directory to store metrics data shared between multi-process services.
Those files are shared among all instances running under Unicorn server.
The directory needs to be accessible to all running Unicorn's processes otherwise
metrics will not function correctly.

For best performance its advisable that this directory will be located in `tmpfs`.

Its location is configured using environment variable `prometheus_multiproc_dir`.

If GitLab is installed using Omnibus and `tmpfs` is available then metrics
directory will be automatically configured.

[← Back to the main Prometheus page](index.md)

[29118]: https://gitlab.com/gitlab-org/gitlab-ce/issues/29118
[Prometheus]: https://prometheus.io
[restart]: ../../restart_gitlab.md#omnibus-gitlab-restart
[whitelist]: ../ip_whitelist.md
[reconfigure]: ../../restart_gitlab.md#omnibus-gitlab-reconfigure
