---
type: reference
---

# Configuring GitLab for Scaling and High Availability

NOTE: **Note:** There is some additional configuration near the bottom for
additional GitLab application servers. It's important to read and understand
these additional steps before proceeding with GitLab installation.

1. If necessary, install the NFS client utility packages using the following
   commands:

   ```
   # Ubuntu/Debian
   apt-get install nfs-common

   # CentOS/Red Hat
   yum install nfs-utils nfs-utils-lib
   ```

1. Specify the necessary NFS shares. Mounts are specified in
   `/etc/fstab`. The exact contents of `/etc/fstab` will depend on how you chose
   to configure your NFS server. See [NFS documentation](nfs.md) for the various
   options. Here is an example snippet to add to `/etc/fstab`:

   ```
   10.1.0.1:/var/opt/gitlab/.ssh /var/opt/gitlab/.ssh nfs4 defaults,soft,rsize=1048576,wsize=1048576,noatime,nofail,lookupcache=positive 0 2
   10.1.0.1:/var/opt/gitlab/gitlab-rails/uploads /var/opt/gitlab/gitlab-rails/uploads nfs4 defaults,soft,rsize=1048576,wsize=1048576,noatime,nofail,lookupcache=positive 0 2
   10.1.0.1:/var/opt/gitlab/gitlab-rails/shared /var/opt/gitlab/gitlab-rails/shared nfs4 defaults,soft,rsize=1048576,wsize=1048576,noatime,nofail,lookupcache=positive 0 2
   10.1.0.1:/var/opt/gitlab/gitlab-ci/builds /var/opt/gitlab/gitlab-ci/builds nfs4 defaults,soft,rsize=1048576,wsize=1048576,noatime,nofail,lookupcache=positive 0 2
   10.1.0.1:/var/opt/gitlab/git-data /var/opt/gitlab/git-data nfs4 defaults,soft,rsize=1048576,wsize=1048576,noatime,nofail,lookupcache=positive 0 2
   ```

1. Create the shared directories. These may be different depending on your NFS
   mount locations.

   ```
   mkdir -p /var/opt/gitlab/.ssh /var/opt/gitlab/gitlab-rails/uploads /var/opt/gitlab/gitlab-rails/shared /var/opt/gitlab/gitlab-ci/builds /var/opt/gitlab/git-data
   ```

