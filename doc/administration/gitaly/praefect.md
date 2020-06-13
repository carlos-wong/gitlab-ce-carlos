# Praefect: High Availability

NOTE: **Note:** Praefect is an experimental service, and data loss is likely.

Praefect is an optional reverse-proxy for [Gitaly](../index.md) to manage a
cluster of Gitaly nodes for high availability. Initially, high availability
be implemented through asynchronous replication. If a Gitaly node becomes
unavailable, it will be possible to fail over to a warm Gitaly replica.

The first minimal version will support:

- Eventual consistency of the secondary replicas.
- Automatic fail over from the primary to the secondary.
- Reporting of possible data loss if replication queue is non empty.

Follow the [HA Gitaly epic](https://gitlab.com/groups/gitlab-org/-/epics/1489)
for updates and roadmap.

## Requirements for configuring Gitaly for High Availability

NOTE: **Note:** this reference architecture is not highly available because
Praefect is a single point of failure.

The minimal [alpha](https://about.gitlab.com/handbook/product/#alpha-beta-ga)
reference architecture additionally requires:

- 1 Praefect node
- 1 PostgreSQL server (PostgreSQL 9.6 or newer)
- 3 Gitaly nodes (1 primary, 2 secondary)

![Alpha architecture diagram](img/praefect_architecture_v12_9.png)

See the [design
document](https://gitlab.com/gitlab-org/gitaly/-/blob/master/doc/design_ha.md)
for implementation details.

## Setup Instructions

If you [installed](https://about.gitlab.com/install/) GitLab using the Omnibus
package (highly recommended), follow the steps below:

1. [Preparation](#preparation)
1. [Configuring the Praefect database](#postgresql)
1. [Configuring the Praefect proxy/router](#praefect)
1. [Configuring each Gitaly node](#gitaly) (once for each Gitaly node)
1. [Updating the GitLab server configuration](#gitlab)

### Preparation

Before beginning, you should already have a working GitLab instance. [Learn how
to install GitLab](https://about.gitlab.com/install/).

Provision a PostgreSQL server (PostgreSQL 9.6 or newer). Configuration through
the GitLab Omnibus distribution is not yet supported. Follow this
[issue](https://gitlab.com/gitlab-org/gitaly/issues/2476) for updates.

Prepare all your new nodes by [installing
GitLab](https://about.gitlab.com/install/).

- 1 Praefect node (minimal storage required)
- 3 Gitaly nodes (high CPU, high memory, fast storage)

You will need the IP/host address for each node.

1. `POSTGRESQL_SERVER_ADDRESS`: the IP/host address of the PostgreSQL server
1. `PRAEFECT_SERVER_ADDRESS`: the IP/host address of the Praefect server
1. `GITALY_SERVER_ADDRESS`: the IP/host address of each Gitaly node

#### Secrets

The communication between components is secured with different secrets, which
are described below. Before you begin, generate a unique secret for each, and
make note of it. This will make it easy to replace these placeholder tokens
with secure tokens as you complete the setup process.

1. `GITLAB_SHELL_SECRET_TOKEN`: this is used by Git hooks to make callback HTTP
   API requests to GitLab when accepting a Git push. This secret is shared with
   GitLab Shell for legacy reasons.
1. `PRAEFECT_EXTERNAL_TOKEN`: repositories hosted on your Praefect cluster can
   only be accessed by Gitaly clients that carry this token.
1. `PRAEFECT_INTERNAL_TOKEN`: this token is used for replication traffic inside
   your Praefect cluster. This is distinct from `PRAEFECT_EXTERNAL_TOKEN`
   because Gitaly clients must not be able to access internal nodes of the
   Praefect cluster directly; that could lead to data loss.
1. `PRAEFECT_SQL_PASSWORD`: this password is used by Praefect to connect to
   PostgreSQL.
1. `GRAFANA_PASSWORD`: this password is used to access the `admin`
   account in the Grafana dashboards.

We will note in the instructions below where these secrets are required.

### PostgreSQL

NOTE: **Note:** don't reuse the GitLab application database for the Praefect
database.

To complete this section you will need:

- 1 Praefect node
- 1 PostgreSQL server (PostgreSQL 9.6 or newer)
  - An SQL user with permissions to create databases

During this section, we will configure the PostgreSQL server, from the Praefect
node, using `psql` which is installed by GitLab Omnibus.

1. SSH into the **Praefect** node and login as root:

   ```shell
   sudo -i
   ```

1. Connect to the PostgreSQL server with administrative access. This is likely
   the `postgres` user. The database `template1` is used because it is created
   by default on all PostgreSQL servers.

   ```shell
   /opt/gitlab/embedded/bin/psql -U postgres -d template1 -h POSTGRESQL_SERVER_ADDRESS
   ```

   Create a new user `praefect` which will be used by Praefect. Replace
   `PRAEFECT_SQL_PASSWORD` with the strong password you generated in the
   preparation step.

   ```sql
   CREATE ROLE praefect WITH LOGIN CREATEDB PASSWORD 'PRAEFECT_SQL_PASSWORD';
   ```

1. Reconnect to the PostgreSQL server, this time as the `praefect` user:

   ```shell
   /opt/gitlab/embedded/bin/psql -U praefect -d template1 -h POSTGRESQL_SERVER_ADDRESS
   ```

   Create a new database `praefect_production`. By creating the database while
   connected as the `praefect` user, we are confident they have access.

   ```sql
   CREATE DATABASE praefect_production WITH ENCODING=UTF8;
   ```

The database used by Praefect is now configured.

### Praefect

To complete this section you will need:

- [Configured PostgreSQL server](#postgresql), including:
  - IP/host address (`POSTGRESQL_SERVER_ADDRESS`)
  - password (`PRAEFECT_SQL_PASSWORD`)

Praefect should be run on a dedicated node. Do not run Praefect on the
application server, or a Gitaly node.

1. SSH into the **Praefect** node and login as root:

   ```shell
   sudo -i
   ```

1. Disable all other services by editing `/etc/gitlab/gitlab.rb`:

   ```ruby
   # Disable all other services on the Praefect node
   postgresql['enable'] = false
   redis['enable'] = false
   nginx['enable'] = false
   prometheus['enable'] = false
   grafana['enable'] = false
   unicorn['enable'] = false
   sidekiq['enable'] = false
   gitlab_workhorse['enable'] = false
   gitaly['enable'] = false

   # Enable only the Praefect service
   praefect['enable'] = true

   # Prevent database connections during 'gitlab-ctl reconfigure'
   gitlab_rails['rake_cache_clear'] = false
   gitlab_rails['auto_migrate'] = false
   ```

1. Configure **Praefect** to listen on network interfaces by editing
   `/etc/gitlab/gitlab.rb`:

   ```ruby
   # Make Praefect accept connections on all network interfaces.
   # Use firewalls to restrict access to this address/port.
   praefect['listen_addr'] = '0.0.0.0:2305'

   # Enable Prometheus metrics access to Praefect. You must use firewalls
   # to restrict access to this address/port.
   praefect['prometheus_listen_addr'] = '0.0.0.0:9652'
   ```

1. Configure a strong `auth_token` for **Praefect** by editing
   `/etc/gitlab/gitlab.rb`. This will be needed by clients outside the cluster
   (like GitLab Shell) to communicate with the Praefect cluster :

   ```ruby
   praefect['auth_token'] = 'PRAEFECT_EXTERNAL_TOKEN'
   ```

1. Configure **Praefect** to connect to the PostgreSQL database by editing
   `/etc/gitlab/gitlab.rb`.

   You will need to replace `POSTGRESQL_SERVER_ADDRESS` with the IP/host address
   of the database, and `PRAEFECT_SQL_PASSWORD` with the strong password set
   above.

   ```ruby
   praefect['database_host'] = 'POSTGRESQL_SERVER_ADDRESS'
   praefect['database_port'] = 5432
   praefect['database_user'] = 'praefect'
   praefect['database_password'] = 'PRAEFECT_SQL_PASSWORD'
   praefect['database_dbname'] = 'praefect_production'
   ```

   If you want to use a TLS client certificate, the options below can be used:

   ```ruby
   # Connect to PostreSQL using a TLS client certificate
   # praefect['database_sslcert'] = '/path/to/client-cert'
   # praefect['database_sslkey'] = '/path/to/client-key'

   # Trust a custom certificate authority
   # praefect['database_sslrootcert'] = '/path/to/rootcert'
   ```

   By default Praefect will refuse to make an unencrypted connection to
   PostgreSQL. You can override this by uncommenting the following line:

   ```ruby
   # praefect['database_sslmode'] = 'disable'
   ```

1. Configure the **Praefect** cluster to connect to each Gitaly node in the
   cluster by editing `/etc/gitlab/gitlab.rb`.

   In the example below we have configured one cluster named `praefect`. This
   cluster has three Gitaly nodes `gitaly-1`, `gitaly-2`, and `gitaly-3`, which
   will be replicas of each other.

   Replace `PRAEFECT_INTERNAL_TOKEN` with a strong secret, which will be used by
   Praefect when communicating with Gitaly nodes in the cluster. This token is
   distinct from the `PRAEFECT_EXTERNAL_TOKEN`.

   Replace `GITALY_HOST` with the IP/host address of the each Gitaly node.

   More Gitaly nodes can be added to the cluster to increase the number of
   replicas. More clusters can also be added for very large GitLab instances.

   NOTE: **Note:** The `gitaly-1` node is currently denoted the primary. This
   can be used to manually fail from one node to another. This will be removed
   in the future to allow for automatic failover.

   ```ruby
   # Name of storage hash must match storage name in git_data_dirs on GitLab
   # server ('praefect') and in git_data_dirs on Gitaly nodes ('gitaly-1')
   praefect['virtual_storages'] = {
     'praefect' => {
       'gitaly-1' => {
         'address' => 'tcp://GITALY_HOST:8075',
         'token'   => 'PRAEFECT_INTERNAL_TOKEN',
         'primary' => true
       },
       'gitaly-2' => {
         'address' => 'tcp://GITALY_HOST:8075',
         'token'   => 'PRAEFECT_INTERNAL_TOKEN'
       },
       'gitaly-3' => {
         'address' => 'tcp://GITALY_HOST:8075',
         'token'   => 'PRAEFECT_INTERNAL_TOKEN'
       }
     }
   }
   ```

1. Save the changes to `/etc/gitlab/gitlab.rb` and [reconfigure Praefect](../restart_gitlab.md#omnibus-gitlab-reconfigure):

   ```shell
   gitlab-ctl reconfigure
   ```

1. Verify that Praefect can reach PostgreSQL:

   ```shell
   sudo -u git /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml sql-ping
   ```

   If the check fails, make sure you have followed the steps correctly. If you
   edit `/etc/gitlab/gitlab.rb`, remember to run `sudo gitlab-ctl reconfigure`
   again before trying the `sql-ping` command.

### Gitaly

NOTE: **Note:** Complete these steps for **each** Gitaly node.

To complete this section you will need:

- [Configured Praefect node](#praefect)
- 3 (or more) servers, with GitLab installed, to be configured as Gitaly nodes.
  These should be dedicated nodes, do not run other services on these nodes.

Every Gitaly server assigned to the Praefect cluster needs to be configured. The
configuration is the same as a normal [standalone Gitaly server](../index.md),
except:

- the storage names are exposed to Praefect, not GitLab
- the secret token is shared with Praefect, not GitLab

The configuration of all Gitaly nodes in the Praefect cluster can be identical,
because we rely on Praefect to route operations correctly.

Particular attention should be shown to:

- the `gitaly['auth_token']` configured in this section must match the `token`
  value under `praefect['virtual_storages']` on the Praefect node. This was set
  in the [previous section](#praefect). This document uses the placeholder
  `PRAEFECT_INTERNAL_TOKEN` throughout.
- the storage names in `git_data_dirs` configured in this section must match the
  storage names under `praefect['virtual_storages']` on the Praefect node. This
  was set in the [previous section](#praefect). This document uses `gitaly-1`,
  `gitaly-2`, and `gitaly-3` as Gitaly storage names.

For more information on Gitaly server configuration, see our [Gitaly
documentation](index.md#3-gitaly-server-configuration).

1. SSH into the **Gitaly** node and login as root:

   ```shell
   sudo -i
   ```

1. Disable all other services by editing `/etc/gitlab/gitlab.rb`:

   ```ruby
   # Disable all other services on the Praefect node
   postgresql['enable'] = false
   redis['enable'] = false
   nginx['enable'] = false
   prometheus['enable'] = false
   grafana['enable'] = false
   unicorn['enable'] = false
   sidekiq['enable'] = false
   gitlab_workhorse['enable'] = false
   prometheus_monitoring['enable'] = false

   # Enable only the Praefect service
   gitaly['enable'] = true

   # Prevent database connections during 'gitlab-ctl reconfigure'
   gitlab_rails['rake_cache_clear'] = false
   gitlab_rails['auto_migrate'] = false
   ```

1. Configure **Gitaly** to listen on network interfaces by editing
   `/etc/gitlab/gitlab.rb`:

   ```ruby
   # Make Gitaly accept connections on all network interfaces.
   # Use firewalls to restrict access to this address/port.
   gitaly['listen_addr'] = '0.0.0.0:8075'

   # Enable Prometheus metrics access to Gitaly. You must use firewalls
   # to restrict access to this address/port.
   gitaly['prometheus_listen_addr'] = '0.0.0.0:9236'
   ```

1. Configure a strong `auth_token` for **Gitaly** by editing
   `/etc/gitlab/gitlab.rb`. This will be needed by clients to communicate with
   this Gitaly nodes. Typically, this token will be the same for all Gitaly
   nodes.

   ```ruby
   gitaly['auth_token'] = 'PRAEFECT_INTERNAL_TOKEN'
   ```

1. Configure the GitLab Shell `secret_token`, and `internal_api_url` which are
   needed for `git push` operations.

   If you have already configured [Gitaly on its own server](../index.md)

   ```ruby
   gitlab_shell['secret_token'] = 'GITLAB_SHELL_SECRET_TOKEN'

   # Configure the gitlab-shell API callback URL. Without this, `git push` will
   # fail. This can be your front door GitLab URL or an internal load balancer.
   # Examples: 'https://example.gitlab.com', 'http://1.2.3.4'
   gitlab_rails['internal_api_url'] = 'GITLAB_SERVER_URL'
   ```

1. Configure the storage location for Git data by setting `git_data_dirs` in
   `/etc/gitlab/gitlab.rb`. Each Gitaly node should have a unique storage name
   (eg `gitaly-1`).

   Instead of configuring `git_data_dirs` uniquely for each Gitaly node, it is
   often easier to have include the configuration for all Gitaly nodes on every
   Gitaly node. This is supported because the Praefect `virtual_storages`
   configuration maps each storage name (eg `gitaly-1`) to a specific node, and
   requests are routed accordingly. This means every Gitaly node in your fleet
   can share the same configuration.

   ```ruby
   # You can include the data dirs for all nodes in the same config, because
   # Praefect will only route requests according to the addresses provided in the
   # prior step.
   git_data_dirs({
     "gitaly-1" => {
       "path" => "/var/opt/gitlab/git-data"
     },
     "gitaly-2" => {
       "path" => "/var/opt/gitlab/git-data"
     },
     "gitaly-3" => {
       "path" => "/var/opt/gitlab/git-data"
     }
   })
   ```

1. Save the changes to `/etc/gitlab/gitlab.rb` and [reconfigure Gitaly](../restart_gitlab.md#omnibus-gitlab-reconfigure):

   ```shell
   gitlab-ctl reconfigure
   ```

1. To ensure that Gitaly [has updated its Prometheus listen address](https://gitlab.com/gitlab-org/gitaly/-/issues/2521), [restart Gitaly](../restart_gitlab.md#omnibus-gitlab-restart):

   ```shell
   gitlab-ctl restart gitaly
   ```

**Complete these steps for each Gitaly node!**

After all Gitaly nodes are configured, you can run the Praefect connection
checker to verify Praefect can connect to all Gitaly servers in the Praefect
config.

1. SSH into the **Praefect** node and run the Praefect connection checker:

   ```shell
   sudo /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml dial-nodes
   ```

### GitLab

To complete this section you will need:

- [Configured Praefect node](#praefect)
- [Configured Gitaly nodes](#gitaly)

The Praefect cluster needs to be exposed as a storage location to the GitLab
application. This is done by updating the `git_data_dirs`.

Particular attention should be shown to:

- the storage name added to `git_data_dirs` in this section must match the
  storage name under `praefect['virtual_storages']` on the Praefect node. This
  was set in the [Praefect](#praefect) section of this guide. This document uses
  `praefect` as the Praefect storage name.

1. SSH into the **GitLab** node and login as root:

   ```shell
   sudo -i
   ```

1. Add the Praefect cluster as a storage location by editing
   `/etc/gitlab/gitlab.rb`.

   You will need to replace:

   - `PRAEFECT_HOST` with the IP address or hostname of the Praefect node
   - `PRAEFECT_EXTERNAL_TOKEN` with the real secret

   ```ruby
   git_data_dirs({
     "default" => {
       "path" => "/var/opt/gitlab/git-data"
     },
     "praefect" => {
       "gitaly_address" => "tcp://PRAEFECT_HOST:2305",
       "gitaly_token" => 'PRAEFECT_EXTERNAL_TOKEN'
     }
   })
   ```

1. Configure the `gitlab_shell['secret_token']` so that callbacks from Gitaly
   nodes during a `git push` are properly authenticated by editing
   `/etc/gitlab/gitlab.rb`:

   You will need to replace `GITLAB_SHELL_SECRET_TOKEN` with the real secret.

   ```ruby
   gitlab_shell['secret_token'] = 'GITLAB_SHELL_SECRET_TOKEN'
   ```

1. Configure the `external_url` so that files could be served by GitLab
   by proper endpoint access by editing `/etc/gitlab/gitlab.rb`:

   You will need to replace `GITLAB_SERVER_URL` with the real URL on which
   current GitLab instance is serving:

   ```ruby
   external_url 'GITLAB_SERVER_URL'
   ```

1. Add Prometheus monitoring settings by editing `/etc/gitlab/gitlab.rb`.

   You will need to replace:

   - `PRAEFECT_HOST` with the IP address or hostname of the Praefect node
   - `GITALY_HOST` with the IP address or hostname of each Gitaly node

   ```ruby
   prometheus['scrape_configs'] = [
     {
       'job_name' => 'praefect',
       'static_configs' => [
         'targets' => [
           'PRAEFECT_HOST:9652' # praefect
         ]
       ]
     },
     {
       'job_name' => 'praefect-gitaly',
       'static_configs' => [
         'targets' => [
           'GITALY_HOST:9236', # gitaly-1
           'GITALY_HOST:9236', # gitaly-2
           'GITALY_HOST:9236', # gitaly-3
         ]
       ]
     }
   ]

   grafana['disable_login_form'] = false
   ```

1. Save the changes to `/etc/gitlab/gitlab.rb` and [reconfigure GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure):

   ```shell
   gitlab-ctl reconfigure
   ```

1. Verify that GitLab can reach Praefect:

   ```shell
   gitlab-rake gitlab:gitaly:check
   ```

1. Set the Grafana admin password. This command will prompt you to enter a new password:

   ```shell
   gitlab-ctl set-grafana-password
   ```

1. Update the **Repository storage** settings from **Admin Area > Settings >
   Repository > Repository storage** to make the newly configured Praefect
   cluster the storage location for new Git repositories.

   - Deselect the **default** storage location
   - Select the **praefect** storage location

1. Verify everything is still working by creating a new project. Check the
   "Initialize repository with a README" box so that there is content in the
   repository that viewed. If the project is created, and you can see the
   README file, it works!

1. Inspect metrics by browsing to `/-/grafana` on your GitLab server.
   Log in with `admin` / `GRAFANA_PASSWORD`. Go to 'Explore' and query
   `gitlab_build_info` to verify that you are getting metrics from all your
   machines.

Congratulations! You have configured a highly available Praefect cluster.

## Migrating existing repositories to Praefect

If your GitLab instance already has repositories, these won't be migrated
automatically.

Repositories may be moved from one storage location using the [Repository
API](../../api/projects.html#edit-project):

```shell
curl --request PUT \
  --header "PRIVATE-TOKEN: <your_access_token>" \
  --data "repository_storage=praefect" \
  https://example.gitlab.com/api/v4/projects/123
```

## Debugging Praefect

If you receive an error, check `/var/log/gitlab/gitlab-rails/production.log`.

Here are common errors and potential causes:

- 500 response code
  - **ActionView::Template::Error (7:permission denied)**
    - `praefect['auth_token']` and `gitlab_rails['gitaly_token']` do not match on the GitLab server.
  - **Unable to save project. Error: 7:permission denied**
    - Secret token in `praefect['storage_nodes']` on GitLab server does not match the
      value in `gitaly['auth_token']` on one or more Gitaly servers.
- 503 response code
  - **GRPC::Unavailable (14:failed to connect to all addresses)**
    - GitLab was unable to reach Praefect.
  - **GRPC::Unavailable (14:all SubCons are in TransientFailure...)**
    - Praefect cannot reach one or more of its child Gitaly nodes. Try running
      the Praefect connection checker to diagnose.
