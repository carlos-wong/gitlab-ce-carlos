# Connecting GitLab with a Kubernetes cluster

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/issues/35954) in GitLab 10.1.

Connect your project to Google Kubernetes Engine (GKE) or an existing Kubernetes
cluster in a few steps.

## Overview

With one or more Kubernetes clusters associated to your project, you can use
[Review Apps](../../../ci/review_apps/index.md), deploy your applications, run
your pipelines, use it with [Auto DevOps](../../../topics/autodevops/index.md),
and much more, all from within GitLab.

There are two options when adding a new cluster to your project; either associate
your account with Google Kubernetes Engine (GKE) so that you can [create new
clusters](#adding-and-creating-a-new-gke-cluster-via-gitlab) from within GitLab,
or provide the credentials to an [existing Kubernetes cluster](#adding-an-existing-kubernetes-cluster).

NOTE: **Note:**
From [GitLab 11.6](https://gitlab.com/gitlab-org/gitlab-ce/issues/34758) you
can also associate a Kubernetes cluster to your groups and from
[GitLab 11.11](https://gitlab.com/gitlab-org/gitlab-ce/issues/39840),
to the GitLab instance. Learn more about [group-level](../../group/clusters/index.md)
and [instance-level](../../instance/clusters/index.md) Kubernetes clusters.

## Adding and creating a new GKE cluster via GitLab

TIP: **Tip:**
Every new Google Cloud Platform (GCP) account receives [$300 in credit upon sign up](https://console.cloud.google.com/freetrial),
and in partnership with Google, GitLab is able to offer an additional $200 for new GCP accounts to get started with GitLab's
Google Kubernetes Engine Integration. All you have to do is [follow this link](https://goo.gl/AaJzRW) and apply for credit.

NOTE: **Note:**
The [Google authentication integration](../../../integration/google.md) must
be enabled in GitLab at the instance level. If that's not the case, ask your
GitLab administrator to enable it. On GitLab.com, this is enabled.

### Requirements

Before creating your first cluster on Google Kubernetes Engine with GitLab's
integration, make sure the following requirements are met:

- A [billing account](https://cloud.google.com/billing/docs/how-to/manage-billing-account)
  is set up and you have permissions to access it.
- The Kubernetes Engine API and related service are enabled. It should work immediately but may take up to 10 minutes after you create a project. For more information see the
  ["Before you begin" section of the Kubernetes Engine docs](https://cloud.google.com/kubernetes-engine/docs/quickstart#before-you-begin).

### Creating the cluster

If all of the above requirements are met, you can proceed to create and add a
new Kubernetes cluster to your project:

1. Navigate to your project's **Operations > Kubernetes** page.

    NOTE: **Note:**
    You need Maintainer [permissions] and above to access the Kubernetes page.

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
   - **RBAC-enabled cluster** - Leave this checked if using default GKE creation options, see the [RBAC section](#role-based-access-control-rbac) for more information.
   - **GitLab-managed cluster** - Leave this checked if you want GitLab to manage namespaces and service accounts for this cluster. See the [Managed clusters section](#gitlab-managed-clusters) for more information.
1. Finally, click the **Create Kubernetes cluster** button.

After a couple of minutes, your cluster will be ready to go. You can now proceed
to install some [pre-defined applications](#installing-applications).

NOTE: **Note:**
GitLab requires basic authentication enabled and a client certificate issued for
the cluster in order to setup an [initial service
account](#access-controls). Starting from [GitLab
11.10](https://gitlab.com/gitlab-org/gitlab-ce/issues/58208), the cluster
creation process will explicitly request that basic authentication and
client certificate is enabled.

## Adding an existing Kubernetes cluster

To add an existing Kubernetes cluster to your project:

1. Navigate to your project's **Operations > Kubernetes** page.

    NOTE: **Note:**
    You need Maintainer [permissions] and above to access the Kubernetes page.

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
    - **CA certificate** (required) - A valid Kubernetes certificate is needed to authenticate to the EKS cluster. We will use the certificate created by default.
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

## Security implications

CAUTION: **Important:**
The whole cluster security is based on a model where [developers](../../permissions.md)
are trusted, so **only trusted users should be allowed to control your clusters**.

The default cluster configuration grants access to a wide set of
functionalities needed to successfully build and deploy a containerized
application. Bear in mind that the same credentials are used for all the
applications running on the cluster.

## Gitlab-managed clusters

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/22011) in GitLab 11.5.
> Became [optional](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/26565) in GitLab 11.11.

NOTE: **Note:**
Only available when creating clusters. Existing clusters not managed by GitLab
cannot become GitLab-managed later.

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

## Base domain

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/24580) in GitLab 11.8.

NOTE: **Note:**
You do not need to specify a base domain on cluster settings when using GitLab Serverless. The domain in that case
will be specified as part of the Knative installation. See [Installing Applications](#installing-applications).

Specifying a base domain will automatically set `KUBE_INGRESS_BASE_DOMAIN` as an environment variable.
If you are using [Auto DevOps](../../../topics/autodevops/index.md), this domain will be used for the different
stages. For example, Auto Review Apps and Auto Deploy.

The domain should have a wildcard DNS configured to the Ingress IP address. After ingress has been installed (see [Installing Applications](#installing-applications)),
you can either:

- Create an `A` record that points to the Ingress IP address with your domain provider.
- Enter a wildcard DNS address using a service such as nip.io or xip.io. For example, `192.168.1.1.xip.io`.

## Access controls

When creating a cluster in GitLab, you will be asked if you would like to create an
[Attribute-based access control (ABAC)](https://kubernetes.io/docs/admin/authorization/abac/) cluster, or
a [Role-based access control (RBAC)](https://kubernetes.io/docs/admin/authorization/rbac/) one.

NOTE: **Note:**
[RBAC](#role-based-access-control-rbac) is recommended and the GitLab default.

Whether [ABAC](#attribute-based-access-control-abac) or [RBAC](#role-based-access-control-rbac) is enabled,
GitLab will create the necessary service accounts and privileges in order to install and run
[GitLab managed applications](#installing-applications):

- If GitLab is creating the cluster, a `gitlab` service account with
  `cluster-admin` privileges will be created in the `default` namespace,
  which will be used by GitLab to manage the newly created cluster.

- A project service account with [`edit`
  privileges](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles)
  will be created in the project namespace (also created by GitLab), which will
  be used in [deployment jobs](#deployment-variables).

  NOTE: **Note:**
  Restricted service account for deployment was [introduced](https://gitlab.com/gitlab-org/gitlab-ce/issues/51716) in GitLab 11.5.

- When you install Helm into your cluster, the `tiller` service account
  will be created with `cluster-admin` privileges in the `gitlab-managed-apps`
  namespace. This service account will be added to the installed Helm Tiller and will
  be used by Helm to install and run [GitLab managed applications](#installing-applications).
  Helm will also create additional service accounts and other resources for each
  installed application. Consult the documentation of the Helm charts for each application
  for details.

If you are [adding an existing Kubernetes cluster](#adding-an-existing-kubernetes-cluster),
ensure the token of the account has administrator privileges for the cluster.

The following sections summarize which resources will be created on ABAC/RBAC clusters.

### Attribute-based access control (ABAC)

| Name              | Kind                 | Details                           | Created when                      |
| ---               | ---                  | ---                               | ---                               |
| `gitlab`          | `ServiceAccount`     | `default` namespace               | Creating a new GKE Cluster        |
| `gitlab-token`    | `Secret`             | Token for `gitlab` ServiceAccount | Creating a new GKE Cluster        |
| `tiller`          | `ServiceAccount`     | `gitlab-managed-apps` namespace   | Installing Helm Tiller            |
| `tiller-admin`    | `ClusterRoleBinding` | `cluster-admin` roleRef           | Installing Helm Tiller            |
| Project namespace | `ServiceAccount`     | Uses namespace of Project         | Deploying to a cluster |
| Project namespace | `Secret`             | Token for project ServiceAccount  | Deploying to a cluster |

### Role-based access control (RBAC)

| Name                | Kind                 | Details                           | Created when                      |
| ---                 | ---                  | ---                               | ---                               |
| `gitlab`            | `ServiceAccount`     | `default` namespace               | Creating a new GKE Cluster        |
| `gitlab-admin`      | `ClusterRoleBinding` | [`cluster-admin`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) roleRef           | Creating a new GKE Cluster |
| `gitlab-token`      | `Secret`             | Token for `gitlab` ServiceAccount | Creating a new GKE Cluster        |
| `tiller`            | `ServiceAccount`     | `gitlab-managed-apps` namespace   | Installing Helm Tiller            |
| `tiller-admin`      | `ClusterRoleBinding` | `cluster-admin` roleRef           | Installing Helm Tiller            |
| Project namespace   | `ServiceAccount`     | Uses namespace of Project         | Deploying to a cluster |
| Project namespace   | `Secret`             | Token for project ServiceAccount  | Deploying to a cluster |
| Project namespace   | `RoleBinding`        | [`edit`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) roleRef                  | Deploying to a cluster |

NOTE: **Note:**
Project-specific resources are only created if your cluster is [managed by GitLab](#gitlab-managed-clusters).

### Security of GitLab Runners

GitLab Runners have the [privileged mode](https://docs.gitlab.com/runner/executors/docker.html#the-privileged-mode)
enabled by default, which allows them to execute special commands and running
Docker in Docker. This functionality is needed to run some of the [Auto DevOps]
jobs. This implies the containers are running in privileged mode and you should,
therefore, be aware of some important details.

The privileged flag gives all capabilities to the running container, which in
turn can do almost everything that the host can do. Be aware of the
inherent security risk associated with performing `docker run` operations on
arbitrary images as they effectively have root access.

If you don't want to use GitLab Runner in privileged mode, first make sure that
you don't have it installed via the applications, and then use the
[Runner's Helm chart](../../../install/kubernetes/gitlab_runner_chart.md) to
install it manually.

## Installing applications

GitLab provides **GitLab Managed Apps**, a one-click install for various applications which can
be added directly to your configured cluster. These applications are
needed for [Review Apps](../../../ci/review_apps/index.md) and
[deployments](../../../ci/environments.md) when using [Auto DevOps](../../../topics/autodevops/index.md).
You can install them after you
[create a cluster](#adding-and-creating-a-new-gke-cluster-via-gitlab).

Applications managed by GitLab will be installed onto the `gitlab-managed-apps` namespace. This differrent
from the namespace used for project deployments. It is only created once and its name is not configurable.

To see a list of available applications to install:

1. Navigate to your project's **Operations > Kubernetes**.
1. Select your cluster.

Install Helm first as it's used to install other applications.

NOTE: **Note:**
As of GitLab 11.6, Helm will be upgraded to the latest version supported
by GitLab before installing any of the applications.

| Application | GitLab version | Description | Helm Chart |
| ----------- | :------------: | ----------- | --------------- |
| [Helm](https://docs.helm.sh/) | 10.2+ | Helm is a package manager for Kubernetes and is required to install all the other applications. It is installed in its own pod inside the cluster which can run the `helm` CLI in a safe environment. | n/a |
| [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) | 10.2+ | Ingress can provide load balancing, SSL termination, and name-based virtual hosting. It acts as a web proxy for your applications and is useful if you want to use [Auto DevOps] or deploy your own web apps. | [stable/nginx-ingress](https://github.com/helm/charts/tree/master/stable/nginx-ingress) |
| [Cert-Manager](https://docs.cert-manager.io/en/latest/) | 11.6+ | Cert-Manager is a native Kubernetes certificate management controller that helps with issuing certificates. Installing Cert-Manager on your cluster will issue a certificate by [Let's Encrypt](https://letsencrypt.org/) and ensure that certificates are valid and up-to-date. | [stable/cert-manager](https://github.com/helm/charts/tree/master/stable/cert-manager) |
| [Prometheus](https://prometheus.io/docs/introduction/overview/) | 10.4+ | Prometheus is an open-source monitoring and alerting system useful to supervise your deployed applications. | [stable/prometheus](https://github.com/helm/charts/tree/master/stable/prometheus) |
| [GitLab Runner](https://docs.gitlab.com/runner/) | 10.6+ | GitLab Runner is the open source project that is used to run your jobs and send the results back to GitLab. It is used in conjunction with [GitLab CI/CD](../../../ci/README.md), the open-source continuous integration service included with GitLab that coordinates the jobs. When installing the GitLab Runner via the applications, it will run in **privileged mode** by default. Make sure you read the [security implications](#security-implications) before doing so. | [runner/gitlab-runner](https://gitlab.com/charts/gitlab-runner) |
| [JupyterHub](http://jupyter.org/) | 11.0+ | [JupyterHub](https://jupyterhub.readthedocs.io/en/stable/) is a multi-user service for managing notebooks across a team. [Jupyter Notebooks](https://jupyter-notebook.readthedocs.io/en/latest/) provide a web-based interactive programming environment used for data analysis, visualization, and machine learning. We use a [custom Jupyter image](https://gitlab.com/gitlab-org/jupyterhub-user-image/blob/master/Dockerfile) that installs additional useful packages on top of the base Jupyter. Authentication will be enabled only for [project members](../members/index.md) with [Developer or higher](../../permissions.md) access to the project. You will also see ready-to-use DevOps Runbooks built with Nurtch's [Rubix library](https://github.com/amit1rrr/rubix). More information on creating executable runbooks can be found in [our Nurtch documentation](runbooks/index.md#nurtch-executable-runbooks). Note that Ingress must be installed and have an IP address assigned before JupyterHub can be installed. | [jupyter/jupyterhub](https://jupyterhub.github.io/helm-chart/) |
| [Knative](https://cloud.google.com/knative) | 11.5+ | Knative provides a platform to create, deploy, and manage serverless workloads from a Kubernetes cluster. It is used in conjunction with, and includes [Istio](https://istio.io) to provide an external IP address for all programs hosted by Knative. You will be prompted to enter a wildcard domain where your applications will be exposed. Configure your DNS server to use the external IP address for that domain. For any application created and installed, they will be accessible as `<program_name>.<kubernetes_namespace>.<domain_name>`. This will require your kubernetes cluster to have [RBAC enabled](#role-based-access-control-rbac). | [knative/knative](https://storage.googleapis.com/triggermesh-charts)

With the exception of Knative, the applications will be installed in a dedicated
namespace called `gitlab-managed-apps`.

CAUTION: **Caution:**
If you have an existing Kubernetes cluster with Helm already installed,
you should be careful as GitLab cannot detect it. In this case, installing
Helm via the applications will result in the cluster having it twice, which
can lead to confusion during deployments.

### Upgrading applications

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/24789)
in GitLab 11.8.

Users can perform a one-click upgrade for the GitLab Runner application,
when there is an upgrade available.

To upgrade the GitLab Runner application:

1. Navigate to your project's **Operations > Kubernetes**.
1. Select your cluster.
1. Click the **Upgrade** button for the Runnner application.

The **Upgrade** button will not be shown if there is no upgrade
available.

NOTE: **Note:**
Upgrades will reset values back to the values built into the `runner`
chart plus the values set by
[`values.yaml`](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/vendor/runner/values.yaml)

### Uninstalling applications

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/issues/60665) in
> GitLab 11.11.

The applications below can be uninstalled.

| Application | GitLab version | Notes |
| ----------- | -------------- | ----- |
| Prometheus  | 11.11+         | All data will be deleted and cannot be restored. |

To uninstall an application:

1. Navigate to your project's **Operations > Kubernetes**.
1. Select your cluster.
1. Click the **Uninstall** button for the application.

Support for uninstalling all applications is planned for progressive rollout.
To follow progress, see [the relevant
epic](https://gitlab.com/groups/gitlab-org/-/epics/1201).

### Troubleshooting applications

Applications can fail with the following error:

```text
Error: remote error: tls: bad certificate
```

To avoid installation errors:

- Before starting the installation of applications, make sure that time is synchronized
  between your GitLab server and your Kubernetes cluster.
- Ensure certificates are not out of sync.  When installing applications, GitLab expects a new cluster with no previous installation of Helm.

  You can confirm that the certificates match via `kubectl`:

  ```sh
  kubectl get configmaps/values-content-configuration-ingress -n gitlab-managed-apps -o \
  "jsonpath={.data['cert\.pem']}" | base64 -d > a.pem
  kubectl get secrets/tiller-secret -n gitlab-managed-apps -o "jsonpath={.data['ca\.crt']}" | base64 -d > b.pem
  diff a.pem b.pem
  ```

## Getting the external endpoint

NOTE: **Note:**
With the following procedure, a load balancer must be installed in your cluster
to obtain the endpoint. You can use either
[Ingress](#installing-applications), or Knative's own load balancer
([Istio](https://istio.io)) if using [Knative](#installing-applications).

In order to publish your web application, you first need to find the endpoint which will be either an IP
address or a hostname associated with your load balancer.

### Automatically determining the external endpoint

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/17052) in GitLab 10.6.

After you install [Ingress or Knative](#installing-applications), Gitlab attempts to determine the external endpoint
and it should be available within a few minutes. If the endpoint doesn't appear
and your cluster runs on Google Kubernetes Engine:

1. Check your [Kubernetes cluster on Google Kubernetes Engine](https://console.cloud.google.com/kubernetes) to ensure there are no errors on its nodes.
1. Ensure you have enough [Quotas](https://console.cloud.google.com/iam-admin/quotas) on Google Kubernetes Engine. For more information, see [Resource Quotas](https://cloud.google.com/compute/quotas).
1. Check [Google Cloud's Status](https://status.cloud.google.com/) to ensure they are not having any disruptions.

If GitLab is still unable to determine the endpoint of your Ingress or Knative application, you can
manually determine it by following the steps below.

### Manually determining the external endpoint

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

### Using a static IP

By default, an ephemeral external IP address is associated to the cluster's load
balancer. If you associate the ephemeral IP with your DNS and the IP changes,
your apps will not be able to be reached, and you'd have to change the DNS
record again. In order to avoid that, you should change it into a static
reserved IP.

Read how to [promote an ephemeral external IP address in GKE](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address#promote_ephemeral_ip).

### Pointing your DNS at the external endpoint

Once you've set up the external endpoint, you should associate it with a [wildcard DNS
record](https://en.wikipedia.org/wiki/Wildcard_DNS_record) such as `*.example.com.`
in order to be able to reach your apps. If your external endpoint is an IP address,
use an A record. If your external endpoint is a hostname, use a CNAME record.

## Multiple Kubernetes clusters **[PREMIUM]**

> Introduced in [GitLab Premium][ee] 10.3.

With GitLab Premium, you can associate more than one Kubernetes clusters to your
project. That way you can have different clusters for different environments,
like dev, staging, production, etc.

Simply add another cluster, like you did the first time, and make sure to
[set an environment scope](#setting-the-environment-scope-premium) that will
differentiate the new cluster with the rest.

## Setting the environment scope **[PREMIUM]**

When adding more than one Kubernetes cluster to your project, you need to differentiate
them with an environment scope. The environment scope associates clusters with [environments](../../../ci/environments.md) similar to how the
[environment-specific variables](https://docs.gitlab.com/ee/ci/variables/index.html#limiting-environment-scopes-of-environment-variables-premium) work.

The default environment scope is `*`, which means all jobs, regardless of their
environment, will use that cluster. Each scope can only be used by a single
cluster in a project, and a validation error will occur if otherwise.
Also, jobs that don't have an environment keyword set will not be able to access any cluster.

---

For example, let's say the following Kubernetes clusters exist in a project:

| Cluster     | Environment scope |
| ----------- | ----------------- |
| Development | `*`               |
| Staging     | `staging`         |
| Production  | `production`      |

And the following environments are set in [`.gitlab-ci.yml`](../../../ci/yaml/README.md):

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

- The development cluster will be used for the "test" job.
- The staging cluster will be used for the "deploy to staging" job.
- The production cluster will be used for the "deploy to production" job.

## Deployment variables

The Kubernetes cluster integration exposes the following
[deployment variables](../../../ci/variables/README.md#deployment-environment-variables) in the
GitLab CI/CD build environment.

| Variable | Description |
| -------- | ----------- |
| `KUBE_URL` | Equal to the API URL. |
| `KUBE_TOKEN` | The Kubernetes token of the [project service account](#access-controls). |
| `KUBE_NAMESPACE` | The Kubernetes namespace is auto-generated if not specified. The default value is `<project_name>-<project_id>`. You can overwrite it to use different one if needed, otherwise the `KUBE_NAMESPACE` variable will receive the default value. |
| `KUBE_CA_PEM_FILE` | Path to a file containing PEM data. Only present if a custom CA bundle was specified. |
| `KUBE_CA_PEM` | (**deprecated**) Raw PEM data. Only if a custom CA bundle was specified. |
| `KUBECONFIG` | Path to a file containing `kubeconfig` for this deployment. CA bundle would be embedded if specified. This config also embeds the same token defined in `KUBE_TOKEN` so you likely will only need this variable. This variable name is also automatically picked up by `kubectl` so you won't actually need to reference it explicitly if using `kubectl`. |
| `KUBE_INGRESS_BASE_DOMAIN` | From GitLab 11.8, this variable can be used to set a domain per cluster. See [cluster domains](#base-domain) for more information. |

NOTE: **NOTE:**
Prior to GitLab 11.5, `KUBE_TOKEN` was the Kubernetes token of the main
service account of the cluster integration.

### Troubleshooting failed deployment jobs

GitLab will create a namespace and service account specifically for your
deployment jobs. On project level clusters, this happens when the cluster
is created. On group level clusters, resources are created immediately
before the deployment job starts.

However, sometimes GitLab can not create them. In such instances, your job will fail with the message:

```text
This job failed because the necessary resources were not successfully created.
```

To find the cause of this error when creating a namespace and service account, check the [logs](../../../administration/logs.md#kuberneteslog).

Common reasons for failure include:

- The token you gave GitLab did not have [`cluster-admin`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles)
  privileges required by GitLab.
- Missing `KUBECONFIG` or `KUBE_TOKEN` variables. To be passed to your job, they must have a matching
  [`environment:name`](../../../ci/environments.md#defining-environments). If your job has no
  `environment:name` set, it will not be passed the Kubernetes credentials.

## Monitoring your Kubernetes cluster **[ULTIMATE]**

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/merge_requests/4701) in [GitLab Ultimate][ee] 10.6.

When [Prometheus is deployed](#installing-applications), GitLab will automatically monitor the cluster's health. At the top of the cluster settings page, CPU and Memory utilization is displayed, along with the total amount available. Keeping an eye on cluster resources can be important, if the cluster runs out of memory pods may be shutdown or fail to start.

![Cluster Monitoring](img/k8s_cluster_monitoring.png)

## Enabling or disabling the Kubernetes cluster integration

After you have successfully added your cluster information, you can enable the
Kubernetes cluster integration:

1. Click the **Enabled/Disabled** switch
1. Hit **Save** for the changes to take effect

You can now start using your Kubernetes cluster for your deployments.

To disable the Kubernetes cluster integration, follow the same procedure.

## Removing the Kubernetes cluster integration

NOTE: **Note:**
You need Maintainer [permissions] and above to remove a Kubernetes cluster integration.

NOTE: **Note:**
When you remove a cluster, you only remove its relation to GitLab, not the
cluster itself. To remove the cluster, you can do so by visiting the GKE
dashboard or using `kubectl`.

To remove the Kubernetes cluster integration from your project, simply click the
**Remove integration** button. You will then be able to follow the procedure
and add a Kubernetes cluster again.

## View Kubernetes pod logs from GitLab **[ULTIMATE]**

Learn how to easily
[view the logs of running pods in connected Kubernetes clusters](kubernetes_pod_logs.md).

## What you can get with the Kubernetes integration

Here's what you can do with GitLab if you enable the Kubernetes integration.

### Deploy Boards **[PREMIUM]**

GitLab's Deploy Boards offer a consolidated view of the current health and
status of each CI [environment](../../../ci/environments.md) running on Kubernetes,
displaying the status of the pods in the deployment. Developers and other
teammates can view the progress and status of a rollout, pod by pod, in the
workflow they already use without any need to access Kubernetes.

[Read more about Deploy Boards](https://docs.gitlab.com/ee/user/project/deploy_boards.html)

### Canary Deployments **[PREMIUM]**

Leverage [Kubernetes' Canary deployments](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/#canary-deployments)
and visualize your canary deployments right inside the Deploy Board, without
the need to leave GitLab.

[Read more about Canary Deployments](https://docs.gitlab.com/ee/user/project/canary_deployments.html)

### Kubernetes monitoring

Automatically detect and monitor Kubernetes metrics. Automatic monitoring of
[NGINX ingress](../integrations/prometheus_library/nginx.md) is also supported.

[Read more about Kubernetes monitoring](../integrations/prometheus_library/kubernetes.md)

### Auto DevOps

Auto DevOps automatically detects, builds, tests, deploys, and monitors your
applications.

To make full use of Auto DevOps(Auto Deploy, Auto Review Apps, and Auto Monitoring)
you will need the Kubernetes project integration enabled.

[Read more about Auto DevOps](../../../topics/autodevops/index.md)

### Web terminals

NOTE: **Note:**
Introduced in GitLab 8.15. You must be the project owner or have `maintainer` permissions
to use terminals. Support is limited to the first container in the
first pod of your environment.

When enabled, the Kubernetes service adds [web terminal](../../../ci/environments.md#web-terminals)
support to your [environments](../../../ci/environments.md). This is based on the `exec` functionality found in
Docker and Kubernetes, so you get a new shell session within your existing
containers. To use this integration, you should deploy to Kubernetes using
the deployment variables above, ensuring any pods you create are labelled with
`app=$CI_ENVIRONMENT_SLUG`. GitLab will do the rest!

### Integrating Amazon EKS cluster with GitLab

- Learn how to [connect and deploy to an Amazon EKS cluster](eks_and_gitlab/index.md).

### Serverless

- [Run serverless workloads on Kubernetes with Knative.](serverless/index.md)

[permissions]: ../../permissions.md
[ee]: https://about.gitlab.com/pricing/
[Auto DevOps]: ../../../topics/autodevops/index.md
