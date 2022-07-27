---
stage: Configure
group: Configure
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Working with the agent for Kubernetes **(FREE)**

Use the following tasks when working with the agent for Kubernetes.

## View your agents

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/340882) in GitLab 14.8, the installed `agentk` version is displayed on the **Agent** tab.

Prerequisite:

- You must have at least the Developer role.

To view the list of agents:

1. On the top bar, select **Menu > Projects** and find the project that contains your agent configuration file.
1. On the left sidebar, select **Infrastructure > Kubernetes clusters**.
1. Select **Agent** tab to view clusters connected to GitLab through the agent.

On this page, you can view:

- All the registered agents for the current project.
- The connection status.
- The version of `agentk` installed on your cluster.
- The path to each agent configuration file.

## View an agent's activity information

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/277323) in GitLab 14.6.

The activity logs help you to identify problems and get the information
you need for troubleshooting. You can see events from a week before the
current date. To view an agent's activity:

1. On the top bar, select **Menu > Projects** and find the project that contains your agent configuration file.
1. On the left sidebar, select **Infrastructure > Kubernetes clusters**.
1. Select the agent you want to see activity for.

The activity list includes:

- Agent registration events: When a new token is **created**.
- Connection events: When an agent is successfully **connected** to a cluster.

The connection status is logged when you connect an agent for
the first time or after more than an hour of inactivity.

View and provide feedback about the UI in [this epic](https://gitlab.com/groups/gitlab-org/-/epics/4739).

## Debug the agent

> The `grpc_level` was [introduced](https://gitlab.com/gitlab-org/cluster-integration/gitlab-agent/-/merge_requests/669) in GitLab 15.1.

To debug the cluster-side component (`agentk`) of the agent, set the log
level according to the available options:

- `error`
- `warning`
- `info`
- `debug`

The agent has two loggers:

- A general purpose logger, which defaults to `info`.
- A gRPC logger, which defaults to `error`.

One can change their log levels by using a top-level `observability` section in the [agent configuration file](install/index.md#configure-your-agent), for example setting the levels to `debug` and `warning`:

```yaml
observability:
  logging:
    level: debug
    grpc_level: warning
```

When `grpc_level` is set to `info` or below, there will be a lot of gRPC logs.

Commit the configuration changes and inspect the agent service logs:

```shell
kubectl logs -f -l=app=gitlab-agent -n gitlab-agent
```

For more information about debugging, see [troubleshooting documentation](troubleshooting.md).

## Reset the agent token

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/327152) in GitLab 14.9.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/336641) in GitLab 14.10, the agent token can be revoked from the UI.

To reset the agent token without downtime:

1. Create a new token:
   1. On the top bar, select **Menu > Projects** and find your project.
   1. On the left sidebar, select **Infrastructure > Kubernetes clusters**.
   1. Select the agent you want to create a token for.
   1. On the **Access tokens** tab, select **Create token**.
   1. Enter token's name and description (optional) and select **Create token**.
1. Securely store the generated token.
1. Use the token to [install the agent in your cluster](install/index.md#install-the-agent-in-the-cluster) and to [update the agent](install/index.md#update-the-agent-version) to another version.
1. To delete the token you're no longer using, return to the token list and select **Revoke** (**{remove}**).

## Remove an agent

You can remove an agent by using the [GitLab UI](#remove-an-agent-through-the-gitlab-ui) or the
[GraphQL API](#remove-an-agent-with-the-gitlab-graphql-api). The agent and any associated tokens
are removed from GitLab, but no changes are made in your Kubernetes cluster. You must
clean up those resources manually.

### Remove an agent through the GitLab UI

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/323055) in GitLab 14.7.

To remove an agent from the UI:

1. On the top bar, select **Menu > Projects** and find the project that contains the agent configuration file.
1. From the left sidebar, select **Infrastructure > Kubernetes clusters**.
1. In the table, in the row for your agent, in the **Options** column, select the vertical ellipsis (**{ellipsis_v}**).
1. Select **Delete agent**.

### Remove an agent with the GitLab GraphQL API

1. Get the `<cluster-agent-token-id>` from a query in the interactive GraphQL explorer.
   - For GitLab.com, go to <https://gitlab.com/-/graphql-explorer> to open GraphQL Explorer.
   - For self-managed GitLab, go to `https://gitlab.example.com/-/graphql-explorer`, replacing `gitlab.example.com` with your instance's URL.

   ```graphql
   query{
     project(fullPath: "<full-path-to-agent-configuration-project>") {
       clusterAgent(name: "<agent-name>") {
         id
         tokens {
           edges {
             node {
               id
             }
           }
         }
       }
     }
   }
   ```

1. Remove an agent record with GraphQL by deleting the `clusterAgentToken`.

   ```graphql
   mutation deleteAgent {
     clusterAgentDelete(input: { id: "<cluster-agent-id>" } ) {
       errors
     }
   }

   mutation deleteToken {
     clusterAgentTokenDelete(input: { id: "<cluster-agent-token-id>" }) {
       errors
     }
   }
   ```

1. Verify whether the removal occurred successfully. If the output in the Pod logs includes `unauthenticated`, it means that the agent was successfully removed:

   ```json
   {
       "level": "warn",
       "time": "2021-04-29T23:44:07.598Z",
       "msg": "GetConfiguration.Recv failed",
       "error": "rpc error: code = Unauthenticated desc = unauthenticated"
   }
   ```

1. Delete the agent in your cluster:

   ```shell
   kubectl delete -n gitlab-kubernetes-agent -f ./resources.yml
   ```