1. Download/install GitLab Omnibus using **steps 1 and 2** from
   [GitLab downloads](https://about.gitlab.com/install/). Do not complete other
   steps on the download page.
1. Create/edit `/etc/gitlab/gitlab.rb` and use the following configuration.
   Be sure to change the `external_url` to match your eventual GitLab front-end
   URL. Depending your the NFS configuration, you may need to change some GitLab
   data locations. See [NFS documentation](nfs.md) for `/etc/gitlab/gitlab.rb`
   configuration values for various scenarios. The example below assumes you've
   added NFS mounts in the default data locations. Additionally the UID and GIDs
   given are just examples and you should configure with your preferred values.

   ```ruby
   external_url 'https://gitlab.example.com'

   # Prevent GitLab from starting if NFS data mounts are not available
   high_availability['mountpoint'] = '/var/opt/gitlab/git-data'

   # Disable components that will not be on the GitLab application server
   roles ['application_role']
   nginx['enable'] = true

   # PostgreSQL connection details
   gitlab_rails['db_adapter'] = 'postgresql'
   gitlab_rails['db_encoding'] = 'unicode'
   gitlab_rails['db_host'] = '10.1.0.5' # IP/hostname of database server
   gitlab_rails['db_password'] = 'DB password'

   # Redis connection details
   gitlab_rails['redis_port'] = '6379'
   gitlab_rails['redis_host'] = '10.1.0.6' # IP/hostname of Redis server
   gitlab_rails['redis_password'] = 'Redis Password'

   # Ensure UIDs and GIDs match between servers for permissions via NFS
   user['uid'] = 9000
   user['gid'] = 9000
   web_server['uid'] = 9001
   web_server['gid'] = 9001
   registry['uid'] = 9002
   registry['gid'] = 9002
   ```

1. [Enable monitoring](#enable-monitoring)

   NOTE: **Note:** To maintain uniformity of links across HA clusters, the `external_url`
   on the first application server as well as the additional application
   servers should point to the external url that users will use to access GitLab.
   In a typical HA setup, this will be the url of the load balancer which will
   route traffic to all GitLab application servers in the HA cluster.

   NOTE: **Note:** When you specify `https` in the `external_url`, as in the example
   above, GitLab assumes you have SSL certificates in `/etc/gitlab/ssl/`. If
   certificates are not present, NGINX will fail to start. See
   [NGINX documentation](https://docs.gitlab.com/omnibus/settings/nginx.html#enable-https)
   for more information.

   NOTE: **Note:** It is best to set the `uid` and `gid`s prior to the initial reconfigure
   of GitLab. Omnibus will not recursively `chown` directories if set after the initial reconfigure.

## First GitLab application server

On the first application server, run:

```sh
sudo gitlab-ctl reconfigure
```

This should compile the configuration and initialize the database. Do
not run this on additional application servers until the next step.

## Extra configuration for additional GitLab application servers

Additional GitLab servers (servers configured **after** the first GitLab server)
need some extra configuration.

1. Configure shared secrets. These values can be obtained from the primary
   GitLab server in `/etc/gitlab/gitlab-secrets.json`. Copy this file to the
   secondary servers **prior to** running the first `reconfigure` in the steps
   above.

   ```ruby
   gitlab_shell['secret_token'] = 'fbfb19c355066a9afb030992231c4a363357f77345edd0f2e772359e5be59b02538e1fa6cae8f93f7d23355341cea2b93600dab6d6c3edcdced558fc6d739860'
   gitlab_rails['otp_key_base'] = 'b719fe119132c7810908bba18315259ed12888d4f5ee5430c42a776d840a396799b0a5ef0a801348c8a357f07aa72bbd58e25a84b8f247a25c72f539c7a6c5fa'
   gitlab_rails['secret_key_base'] = '6e657410d57c71b4fc3ed0d694e7842b1895a8b401d812c17fe61caf95b48a6d703cb53c112bc01ebd197a85da81b18e29682040e99b4f26594772a4a2c98c6d'
   gitlab_rails['db_key_base'] = 'bf2e47b68d6cafaef1d767e628b619365becf27571e10f196f98dc85e7771042b9203199d39aff91fcb6837c8ed83f2a912b278da50999bb11a2fbc0fba52964'
   ```

1. Run `touch /etc/gitlab/skip-auto-reconfigure` to prevent database migrations
   from running on upgrade. Only the primary GitLab application server should
   handle migrations.

1. **Recommended** Configure host keys. Copy the contents (primary and public keys) of `/etc/ssh/` on
   the primary application server to `/etc/ssh` on all secondary servers. This
   prevents false man-in-the-middle-attack alerts when accessing servers in your
   High Availability cluster behind a load balancer.

1. Run `sudo gitlab-ctl reconfigure` to compile the configuration.

## Enable Monitoring

> [Introduced](https://gitlab.com/gitlab-org/omnibus-gitlab/issues/3786) in GitLab 12.0.

If you enable Monitoring, it must be enabled on **all** GitLab servers.

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
   gitlab_workhorse['prometheus_listen_addr'] = '0.0.0.0:9229'
   sidekiq['listen_address'] = "0.0.0.0"
   unicorn['listen'] = '0.0.0.0'

   # Add the monitoring node's IP address to the monitoring whitelist and allow it to
   # scrape the NGINX metrics. Replace placeholder `monitoring.gitlab.example.com` with
   # the address and/or subnets gathered from the monitoring node(s).
   gitlab_rails['monitoring_whitelist'] = ['monitoring.gitlab.example.com', '127.0.0.0/8']
   nginx['status']['options']['allow'] = ['monitoring.gitlab.example.com', '127.0.0.0/8']
   ```

1. Run `sudo gitlab-ctl reconfigure` to compile the configuration.

   CAUTION: **Warning:**
   After changing `unicorn['listen']` in `gitlab.rb`, and running `sudo gitlab-ctl reconfigure`,
   it can take an extended period of time for Unicorn to complete reloading after receiving a `HUP`.
   For more information, see the [issue](https://gitlab.com/gitlab-org/omnibus-gitlab/issues/4401).

## Troubleshooting

- `mount: wrong fs type, bad option, bad superblock on`

You have not installed the necessary NFS client utilities. See step 1 above.

- `mount: mount point /var/opt/gitlab/... does not exist`

This particular directory does not exist on the NFS server. Ensure
the share is exported and exists on the NFS server and try to remount.

---

## Upgrading GitLab HA

GitLab HA installations can be upgraded with no downtime, but the
upgrade process must be carefully coordinated to avoid failures. See the
[Omnibus GitLab multi-node upgrade
document](https://docs.gitlab.com/omnibus/update/#multi-node--ha-deployment)
for more details.

Read more on high-availability configuration:

1. [Configure the database](database.md)
1. [Configure Redis](redis.md)
1. [Configure NFS](nfs.md)
1. [Configure the load balancers](load_balancer.md)
