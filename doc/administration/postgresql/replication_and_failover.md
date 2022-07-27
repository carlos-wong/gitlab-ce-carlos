---
stage: Data Stores
group: Database
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# PostgreSQL replication and failover with Omnibus GitLab **(PREMIUM SELF)**

If you're a Free user of GitLab self-managed, consider using a cloud-hosted solution.
This document doesn't cover installations from source.

If a setup with replication and failover isn't what you were looking for, see
the [database configuration document](https://docs.gitlab.com/omnibus/settings/database.html)
for the Omnibus GitLab packages.

It's recommended to read this document fully before attempting to configure PostgreSQL with
replication and failover for GitLab.

## Architecture

The Omnibus GitLab recommended configuration for a PostgreSQL cluster with
replication failover requires:

- A minimum of three PostgreSQL nodes.
- A minimum of three Consul server nodes.
- A minimum of three PgBouncer nodes that track and handle primary database reads and writes.
  - An internal load balancer (TCP) to balance requests between the PgBouncer nodes.
- [Database Load Balancing](database_load_balancing.md) enabled.
  - A local PgBouncer service configured on each PostgreSQL node. Note that this is separate from the main PgBouncer cluster that tracks the primary.

```plantuml
@startuml
card "**Internal Load Balancer**" as ilb #9370DB
skinparam linetype ortho

together {
  collections "**GitLab Rails** x3" as gitlab #32CD32
  collections "**Sidekiq** x4" as sidekiq #ff8dd1
}

collections "**Consul** x3" as consul #e76a9b

card "Database" as database {
  collections "**PGBouncer x3**\n//Consul//" as pgbouncer #4EA7FF

  card "**PostgreSQL** //Primary//\n//Patroni//\n//PgBouncer//\n//Consul//" as postgres_primary #4EA7FF
  collections "**PostgreSQL** //Secondary// **x2**\n//Patroni//\n//PgBouncer//\n//Consul//" as postgres_secondary #4EA7FF

  pgbouncer -[#4EA7FF]-> postgres_primary
  postgres_primary .[#4EA7FF]r-> postgres_secondary
}

gitlab -[#32CD32]-> ilb
gitlab -[hidden]-> pgbouncer
gitlab .[#32CD32,norank]-> postgres_primary
gitlab .[#32CD32,norank]-> postgres_secondary

sidekiq -[#ff8dd1]-> ilb
sidekiq -[hidden]-> pgbouncer
sidekiq .[#ff8dd1,norank]-> postgres_primary
sidekiq .[#ff8dd1,norank]-> postgres_secondary

ilb -[#9370DB]-> pgbouncer

consul -[#e76a9b]r-> pgbouncer
consul .[#e76a9b,norank]r-> postgres_primary
consul .[#e76a9b,norank]r-> postgres_secondary
@enduml
```

You also need to take into consideration the underlying network topology, making
sure you have redundant connectivity between all Database and GitLab instances
to avoid the network becoming a single point of failure.

NOTE:
As of GitLab 13.3, PostgreSQL 12 is shipped with Omnibus GitLab. Clustering for PostgreSQL 12 is supported only with
Patroni. See the [Patroni](#patroni) section for further details. Starting with GitLab 14.0, only PostgreSQL 12 is
shipped with Omnibus GitLab, and thus Patroni becomes mandatory for replication and failover.

### Database node

Each database node runs four services:

- `PostgreSQL`: The database itself.
- `Patroni`: Communicates with other Patroni services in the cluster and handles failover when issues with the leader server occurs. The failover procedure consists of:
  - Selecting a new leader for the cluster.
  - Promoting the new node to leader.
  - Instructing remaining servers to follow the new leader node.
- `PgBouncer`: A local pooler for the node. Used for _read_ queries as part of [Database Load Balancing](database_load_balancing.md).
- `Consul` agent: To communicate with Consul cluster which stores the current Patroni state. The agent monitors the status of each node in the database cluster and tracks its health in a service definition on the Consul cluster.

### Consul server node

The Consul server node runs the Consul server service. These nodes must have reached the quorum and elected a leader _before_ Patroni cluster bootstrap; otherwise, database nodes wait until such Consul leader is elected.

### PgBouncer node

Each PgBouncer node runs two services:

- `PgBouncer`: The database connection pooler itself.
- `Consul` agent: Watches the status of the PostgreSQL service definition on the Consul cluster. If that status changes, Consul runs a script which updates the PgBouncer configuration to point to the new PostgreSQL leader node and reloads the PgBouncer service.

### Connection flow

Each service in the package comes with a set of [default ports](../package_information/defaults.md#ports). You may need to make specific firewall rules for the connections listed below:

There are several connection flows in this setup:

- [Primary](#primary)
- [Database Load Balancing](#database-load-balancing)
- [Replication](#replication)

#### Primary

- Application servers connect to either PgBouncer directly via its [default port](../package_information/defaults.md) or via a configured Internal Load Balancer (TCP) that serves multiple PgBouncers.
- PgBouncer connects to the primary database server's [PostgreSQL default port](../package_information/defaults.md).

#### Database Load Balancing

For read queries against data that haven't been recently changed and are up to date on all database nodes:

- Application servers connect to the local PgBouncer service via its [default port](../package_information/defaults.md) on each database node in a round-robin approach.
- Local PgBouncer connects to the local database server's [PostgreSQL default port](../package_information/defaults.md).

#### Replication

- Patroni actively manages the running PostgreSQL processes and configuration.
- PostgreSQL secondaries connect to the primary database servers [PostgreSQL default port](../package_information/defaults.md)
- Consul servers and agents connect to each others [Consul default ports](../package_information/defaults.md)

## Setting it up

### Required information

Before proceeding with configuration, you need to collect all the necessary
information.

#### Network information

PostgreSQL doesn't listen on any network interface by default. It needs to know
which IP address to listen on to be accessible to other services. Similarly,
PostgreSQL access is controlled based on the network source.

This is why you need:

- The IP address of each node's network interface. This can be set to `0.0.0.0` to
  listen on all interfaces. It cannot be set to the loopback address `127.0.0.1`.
- Network Address. This can be in subnet (that is, `192.168.0.0/255.255.255.0`)
  or Classless Inter-Domain Routing (CIDR) (`192.168.0.0/24`) form.

#### Consul information

When using default setup, minimum configuration requires:

- `CONSUL_USERNAME`. The default user for Omnibus GitLab is `gitlab-consul`
- `CONSUL_DATABASE_PASSWORD`. Password for the database user.
- `CONSUL_PASSWORD_HASH`. This is a hash generated out of Consul username/password pair. It can be generated with:

   ```shell
   sudo gitlab-ctl pg-password-md5 CONSUL_USERNAME
   ```

- `CONSUL_SERVER_NODES`. The IP addresses or DNS records of the Consul server nodes.

Few notes on the service itself:

- The service runs under a system account, by default `gitlab-consul`.
- If you are using a different username, you have to specify it through the `CONSUL_USERNAME` variable.
- Passwords are stored in the following locations:
  - `/etc/gitlab/gitlab.rb`: hashed
  - `/var/opt/gitlab/pgbouncer/pg_auth`: hashed
  - `/var/opt/gitlab/consul/.pgpass`: plaintext

#### PostgreSQL information

When configuring PostgreSQL, we do the following:

- Set `max_replication_slots` to double the number of database nodes. Patroni uses one extra slot per node when initiating the replication.
- Set `max_wal_senders` to one more than the allocated number of replication slots in the cluster. This prevents replication from using up all of the available database connections.

In this document we are assuming 3 database nodes, which makes this configuration:

```ruby
patroni['postgresql']['max_replication_slots'] = 6
patroni['postgresql']['max_wal_senders'] = 7
```

As previously mentioned, prepare the network subnets that need permission
to authenticate with the database.
You also need to have the IP addresses or DNS records of Consul
server nodes on hand.

You need the following password information for the application's database user:

- `POSTGRESQL_USERNAME`. The default user for Omnibus GitLab is `gitlab`
- `POSTGRESQL_USER_PASSWORD`. The password for the database user
- `POSTGRESQL_PASSWORD_HASH`. This is a hash generated out of the username/password pair.
  It can be generated with:

  ```shell
  sudo gitlab-ctl pg-password-md5 POSTGRESQL_USERNAME
  ```

#### Patroni information

You need the following password information for the Patroni API:

- `PATRONI_API_USERNAME`. A username for basic auth to the API
- `PATRONI_API_PASSWORD`. A password for basic auth to the API

#### PgBouncer information

When using a default setup, the minimum configuration requires:

- `PGBOUNCER_USERNAME`. The default user for Omnibus GitLab is `pgbouncer`
- `PGBOUNCER_PASSWORD`. This is a password for PgBouncer service.
- `PGBOUNCER_PASSWORD_HASH`. This is a hash generated out of PgBouncer username/password pair. It can be generated with:

  ```shell
  sudo gitlab-ctl pg-password-md5 PGBOUNCER_USERNAME
  ```

- `PGBOUNCER_NODE`, is the IP address or a FQDN of the node running PgBouncer.

Few things to remember about the service itself:

- The service runs as the same system account as the database. In the package, this is by default `gitlab-psql`
- If you use a non-default user account for PgBouncer service (by default `pgbouncer`), you need to specify this username.
- Passwords are stored in the following locations:
  - `/etc/gitlab/gitlab.rb`: hashed, and in plain text
  - `/var/opt/gitlab/pgbouncer/pg_auth`: hashed

### Installing Omnibus GitLab

First, make sure to [download/install](https://about.gitlab.com/install/)
Omnibus GitLab **on each node**.

Make sure you install the necessary dependencies from step 1,
add GitLab package repository from step 2.
When installing the GitLab package, do not supply `EXTERNAL_URL` value.

### Configuring the Database nodes

1. Make sure to [configure the Consul nodes](../consul.md).
1. Make sure you collect [`CONSUL_SERVER_NODES`](#consul-information), [`PGBOUNCER_PASSWORD_HASH`](#pgbouncer-information), [`POSTGRESQL_PASSWORD_HASH`](#postgresql-information), the [number of db nodes](#postgresql-information), and the [network address](#network-information) before executing the next step.

#### Configuring Patroni cluster

You must enable Patroni explicitly to be able to use it (with `patroni['enable'] = true`).

Any PostgreSQL configuration item that controls replication, for example `wal_level`, `max_wal_senders`, or others are strictly
controlled by Patroni. These configurations override the original settings that you make with the `postgresql[...]` configuration key.
Hence, they are all separated and placed under `patroni['postgresql'][...]`. This behavior is limited to replication.
Patroni honours any other PostgreSQL configuration that was made with the `postgresql[...]` configuration key. For example,
`max_wal_senders` by default is set to `5`. If you wish to change this you must set it with the `patroni['postgresql']['max_wal_senders']`
configuration key.

NOTE:
The configuration of a Patroni node is very similar to a repmgr but shorter. When Patroni is enabled, first you can ignore
any replication setting of PostgreSQL (which is overwritten). Then, you can remove any `repmgr[...]` or
repmgr-specific configuration as well. Especially, make sure that you remove `postgresql['shared_preload_libraries'] = 'repmgr_funcs'`.

Here is an example:

```ruby
# Disable all components except Patroni, PgBouncer and Consul
roles(['patroni_role', 'pgbouncer_role'])

# PostgreSQL configuration
postgresql['listen_address'] = '0.0.0.0'

# Disable automatic database migrations
gitlab_rails['auto_migrate'] = false

# Configure the Consul agent
consul['services'] = %w(postgresql)

# START user configuration
# Please set the real values as explained in Required Information section
#
# Replace PGBOUNCER_PASSWORD_HASH with a generated md5 value
postgresql['pgbouncer_user_password'] = 'PGBOUNCER_PASSWORD_HASH'
# Replace POSTGRESQL_REPLICATION_PASSWORD_HASH with a generated md5 value
postgresql['sql_replication_password'] = 'POSTGRESQL_REPLICATION_PASSWORD_HASH'
# Replace POSTGRESQL_PASSWORD_HASH with a generated md5 value
postgresql['sql_user_password'] = 'POSTGRESQL_PASSWORD_HASH'

# Replace PATRONI_API_USERNAME with a username for Patroni Rest API calls (use the same username in all nodes)
patroni['username'] = 'PATRONI_API_USERNAME'
# Replace PATRONI_API_PASSWORD with a password for Patroni Rest API calls (use the same password in all nodes)
patroni['password'] = 'PATRONI_API_PASSWORD'

# Sets `max_replication_slots` to double the number of database nodes.
# Patroni uses one extra slot per node when initiating the replication.
patroni['postgresql']['max_replication_slots'] = X

# Set `max_wal_senders` to one more than the number of replication slots in the cluster.
# This is used to prevent replication from using up all of the
# available database connections.
patroni['postgresql']['max_wal_senders'] = X+1

# Replace XXX.XXX.XXX.XXX/YY with Network Addresses for your other patroni nodes
patroni['allowlist'] = %w(XXX.XXX.XXX.XXX/YY 127.0.0.1/32)

# Replace XXX.XXX.XXX.XXX/YY with Network Address
postgresql['trust_auth_cidr_addresses'] = %w(XXX.XXX.XXX.XXX/YY 127.0.0.1/32)

# Local PgBouncer service for Database Load Balancing
pgbouncer['databases'] = {
  gitlabhq_production: {
    host: "127.0.0.1",
    user: "PGBOUNCER_USERNAME",
    password: 'PGBOUNCER_PASSWORD_HASH'
  }
}

# Replace placeholders:
#
# Y.Y.Y.Y consul1.gitlab.example.com Z.Z.Z.Z
# with the addresses gathered for CONSUL_SERVER_NODES
consul['configuration'] = {
  retry_join: %w(Y.Y.Y.Y consul1.gitlab.example.com Z.Z.Z.Z)
}
#
# END user configuration
```

All database nodes use the same configuration. The leader node is not determined in configuration,
and there is no additional or different configuration for either leader or replica nodes.

After the configuration of a node is complete, you must [reconfigure Omnibus GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure)
on each node for the changes to take effect.

Generally, when Consul cluster is ready, the first node that [reconfigures](../restart_gitlab.md#omnibus-gitlab-reconfigure)
becomes the leader. You do not need to sequence the nodes reconfiguration. You can run them in parallel or in any order.
If you choose an arbitrary order, you do not have any predetermined leader.

#### Enable Monitoring

> [Introduced](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/3786) in GitLab 12.0.

If you enable Monitoring, it must be enabled on **all** database servers.

1. Create/edit `/etc/gitlab/gitlab.rb` and add the following configuration:

   ```ruby
   # Enable service discovery for Prometheus
   consul['monitoring_service_discovery'] = true

   # Set the network addresses that the exporters must listen on
   node_exporter['listen_address'] = '0.0.0.0:9100'
   postgres_exporter['listen_address'] = '0.0.0.0:9187'
   ```

1. Run `sudo gitlab-ctl reconfigure` to compile the configuration.

#### Enable TLS support for the Patroni API

By default, Patroni's [REST API](https://patroni.readthedocs.io/en/latest/rest_api.html#rest-api) is served over HTTP.
You have the option to enable TLS and use HTTPS over the same [port](../package_information/defaults.md).

To enable TLS, you need PEM-formatted certificate and private key files. Both files must be readable by the PostgreSQL user (`gitlab-psql` by default, or the one set by `postgresql['username']`):

```ruby
patroni['tls_certificate_file'] = '/path/to/server/certificate.pem'
patroni['tls_key_file'] = '/path/to/server/key.pem'
```

If the server's private key is encrypted, specify the password to decrypt it:

```ruby
patroni['tls_key_password'] = 'private-key-password' # This is the plain-text password.
```

If you are using a self-signed certificate or an internal CA, you need to either disable the TLS verification or pass the certificate of the
internal CA, otherwise you may run into an unexpected error when using the `gitlab-ctl patroni ....` commands. Omnibus ensures that Patroni API
clients honor this configuration.

TLS certificate verification is enabled by default. To disable it:

```ruby
patroni['tls_verify'] = false
```

Alternatively, you can pass a PEM-formatted certificate of the internal CA. Again, the file must be readable by the PostgreSQL user:

```ruby
patroni['tls_ca_file'] = '/path/to/ca.pem'
```

When TLS is enabled, mutual authentication of the API server and client is possible for all endpoints, the extent of which depends on
the `patroni['tls_client_mode']` attribute:

- `none` (default): The API does not check for any client certificates.
- `optional`: Client certificates are required for all [unsafe](https://patroni.readthedocs.io/en/latest/security.html#protecting-the-rest-api) API calls.
- `required`: Client certificates are required for all API calls.

The client certificates are verified against the CA certificate that is specified with the `patroni['tls_ca_file']` attribute. Therefore,
this attribute is required for mutual TLS authentication. You also need to specify PEM-formatted client certificate and private key files.
Both files must be readable by the PostgreSQL user:

```ruby
patroni['tls_client_mode'] = 'required'
patroni['tls_ca_file'] = '/path/to/ca.pem'

patroni['tls_client_certificate_file'] = '/path/to/client/certificate.pem'
patroni['tls_client_key_file'] = '/path/to/client/key.pem'
```

You can use different certificates and keys for both API server and client on different Patroni nodes as long as they can be verified.
However, the CA certificate (`patroni['tls_ca_file']`), TLS certificate verification (`patroni['tls_verify']`), and client TLS
authentication mode (`patroni['tls_client_mode']`), must each have the same value on all nodes.

### Configure PgBouncer nodes

1. Make sure you collect [`CONSUL_SERVER_NODES`](#consul-information), [`CONSUL_PASSWORD_HASH`](#consul-information), and [`PGBOUNCER_PASSWORD_HASH`](#pgbouncer-information) before executing the next step.

1. One each node, edit the `/etc/gitlab/gitlab.rb` configuration file and replace values noted in the `# START user configuration` section as below:

   ```ruby
   # Disable all components except PgBouncer and Consul agent
   roles(['pgbouncer_role'])

   # Configure PgBouncer
   pgbouncer['admin_users'] = %w(pgbouncer gitlab-consul)

   # Configure Consul agent
   consul['watchers'] = %w(postgresql)

   # START user configuration
   # Please set the real values as explained in Required Information section
   # Replace CONSUL_PASSWORD_HASH with with a generated md5 value
   # Replace PGBOUNCER_PASSWORD_HASH with with a generated md5 value
   pgbouncer['users'] = {
     'gitlab-consul': {
       password: 'CONSUL_PASSWORD_HASH'
     },
     'pgbouncer': {
       password: 'PGBOUNCER_PASSWORD_HASH'
     }
   }
   # Replace placeholders:
   #
   # Y.Y.Y.Y consul1.gitlab.example.com Z.Z.Z.Z
   # with the addresses gathered for CONSUL_SERVER_NODES
   consul['configuration'] = {
     retry_join: %w(Y.Y.Y.Y consul1.gitlab.example.com Z.Z.Z.Z)
   }
   #
   # END user configuration
   ```

   NOTE:
   `pgbouncer_role` was introduced with GitLab 10.3.

1. Run `gitlab-ctl reconfigure`

1. Create a `.pgpass` file so Consul is able to
   reload PgBouncer. Enter the `PGBOUNCER_PASSWORD` twice when asked:

   ```shell
   gitlab-ctl write-pgpass --host 127.0.0.1 --database pgbouncer --user pgbouncer --hostuser gitlab-consul
   ```

1. [Enable monitoring](../postgresql/pgbouncer.md#enable-monitoring)

#### PgBouncer Checkpoint

1. Ensure each node is talking to the current node leader:

   ```shell
   gitlab-ctl pgb-console # Supply PGBOUNCER_PASSWORD when prompted
   ```

   If there is an error `psql: ERROR:  Auth failed` after typing in the
   password, ensure you have previously generated the MD5 password hashes with the correct
   format. The correct format is to concatenate the password and the username:
   `PASSWORDUSERNAME`. For example, `Sup3rS3cr3tpgbouncer` would be the text
   needed to generate an MD5 password hash for the `pgbouncer` user.

1. After the console prompt has become available, run the following queries:

   ```shell
   show databases ; show clients ;
   ```

   The output should be similar to the following:

   ```plaintext
           name         |  host       | port |      database       | force_user | pool_size | reserve_pool | pool_mode | max_connections | current_connections
   ---------------------+-------------+------+---------------------+------------+-----------+--------------+-----------+-----------------+---------------------
    gitlabhq_production | MASTER_HOST | 5432 | gitlabhq_production |            |        20 |            0 |           |               0 |                   0
    pgbouncer           |             | 6432 | pgbouncer           | pgbouncer  |         2 |            0 | statement |               0 |                   0
   (2 rows)

    type |   user    |      database       |  state  |   addr         | port  | local_addr | local_port |    connect_time     |    request_time     |    ptr    | link | remote_pid | tls
   ------+-----------+---------------------+---------+----------------+-------+------------+------------+---------------------+---------------------+-----------+------+------------+-----
    C    | pgbouncer | pgbouncer           | active  | 127.0.0.1      | 56846 | 127.0.0.1  |       6432 | 2017-08-21 18:09:59 | 2017-08-21 18:10:48 | 0x22b3880 |      |          0 |
   (2 rows)
   ```

#### Configure the internal load balancer

If you're running more than one PgBouncer node as recommended, you must set up a TCP internal load balancer to serve each correctly. This can be accomplished with any reputable TCP load balancer.

As an example, here's how you could do it with [HAProxy](https://www.haproxy.org/):

```plaintext
global
    log /dev/log local0
    log localhost local1 notice
    log stdout format raw local0

defaults
    log global
    default-server inter 10s fall 3 rise 2
    balance leastconn

frontend internal-pgbouncer-tcp-in
    bind *:6432
    mode tcp
    option tcplog

    default_backend pgbouncer

backend pgbouncer
    mode tcp
    option tcp-check

    server pgbouncer1 <ip>:6432 check
    server pgbouncer2 <ip>:6432 check
    server pgbouncer3 <ip>:6432 check
```

Refer to your preferred Load Balancer's documentation for further guidance.

### Configuring the Application nodes

Application nodes run the `gitlab-rails` service. You may have other
attributes set, but the following need to be set.

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   # Disable PostgreSQL on the application node
   postgresql['enable'] = false

   gitlab_rails['db_host'] = 'PGBOUNCER_NODE' or 'INTERNAL_LOAD_BALANCER'
   gitlab_rails['db_port'] = 6432
   gitlab_rails['db_password'] = 'POSTGRESQL_USER_PASSWORD'
   gitlab_rails['auto_migrate'] = false
   gitlab_rails['db_load_balancing'] = { 'hosts' => ['POSTGRESQL_NODE_1', 'POSTGRESQL_NODE_2', 'POSTGRESQL_NODE_3'] }
   ```

1. [Reconfigure GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

#### Application node post-configuration

Ensure that all migrations ran:

```shell
gitlab-rake gitlab:db:configure
```

> **Note**: If you encounter a `rake aborted!` error stating that PgBouncer is failing to connect to PostgreSQL it may be that your PgBouncer node's IP address is missing from
PostgreSQL's `trust_auth_cidr_addresses` in `gitlab.rb` on your database nodes. See
[PgBouncer error `ERROR:  pgbouncer cannot connect to server`](#pgbouncer-error-error-pgbouncer-cannot-connect-to-server)
in the Troubleshooting section before proceeding.

### Backups

Do not backup or restore GitLab through a PgBouncer connection: this causes a GitLab outage.

[Read more about this and how to reconfigure backups](../../raketasks/backup_restore.md#back-up-and-restore-for-installations-using-pgbouncer).

### Ensure GitLab is running

At this point, your GitLab instance should be up and running. Verify you're able
to sign in, and create issues and merge requests. If you encounter issues, see
the [Troubleshooting section](#troubleshooting).

## Example configuration

This section describes several fully expanded example configurations.

### Example recommended setup

This example uses three Consul servers, three PgBouncer servers (with an
associated internal load balancer), three PostgreSQL servers, and one
application node.

We start with all servers on the same 10.6.0.0/16 private network range, they
can connect to each freely other on those addresses.

Here is a list and description of each machine and the assigned IP:

- `10.6.0.11`: Consul 1
- `10.6.0.12`: Consul 2
- `10.6.0.13`: Consul 3
- `10.6.0.20`: Internal Load Balancer
- `10.6.0.21`: PgBouncer 1
- `10.6.0.22`: PgBouncer 2
- `10.6.0.23`: PgBouncer 3
- `10.6.0.31`: PostgreSQL 1
- `10.6.0.32`: PostgreSQL 2
- `10.6.0.33`: PostgreSQL 3
- `10.6.0.41`: GitLab application

All passwords are set to `toomanysecrets`. Please do not use this password or derived hashes and the `external_url` for GitLab is `http://gitlab.example.com`.

After the initial configuration, if a failover occurs, the PostgresSQL leader node changes to one of the available secondaries until it is failed back.

#### Example recommended setup for Consul servers

On each server edit `/etc/gitlab/gitlab.rb`:

```ruby
# Disable all components except Consul
roles(['consul_role'])

consul['configuration'] = {
  server: true,
  retry_join: %w(10.6.0.11 10.6.0.12 10.6.0.13)
}
consul['monitoring_service_discovery'] =  true
```

[Reconfigure Omnibus GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

#### Example recommended setup for PgBouncer servers

On each server edit `/etc/gitlab/gitlab.rb`:

```ruby
# Disable all components except Pgbouncer and Consul agent
roles(['pgbouncer_role'])

# Configure PgBouncer
pgbouncer['admin_users'] = %w(pgbouncer gitlab-consul)

pgbouncer['users'] = {
  'gitlab-consul': {
    password: '5e0e3263571e3704ad655076301d6ebe'
  },
  'pgbouncer': {
    password: '771a8625958a529132abe6f1a4acb19c'
  }
}

consul['watchers'] = %w(postgresql)
consul['configuration'] = {
  retry_join: %w(10.6.0.11 10.6.0.12 10.6.0.13)
}
consul['monitoring_service_discovery'] =  true
```

[Reconfigure Omnibus GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

#### Internal load balancer setup

An internal load balancer (TCP) is then required to be setup to serve each PgBouncer node (in this example on the IP of `10.6.0.20`). An example of how to do this can be found in the [PgBouncer Configure Internal Load Balancer](#configure-the-internal-load-balancer) section.

#### Example recommended setup for PostgreSQL servers

On database nodes edit `/etc/gitlab/gitlab.rb`:

```ruby
# Disable all components except Patroni, PgBouncer and Consul
roles(['patroni_role', 'pgbouncer_role'])

# PostgreSQL configuration
postgresql['listen_address'] = '0.0.0.0'
postgresql['hot_standby'] = 'on'
postgresql['wal_level'] = 'replica'

# Disable automatic database migrations
gitlab_rails['auto_migrate'] = false

postgresql['pgbouncer_user_password'] = '771a8625958a529132abe6f1a4acb19c'
postgresql['sql_user_password'] = '450409b85a0223a214b5fb1484f34d0f'
patroni['username'] = 'PATRONI_API_USERNAME'
patroni['password'] = 'PATRONI_API_PASSWORD'
patroni['postgresql']['max_replication_slots'] = 6
patroni['postgresql']['max_wal_senders'] = 7

patroni['allowlist'] = = %w(10.6.0.0/16 127.0.0.1/32)
postgresql['trust_auth_cidr_addresses'] = %w(10.6.0.0/16 127.0.0.1/32)

# Local PgBouncer service for Database Load Balancing
pgbouncer['databases'] = {
  gitlabhq_production: {
    host: "127.0.0.1",
    user: "pgbouncer",
    password: '771a8625958a529132abe6f1a4acb19c'
  }
}

# Configure the Consul agent
consul['services'] = %w(postgresql)
consul['configuration'] = {
  retry_join: %w(10.6.0.11 10.6.0.12 10.6.0.13)
}
consul['monitoring_service_discovery'] =  true
```

[Reconfigure Omnibus GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

#### Example recommended setup manual steps

After deploying the configuration follow these steps:

1. Find the primary database node:

   ```shell
   gitlab-ctl get-postgresql-primary
   ```

1. On `10.6.0.41`, our application server:

   Set `gitlab-consul` user's PgBouncer password to `toomanysecrets`:

   ```shell
   gitlab-ctl write-pgpass --host 127.0.0.1 --database pgbouncer --user pgbouncer --hostuser gitlab-consul
   ```

   Run database migrations:

   ```shell
   gitlab-rake gitlab:db:configure
   ```

## Patroni

NOTE:
Using Patroni instead of Repmgr is supported for PostgreSQL 11 and required for PostgreSQL 12. Starting with GitLab 14.0, only PostgreSQL 12 is available and hence Patroni is mandatory to achieve failover and replication.

Patroni is an opinionated solution for PostgreSQL high-availability. It takes the control of PostgreSQL, overrides its configuration, and manages its lifecycle (start, stop, restart). Patroni is the only option for PostgreSQL 12 clustering and for cascading replication for Geo deployments.

The fundamental [architecture](#example-recommended-setup-manual-steps) (mentioned above) does not change for Patroni.
You do not need any special consideration for Patroni while provisioning your database nodes. Patroni heavily relies on Consul to store the state of the cluster and elect a leader. Any failure in Consul cluster and its leader election propagates to the Patroni cluster as well.

Patroni monitors the cluster and handles any failover. When the primary node fails, it works with Consul to notify PgBouncer. On failure, Patroni handles the transitioning of the old primary to a replica and rejoins it to the cluster automatically.

With Patroni, the connection flow is slightly different. Patroni on each node connects to Consul agent to join the cluster. Only after this point it decides if the node is the primary or a replica. Based on this decision, it configures and starts PostgreSQL which it communicates with directly over a Unix socket. This means that if the Consul cluster is not functional or does not have a leader, Patroni and by extension PostgreSQL does not start. Patroni also exposes a REST API which can be accessed via its [default port](../package_information/defaults.md)
on each node.

### Check replication status

Run `gitlab-ctl patroni members` to query Patroni for a summary of the cluster status:

```plaintext
+ Cluster: postgresql-ha (6970678148837286213) ------+---------+---------+----+-----------+
| Member                              | Host         | Role    | State   | TL | Lag in MB |
+-------------------------------------+--------------+---------+---------+----+-----------+
| gitlab-database-1.example.com       | 172.18.0.111 | Replica | running |  5 |         0 |
| gitlab-database-2.example.com       | 172.18.0.112 | Replica | running |  5 |       100 |
| gitlab-database-3.example.com       | 172.18.0.113 | Leader  | running |  5 |           |
+-------------------------------------+--------------+---------+---------+----+-----------+
```

To verify the status of replication:

```shell
echo -e 'select * from pg_stat_wal_receiver\x\g\x \n select * from pg_stat_replication\x\g\x' | gitlab-psql
```

The same command can be run on all three database servers. It returns any information
about replication available depending on the role the server is performing.

The leader should return one record per replica:

```sql
-[ RECORD 1 ]----+------------------------------
pid              | 371
usesysid         | 16384
usename          | gitlab_replicator
application_name | gitlab-database-1.example.com
client_addr      | 172.18.0.111
client_hostname  |
client_port      | 42900
backend_start    | 2021-06-14 08:01:59.580341+00
backend_xmin     |
state            | streaming
sent_lsn         | 0/EA13220
write_lsn        | 0/EA13220
flush_lsn        | 0/EA13220
replay_lsn       | 0/EA13220
write_lag        |
flush_lag        |
replay_lag       |
sync_priority    | 0
sync_state       | async
reply_time       | 2021-06-18 19:17:14.915419+00
```

Investigate further if:

- There are missing or extra records.
- `reply_time` is not current.

The `lsn` fields relate to which write-ahead-log segments have been replicated.
Run the following on the leader to find out the current Log Sequence Number (LSN):

```shell
echo 'SELECT pg_current_wal_lsn();' | gitlab-psql
```

If a replica is not in sync, `gitlab-ctl patroni members` indicates the volume
of missing data, and the `lag` fields indicate the elapsed time.

Read more about the data returned by the leader
[in the PostgreSQL documentation](https://www.postgresql.org/docs/12/monitoring-stats.html#PG-STAT-REPLICATION-VIEW),
including other values for the `state` field.

The replicas should return:

```sql
-[ RECORD 1 ]---------+-------------------------------------------------------------------------------------------------
pid                   | 391
status                | streaming
receive_start_lsn     | 0/D000000
receive_start_tli     | 5
received_lsn          | 0/EA13220
received_tli          | 5
last_msg_send_time    | 2021-06-18 19:16:54.807375+00
last_msg_receipt_time | 2021-06-18 19:16:54.807512+00
latest_end_lsn        | 0/EA13220
latest_end_time       | 2021-06-18 19:07:23.844879+00
slot_name             | gitlab-database-1.example.com
sender_host           | 172.18.0.113
sender_port           | 5432
conninfo              | user=gitlab_replicator host=172.18.0.113 port=5432 application_name=gitlab-database-1.example.com
```

Read more about the data returned by the replica
[in the PostgreSQL documentation](https://www.postgresql.org/docs/12/monitoring-stats.html#PG-STAT-WAL-RECEIVER-VIEW).

### Selecting the appropriate Patroni replication method

[Review the Patroni documentation carefully](https://patroni.readthedocs.io/en/latest/SETTINGS.html#postgresql)
before making changes as **_some of the options carry a risk of potential data
loss if not fully understood_**. The [replication mode](https://patroni.readthedocs.io/en/latest/replication_modes.html)
configured determines the amount of tolerable data loss.

WARNING:
Replication is not a backup strategy! There is no replacement for a well-considered and tested backup solution.

Omnibus GitLab defaults [`synchronous_commit`](https://www.postgresql.org/docs/11/runtime-config-wal.html#GUC-SYNCHRONOUS-COMMIT) to `on`.

```ruby
postgresql['synchronous_commit'] = 'on'
gitlab['geo-postgresql']['synchronous_commit'] = 'on'
```

#### Customizing Patroni failover behavior

Omnibus GitLab exposes several options allowing more control over the [Patroni restoration process](#recovering-the-patroni-cluster).

Each option is shown below with its default value in `/etc/gitlab/gitlab.rb`.

```ruby
patroni['use_pg_rewind'] = true
patroni['remove_data_directory_on_rewind_failure'] = false
patroni['remove_data_directory_on_diverged_timelines'] = false
```

[The upstream documentation is always more up to date](https://patroni.readthedocs.io/en/latest/SETTINGS.html#postgresql), but the table below should provide a minimal overview of functionality.

|Setting|Overview|
|-|-|
|`use_pg_rewind`|Try running `pg_rewind` on the former cluster leader before it rejoins the database cluster.|
|`remove_data_directory_on_rewind_failure`|If `pg_rewind` fails, remove the local PostgreSQL data directory and re-replicate from the current cluster leader.|
|`remove_data_directory_on_diverged_timelines`|If `pg_rewind` cannot be used and the former leader's timeline has diverged from the current one, delete the local data directory and re-replicate from the current cluster leader.|

### Database authorization for Patroni

Patroni uses a Unix socket to manage the PostgreSQL instance. Therefore, a connection from the `local` socket must be trusted.

Also, replicas use the replication user (`gitlab_replicator` by default) to communicate with the leader. For this user,
you can choose between `trust` and `md5` authentication. If you set `postgresql['sql_replication_password']`,
Patroni uses `md5` authentication, and otherwise falls back to `trust`. You must to specify the cluster CIDR in
`postgresql['md5_auth_cidr_addresses']` or `postgresql['trust_auth_cidr_addresses']` respectively.

### Interacting with Patroni cluster

You can use `gitlab-ctl patroni members` to check the status of the cluster members. To check the status of each node
`gitlab-ctl patroni` provides two additional sub-commands, `check-leader` and `check-replica` which indicate if a node
is the primary or a replica.

When Patroni is enabled, it exclusively controls PostgreSQL's startup,
shutdown, and restart. This means, to shut down PostgreSQL on a certain node, you must shutdown Patroni on the same node with:

```shell
sudo gitlab-ctl stop patroni
```

Stopping or restarting the Patroni service on the leader node triggers an automatic failover. If you need Patroni to reload its configuration or restart the PostgreSQL process without triggering the failover, you must use the `reload` or `restart` sub-commands of `gitlab-ctl patroni` instead. These two sub-commands are wrappers of the same `patronictl` commands.

### Manual failover procedure for Patroni

While Patroni supports automatic failover, you also have the ability to perform
a manual one, where you have two slightly different options:

- **Failover**: allows you to perform a manual failover when there are no healthy nodes.
  You can perform this action in any PostgreSQL node:

  ```shell
  sudo gitlab-ctl patroni failover
  ```

- **Switchover**: only works when the cluster is healthy and allows you to schedule a switchover (it can happen immediately).
  You can perform this action in any PostgreSQL node:

  ```shell
  sudo gitlab-ctl patroni switchover
  ```

For further details on this subject, see the
[Patroni documentation](https://patroni.readthedocs.io/en/latest/rest_api.html#switchover-and-failover-endpoints).

#### Geo secondary site considerations

When a Geo secondary site is replicating from a primary site that uses `Patroni` and `PgBouncer`, [replicating through PgBouncer is not supported](https://github.com/pgbouncer/pgbouncer/issues/382#issuecomment-517911529). The secondary *must* replicate directly from the leader node in the `Patroni` cluster. When there is an automatic or manual failover in the `Patroni` cluster, you can manually re-point your secondary site to replicate from the new leader with:

```shell
sudo gitlab-ctl replicate-geo-database --host=<new_leader_ip> --replication-slot=<slot_name>
```

Otherwise, the replication does not happen, even if the original node gets re-added as a follower node. This re-syncs your secondary site database and may take a long time depending on the amount of data to sync. You may also need to run `gitlab-ctl reconfigure` if replication is still not working after re-syncing.

### Recovering the Patroni cluster

To recover the old primary and rejoin it to the cluster as a replica, you can start Patroni with:

```shell
sudo gitlab-ctl start patroni
```

No further configuration or intervention is needed.

### Maintenance procedure for Patroni

With Patroni enabled, you can run planned maintenance on your nodes. To perform maintenance on one node without Patroni, you can put it into maintenance mode with:

```shell
sudo gitlab-ctl patroni pause
```

When Patroni runs in a paused mode, it does not change the state of PostgreSQL. After you are done, you can resume Patroni:

```shell
sudo gitlab-ctl patroni resume
```

For further details, see [Patroni documentation on this subject](https://patroni.readthedocs.io/en/latest/pause.html).

### Switching from repmgr to Patroni

WARNING:
Switching from repmgr to Patroni is straightforward, the other way around is *not*. Rolling back from Patroni to repmgr can be complicated and may involve deletion of data directory. If you need to do that, please contact GitLab support.

You can switch an exiting database cluster to use Patroni instead of repmgr with the following steps:

1. Stop repmgr on all replica nodes and lastly with the primary node:

   ```shell
   sudo gitlab-ctl stop repmgrd
   ```

1. Stop PostgreSQL on all replica nodes:

   ```shell
   sudo gitlab-ctl stop postgresql
   ```

   NOTE:
   Ensure that there is no `walsender` process running on the primary node.
   `ps aux | grep walsender` must not show any running process.

1. On the primary node, [configure Patroni](#configuring-patroni-cluster). Remove `repmgr` and any other
   repmgr-specific configuration. Also remove any configuration that is related to PostgreSQL replication.
1. [Reconfigure Omnibus GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure) on the primary node.
   It makes it the leader. You can check this with:

   ```shell
   sudo gitlab-ctl tail patroni
   ```

1. Repeat the last two steps for all replica nodes. `gitlab.rb` should look the same on all nodes.
1. If present, remove the `gitlab_repmgr` database and role on the primary. If you don't delete the `gitlab_repmgr`
   database, upgrading PostgreSQL 11 to 12 fails with:

   ```plaintext
   could not load library "$libdir/repmgr_funcs": ERROR:  could not access file "$libdir/repmgr_funcs": No such file or directory
   ```

### Upgrading PostgreSQL major version in a Patroni cluster

As of GitLab 14.1, PostgreSQL 12.6 and 13.3 are both shipped with Omnibus GitLab by default. As of GitLab 15.0, PostgreSQL 13 is the default. If you want to upgrade to PostgreSQL 13 in versions prior to GitLab 15.0, you must ask for it explicitly.

WARNING:
The procedure for upgrading PostgreSQL in a Patroni cluster is different than when upgrading using repmgr.
The following outlines the key differences and important considerations that need to be accounted for when
upgrading PostgreSQL.

Here are a few key facts that you must consider before upgrading PostgreSQL:

- The main point is that you have to **shut down the Patroni cluster**. This means that your
  GitLab deployment is down for the duration of database upgrade or, at least, as long as your leader
  node is upgraded. This can be **a significant downtime depending on the size of your database**.

- Upgrading PostgreSQL creates a new data directory with a new control data. From Patroni's perspective this is a new cluster that needs to be bootstrapped again. Therefore, as part of the upgrade procedure, the cluster state (stored in Consul) is wiped out. After the upgrade is complete, Patroni bootstraps a new cluster. **This changes your _cluster ID_**.

- The procedures for upgrading leader and replicas are not the same. That is why it is important to use the right procedure on each node.

- Upgrading a replica node **deletes the data directory and resynchronizes it** from the leader using the
  configured replication method (`pg_basebackup` is the only available option). It might take some
  time for replica to catch up with the leader, depending on the size of your database.

- An overview of the upgrade procedure is outlined in [Patroni's documentation](https://patroni.readthedocs.io/en/latest/existing_data.html#major-upgrade-of-postgresql-version).
  You can still use `gitlab-ctl pg-upgrade` which implements this procedure with a few adjustments.

Considering these, you should carefully plan your PostgreSQL upgrade:

1. Find out which node is the leader and which node is a replica:

   ```shell
   gitlab-ctl patroni members
   ```

   NOTE:
   On a Geo secondary site, the Patroni leader node is called `standby leader`.

1. Stop Patroni **only on replicas**.

   ```shell
   sudo gitlab-ctl stop patroni
   ```

1. Enable the maintenance mode on the **application node**:

   ```shell
   sudo gitlab-ctl deploy-page up
   ```

1. Upgrade PostgreSQL on **the leader node** and make sure that the upgrade is completed successfully:

   ```shell
   sudo gitlab-ctl pg-upgrade -V 13
   ```

   NOTE:
   `gitlab-ctl pg-upgrade` tries to detect the role of the node. If for any reason the auto-detection
   does not work or you believe it did not detect the role correctly, you can use the `--leader` or
   `--replica` arguments to manually override it.

1. Check the status of the leader and cluster. You can proceed only if you have a healthy leader:

   ```shell
   gitlab-ctl patroni check-leader

   # OR

   gitlab-ctl patroni members
   ```

1. You can now disable the maintenance mode on the **application node**:

   ```shell
   sudo gitlab-ctl deploy-page down
   ```

1. Upgrade PostgreSQL **on replicas** (you can do this in parallel on all of them):

   ```shell
   sudo gitlab-ctl pg-upgrade -V 13
   ```

NOTE:
Reverting the PostgreSQL upgrade with `gitlab-ctl revert-pg-upgrade` has the same considerations as
`gitlab-ctl pg-upgrade`. You should follow the same procedure by first stopping the replicas,
then reverting the leader, and finally reverting the replicas.

## Troubleshooting

### Consul and PostgreSQL changes not taking effect

Due to the potential impacts, `gitlab-ctl reconfigure` only reloads Consul and PostgreSQL, it does not restart the services. However, not all changes can be activated by reloading.

To restart either service, run `gitlab-ctl restart SERVICE`

For PostgreSQL, it is usually safe to restart the leader node by default. Automatic failover defaults to a 1 minute timeout. Provided the database returns before then, nothing else needs to be done.

On the Consul server nodes, it is important to [restart the Consul service](../consul.md#restart-consul) in a controlled manner.

### PgBouncer error `ERROR: pgbouncer cannot connect to server`

You may get this error when running `gitlab-rake gitlab:db:configure` or you
may see the error in the PgBouncer log file.

```plaintext
PG::ConnectionBad: ERROR:  pgbouncer cannot connect to server
```

The problem may be that your PgBouncer node's IP address is not included in the
`trust_auth_cidr_addresses` setting in `/etc/gitlab/gitlab.rb` on the database nodes.

You can confirm that this is the issue by checking the PostgreSQL log on the leader
database node. If you see the following error then `trust_auth_cidr_addresses`
is the problem.

```plaintext
2018-03-29_13:59:12.11776 FATAL:  no pg_hba.conf entry for host "123.123.123.123", user "pgbouncer", database "gitlabhq_production", SSL off
```

To fix the problem, add the IP address to `/etc/gitlab/gitlab.rb`.

```ruby
postgresql['trust_auth_cidr_addresses'] = %w(123.123.123.123/32 <other_cidrs>)
```

[Reconfigure GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.

### Reinitialize a replica

If a replica cannot start or rejoin the cluster, or when it lags behind and can not catch up, it might be necessary to reinitialize the replica:

1. [Check the replication status](#check-replication-status) to confirm which server
   needs to be reinitialized. For example:

   ```plaintext
   + Cluster: postgresql-ha (6970678148837286213) ------+---------+--------------+----+-----------+
   | Member                              | Host         | Role    | State        | TL | Lag in MB |
   +-------------------------------------+--------------+---------+--------------+----+-----------+
   | gitlab-database-1.example.com       | 172.18.0.111 | Replica | running      | 55 |         0 |
   | gitlab-database-2.example.com       | 172.18.0.112 | Replica | start failed |    |   unknown |
   | gitlab-database-3.example.com       | 172.18.0.113 | Leader  | running      | 55 |           |
   +-------------------------------------+--------------+---------+--------------+----+-----------+
   ```

1. Sign in to the broken server and reinitialize the database and replication. Patroni will shut
   down PostgreSQL on that server, remove the data directory, and reinitialize it from scratch:

   ```shell
   sudo gitlab-ctl patroni reinitialize-replica --member gitlab-database-2.example.com
   ```

   This can be run on any Patroni node, but be aware that `sudo gitlab-ctl patroni
   reinitialize-replica` without `--member` will reinitialize the server it is run on.
   It is recommended to run it locally on the broken server to reduce the risk of
   unintended data loss.
1. Monitor the logs:

   ```shell
   sudo gitlab-ctl tail patroni
   ```

### Reset the Patroni state in Consul

WARNING:
This is a destructive process and may lead the cluster into a bad state. Make sure that you have a healthy backup before running this process.

As a last resort, if your Patroni cluster is in an unknown or bad state and no node can start, you can
reset the Patroni state in Consul completely, resulting in a reinitialized Patroni cluster when
the first Patroni node starts.

To reset the Patroni state in Consul:

1. Take note of the Patroni node that was the leader, or that the application thinks is the current leader, if the current state shows more than one, or none. One way to do this is to look on the PgBouncer nodes in `/var/opt/gitlab/consul/databases.ini`, which contains the hostname of the current leader.
1. Stop Patroni on all nodes:

   ```shell
   sudo gitlab-ctl stop patroni
   ```

1. Reset the state in Consul:

   ```shell
   /opt/gitlab/embedded/bin/consul kv delete -recurse /service/postgresql-ha/
   ```

1. Start one Patroni node, which initializes the Patroni cluster to elect as a leader.
   It's highly recommended to start the previous leader (noted in the first step),
   so as to not lose existing writes that may have not been replicated because
   of the broken cluster state:

   ```shell
   sudo gitlab-ctl start patroni
   ```

1. Start all other Patroni nodes that join the Patroni cluster as replicas:

   ```shell
   sudo gitlab-ctl start patroni
   ```

If you are still seeing issues, the next step is restoring the last healthy backup.

### Errors in the Patroni log about a `pg_hba.conf` entry for `127.0.0.1`

The following log entry in the Patroni log indicates the replication is not working
and a configuration change is needed:

```plaintext
FATAL:  no pg_hba.conf entry for replication connection from host "127.0.0.1", user "gitlab_replicator"
```

To fix the problem, ensure the loopback interface is included in the CIDR addresses list:

1. Edit `/etc/gitlab/gitlab.rb`:

   ```ruby
   postgresql['trust_auth_cidr_addresses'] = %w(<other_cidrs> 127.0.0.1/32)
   ```

1. [Reconfigure GitLab](../restart_gitlab.md#omnibus-gitlab-reconfigure) for the changes to take effect.
1. Check that [all the replicas are synchronized](#check-replication-status)

### Errors in Patroni logs: the requested start point is ahead of the Write Ahead Log (WAL) flush position

This error indicates that the database is not replicating:

```plaintext
FATAL:  could not receive data from WAL stream: ERROR:  requested starting point 0/5000000 is ahead of the WAL flush position of this server 0/4000388
```

This example error is from a replica that was initially misconfigured, and had never replicated.

Fix it [by reinitializing the replica](#reinitialize-a-replica).

### Patroni fails to start with `MemoryError`

Patroni may fail to start, logging an error and stack trace:

```plaintext
MemoryError
Traceback (most recent call last):
  File "/opt/gitlab/embedded/bin/patroni", line 8, in <module>
    sys.exit(main())
[..]
  File "/opt/gitlab/embedded/lib/python3.7/ctypes/__init__.py", line 273, in _reset_cache
    CFUNCTYPE(c_int)(lambda: None)
```

If the stack trace ends with `CFUNCTYPE(c_int)(lambda: None)`, this code triggers `MemoryError`
if the Linux server has been hardened for security.

The code causes Python to write temporary executable files, and if it cannot find a file system in which to do this. For example, if `noexec` is set on the `/tmp` file system, it fails with `MemoryError` ([read more in the issue](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/6184)).

Workarounds:

- Remove `noexec` from the mount options for filesystems like `/tmp` and `/var/tmp`.
- If set to enforcing, SELinux may also prevent these operations. Verify the issue is fixed by setting
  SELinux to permissive.

Patroni has been shipping with Omnibus GitLab since 13.1, along with a build of Python 3.7.
Workarounds should stop being required when GitLab 14.x starts shipping with
[a later version of Python](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/6164) as
the code which causes this was removed from Python 3.8.

### Issues with other components

If you're running into an issue with a component not outlined here, be sure to check the troubleshooting section of their specific documentation page:

- [Consul](../consul.md#troubleshooting-consul)
- [PostgreSQL](https://docs.gitlab.com/omnibus/settings/database.html#troubleshooting)
