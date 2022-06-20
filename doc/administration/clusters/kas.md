---
stage: Configure
group: Configure
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Install the GitLab agent server for Kubernetes (KAS) **(FREE SELF)**

> - [Introduced](https://gitlab.com/groups/gitlab-org/-/epics/3834) in GitLab 13.10, the GitLab agent server (KAS) became available on GitLab.com at `wss://kas.gitlab.com`.
> - [Moved](https://gitlab.com/groups/gitlab-org/-/epics/6290) from GitLab Premium to GitLab Free in 14.5.

The agent server is a component you install together with GitLab. It is required to
manage the [GitLab agent for Kubernetes](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent).

The KAS acronym refers to the former name, `Kubernetes agent server`.

The agent server for Kubernetes is installed and available on GitLab.com at `wss://kas.gitlab.com`.
If you use self-managed GitLab, you must install an agent server or specify an external installation.

## Installation options

As a GitLab administrator, you can install the agent server:

- For [Omnibus installations](#for-omnibus).
- For [GitLab Helm Chart installations](#for-gitlab-helm-chart).

Or, you can [use an external agent server](#use-an-external-installation).

### For Omnibus

For [Omnibus](https://docs.gitlab.com/omnibus/) package installations:

1. To enable the agent server, edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   gitlab_kas['enable'] = true
   ```

1. [Reconfigure GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure).

For additional configuration options, see the **Enable GitLab KAS** section of the
[`gitlab.rb.template`](https://gitlab.com/gitlab-org/omnibus-gitlab/-/blob/master/files/gitlab-config-template/gitlab.rb.template).

### For GitLab Helm Chart

For GitLab [Helm Chart](https://docs.gitlab.com/charts/) installations:

1. Set `global.kas.enabled` to `true`. For example, in a shell with `helm` and `kubectl`
   installed, run:

   ```shell
   helm repo add gitlab https://charts.gitlab.io/
   helm repo update
   helm upgrade --install gitlab gitlab/gitlab \
     --timeout 600s \
     --set global.hosts.domain=<YOUR_DOMAIN> \
     --set global.hosts.externalIP=<YOUR_IP> \
     --set certmanager-issuer.email=<YOUR_EMAIL> \
     --set global.kas.enabled=true # <-- without this setting, the agent server will not be installed
   ```

1. To configure the agent server, use a `gitlab.kas` sub-section in your `values.yaml` file:

   ```yaml
   gitlab:
     kas:
       # put your custom options here
   ```

For details, see [how to use the GitLab-KAS chart](https://docs.gitlab.com/charts/charts/gitlab/kas/).

### Use an external installation

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/299850) in GitLab 13.10.

Instead of installing the agent server, you can configure GitLab to use an external agent server.

If you used the GitLab Helm Chart to install GitLab, see
[how to configure your external agent server](https://docs.gitlab.com/charts/charts/globals.html#external-kas).

If you used the Omnibus packages:

1. Edit `/etc/gitlab/gitlab.rb` and add the paths to your external agent server:

   ```ruby
   gitlab_kas['enable'] = false
   gitlab_kas['api_secret_key'] = 'Your shared secret between GitLab and KAS'

   gitlab_rails['gitlab_kas_enabled'] = true
   gitlab_rails['gitlab_kas_external_url'] = 'wss://kas.gitlab.example.com' # User-facing URL for the in-cluster agentk
   gitlab_rails['gitlab_kas_internal_url'] = 'grpc://kas.internal.gitlab.example.com' # Internal URL for the GitLab backend
   ```

1. [Reconfigure GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure).

## Troubleshooting

If you have issues while using the agent server for Kubernetes, view the
service logs by running the following command:

```shell
kubectl logs -f -l=app=kas -n <YOUR-GITLAB-NAMESPACE>
```

In Omnibus GitLab, find the logs in `/var/log/gitlab/gitlab-kas/`.

You can also [troubleshoot issues with individual agents](../../user/clusters/agent/troubleshooting.md).

### GitOps: failed to get project information

If you get the following error message:

```json
{"level":"warn","time":"2020-10-30T08:37:26.123Z","msg":"GitOps: failed to get project info","agent_id":4,"project_id":"root/kas-manifest001","error":"error kind: 0; status: 404"}
```

The project specified by the manifest (`root/kas-manifest001`)
doesn't exist or the project where the manifest is kept is private. To fix this issue,
ensure the project path is correct and that the project's visibility is [set to public](../../user/public_access.md).

### Configuration file not found

If you get the following error message:

```plaintext
time="2020-10-29T04:44:14Z" level=warning msg="Config: failed to fetch" agent_id=2 error="configuration file not found: \".gitlab/agents/test-agent/config.yaml\
```

The path is incorrect for either:

- The repository where the agent was registered.
- The agent configuration file.

To fix this issue, ensure that the paths are correct.

### `dial tcp <GITLAB_INTERNAL_IP>:443: connect: connection refused`

If you are running self-managed GitLab and:

- The instance isn't running behind an SSL-terminating proxy.
- The instance doesn't have HTTPS configured on the GitLab instance itself.
- The instance's hostname resolves locally to its internal IP address.

When the agent server tries to connect to the GitLab API, the following error might occur:

```json
{"level":"error","time":"2021-08-16T14:56:47.289Z","msg":"GetAgentInfo()","correlation_id":"01FD7QE35RXXXX8R47WZFBAXTN","grpc_service":"gitlab.agent.reverse_tunnel.rpc.ReverseTunnel","grpc_method":"Connect","error":"Get \"https://gitlab.example.com/api/v4/internal/kubernetes/agent_info\": dial tcp 172.17.0.4:443: connect: connection refused"}
```

To fix this issue for [Omnibus](https://docs.gitlab.com/omnibus/) package installations,
set the following parameter in `/etc/gitlab/gitlab.rb`. Replace `gitlab.example.com` with your GitLab instance's hostname:

```ruby
gitlab_kas['gitlab_address'] = 'http://gitlab.example.com'
```
