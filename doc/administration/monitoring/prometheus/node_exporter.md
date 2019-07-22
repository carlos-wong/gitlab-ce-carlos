# Node exporter

>**Note:**
Available since Omnibus GitLab 8.16. For installations from source you'll
have to install and configure it yourself.

The [node exporter] allows you to measure various machine resources such as
memory, disk and CPU utilization.

To enable the node exporter:

1. [Enable Prometheus](index.md#configuring-prometheus)
1. Edit `/etc/gitlab/gitlab.rb`
1. Add or find and uncomment the following line, making sure it's set to `true`:

   ```ruby
   node_exporter['enable'] = true
   ```

1. Save the file and [reconfigure GitLab][reconfigure] for the changes to
   take effect

Prometheus will now automatically begin collecting performance data from
the node exporter exposed under `localhost:9100`.

[← Back to the main Prometheus page](index.md)

[node exporter]: https://github.com/prometheus/node_exporter
[prometheus]: https://prometheus.io
[reconfigure]: ../../restart_gitlab.md#omnibus-gitlab-reconfigure
