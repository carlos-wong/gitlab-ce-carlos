---
type: reference
---

# Configuring Redis for Scaling and High Availability

## Provide your own Redis instance **(CORE ONLY)**

The following are the requirements for providing your own Redis instance:

- Redis version 2.8 or higher. Version 3.2 or higher is recommend as this is
  what ships with the GitLab Omnibus package.
- Standalone Redis or Redis high availability with Sentinel are supported. Redis
  Cluster is not supported.
- Managed Redis from cloud providers such as AWS Elasticache will work. If these
  services support high availability, be sure it is not the Redis Cluster type.

Note the Redis node's IP address or hostname, port, and password (if required).
These will be necessary when configuring the GitLab application servers later.

## Redis in a Scaled Environment

This section is relevant for [Scaled Architecture](README.md#scalable-architecture-examples)
environments including [Basic Scaling](README.md#basic-scaling) and
[Full Scaling](README.md#full-scaling).

### Provide your own Redis instance **(CORE ONLY)**

If you want to use your own deployed Redis instance(s),
see [Provide your own Redis instance](#provide-your-own-redis-instance-core-only)
for more details. However, you can use the GitLab Omnibus package to easily
deploy the bundled Redis.

### Standalone Redis using GitLab Omnibus **(CORE ONLY)**

The GitLab Omnibus package can be used to configure a standalone Redis server.
In this configuration Redis is not highly available, and represents a single
point of failure. However, in a scaled environment the objective is to allow
the environment to handle more users or to increase throughput. Redis itself
is generally stable and can handle many requests so it is an acceptable
trade off to have only a single instance. See [Scaling and High Availability](README.md)
for an overview of GitLab scaling and high availability options.

The steps below are the minimum necessary to configure a Redis server with
Omnibus:

1. SSH into the Redis server.
1. [Download/install](https://about.gitlab.com/install/) the Omnibus GitLab
   package you want using **steps 1 and 2** from the GitLab downloads page.
     - Do not complete any other steps on the download page.

1. Edit `/etc/gitlab/gitlab.rb` and add the contents:

   ```ruby
   ## Enable Redis
   redis['enable'] = true

   ## Disable all other services
   sidekiq['enable'] = false
   gitlab_workhorse['enable'] = false
   unicorn['enable'] = false
   postgresql['enable'] = false
   nginx['enable'] = false
   prometheus['enable'] = false
   alertmanager['enable'] = false
   pgbouncer_exporter['enable'] = false
   gitlab_exporter['enable'] = false
   gitaly['enable'] = false

   redis['bind'] = '0.0.0.0'
   redis['port'] = 6379
   redis['password'] = 'SECRET_PASSWORD_HERE'

   gitlab_rails['auto_migrate'] = false
   ```

1. [Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.
1. Note the Redis node's IP address or hostname, port, and
   Redis password. These will be necessary when configuring the GitLab
   application servers later.
1. [Enable Monitoring](#enable-monitoring)

Advanced configuration options are supported and can be added if
needed.

Continue configuration of other components by going
[back to Scaled Architectures](README.md#scalable-architecture-examples)

## Redis with High Availability

This section is relevant for [High Availability Architecture](README.md#high-availability-architecture-examples)
environments including [Horizontal](README.md#horizontal),
[Hybrid](README.md#hybrid), and
[Fully Distributed](README.md#fully-distributed).

### Provide your own Redis instance **(CORE ONLY)**

If you want to use your own deployed Redis instance(s),
see [Provide your own Redis instance](#provide-your-own-redis-instance-core-only)
for more details. However, you can use the GitLab Omnibus package to easily
deploy the bundled Redis.

### High Availability with GitLab Omnibus **(PREMIUM ONLY)**

> Experimental Redis Sentinel support was [introduced in GitLab 8.11][ce-1877].
Starting with 8.14, Redis Sentinel is no longer experimental.
If you've used it with versions `< 8.14` before, please check the updated
documentation here.

High Availability with [Redis] is possible using a **Master** x **Slave**
topology with a [Redis Sentinel][sentinel] service to watch and automatically
start the failover procedure.

You can choose to install and manage Redis and Sentinel yourself, use
a hosted cloud solution or you can use the one that comes bundled with
Omnibus GitLab packages.

> **Notes:**
>
> - Redis requires authentication for High Availability. See
>  [Redis Security](https://redis.io/topics/security) documentation for more
>  information. We recommend using a combination of a Redis password and tight
>  firewall rules to secure your Redis service.
> - You are highly encouraged to read the [Redis Sentinel][sentinel] documentation
>  before configuring Redis HA with GitLab to fully understand the topology and
>  architecture.
> - This is the documentation for the Omnibus GitLab packages. For installations
>  from source, follow the [Redis HA source installation](redis_source.md) guide.
> - Redis Sentinel daemon is bundled with Omnibus GitLab Enterprise Edition only.
>  For configuring Sentinel with the Omnibus GitLab Community Edition and
>  installations from source, read the
>  [Available configuration setups](#available-configuration-setups) section
>  below.

## Overview

Before diving into the details of setting up Redis and Redis Sentinel for HA,
make sure you read this Overview section to better understand how the components
are tied together.

You need at least `3` independent machines: physical, or VMs running into
distinct physical machines. It is essential that all master and slaves Redis
instances run in different machines. If you fail to provision the machines in
that specific way, any issue with the shared environment can bring your entire
setup down.

It is OK to run a Sentinel alongside of a master or slave Redis instance.
There should be no more than one Sentinel on the same machine though.

You also need to take into consideration the underlying network topology,
making sure you have redundant connectivity between Redis / Sentinel and
GitLab instances, otherwise the networks will become a single point of
failure.

Make sure that you read this document once as a whole before configuring the
components below.

> **Notes:**
>
> - Starting with GitLab `8.11`, you can configure a list of Redis Sentinel
>   servers that will monitor a group of Redis servers to provide failover support.
> - Starting with GitLab `8.14`, the Omnibus GitLab Enterprise Edition package
>  comes with Redis Sentinel daemon built-in.

High Availability with Redis requires a few things:

- Multiple Redis instances
- Run Redis in a **Master** x **Slave** topology
- Multiple Sentinel instances
- Application support and visibility to all Sentinel and Redis instances

Redis Sentinel can handle the most important tasks in an HA environment and that's
to help keep servers online with minimal to no downtime. Redis Sentinel:

- Monitors **Master** and **Slaves** instances to see if they are available
- Promotes a **Slave** to **Master** when the **Master** fails
- Demotes a **Master** to **Slave** when the failed **Master** comes back online
  (to prevent data-partitioning)
- Can be queried by the application to always connect to the current **Master**
  server

When a **Master** fails to respond, it's the application's responsibility
(in our case GitLab) to handle timeout and reconnect (querying a **Sentinel**
for a new **Master**).

To get a better understanding on how to correctly set up Sentinel, please read
the [Redis Sentinel documentation](https://redis.io/topics/sentinel) first, as
failing to configure it correctly can lead to data loss or can bring your
whole cluster down, invalidating the failover effort.

### Recommended setup

For a minimal setup, you will install the Omnibus GitLab package in `3`
**independent** machines, both with **Redis** and **Sentinel**:

- Redis Master + Sentinel
- Redis Slave + Sentinel
- Redis Slave + Sentinel

If you are not sure or don't understand why and where the amount of nodes come
from, read [Redis setup overview](#redis-setup-overview) and
[Sentinel setup overview](#sentinel-setup-overview).

For a recommended setup that can resist more failures, you will install
the Omnibus GitLab package in `5` **independent** machines, both with
**Redis** and **Sentinel**:

- Redis Master + Sentinel
- Redis Slave + Sentinel
- Redis Slave + Sentinel
- Redis Slave + Sentinel
- Redis Slave + Sentinel

### Redis setup overview

You must have at least `3` Redis servers: `1` Master, `2` Slaves, and they
need to each be on independent machines (see explanation above).

You can have additional Redis nodes, that will help survive a situation
where more nodes goes down. Whenever there is only `2` nodes online, a failover
will not be initiated.

As an example, if you have `6` Redis nodes, a maximum of `3` can be
simultaneously down.

Please note that there are different requirements for Sentinel nodes.
If you host them in the same Redis machines, you may need to take
that restrictions into consideration when calculating the amount of
nodes to be provisioned. See [Sentinel setup overview](#sentinel-setup-overview)
documentation for more information.

All Redis nodes should be configured the same way and with similar server specs, as
in a failover situation, any **Slave** can be promoted as the new **Master** by
the Sentinel servers.

The replication requires authentication, so you need to define a password to
protect all Redis nodes and the Sentinels. They will all share the same
password, and all instances must be able to talk to
each other over the network.

### Sentinel setup overview

Sentinels watch both other Sentinels and Redis nodes. Whenever a Sentinel
detects that a Redis node is not responding, it will announce that to the
other Sentinels. They have to reach the **quorum**, that is the minimum amount
of Sentinels that agrees a node is down, in order to be able to start a failover.

Whenever the **quorum** is met, the **majority** of all known Sentinel nodes
need to be available and reachable, so that they can elect the Sentinel **leader**
who will take all the decisions to restore the service availability by:

- Promoting a new **Master**
- Reconfiguring the other **Slaves** and make them point to the new **Master**
- Announce the new **Master** to every other Sentinel peer
- Reconfigure the old **Master** and demote to **Slave** when it comes back online

You must have at least `3` Redis Sentinel servers, and they need to
be each in an independent machine (that are believed to fail independently),
ideally in different geographical areas.

You can configure them in the same machines where you've configured the other
Redis servers, but understand that if a whole node goes down, you loose both
a Sentinel and a Redis instance.

The number of sentinels should ideally always be an **odd** number, for the
consensus algorithm to be effective in the case of a failure.

In a `3` nodes topology, you can only afford `1` Sentinel node going down.
Whenever the **majority** of the Sentinels goes down, the network partition
protection prevents destructive actions and a failover **will not be started**.

Here are some examples:

- With `5` or `6` sentinels, a maximum of `2` can go down for a failover begin.
- With `7` sentinels, a maximum of `3` nodes can go down.

The **Leader** election can sometimes fail the voting round when **consensus**
is not achieved (see the odd number of nodes requirement above). In that case,
a new attempt will be made after the amount of time defined in
`sentinel['failover_timeout']` (in milliseconds).

>**Note:**
We will see where `sentinel['failover_timeout']` is defined later.

The `failover_timeout` variable has a lot of different use cases. According to
the official documentation:

- The time needed to re-start a failover after a previous failover was
  already tried against the same master by a given Sentinel, is two
  times the failover timeout.

- The time needed for a slave replicating to a wrong master according
  to a Sentinel current configuration, to be forced to replicate
  with the right master, is exactly the failover timeout (counting since
  the moment a Sentinel detected the misconfiguration).

- The time needed to cancel a failover that is already in progress but
  did not produced any configuration change (SLAVEOF NO ONE yet not
  acknowledged by the promoted slave).

- The maximum time a failover in progress waits for all the slaves to be
  reconfigured as slaves of the new master. However even after this time
  the slaves will be reconfigured by the Sentinels anyway, but not with
  the exact parallel-syncs progression as specified.

### Available configuration setups

Based on your infrastructure setup and how you have installed GitLab, there are
multiple ways to configure Redis HA. Omnibus GitLab packages have Redis and/or
Redis Sentinel bundled with them so you only need to focus on configuration.
Pick the one that suits your needs.

- [Installations from source][source]: You need to install Redis and Sentinel
  yourself. Use the [Redis HA installation from source](redis_source.md)
  documentation.
- [Omnibus GitLab **Community Edition** (CE) package](https://about.gitlab.com/install/?version=ce): Redis is bundled, so you
  can use the package with only the Redis service enabled as described in steps
  1 and 2 of this document (works for both master and slave setups). To install
  and configure Sentinel, jump directly to the Sentinel section in the
  [Redis HA installation from source](redis_source.md#step-3-configuring-the-redis-sentinel-instances) documentation.
- [Omnibus GitLab **Enterprise Edition** (EE) package](https://about.gitlab.com/install/?version=ee): Both Redis and Sentinel
  are bundled in the package, so you can use the EE package to set up the whole
  Redis HA infrastructure (master, slave and Sentinel) which is described in
  this document.
- If you have installed GitLab using the Omnibus GitLab packages (CE or EE),
  but you want to use your own external Redis server, follow steps 1-3 in the
  [Redis HA installation from source](redis_source.md) documentation, then go
  straight to step 4 in this guide to
  [set up the GitLab application](#step-4-configuring-the-gitlab-application).

## Configuring Redis HA

This is the section where we install and set up the new Redis instances.

> **Notes:**
>
> - We assume that you have installed GitLab and all HA components from scratch. If you
>   already have it installed and running, read how to
>   [switch from a single-machine installation to Redis HA](#switching-from-an-existing-single-machine-installation-to-redis-ha).
> - Redis nodes (both master and slaves) will need the same password defined in
>   `redis['password']`. At any time during a failover the Sentinels can
>  reconfigure a node and change its status from master to slave and vice versa.

### Prerequisites

The prerequisites for a HA Redis setup are the following:

1. Provision the minimum required number of instances as specified in the
   [recommended setup](#recommended-setup) section.
1. We **Do not** recommend installing Redis or Redis Sentinel in the same machines your
   GitLab application is running on as this weakens your HA configuration. You can however opt in to install Redis
   and Sentinel in the same machine.
1. All Redis nodes must be able to talk to each other and accept incoming
   connections over Redis (`6379`) and Sentinel (`26379`) ports (unless you
   change the default ones).
1. The server that hosts the GitLab application must be able to access the
   Redis nodes.
1. Protect the nodes from access from external networks ([Internet][it]), using
   firewall.

### Step 1. Configuring the master Redis instance

1. SSH into the **master** Redis server.
1. [Download/install](https://about.gitlab.com/install/) the Omnibus GitLab
   package you want using **steps 1 and 2** from the GitLab downloads page.
   - Make sure you select the correct Omnibus package, with the same version
     and type (Community, Enterprise editions) of your current install.
   - Do not complete any other steps on the download page.

1. Edit `/etc/gitlab/gitlab.rb` and add the contents:

   ```ruby
   # Specify server role as 'redis_master_role'
   roles ['redis_master_role']

   # IP address pointing to a local IP that the other machines can reach to.
   # You can also set bind to '0.0.0.0' which listen in all interfaces.
   # If you really need to bind to an external accessible IP, make
   # sure you add extra firewall rules to prevent unauthorized access.
   redis['bind'] = '10.0.0.1'

   # Define a port so Redis can listen for TCP requests which will allow other
   # machines to connect to it.
   redis['port'] = 6379

   # Set up password authentication for Redis (use the same password in all nodes).
   redis['password'] = 'redis-password-goes-here'
   ```

1. Only the primary GitLab application server should handle migrations. To
   prevent database migrations from running on upgrade, add the following
   configuration to your `/etc/gitlab/gitlab.rb` file:

   ```
   gitlab_rails['auto_migrate'] = false
   ```

1. [Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.

> Note: You can specify multiple roles like sentinel and Redis as:
> `roles ['redis_sentinel_role', 'redis_master_role']`. Read more about high
> availability roles at <https://docs.gitlab.com/omnibus/roles/>.

### Step 2. Configuring the slave Redis instances

1. SSH into the **slave** Redis server.
1. [Download/install](https://about.gitlab.com/install/) the Omnibus GitLab
   package you want using **steps 1 and 2** from the GitLab downloads page.
   - Make sure you select the correct Omnibus package, with the same version
     and type (Community, Enterprise editions) of your current install.
   - Do not complete any other steps on the download page.

1. Edit `/etc/gitlab/gitlab.rb` and add the contents:

   ```ruby
   # Specify server role as 'redis_slave_role'
   roles ['redis_slave_role']

   # IP address pointing to a local IP that the other machines can reach to.
   # You can also set bind to '0.0.0.0' which listen in all interfaces.
   # If you really need to bind to an external accessible IP, make
   # sure you add extra firewall rules to prevent unauthorized access.
   redis['bind'] = '10.0.0.2'

   # Define a port so Redis can listen for TCP requests which will allow other
   # machines to connect to it.
   redis['port'] = 6379

   # The same password for Redis authentication you set up for the master node.
   redis['password'] = 'redis-password-goes-here'

   # The IP of the master Redis node.
   redis['master_ip'] = '10.0.0.1'

   # Port of master Redis server, uncomment to change to non default. Defaults
   # to `6379`.
   #redis['master_port'] = 6379
   ```

1. To prevent reconfigure from running automatically on upgrade, run:

   ```
   sudo touch /etc/gitlab/skip-auto-reconfigure
   ```

1. [Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.
1. Go through the steps again for all the other slave nodes.

> Note: You can specify multiple roles like sentinel and Redis as:
> `roles ['redis_sentinel_role', 'redis_slave_role']`. Read more about high
> availability roles at <https://docs.gitlab.com/omnibus/roles/>.

---

These values don't have to be changed again in `/etc/gitlab/gitlab.rb` after
a failover, as the nodes will be managed by the Sentinels, and even after a
`gitlab-ctl reconfigure`, they will get their configuration restored by
the same Sentinels.

### Step 3. Configuring the Redis Sentinel instances

>**Note:**
Redis Sentinel is bundled with Omnibus GitLab Enterprise Edition only. The
following section assumes you are using Omnibus GitLab Enterprise Edition.
For the Omnibus Community Edition and installations from source, follow the
[Redis HA source install](redis_source.md) guide.

NOTE: **Note:** If you are using an external Redis Sentinel instance, be sure
to exclude the `requirepass` parameter from the Sentinel
configuration. This parameter will cause clients to report `NOAUTH
Authentication required.`. [Redis Sentinel 3.2.x does not support
password authentication](https://github.com/antirez/redis/issues/3279).

Now that the Redis servers are all set up, let's configure the Sentinel
servers.

If you are not sure if your Redis servers are working and replicating
correctly, please read the [Troubleshooting Replication](#troubleshooting-redis-replication)
and fix it before proceeding with Sentinel setup.

You must have at least `3` Redis Sentinel servers, and they need to
be each in an independent machine. You can configure them in the same
machines where you've configured the other Redis servers.

With GitLab Enterprise Edition, you can use the Omnibus package to set up
multiple machines with the Sentinel daemon.

---

1. SSH into the server that will host Redis Sentinel.
1. **You can omit this step if the Sentinels will be hosted in the same node as
   the other Redis instances.**

   [Download/install](https://about.gitlab.com/downloads-ee) the
   Omnibus GitLab Enterprise Edition package using **steps 1 and 2** from the
   GitLab downloads page.
   - Make sure you select the correct Omnibus package, with the same version
     the GitLab application is running.
   - Do not complete any other steps on the download page.

1. Edit `/etc/gitlab/gitlab.rb` and add the contents (if you are installing the
   Sentinels in the same node as the other Redis instances, some values might
   be duplicate below):

   ```ruby
   roles ['redis_sentinel_role']

   # Must be the same in every sentinel node
   redis['master_name'] = 'gitlab-redis'

   # The same password for Redis authentication you set up for the master node.
   redis['master_password'] = 'redis-password-goes-here'

   # The IP of the master Redis node.
   redis['master_ip'] = '10.0.0.1'

   # Define a port so Redis can listen for TCP requests which will allow other
   # machines to connect to it.
   redis['port'] = 6379

   # Port of master Redis server, uncomment to change to non default. Defaults
   # to `6379`.
   #redis['master_port'] = 6379

   ## Configure Sentinel
   sentinel['bind'] = '10.0.0.1'

   # Port that Sentinel listens on, uncomment to change to non default. Defaults
   # to `26379`.
   # sentinel['port'] = 26379

   ## Quorum must reflect the amount of voting sentinels it take to start a failover.
   ## Value must NOT be greater then the amount of sentinels.
   ##
   ## The quorum can be used to tune Sentinel in two ways:
   ## 1. If a the quorum is set to a value smaller than the majority of Sentinels
   ##    we deploy, we are basically making Sentinel more sensible to master failures,
   ##    triggering a failover as soon as even just a minority of Sentinels is no longer
   ##    able to talk with the master.
   ## 1. If a quorum is set to a value greater than the majority of Sentinels, we are
   ##    making Sentinel able to failover only when there are a very large number (larger
   ##    than majority) of well connected Sentinels which agree about the master being down.s
   sentinel['quorum'] = 2

   ## Consider unresponsive server down after x amount of ms.
   # sentinel['down_after_milliseconds'] = 10000

   ## Specifies the failover timeout in milliseconds. It is used in many ways:
   ##
   ## - The time needed to re-start a failover after a previous failover was
   ##   already tried against the same master by a given Sentinel, is two
   ##   times the failover timeout.
   ##
   ## - The time needed for a slave replicating to a wrong master according
   ##   to a Sentinel current configuration, to be forced to replicate
   ##   with the right master, is exactly the failover timeout (counting since
   ##   the moment a Sentinel detected the misconfiguration).
   ##
   ## - The time needed to cancel a failover that is already in progress but
   ##   did not produced any configuration change (SLAVEOF NO ONE yet not
   ##   acknowledged by the promoted slave).
   ##
   ## - The maximum time a failover in progress waits for all the slaves to be
   ##   reconfigured as slaves of the new master. However even after this time
   ##   the slaves will be reconfigured by the Sentinels anyway, but not with
   ##   the exact parallel-syncs progression as specified.
   # sentinel['failover_timeout'] = 60000
   ```

1. To prevent database migrations from running on upgrade, run:

   ```
   sudo touch /etc/gitlab/skip-auto-reconfigure
   ```

   Only the primary GitLab application server should handle migrations.

1. [Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.
1. Go through the steps again for all the other Sentinel nodes.

### Step 4. Configuring the GitLab application

The final part is to inform the main GitLab application server of the Redis
Sentinels servers and authentication credentials.

You can enable or disable Sentinel support at any time in new or existing
installations. From the GitLab application perspective, all it requires is
the correct credentials for the Sentinel nodes.

While it doesn't require a list of all Sentinel nodes, in case of a failure,
it needs to access at least one of the listed.

>**Note:**
The following steps should be performed in the [GitLab application server](gitlab.md)
which ideally should not have Redis or Sentinels on it for a HA setup.

1. SSH into the server where the GitLab application is installed.
1. Edit `/etc/gitlab/gitlab.rb` and add/change the following lines:

   ```ruby
   ## Must be the same in every sentinel node
   redis['master_name'] = 'gitlab-redis'

   ## The same password for Redis authentication you set up for the master node.
   redis['master_password'] = 'redis-password-goes-here'

   ## A list of sentinels with `host` and `port`
   gitlab_rails['redis_sentinels'] = [
     {'host' => '10.0.0.1', 'port' => 26379},
     {'host' => '10.0.0.2', 'port' => 26379},
     {'host' => '10.0.0.3', 'port' => 26379}
   ]
   ```

1. [Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.

## Switching from an existing single-machine installation to Redis HA

If you already have a single-machine GitLab install running, you will need to
replicate from this machine first, before de-activating the Redis instance
inside it.

Your single-machine install will be the initial **Master**, and the `3` others
should be configured as **Slave** pointing to this machine.

After replication catches up, you will need to stop services in the
single-machine install, to rotate the **Master** to one of the new nodes.

Make the required changes in configuration and restart the new nodes again.

To disable Redis in the single install, edit `/etc/gitlab/gitlab.rb`:

```ruby
redis['enable'] = false
```

If you fail to replicate first, you may loose data (unprocessed background jobs).

## Example of a minimal configuration with 1 master, 2 slaves and 3 Sentinels

>**Note:**
Redis Sentinel is bundled with Omnibus GitLab Enterprise Edition only. For
different setups, read the
[available configuration setups](#available-configuration-setups) section.

In this example we consider that all servers have an internal network
interface with IPs in the `10.0.0.x` range, and that they can connect
to each other using these IPs.

In a real world usage, you would also set up firewall rules to prevent
unauthorized access from other machines and block traffic from the
outside (Internet).

We will use the same `3` nodes with **Redis** + **Sentinel** topology
discussed in [Redis setup overview](#redis-setup-overview) and
[Sentinel setup overview](#sentinel-setup-overview) documentation.

Here is a list and description of each **machine** and the assigned **IP**:

- `10.0.0.1`: Redis Master + Sentinel 1
- `10.0.0.2`: Redis Slave 1 + Sentinel 2
- `10.0.0.3`: Redis Slave 2 + Sentinel 3
- `10.0.0.4`: GitLab application

Please note that after the initial configuration, if a failover is initiated
by the Sentinel nodes, the Redis nodes will be reconfigured and the **Master**
will change permanently (including in `redis.conf`) from one node to the other,
until a new failover is initiated again.

The same thing will happen with `sentinel.conf` that will be overridden after the
initial execution, after any new sentinel node starts watching the **Master**,
or a failover promotes a different **Master** node.

### Example configuration for Redis master and Sentinel 1

In `/etc/gitlab/gitlab.rb`:

```ruby
roles ['redis_sentinel_role', 'redis_master_role']
redis['bind'] = '10.0.0.1'
redis['port'] = 6379
redis['password'] = 'redis-password-goes-here'
redis['master_name'] = 'gitlab-redis' # must be the same in every sentinel node
redis['master_password'] = 'redis-password-goes-here' # the same value defined in redis['password'] in the master instance
redis['master_ip'] = '10.0.0.1' # ip of the initial master redis instance
#redis['master_port'] = 6379 # port of the initial master redis instance, uncomment to change to non default
sentinel['bind'] = '10.0.0.1'
# sentinel['port'] = 26379 # uncomment to change default port
sentinel['quorum'] = 2
# sentinel['down_after_milliseconds'] = 10000
# sentinel['failover_timeout'] = 60000
```

[Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.

### Example configuration for Redis slave 1 and Sentinel 2

In `/etc/gitlab/gitlab.rb`:

```ruby
roles ['redis_sentinel_role', 'redis_slave_role']
redis['bind'] = '10.0.0.2'
redis['port'] = 6379
redis['password'] = 'redis-password-goes-here'
redis['master_password'] = 'redis-password-goes-here'
redis['master_ip'] = '10.0.0.1' # IP of master Redis server
#redis['master_port'] = 6379 # Port of master Redis server, uncomment to change to non default
redis['master_name'] = 'gitlab-redis' # must be the same in every sentinel node
sentinel['bind'] = '10.0.0.2'
# sentinel['port'] = 26379 # uncomment to change default port
sentinel['quorum'] = 2
# sentinel['down_after_milliseconds'] = 10000
# sentinel['failover_timeout'] = 60000
```

[Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.

### Example configuration for Redis slave 2 and Sentinel 3

In `/etc/gitlab/gitlab.rb`:

```ruby
roles ['redis_sentinel_role', 'redis_slave_role']
redis['bind'] = '10.0.0.3'
redis['port'] = 6379
redis['password'] = 'redis-password-goes-here'
redis['master_password'] = 'redis-password-goes-here'
redis['master_ip'] = '10.0.0.1' # IP of master Redis server
#redis['master_port'] = 6379 # Port of master Redis server, uncomment to change to non default
redis['master_name'] = 'gitlab-redis' # must be the same in every sentinel node
sentinel['bind'] = '10.0.0.3'
# sentinel['port'] = 26379 # uncomment to change default port
sentinel['quorum'] = 2
# sentinel['down_after_milliseconds'] = 10000
# sentinel['failover_timeout'] = 60000
```

[Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.

### Example configuration for the GitLab application

In `/etc/gitlab/gitlab.rb`:

```ruby
redis['master_name'] = 'gitlab-redis'
redis['master_password'] = 'redis-password-goes-here'
gitlab_rails['redis_sentinels'] = [
  {'host' => '10.0.0.1', 'port' => 26379},
  {'host' => '10.0.0.2', 'port' => 26379},
  {'host' => '10.0.0.3', 'port' => 26379}
]
```

[Reconfigure Omnibus GitLab][reconfigure] for the changes to take effect.

## Enable Monitoring

> [Introduced](https://gitlab.com/gitlab-org/omnibus-gitlab/issues/3786) in GitLab 12.0.

If you enable Monitoring, it must be enabled on **all** Redis servers.

1. Make sure to collect [`CONSUL_SERVER_NODES`](database.md#consul-information), which are the IP addresses or DNS records of the Consul server nodes, for the next step. Note they are presented as `Y.Y.Y.Y consul1.gitlab.example.com Z.Z.Z.Z`

1. Create/edit `/etc/gitlab/gitlab.rb` and add the following configuration:

   ```ruby
   # Enable service discovery for Prometheus
   consul['enable'] = true
   consul['monitoring_service_discovery'] =  true

   # Replace placeholders
   # Y.Y.Y.Y consul1.gitlab.example.com Z.Z.Z.Z
   # with the addresses of the Consul server nodes
   consul['configuration'] = {
      retry_join: %w(Y.Y.Y.Y consul1.gitlab.example.com Z.Z.Z.Z),
   }

   # Set the network addresses that the exporters will listen on
   node_exporter['listen_address'] = '0.0.0.0:9100'
   redis_exporter['listen_address'] = '0.0.0.0:9121'
   ```

1. Run `sudo gitlab-ctl reconfigure` to compile the configuration.

## Advanced configuration

Omnibus GitLab configures some things behind the curtains to make the sysadmins'
lives easier. If you want to know what happens underneath keep reading.

### Running multiple Redis clusters

GitLab supports running [separate Redis clusters for different persistent
classes](https://docs.gitlab.com/omnibus/settings/redis.html#running-with-multiple-redis-instances):
cache, queues, and shared_state. To make this work with Sentinel:

1. Set the appropriate variable in `/etc/gitlab/gitlab.rb` for each instance you are using:

   ```ruby
   gitlab_rails['redis_cache_instance'] = REDIS_CACHE_URL
   gitlab_rails['redis_queues_instance'] = REDIS_QUEUES_URL
   gitlab_rails['redis_shared_state_instance'] = REDIS_SHARED_STATE_URL
   ```

    **Note**: Redis URLs should be in the format: `redis://:PASSWORD@SENTINEL_MASTER_NAME`

   1. PASSWORD is the plaintext password for the Redis instance
   1. SENTINEL_MASTER_NAME is the Sentinel master name (e.g. `gitlab-redis-cache`)

1. Include an array of hashes with host/port combinations, such as the following:

   ```ruby
   gitlab_rails['redis_cache_sentinels'] = [
     { host: REDIS_CACHE_SENTINEL_HOST, port: PORT1 },
     { host: REDIS_CACHE_SENTINEL_HOST2, port: PORT2 }
   ]
   gitlab_rails['redis_queues_sentinels'] = [
     { host: REDIS_QUEUES_SENTINEL_HOST, port: PORT1 },
     { host: REDIS_QUEUES_SENTINEL_HOST2, port: PORT2 }
   ]
   gitlab_rails['redis_shared_state_sentinels'] = [
     { host: SHARED_STATE_SENTINEL_HOST, port: PORT1 },
     { host: SHARED_STATE_SENTINEL_HOST2, port: PORT2 }
   ]
   ```

1. Note that for each persistence class, GitLab will default to using the
   configuration specified in `gitlab_rails['redis_sentinels']` unless
   overridden by the settings above.
1. Be sure to include BOTH configuration options for each persistent classes. For example,
   if you choose to configure a cache instance, you must specify both `gitlab_rails['redis_cache_instance']`
   and `gitlab_rails['redis_cache_sentinels']` for GitLab to generate the proper configuration files.
1. Run `gitlab-ctl reconfigure`

### Control running services

In the previous example, we've used `redis_sentinel_role` and
`redis_master_role` which simplifies the amount of configuration changes.

If you want more control, here is what each one sets for you automatically
when enabled:

```ruby
## Redis Sentinel Role
redis_sentinel_role['enable'] = true

# When Sentinel Role is enabled, the following services are also enabled
sentinel['enable'] = true

# The following services are disabled
redis['enable'] = false
bootstrap['enable'] = false
nginx['enable'] = false
postgresql['enable'] = false
gitlab_rails['enable'] = false
mailroom['enable'] = false

-------

## Redis master/slave Role
redis_master_role['enable'] = true # enable only one of them
redis_slave_role['enable'] = true # enable only one of them

# When Redis Master or Slave role are enabled, the following services are
# enabled/disabled. Note that if Redis and Sentinel roles are combined, both
# services will be enabled.

# The following services are disabled
sentinel['enable'] = false
bootstrap['enable'] = false
nginx['enable'] = false
postgresql['enable'] = false
gitlab_rails['enable'] = false
mailroom['enable'] = false

# For Redis Slave role, also change this setting from default 'true' to 'false':
redis['master'] = false
```

You can find the relevant attributes defined in [gitlab_rails.rb][omnifile].

## Troubleshooting

There are a lot of moving parts that needs to be taken care carefully
in order for the HA setup to work as expected.

Before proceeding with the troubleshooting below, check your firewall rules:

- Redis machines
  - Accept TCP connection in `6379`
  - Connect to the other Redis machines via TCP in `6379`
- Sentinel machines
  - Accept TCP connection in `26379`
  - Connect to other Sentinel machines via TCP in `26379`
  - Connect to the Redis machines via TCP in `6379`

### Troubleshooting Redis replication

You can check if everything is correct by connecting to each server using
`redis-cli` application, and sending the `info replication` command as below.

```
/opt/gitlab/embedded/bin/redis-cli -h <redis-host-or-ip> -a '<redis-password>' info replication
```

When connected to a `master` Redis, you will see the number of connected
`slaves`, and a list of each with connection details:

```
# Replication
role:master
connected_slaves:1
slave0:ip=10.133.5.21,port=6379,state=online,offset=208037514,lag=1
master_repl_offset:208037658
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:206989083
repl_backlog_histlen:1048576
```

When it's a `slave`, you will see details of the master connection and if
its `up` or `down`:

```
# Replication
role:slave
master_host:10.133.1.58
master_port:6379
master_link_status:up
master_last_io_seconds_ago:1
master_sync_in_progress:0
slave_repl_offset:208096498
slave_priority:100
slave_read_only:1
connected_slaves:0
master_repl_offset:0
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0
```

### Troubleshooting Sentinel

If you get an error like: `Redis::CannotConnectError: No sentinels available.`,
there may be something wrong with your configuration files or it can be related
to [this issue][gh-531].

You must make sure you are defining the same value in `redis['master_name']`
and `redis['master_pasword']` as you defined for your sentinel node.

The way the Redis connector `redis-rb` works with sentinel is a bit
non-intuitive. We try to hide the complexity in omnibus, but it still requires
a few extra configs.

---

To make sure your configuration is correct:

1. SSH into your GitLab application server
1. Enter the Rails console:

   ```
   # For Omnibus installations
   sudo gitlab-rails console

   # For source installations
   sudo -u git rails console production
   ```

1. Run in the console:

   ```ruby
   redis = Redis.new(Gitlab::Redis::SharedState.params)
   redis.info
   ```

   Keep this screen open and try to simulate a failover below.

1. To simulate a failover on master Redis, SSH into the Redis server and run:

   ```bash
   # port must match your master redis port, and the sleep time must be a few seconds bigger than defined one
    redis-cli -h localhost -p 6379 DEBUG sleep 20
   ```

1. Then back in the Rails console from the first step, run:

   ```
   redis.info
   ```

   You should see a different port after a few seconds delay
   (the failover/reconnect time).

## Changelog

Changes to Redis HA over time.

**8.14**

- Redis Sentinel support is production-ready and bundled in the Omnibus GitLab
  Enterprise Edition package
- Documentation restructure for better readability

**8.11**

- Experimental Redis Sentinel support was added

## Further reading

Read more on High Availability:

1. [High Availability Overview](README.md)
1. [Configure the database](database.md)
1. [Configure NFS](nfs.md)
1. [Configure the GitLab application servers](gitlab.md)
1. [Configure the load balancers](load_balancer.md)

[ce-1877]: https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/1877
[restart]: ../restart_gitlab.md#installations-from-source
[reconfigure]: ../restart_gitlab.md#omnibus-gitlab-reconfigure
[gh-531]: https://github.com/redis/redis-rb/issues/531
[gh-534]: https://github.com/redis/redis-rb/issues/534
[redis]: https://redis.io/
[sentinel]: https://redis.io/topics/sentinel
[omnifile]: https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-cookbooks/gitlab/libraries/gitlab_rails.rb
[source]: ../../install/installation.md
[it]: https://gitlab.com/gitlab-org/gitlab-foss/uploads/c4cc8cd353604bd80315f9384035ff9e/The_Internet_IT_Crowd.png
