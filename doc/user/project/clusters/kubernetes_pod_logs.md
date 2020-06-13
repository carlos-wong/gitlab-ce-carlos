# Kubernetes Logs

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/4752) in [GitLab Ultimate](https://about.gitlab.com/pricing/) 11.0.
> [Moved](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/25455) to [GitLab Core](https://about.gitlab.com/pricing/) 12.9.

GitLab makes it easy to view the logs of running pods in [connected Kubernetes clusters](index.md).
By displaying the logs directly in GitLab, developers can avoid having to manage console tools or jump to a different interface.

NOTE: **Kubernetes + GitLab**
Everything you need to build, test, deploy, and run your app at scale.
[Learn more](https://about.gitlab.com/solutions/kubernetes/).

## Overview

[Kubernetes](https://kubernetes.io) logs can be viewed directly within GitLab.

![Pod logs](img/kubernetes_pod_logs_v12_9.png)

## Requirements

[Deploying to a Kubernetes environment](../deploy_boards.md#enabling-deploy-boards) is required in order to be able to use Logs.

## Usage

To access logs, you must have the right [permissions](../../permissions.md#project-members-permissions).

You can access them in two ways.

### From the project sidebar

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/merge_requests/22011) in GitLab 12.5.

Go to **{cloud-gear}** **Operations > Logs** on the sidebar menu.

![Sidebar menu](img/sidebar_menu_pod_logs_v12_5.png)

### From Deploy Boards

Logs can be displayed by clicking on a specific pod from [Deploy Boards](../deploy_boards.md):

1. Go to **{cloud-gear}** **Operations > Environments** and find the environment which contains the desired pod, like `production`.
1. On the **Environments** page, you should see the status of the environment's pods with [Deploy Boards](../deploy_boards.md).
1. When mousing over the list of pods, a tooltip will appear with the exact pod name and status.
   ![Deploy Boards pod list](img/pod_logs_deploy_board.png)
1. Click on the desired pod to bring up the logs view.

### Logs view

The logs view lets you filter the logs by:

- Pods.
- [From GitLab 12.4](https://gitlab.com/gitlab-org/gitlab/issues/5769), environments.
- [From GitLab 12.7](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/21656), [full text search](#full-text-search).
- [From GitLab 12.8](https://gitlab.com/gitlab-org/gitlab/issues/197879), dates.

Loading more than 500 log lines is possible from [GitLab 12.9](https://gitlab.com/gitlab-org/gitlab/-/issues/198050) onwards.

Support for pods with multiple containers is coming [in a future release](https://gitlab.com/gitlab-org/gitlab/issues/13404).

Support for historical data is coming [in a future release](https://gitlab.com/gitlab-org/gitlab/issues/196191).

### Filter by date

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/197879) in GitLab 12.8.

When you enable [Elastic Stack](../../clusters/applications.md#elastic-stack) on your cluster, you can filter by date.

Click on **Show last** to see the available options.

### Full text search

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/21656) in GitLab 12.7.

When you enable [Elastic Stack](../../clusters/applications.md#elastic-stack) on your cluster,
you can search the content of your logs through a search bar.

The search is passed on to Elasticsearch using the [simple_query_string](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-simple-query-string-query.html)
Elasticsearch function, which supports the following operators:

| Operator                   | Description                                                |
|----------------------------|------------------------------------------------------------|
|  `\|`                      | An OR operation.                                            |
| `-`                        | Negates a single token.                                     |
| `+`                        | An AND operation.                                           |
| `"`                        | Wraps a number of tokens to signify a phrase for searching. |
| `*` (at the end of a term) | A prefix query.                                             |
| `(` and `)`                | Precedence.                                                 |
| `~N` (after a word)        | Edit distance (fuzziness).                                  |
| `~N` (after a phrase)      | Slop amount.                                                |
