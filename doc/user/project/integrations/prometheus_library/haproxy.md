---
stage: Monitor
group: Respond
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Monitoring HAProxy (DEPRECATED) **(FREE)**

> [Deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/346541) in GitLab 14.7.

WARNING:
This feature is in its end-of-life process. It is [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/346541)
in GitLab 14.7, and is planned for removal in GitLab 16.0.

GitLab has support for automatically detecting and monitoring HAProxy. This is provided by leveraging the [HAProxy Exporter](https://github.com/prometheus/haproxy_exporter), which translates HAProxy statistics into a Prometheus readable form.

## Requirements

The [Prometheus service](../prometheus.md) must be enabled.

## Metrics supported

| Name | Query |
| ---- | ----- |
| Throughput (req/sec) | `sum(rate(haproxy_frontend_http_requests_total{%{environment_filter}}[2m])) by (code)` |
| HTTP Error Rate (%) | `sum(rate(haproxy_frontend_http_requests_total{code="5xx",%{environment_filter}}[2m])) / sum(rate(haproxy_frontend_http_requests_total{%{environment_filter}}[2m]))` |

## Configuring Prometheus to monitor for HAProxy metrics

To get started with NGINX monitoring, you should install and configure the [HAProxy exporter](https://github.com/prometheus/haproxy_exporter) which parses these statistics and translates them into a Prometheus monitoring endpoint.

## Specifying the Environment label

In order to isolate and only display relevant metrics for a given environment
however, GitLab needs a method to detect which labels are associated. To do this, GitLab [looks for an `environment` label](index.md#identifying-environments).
