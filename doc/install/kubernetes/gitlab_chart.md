# GitLab Helm Chart

This is the official way to install GitLab on a cloud native environment.

NOTE: **Kubernetes experience required:**
Our Helm charts are recommended for those who are familiar with Kubernetes.
If you're not sure if Kubernetes is for you, our
[Omnibus GitLab packages](../README.md#installing-gitlab-using-the-omnibus-gitlab-package-recommended)
are mature, scalable, support [high availability](../../administration/high_availability/README.md)
and are used today on GitLab.com.
It is not necessary to have GitLab installed on Kubernetes in order to use [GitLab Kubernetes integration](https://docs.gitlab.com/ee/user/project/clusters/index.html). 

## Introduction

The `gitlab` chart is the best way to operate GitLab on Kubernetes. This chart
contains all the required components to get started, and can scale to large deployments.

The default deployment includes:

- Core GitLab components: Unicorn, Shell, Workhorse, Registry, Sidekiq, and Gitaly
- Optional dependencies: Postgres, Redis, Minio
- An auto-scaling, unprivileged [GitLab Runner](https://docs.gitlab.com/runner/) using the Kubernetes executor
- Automatically provisioned SSL via [Let's Encrypt](https://letsencrypt.org/).

## Limitations

Some features of GitLab are not currently available:

- [GitLab Pages](https://gitlab.com/charts/gitlab/issues/37)
- [GitLab Geo](https://gitlab.com/charts/gitlab/issues/8)
- [No in-cluster HA database](https://gitlab.com/charts/gitlab/issues/48)
- MySQL will not be supported, as support is [deprecated within GitLab](https://docs.gitlab.com/omnibus/settings/database.html#using-a-mysql-database-management-server-enterprise-edition-only)

## Installing GitLab using the Helm Chart

The `gitlab` chart includes all required dependencies, and takes a few minutes
to deploy.

TIP: **Tip:**
For production deployments, we strongly recommend using the
[detailed installation instructions](https://gitlab.com/charts/gitlab/blob/master/doc/installation/index.md)
utilizing [external Postgres, Redis, and object storage](https://gitlab.com/charts/gitlab/tree/master/doc/advanced) services.

### Requirements

In order to deploy GitLab on Kubernetes, the following are required:

1. `helm` and `kubectl` [installed on your computer](preparation/tools_installation.md).
1. A Kubernetes cluster, version 1.8 or higher. 6vCPU and 16GB of RAM is recommended.
   - [Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
   - [Google GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-container-cluster)
   - [IBM IKS](https://console.bluemix.net/docs/tutorials/scalable-webapp-kubernetes.html#create_kube_cluster)
   - [Microsoft AKS](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough-portal)
1. A [wildcard DNS entry and external IP address](preparation/networking.md)
1. [Authenticate and connect](preparation/connect.md) to the cluster
1. Configure and initialize [Helm Tiller](preparation/tiller.md).

### Deployment of GitLab to Kubernetes

To deploy GitLab, the following three parameters are required:

- `global.hosts.domain`: the [base domain](preparation/networking.md) of the
  wildcard host entry. For example, `example.com` if the wild card entry is
  `*.example.com`.
- `global.hosts.externalIP`: the [external IP](preparation/networking.md) which
  the wildcard DNS resolves to.
- `certmanager-issuer.email`: the email address to use when requesting new SSL
  certificates from Let's Encrypt.

NOTE: **Note:**
For deployments to Amazon EKS, there are
[additional configuration requirements](preparation/eks.md). A full list of
configuration options is [also available](https://gitlab.com/charts/gitlab/blob/master/doc/installation/command-line-options.md).

Once you have all of your configuration options collected, you can get any
dependencies and run helm. In this example, the helm release is named "gitlab":

```sh
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600 \
  --set global.hosts.domain=example.com \
  --set global.hosts.externalIP=10.10.10.10 \
  --set certmanager-issuer.email=email@example.com
```

### Monitoring the Deployment

This will output the list of resources installed once the deployment finishes,
which may take 5-10 minutes.

The status of the deployment can be checked by running `helm status gitlab`
which can also be done while the deployment is taking place if you run the
command in another terminal.

### Initial login

You can access the GitLab instance by visiting the domain name beginning with
`gitlab.` followed by the domain specified during installation. From the example
above, the URL would be `https://gitlab.example.com`.

If you manually created the secret for initial root password, you
can use that to sign in as `root` user. If not, GitLab automatically
created a random password for `root` user. This can be extracted by the
following command (replace `<name>` by name of the release - which is `gitlab`
if you used the command above):

```sh
kubectl get secret <name>-gitlab-initial-root-password -ojsonpath={.data.password} | base64 --decode ; echo
```

### Outgoing email

By default outgoing email is disabled. To enable it, provide details for your SMTP server
using the `global.smtp` and `global.email` settings. You can find details for these settings in the
[command line options](https://gitlab.com/charts/gitlab/blob/master/doc/installation/command-line-options.md#email-configuration).

If your SMTP server requires authentication make sure to read the section on providing
your password in the [secrets documentation](https://gitlab.com/charts/gitlab/blob/master/doc/installation/secrets.md#smtp-password).
You can disable authentication settings with `--set global.smtp.authentication=""`.

If your Kubernetes cluster is on GKE, be aware that SMTP port [25 is blocked](https://cloud.google.com/compute/docs/tutorials/sending-mail/#using_standard_email_ports).

### Deploying the Community Edition

To deploy the Community Edition, include these options in your `helm install` command:

```sh
--set gitlab.migrations.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-rails-ce
--set gitlab.sidekiq.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-sidekiq-ce
--set gitlab.unicorn.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-unicorn-ce
--set gitlab.unicorn.workhorse.image=registry.gitlab.com/gitlab-org/build/cng/gitlab-workhorse-ce
--set gitlab.task-runner.image.repository=registry.gitlab.com/gitlab-org/build/cng/gitlab-task-runner-ce
```

## Updating GitLab using the Helm Chart

Once your GitLab Chart is installed, configuration changes and chart updates
should be done using `helm upgrade`:

```sh
helm repo update
helm upgrade --reuse-values gitlab gitlab/gitlab
```

## Uninstalling GitLab using the Helm Chart

To uninstall the GitLab Chart, run the following:

```sh
helm delete gitlab
```

[kube-srv]: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services---service-types
[storageclass]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#storageclasses
