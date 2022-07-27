---
stage: Configure
group: Configure
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Create a Civo Kubernetes cluster

Every new Civo account receives [$250 in credit](https://civo.com/signup) to get started with the GitLab integration with Civo Kubernetes. You can also use a marketplace app to install GitLab on your Civo Kubernetes cluster.

Learn how to create a new cluster on Civo Kubernetes through
[Infrastructure as Code (IaC)](../../index.md). This process uses the Civo
and Kubernetes Terraform providers to create Civo Kubernetes clusters. You connect the clusters to GitLab
by using the GitLab agent for Kubernetes.

**Prerequisites:**

- A [Civo account](https://civo.com/signup).
- [A runner](https://docs.gitlab.com/runner/install/) you can use to run the GitLab CI/CD pipeline.

**Steps:**

1. [Import the example project](#import-the-example-project).
1. [Register the agent for Kubernetes](#register-the-agent).
1. [Configure your project](#configure-your-project).
1. [Provision your cluster](#provision-your-cluster).

## Import the example project

To create a cluster from GitLab using Infrastructure as Code, you must
create a project to manage the cluster from. In this tutorial, you start with
a sample project and modify it according to your needs.

Start by [importing the example project by URL](../../../project/import/repo_by_url.md).

To import the project:

1. On the top bar, select **Menu > Create new project**.
1. Select **Import project**.
1. Select **Repository by URL**.
1. For the **Git repository URL**, enter `https://gitlab.com/civocloud/gitlab-terraform-civo.git`.
1. Complete the fields and select **Create project**.

This project provides you with:

- A [cluster on Civo](https://gitlab.com/civocloud/gitlab-terraform-civo/-/blob/master/civo.tf) with defaults for name, region, node count, and Kubernetes version.
- The [GitLab agent for Kubernetes](https://gitlab.com/civocloud/gitlab-terraform-civo/-/blob/master/agent.tf) installed in the cluster.

## Register the agent

To create a GitLab agent for Kubernetes:

1. On the left sidebar, select **Infrastructure > Kubernetes clusters**.
1. Select **Connect a cluster (agent)**.
1. From the **Select an agent** dropdown list, select `civo-agent` and select **Register an agent**.
1. GitLab generates a registration token for the agent. Securely store this secret token, as you will need it later.
1. GitLab provides an address for the agent server (KAS), which you will also need later.

## Configure your project

Use CI/CD environment variables to configure your project.

**Required configuration:**

1. On the left sidebar, select **Settings > CI/CD**.
1. Expand **Variables**.
1. Set the variable `BASE64_CIVO_TOKEN` to the [token](https://www.civo.com/account/security) from your Civo account.
1. Set the variable `TF_VAR_agent_token` to the agent token you received in the previous task.
1. Set the variable `TF_VAR_kas_address` to the agent server address in the previous task.

![img/variables_civo.png](img/variables_civo.png)

**Optional configuration:**

The file [`variables.tf`](https://gitlab.com/civocloud/gitlab-terraform-civo/-/blob/master/variables.tf)
contains other variables that you can override according to your needs:

- `TF_VAR_civo_region`: Set your cluster's region.
- `TF_VAR_cluster_name`: Set your cluster's name.
- `TF_VAR_cluster_description`: Set a description for the cluster. To create a reference to your GitLab project on your Civo cluster detail page, set this value to `$CI_PROJECT_URL`. This value helps you determine which project was responsible for provisioning the cluster you see on the Civo dashboard.
- `TF_VAR_target_nodes_size`: Set the size of the nodes to use for the cluster
- `TF_VAR_num_target_nodes`: Set the number of Kubernetes nodes.
- `TF_VAR_agent_version`: Set the version of the GitLab agent.
- `TF_VAR_agent_namespace`: Set the Kubernetes namespace for the GitLab agent.

Refer to the [Civo Terraform provider](https://registry.terraform.io/providers/civo/civo/latest/docs/resources/kubernetes_cluster) and the [Kubernetes Terraform provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs) documentation for further resource options.

## Provision your cluster

After configuring your project, manually trigger the provisioning of your cluster. In GitLab:

1. On the left sidebar, go to **CI/CD > Pipelines**.
1. Next to **Play** (**{play}**), select the dropdown icon (**{angle-down}**).
1. Select **Deploy** to manually trigger the deployment job.

When the pipeline finishes successfully, you can see your new cluster:

- In Civo dashboard: on your [Kubernetes tab](https://www.civo.com/account/kubernetes).
- In GitLab: from your project's sidebar, select **Infrastructure > Kubernetes clusters**.

## Use your cluster

After you provision the cluster, it is connected to GitLab and is ready for deployments. To check the connection:

1. On the left sidebar, select **Infrastructure > Kubernetes clusters**.
1. In the list, view the **Connection status** column.

For more information about the capabilities of the connection, see [the GitLab agent for Kubernetes documentation](../index.md).

## Remove the cluster

A cleanup job is not included in your pipeline by default. To remove all created resources, you
must modify your GitLab CI/CD template before running the cleanup job.

To remove all resources:

1. Add the following to your `.gitlab-ci.yml` file:

    ```yaml
    stages:
      - init
      - validate
      - build
      - deploy
      - cleanup

    destroy:
      extends: .destroy
      needs: []
    ```

1. On the left sidebar, select **CI/CD > Pipelines** and select the most recent pipeline.
1. For the `destroy` job, select **Play** (**{play}**).

## Civo support

This Civo integration is supported by Civo. Send your support requests to [Civo support](https://www.civo.com/contact).
