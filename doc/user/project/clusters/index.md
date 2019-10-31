# Kubernetes clusters

> - [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/35954) in GitLab 10.1 for projects.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/34758) in
>   GitLab 11.6 for [groups](../../group/clusters/index.md).
> - [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/39840) in
>   GitLab 11.11 for [instances](../../instance/clusters/index.md).

GitLab provides many features with a Kubernetes integration. Kubernetes can be
integrated with projects, but also:

- [Groups](../../group/clusters/index.md).
- [Instances](../../instance/clusters/index.md).

NOTE: **Scalable app deployment with GitLab and Google Cloud Platform**
[Watch the webcast](https://about.gitlab.com/webcast/scalable-app-deploy/) and learn how to spin up a Kubernetes cluster managed by Google Cloud Platform (GCP) in a few clicks.

## Overview

Using the GitLab project Kubernetes integration, you can:

- Use [Review Apps](../../../ci/review_apps/index.md).
- Run [pipelines](../../../ci/pipelines.md).
- [Deploy](#deploying-to-a-kubernetes-cluster) your applications.
- Detect and [monitor Kubernetes](#kubernetes-monitoring).
- Use it with [Auto DevOps](#auto-devops).
- Use [Web terminals](#web-terminals).
- Use [Deploy Boards](#deploy-boards-premium). **(PREMIUM)**
- Use [Canary Deployments](#canary-deployments-premium). **(PREMIUM)**
- View [Pod logs](#pod-logs-ultimate). **(ULTIMATE)**

You can also:

- Connect and deploy to an [Amazon EKS cluster](eks_and_gitlab/index.html).
- Run serverless workloads on [Kubernetes with Knative](serverless/index.md).

### Deploy Boards **(PREMIUM)**

GitLab's Deploy Boards offer a consolidated view of the current health and
status of each CI [environment](../../../ci/environments.md) running on Kubernetes,
displaying the status of the pods in the deployment. Developers and other
teammates can view the progress and status of a rollout, pod by pod, in the
workflow they already use without any need to access Kubernetes.

[Read more about Deploy Boards](../deploy_boards.md)

### Canary Deployments **(PREMIUM)**

Leverage [Kubernetes' Canary deployments](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/#canary-deployments)
and visualize your canary deployments right inside the Deploy Board, without
the need to leave GitLab.

[Read more about Canary Deployments](../canary_deployments.md)

### Pod logs **(ULTIMATE)**

GitLab makes it easy to view the logs of running pods in connected Kubernetes clusters. By displaying the logs directly in GitLab, developers can avoid having to manage console tools or jump to a different interface.

[Read more about Kubernetes pod logs](kubernetes_pod_logs.md)

### Kubernetes monitoring

Automatically detect and monitor Kubernetes metrics. Automatic monitoring of
[NGINX Ingress](../integrations/prometheus_library/nginx.md) is also supported.

[Read more about Kubernetes monitoring](../integrations/prometheus_library/kubernetes.md)

### Auto DevOps

Auto DevOps automatically detects, builds, tests, deploys, and monitors your
applications.

To make full use of Auto DevOps(Auto Deploy, Auto Review Apps, and Auto Monitoring)
you will need the Kubernetes project integration enabled.

[Read more about Auto DevOps](../../../topics/autodevops/index.md)

NOTE: **Note**
Kubernetes clusters can be used without Auto DevOps.

### Web terminals

NOTE: **Note:**
Introduced in GitLab 8.15. You must be the project owner or have `maintainer` permissions
to use terminals. Support is limited to the first container in the
first pod of your environment.

When enabled, the Kubernetes service adds [web terminal](../../../ci/environments.md#web-terminals)
support to your [environments](../../../ci/environments.md). This is based on the `exec` functionality found in
Docker and Kubernetes, so you get a new shell session within your existing
containers. To use this integration, you should deploy to Kubernetes using
the deployment variables above, ensuring any deployments, replica sets, and
pods are annotated with:

- `app.gitlab.com/env: $CI_ENVIRONMENT_SLUG`
- `app.gitlab.com/app: $CI_PROJECT_PATH_SLUG`

`$CI_ENVIRONMENT_SLUG` and `$CI_PROJECT_PATH_SLUG` are the values of
the CI variables.

## Adding and removing clusters

There are two options when adding a new cluster to your project:

- Associate your account with Google Kubernetes Engine (GKE) to
  [create new clusters](#add-new-gke-cluster) from within GitLab.
- Provide credentials to an
  [existing Kubernetes cluster](#add-existing-kubernetes-cluster).

### Add new GKE cluster

TIP: **Tip:**
Every new Google Cloud Platform (GCP) account receives [$300 in credit upon sign up](https://console.cloud.google.com/freetrial),
and in partnership with Google, GitLab is able to offer an additional $200 for new GCP accounts to get started with GitLab's
Google Kubernetes Engine Integration. All you have to do is [follow this link](https://cloud.google.com/partners/partnercredit/?PCN=a0n60000006Vpz4AAC) and apply for credit.

NOTE: **Note:**
The [Google authentication integration](../../../integration/google.md) must
be enabled in GitLab at the instance level. If that's not the case, ask your
GitLab administrator to enable it. On GitLab.com, this is enabled.

#### Requirements

Before creating your first cluster on Google Kubernetes Engine with GitLab's
integration, make sure the following requirements are met:

- A [billing account](https://cloud.google.com/billing/docs/how-to/manage-billing-account)
  is set up and you have permissions to access it.
- The Kubernetes Engine API and related service are enabled. It should work immediately but may take up to 10 minutes after you create a project. For more information see the
  ["Before you begin" section of the Kubernetes Engine docs](https://cloud.google.com/kubernetes-engine/docs/quickstart#before-you-begin).

#### Creating the cluster

If all of the above requirements are met, you can proceed to create and add a
new Kubernetes cluster to your project:

1. Navigate to your project's **Operations > Kubernetes** page.

   NOTE: **Note:**
   You need Maintainer [permissions](../../permissions.md) and above to access the Kubernetes page.

1. Click **Add Kubernetes cluster**.
1. Click **Create with Google Kubernetes Engine**.
1. Connect your Google account if you haven't done already by clicking the
   **Sign in with Google** button.
1. From there on, choose your cluster's settings:
   - **Kubernetes cluster name** - The name you wish to give the cluster.
   - **Environment scope** - The [associated environment](#setting-the-environment-scope-premium) to this cluster.
   - **Google Cloud Platform project** - Choose the project you created in your GCP
     console that will host the Kubernetes cluster. Learn more about
     [Google Cloud Platform projects](https://cloud.google.com/resource-manager/docs/creating-managing-projects).
   - **Zone** - Choose the [region zone](https://cloud.google.com/compute/docs/regions-zones/)
     under which the cluster will be created.
   - **Number of nodes** - Enter the number of nodes you wish the cluster to have.
   - **Machine type** - The [machine type](https://cloud.google.com/compute/docs/machine-types)
     of the Virtual Machine instance that the cluster will be based on.
   - **Enable Cloud Run on GKE (beta)** - Check this if you want to use Cloud Run on GKE for this cluster. See the [Cloud Run on GKE section](#cloud-run-on-gke) for more information.
   - **GitLab-managed cluster** - Leave this checked if you want GitLab to manage namespaces and service accounts for this cluster. See the [Managed clusters section](#gitlab-managed-clusters) for more information.
1. Finally, click the **Create Kubernetes cluster** button.

After a couple of minutes, your cluster will be ready to go. You can now proceed
to install some [pre-defined applications](#installing-applications).

NOTE: **Note:**
GitLab requires basic authentication enabled and a client certificate issued for
the cluster in order to setup an [initial service
account](#access-controls). Starting from [GitLab
11.10](https://gitlab.com/gitlab-org/gitlab-foss/issues/58208), the cluster
creation process will explicitly request that basic authentication and
client certificate is enabled.

NOTE: **Note:**
Starting from [GitLab 12.1](https://gitlab.com/gitlab-org/gitlab-foss/issues/55902), all GKE clusters created by GitLab are RBAC enabled. Take a look at the [RBAC section](#rbac-cluster-resources) for more information.

### Add existing Kubernetes cluster

NOTE: **Note:**
Kubernetes integration is not supported for arm64 clusters. See the issue [Helm Tiller fails to install on arm64 cluster](https://gitlab.com/gitlab-org/gitlab-foss/issues/64044) for details.

To add an existing Kubernetes cluster to your project:

1. Navigate to your project's **Operations > Kubernetes** page.

   NOTE: **Note:**
   You need Maintainer [permissions](../../permissions.md) and above to access the Kubernetes page.

1. Click **Add Kubernetes cluster**.
1. Click **Add an existing Kubernetes cluster** and fill in the details:
   - **Kubernetes cluster name** (required) - The name you wish to give the cluster.
   - **Environment scope** (required) - The
     [associated environment](#setting-the-environment-scope-premium) to this cluster.
   - **API URL** (required) -
     It's the URL that GitLab uses to access the Kubernetes API. Kubernetes
     exposes several APIs, we want the "base" URL that is common to all of them,
     e.g., `https://kubernetes.example.com` rather than `https://kubernetes.example.com/api/v1`.

     Get the API URL by running this command:

     ```sh
     kubectl cluster-info | grep 'Kubernetes master' | awk '/http/ {print $NF}'
     ```

   - **CA certificate** (required) - A valid Kubernetes certificate is needed to authenticate to the cluster. We will use the certificate created by default.
     - List the secrets with `kubectl get secrets`, and one should named similar to
      `default-token-xxxxx`. Copy that token name for use below.
     - Get the certificate by running this command:

     ```sh
     kubectl get secret <secret name> -o jsonpath="{['data']['ca\.crt']}" | base64 --decode
     ```

   - **Token** -
     GitLab authenticates against Kubernetes using service tokens, which are
     scoped to a particular `namespace`.
     **The token used should belong to a service account with
     [`cluster-admin`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles)
     privileges.** To create this service account:

     1. Create a file called `gitlab-admin-service-account.yaml` with contents:

        ```yaml
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: gitlab-admin
          namespace: kube-system
        ---
        apiVersion: rbac.authorization.k8s.io/v1beta1
        kind: ClusterRoleBinding
        metadata:
          name: gitlab-admin
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: ClusterRole
          name: cluster-admin
        subjects:
        - kind: ServiceAccount
          name: gitlab-admin
          namespace: kube-system
        ```

     1. Apply the service account and cluster role binding to your cluster:

        ```bash
        kubectl apply -f gitlab-admin-service-account.yaml
        ```

        Output:

        ```bash
        serviceaccount "gitlab-admin" created
        clusterrolebinding "gitlab-admin" created
        ```

     1. Retrieve the token for the `gitlab-admin` service account:

        ```bash
        kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep gitlab-admin | awk '{print $1}')
        ```

        Copy the `<authentication_token>` value from the output:

        ```yaml
        Name:         gitlab-admin-token-b5zv4
        Namespace:    kube-system
        Labels:       <none>
        Annotations:  kubernetes.io/service-account.name=gitlab-admin
                      kubernetes.io/service-account.uid=bcfe66ac-39be-11e8-97e8-026dce96b6e8

        Type:  kubernetes.io/service-account-token

        Data
        ====
        ca.crt:     1025 bytes
        namespace:  11 bytes
        token:      <authentication_token>
        ```

     NOTE: **Note:**
     For GKE clusters, you will need the
     `container.clusterRoleBindings.create` permission to create a cluster
     role binding. You can follow the [Google Cloud
     documentation](https://cloud.google.com/iam/docs/granting-changing-revoking-access)
     to grant access.

   - **GitLab-managed cluster** - Leave this checked if you want GitLab to manage namespaces and service accounts for this cluster. See the [Managed clusters section](#gitlab-managed-clusters) for more information.

   - **Project namespace** (optional) - You don't have to fill it in; by leaving
     it blank, GitLab will create one for you. Also:
     - Each project should have a unique namespace.
     - The project namespace is not necessarily the namespace of the secret, if
       you're using a secret with broader permissions, like the secret from `default`.
     - You should **not** use `default` as the project namespace.
     - If you or someone created a secret specifically for the project, usually
       with limited permissions, the secret's namespace and project namespace may
       be the same.

1. Finally, click the **Create Kubernetes cluster** button.

After a couple of minutes, your cluster will be ready to go. You can now proceed
to install some [pre-defined applications](#installing-applications).

### Enabling or disabling integration

After you have successfully added your cluster information, you can enable the
Kubernetes cluster integration:

1. Click the **Enabled/Disabled** switch
1. Hit **Save** for the changes to take effect

To disable the Kubernetes cluster integration, follow the same procedure.

### Removing integration

NOTE: **Note:**
You need Maintainer [permissions](../../permissions.md) and above to remove a Kubernetes cluster integration.

NOTE: **Note:**
When you remove a cluster, you only remove its relation to GitLab, not the
cluster itself. To remove the cluster, you can do so by visiting the GKE
dashboard or using `kubectl`.

To remove the Kubernetes cluster integration from your project, simply click the
**Remove integration** button. You will then be able to follow the procedure
and add a Kubernetes cluster again.

## Cluster configuration

This section covers important considerations for configuring Kubernetes
clusters with GitLab.

### Security implications

CAUTION: **Important:**
The whole cluster security is based on a model where [developers](../../permissions.md)
are trusted, so **only trusted users should be allowed to control your clusters**.

The default cluster configuration grants access to a wide set of
functionalities needed to successfully build and deploy a containerized
application. Bear in mind that the same credentials are used for all the
applications running on the cluster.

### Cloud Run on GKE

> [Introduced](https://gitlab.com/gitlab-org/gitlab/merge_requests/16566) in GitLab 12.4.

You can choose to use Cloud Run on GKE in place of installing Knative and Istio
separately after the cluster has been created. This means that Cloud Run
(Knative), Istio, and HTTP Load Balancing will be enabled on the cluster at
create time and cannot be [installed or uninstalled](../../clusters/applications.md) separately.

### GitLab-managed clusters

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/22011) in GitLab 11.5.
> Became [optional](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/26565) in GitLab 11.11.

You can choose to allow GitLab to manage your cluster for you. If your cluster is
managed by GitLab, resources for your projects will be automatically created. See the
[Access controls](#access-controls) section for details on which resources will
be created.

If you choose to manage your own cluster, project-specific resources will not be created
automatically. If you are using [Auto DevOps](../../../topics/autodevops/index.md), you will
need to explicitly provide the `KUBE_NAMESPACE` [deployment variable](#deployment-variables)
that will be used by your deployment jobs, otherwise a namespace will be created for you.

NOTE: **Note:**
If you [install applications](#installing-applications) on your cluster, GitLab will create
the resources required to run these even if you have chosen to manage your own cluster.

### Base domain

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/24580) in GitLab 11.8.

NOTE: **Note:**
You do not need to specify a base domain on cluster settings when using GitLab Serverless. The domain in that case
will be specified as part of the Knative installation. See [Installing Applications](#installing-applications).

Specifying a base domain will automatically set `KUBE_INGRESS_BASE_DOMAIN` as an environment variable.
If you are using [Auto DevOps](../../../topics/autodevops/index.md), this domain will be used for the different
stages. For example, Auto Review Apps and Auto Deploy.

The domain should have a wildcard DNS configured to the Ingress IP address. After Ingress has been installed (see [Installing Applications](#installing-applications)),
you can either:

- Create an `A` record that points to the Ingress IP address with your domain provider.
- Enter a wildcard DNS address using a service such as nip.io or xip.io. For example, `192.168.1.1.xip.io`.

### Access controls

When creating a cluster in GitLab, you will be asked if you would like to create either:

- An [Attribute-based access control (ABAC)](https://kubernetes.io/docs/reference/access-authn-authz/abac/) cluster.
- A [Role-based access control (RBAC)](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) cluster.

NOTE: **Note:**
[RBAC](#rbac-cluster-resources) is recommended and the GitLab default.

GitLab creates the necessary service accounts and privileges to install and run
[GitLab managed applications](#installing-applications). When GitLab creates the cluster,
a `gitlab` service account with `cluster-admin` privileges is created in the `default` namespace
to manage the newly created cluster.

  NOTE: **Note:**
  Restricted service account for deployment was [introduced](https://gitlab.com/gitlab-org/gitlab-foss/issues/51716) in GitLab 11.5.

When you install Helm into your cluster, the `tiller` service account
is created with `cluster-admin` privileges in the `gitlab-managed-apps`
namespace. This service account will be added to the installed Helm Tiller and will
be used by Helm to install and run [GitLab managed applications](#installing-applications).
Helm will also create additional service accounts and other resources for each
installed application. Consult the documentation of the Helm charts for each application
for details.

If you are [adding an existing Kubernetes cluster](#add-existing-kubernetes-cluster),
ensure the token of the account has administrator privileges for the cluster.

The resources created by GitLab differ depending on the type of cluster.

#### ABAC cluster resources

GitLab creates the following resources for ABAC clusters.

| Name                  | Type                 | Details                              | Created when               |
|:----------------------|:---------------------|:-------------------------------------|:---------------------------|
| `gitlab`              | `ServiceAccount`     | `default` namespace                         | Creating a new GKE Cluster |
| `gitlab-token`        | `Secret`             | Token for `gitlab` ServiceAccount           | Creating a new GKE Cluster |
| `tiller`              | `ServiceAccount`     | `gitlab-managed-apps` namespace             | Installing Helm Tiller     |
| `tiller-admin`        | `ClusterRoleBinding` | `cluster-admin` roleRef                     | Installing Helm Tiller     |
| Environment namespace | `Namespace`          | Contains all environment-specific resources | Deploying to a cluster     |
| Environment namespace | `ServiceAccount`     | Uses namespace of environment               | Deploying to a cluster     |
| Environment namespace | `Secret`             | Token for environment ServiceAccount        | Deploying to a cluster     |

#### RBAC cluster resources

GitLab creates the following resources for RBAC clusters.

| Name                  | Type                 | Details                                                                                                    | Created when               |
|:----------------------|:---------------------|:-----------------------------------------------------------------------------------------------------------|:---------------------------|
| `gitlab`              | `ServiceAccount`     | `default` namespace                                                                                        | Creating a new GKE Cluster |
| `gitlab-admin`        | `ClusterRoleBinding` | [`cluster-admin`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) roleRef | Creating a new GKE Cluster |
| `gitlab-token`        | `Secret`             | Token for `gitlab` ServiceAccount                                                                          | Creating a new GKE Cluster |
| `tiller`              | `ServiceAccount`     | `gitlab-managed-apps` namespace                                                                            | Installing Helm Tiller     |
| `tiller-admin`        | `ClusterRoleBinding` | `cluster-admin` roleRef                                                                                    | Installing Helm Tiller     |
| Environment namespace | `Namespace`          | Contains all environment-specific resources                                                                | Deploying to a cluster     |
| Environment namespace | `ServiceAccount`     | Uses namespace of environment                                                                              | Deploying to a cluster     |
| Environment namespace | `Secret`             | Token for environment ServiceAccount                                                                       | Deploying to a cluster     |
| Environment namespace | `RoleBinding`        | [`edit`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) roleRef          | Deploying to a cluster     |

NOTE: **Note:**
Environment-specific resources are only created if your cluster is [managed by GitLab](#gitlab-managed-clusters).

NOTE: **Note:**
If your cluster was created before GitLab 12.2, it will use a single namespace for all project environments.

#### Security of GitLab Runners

GitLab Runners have the [privileged mode](https://docs.gitlab.com/runner/executors/docker.html#the-privileged-mode)
enabled by default, which allows them to execute special commands and running
Docker in Docker. This functionality is needed to run some of the
[Auto DevOps](../../../topics/autodevops/index.md)
jobs. This implies the containers are running in privileged mode and you should,
therefore, be aware of some important details.

The privileged flag gives all capabilities to the running container, which in
turn can do almost everything that the host can do. Be aware of the
inherent security risk associated with performing `docker run` operations on
arbitrary images as they effectively have root access.

If you don't want to use GitLab Runner in privileged mode, either:

- Use shared Runners on GitLab.com. They don't have this security issue.
- Set up your own Runners using configuration described at
  [Shared Runners](../../gitlab_com/index.md#shared-runners). This involves:
  1. Making sure that you don't have it installed via
     [the applications](#installing-applications).
  1. Installing a Runner
     [using `docker+machine`](https://docs.gitlab.com/runner/executors/docker_machine.html).

### Setting the environment scope **(PREMIUM)**

When adding more than one Kubernetes cluster to your project, you need to differentiate
them with an environment scope. The environment scope associates clusters with [environments](../../../ci/environments.md) similar to how the
[environment-specific variables](../../../ci/variables/README.md#limiting-environment-scopes-of-environment-variables) work.

The default environment scope is `*`, which means all jobs, regardless of their
environment, will use that cluster. Each scope can only be used by a single
cluster in a project, and a validation error will occur if otherwise.
Also, jobs that don't have an environment keyword set will not be able to access any cluster.

For example, let's say the following Kubernetes clusters exist in a project:

| Cluster     | Environment scope |
| ----------- | ----------------- |
| Development | `*`               |
| Production  | `production`      |

And the following environments are set in
[`.gitlab-ci.yml`](../../../ci/yaml/README.md):

```yaml
stages:
- test
- deploy

test:
  stage: test
  script: sh test

deploy to staging:
  stage: deploy
  script: make deploy
  environment:
    name: staging
    url: https://staging.example.com/

deploy to production:
  stage: deploy
  script: make deploy
  environment:
    name: production
    url: https://example.com/
```

The result will then be:

- The Development cluster details will be available in the `deploy to staging`
  job.
- The production cluster details will be available in the `deploy to production`
  job.
- No cluster details will be available in the `test` job because it doesn't
  define any environment.

### Multiple Kubernetes clusters **(PREMIUM)**

> Introduced in [GitLab Premium](https://about.gitlab.com/pricing/) 10.3.

With GitLab Premium, you can associate more than one Kubernetes cluster to your
project. That way you can have different clusters for different environments,
like dev, staging, production, etc.

Simply add another cluster, like you did the first time, and make sure to
[set an environment scope](#setting-the-environment-scope-premium) that will
differentiate the new cluster with the rest.

## Installing applications

GitLab can install and manage some applications in your project-level
cluster. For more information on installing, upgrading, uninstalling,
and troubleshooting applications for your project cluster, see
[GitLab Managed Apps](../../clusters/applications.md).

### Getting the external endpoint

NOTE: **Note:**
With the following procedure, a load balancer must be installed in your cluster
to obtain the endpoint. You can use either
[Ingress](#installing-applications), or Knative's own load balancer
([Istio](https://istio.io)) if using [Knative](#installing-applications).

In order to publish your web application, you first need to find the endpoint which will be either an IP
address or a hostname associated with your load balancer.

#### Automatically determining the external endpoint

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/17052) in GitLab 10.6.

After you install [Ingress or Knative](#installing-applications), GitLab attempts to determine the external endpoint
and it should be available within a few minutes. If the endpoint doesn't appear
and your cluster runs on Google Kubernetes Engine:

1. Check your [Kubernetes cluster on Google Kubernetes Engine](https://console.cloud.google.com/kubernetes) to ensure there are no errors on its nodes.
1. Ensure you have enough [Quotas](https://console.cloud.google.com/iam-admin/quotas) on Google Kubernetes Engine. For more information, see [Resource Quotas](https://cloud.google.com/compute/quotas).
1. Check [Google Cloud's Status](https://status.cloud.google.com/) to ensure they are not having any disruptions.

If GitLab is still unable to determine the endpoint of your Ingress or Knative application, you can
manually determine it by following the steps below.

#### Manually determining the external endpoint

If the cluster is on GKE, click the **Google Kubernetes Engine** link in the
**Advanced settings**, or go directly to the
[Google Kubernetes Engine dashboard](https://console.cloud.google.com/kubernetes/)
and select the proper project and cluster. Then click **Connect** and execute
the `gcloud` command in a local terminal or using the **Cloud Shell**.

If the cluster is not on GKE, follow the specific instructions for your
Kubernetes provider to configure `kubectl` with the right credentials.
The output of the following examples will show the external endpoint of your
cluster. This information can then be used to set up DNS entries and forwarding
rules that allow external access to your deployed applications.

If you installed the Ingress [via the **Applications**](#installing-applications),
run the following command:

```bash
kubectl get service --namespace=gitlab-managed-apps ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Some Kubernetes clusters return a hostname instead, like [Amazon EKS](https://aws.amazon.com/eks/). For these platforms, run:

```bash
kubectl get service --namespace=gitlab-managed-apps ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

For Istio/Knative, the command will be different:

```bash
kubectl get svc --namespace=istio-system knative-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip} '
```

Otherwise, you can list the IP addresses of all load balancers:

```bash
kubectl get svc --all-namespaces -o jsonpath='{range.items[?(@.status.loadBalancer.ingress)]}{.status.loadBalancer.ingress[*].ip} '
```

#### Using a static IP

By default, an ephemeral external IP address is associated to the cluster's load
balancer. If you associate the ephemeral IP with your DNS and the IP changes,
your apps will not be able to be reached, and you'd have to change the DNS
record again. In order to avoid that, you should change it into a static
reserved IP.

Read how to [promote an ephemeral external IP address in GKE](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address#promote_ephemeral_ip).

#### Pointing your DNS at the external endpoint

Once you've set up the external endpoint, you should associate it with a [wildcard DNS
record](https://en.wikipedia.org/wiki/Wildcard_DNS_record) such as `*.example.com.`
in order to be able to reach your apps. If your external endpoint is an IP address,
use an A record. If your external endpoint is a hostname, use a CNAME record.

## Deploying to a Kubernetes cluster

A Kubernetes cluster can be the destination for a deployment job. If

- The cluster is integrated with GitLab, special
  [deployment variables](#deployment-variables) are made available to your job
  and configuration is not required. You can immediately begin interacting with
  the cluster from your jobs using tools such as `kubectl` or `helm`.
- You don't use GitLab's cluster integration you can still deploy to your
  cluster. However, you will need configure Kubernetes tools yourself
  using [environment variables](../../../ci/variables/README.md#creating-a-custom-environment-variable)
  before you can interact with the cluster from your jobs.

### Deployment variables

The Kubernetes cluster integration exposes the following
[deployment variables](../../../ci/variables/README.md#deployment-environment-variables) in the
GitLab CI/CD build environment.

| Variable | Description |
| -------- | ----------- |
| `KUBE_URL` | Equal to the API URL. |
| `KUBE_TOKEN` | The Kubernetes token of the [environment service account](#access-controls). |
| `KUBE_NAMESPACE` | The Kubernetes namespace is auto-generated if not specified. The default value is `<project_name>-<project_id>-<environment>`. You can overwrite it to use different one if needed, otherwise the `KUBE_NAMESPACE` variable will receive the default value. |
| `KUBE_CA_PEM_FILE` | Path to a file containing PEM data. Only present if a custom CA bundle was specified. |
| `KUBE_CA_PEM` | (**deprecated**) Raw PEM data. Only if a custom CA bundle was specified. |
| `KUBECONFIG` | Path to a file containing `kubeconfig` for this deployment. CA bundle would be embedded if specified. This config also embeds the same token defined in `KUBE_TOKEN` so you likely will only need this variable. This variable name is also automatically picked up by `kubectl` so you won't actually need to reference it explicitly if using `kubectl`. |
| `KUBE_INGRESS_BASE_DOMAIN` | From GitLab 11.8, this variable can be used to set a domain per cluster. See [cluster domains](#base-domain) for more information. |

NOTE: **NOTE:**
Prior to GitLab 11.5, `KUBE_TOKEN` was the Kubernetes token of the main
service account of the cluster integration.

NOTE: **Note:**
If your cluster was created before GitLab 12.2, default `KUBE_NAMESPACE` will be set to `<project_name>-<project_id>`.

### Troubleshooting

Before the deployment jobs starts, GitLab creates the following specifically for
the deployment job:

- A namespace.
- A service account.

However, sometimes GitLab can not create them. In such instances, your job will fail with the message:

```text
This job failed because the necessary resources were not successfully created.
```

To find the cause of this error when creating a namespace and service account, check the [logs](../../../administration/logs.md#kuberneteslog).

Reasons for failure include:

- The token you gave GitLab does not have [`cluster-admin`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles)
  privileges required by GitLab.
- Missing `KUBECONFIG` or `KUBE_TOKEN` variables. To be passed to your job, they must have a matching
  [`environment:name`](../../../ci/environments.md#defining-environments). If your job has no
  `environment:name` set, it will not be passed the Kubernetes credentials.

NOTE: **NOTE:**
Project-level clusters upgraded from GitLab 12.0 or older may be configured
in a way that causes this error. Ensure you deselect the
[GitLab-managed cluster](#gitlab-managed-clusters) option if you want to manage
namespaces and service accounts yourself.

## Monitoring your Kubernetes cluster **(ULTIMATE)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/merge_requests/4701) in [GitLab Ultimate](https://about.gitlab.com/pricing/) 10.6.

When [Prometheus is deployed](#installing-applications), GitLab will automatically monitor the cluster's health. At the top of the cluster settings page, CPU and Memory utilization is displayed, along with the total amount available. Keeping an eye on cluster resources can be important, if the cluster runs out of memory pods may be shutdown or fail to start.

![Cluster Monitoring](img/k8s_cluster_monitoring.png)
