---
stage: Configure
group: Configure
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Connecting a Kubernetes cluster with GitLab

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/223061) in GitLab 13.4.
> - Support for `grpcs` [introduced](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/issues/7) in GitLab 13.6.
> - Agent server [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/300960) on GitLab.com under `wss://kas.gitlab.com` through an Early Adopter Program in GitLab 13.10.
> - [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/3834) in GitLab 13.11, the GitLab agent became available on GitLab.com.
> - [Moved](https://gitlab.com/groups/gitlab-org/-/epics/6290) from GitLab Premium to GitLab Free in 14.5.
> - [Renamed](https://gitlab.com/groups/gitlab-org/-/epics/7167) from "GitLab Kubernetes Agent" to "GitLab agent for Kubernetes" in GitLab 14.6.

You can connect your Kubernetes cluster with GitLab to deploy, manage,
and monitor your cloud-native solutions.

To connect a Kubernetes cluster to GitLab, you must first [install an agent in your cluster](install/index.md).

The agent runs in the cluster, and you can use it to:

- Communicate with a cluster, which is behind a firewall or NAT.
- Access API endpoints in a cluster in real time.
- Push information about events happening in the cluster.
- Enable a cache of Kubernetes objects, which are kept up-to-date with very low latency.

For more details about the agent's purpose and architecture, see the [architecture documentation](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/blob/master/doc/architecture.md).

## Workflows

You can choose from two primary workflows.

In a [**GitOps** workflow](gitops.md), you keep your Kubernetes manifests in GitLab. You install a GitLab agent in your cluster, and
any time you update your manifests, the agent updates the cluster. This workflow is fully driven with Git and is considered pull-based,
because the cluster is pulling updates from your GitLab repository.

In a [**CI/CD** workflow](ci_cd_workflow.md), you use GitLab CI/CD to query and update your cluster by using the Kubernetes API.
This workflow is considered push-based, because GitLab is pushing requests from GitLab CI/CD to your cluster.

## Supported cluster versions

GitLab supports the following Kubernetes versions. You can upgrade your
Kubernetes version to a supported version at any time:

- 1.24 (support ends on September 22, 2023 or when 1.27 becomes supported)
- 1.23 (support ends on February 22, 2023 or when 1.26 becomes supported)
- 1.22 (support ends on October 22, 2022)
- 1.21 (support ends on August 22, 2022)

GitLab aims to support a new minor Kubernetes version three months after its initial release. GitLab supports at least three production-ready Kubernetes minor
versions at any given time.

Support for deprecated APIs can be removed from the GitLab codebase when we drop support for the Kubernetes version that only supports the deprecated API.

Some GitLab features might work on versions not listed here. [This epic](https://gitlab.com/groups/gitlab-org/-/epics/4827) tracks support for Kubernetes versions.

## Migrate to the agent from the legacy certificate-based integration

Read about how to [migrate to the agent for Kubernetes](../../infrastructure/clusters/migrate_to_gitlab_agent.md) from the certificate-based integration.

## Related topics

- [GitOps workflow](gitops.md)
- [GitOps examples and learning materials](gitops.md#related-topics)
- [GitLab CI/CD workflow](ci_cd_workflow.md)
- [Install the agent](install/index.md)
- [Work with the agent](repository.md)
- [Troubleshooting](troubleshooting.md)
- [Guided explorations for a production ready GitOps setup](https://gitlab.com/groups/guided-explorations/gl-k8s-agent/gitops/-/wikis/home#gitlab-agent-for-kubernetes-gitops-working-examples)
- [CI/CD for Kubernetes examples and learning materials](ci_cd_workflow.md#related-topics)
- [Contribute to the agent's development](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/tree/master/doc)
