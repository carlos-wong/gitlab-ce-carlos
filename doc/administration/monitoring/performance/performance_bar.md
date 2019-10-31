# Performance Bar

A Performance Bar can be displayed, to dig into the performance of a page. When
activated, it looks as follows:

![Performance Bar](img/performance_bar.png)

It allows you to see (from left to right):

- the current host serving the page
- time taken and number of DB queries, click through for details of these queries
  ![SQL profiling using the Performance Bar](img/performance_bar_sql_queries.png)
- time taken and number of [Gitaly] calls, click through for details of these calls
  ![Gitaly profiling using the Performance Bar](img/performance_bar_gitaly_calls.png)
- time taken and number of [Rugged] calls, click through for details of these calls
  ![Rugged profiling using the Performance Bar](img/performance_bar_rugged_calls.png)
- time taken and number of Redis calls, click through for details of these calls
  ![Redis profiling using the Performance Bar](img/performance_bar_redis_calls.png)

On the far right is a request selector that allows you to view the same metrics
(excluding the page timing and line profiler) for any requests made while the
page was open. Only the first two requests per unique URL are captured.

## Request warnings

For requests exceeding pre-defined limits, a warning icon will be shown
next to the failing metric, along with an explanation. In this example,
the Gitaly call duration exceeded the threshold:

![Gitaly call duration exceeded threshold](img/performance_bar_gitaly_threshold.png)

If any requests on the current page generated warnings, the icon will
appear next to the request selector:

![Request selector showing two requests with warnings](img/performance_bar_request_selector_warning.png)

And requests with warnings are indicated in the request selector with a
`(!)` after their path:

![Request selector showing dropdown](img/performance_bar_request_selector_warning_expanded.png)

## Enable the Performance Bar via the Admin panel

GitLab Performance Bar is disabled by default. To enable it for a given group,
navigate to the Admin area in **Settings > Metrics and Profiling > Profiling - Performance bar**
(`admin/application_settings/metrics_and_profiling`).

The only required setting you need to set is the full path of the group that
will be allowed to display the Performance Bar.
Make sure _Enable the Performance Bar_ is checked and hit
**Save** to save the changes.

Once the Performance Bar is enabled, you will need to press the [<kbd>p</kbd> +
<kbd>b</kbd> keyboard shortcut](../../../workflow/shortcuts.md) to actually
display it.

You can toggle the Bar using the same shortcut.

![GitLab Performance Bar Admin Settings](img/performance_bar_configuration_settings.png)

[Gitaly]: ../../gitaly/index.md
[Rugged]: ../../high_availability/nfs.md#improving-nfs-performance-with-gitlab
