---
stage: Data Stores
group: Database
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Moving GitLab databases to a different PostgreSQL instance **(FREE SELF)**

Sometimes it is necessary to move your databases from one PostgreSQL instance to
another. For example, if you are using AWS Aurora and are preparing to
enable Database Load Balancing, you will need to move your databases to
RDS for PostgreSQL.

To move databases from one instance to another:

1. Gather the source and destination PostgreSQL endpoint information:

   ```shell
   SRC_PGHOST=<source postgresql host>
   SRC_PGUSER=<source postgresql user>

   DST_PGHOST=<destination postgresql host>
   DST_PGUSER=<destination postgresql user>
   ```

1. Stop GitLab:

   ```shell
   sudo gitlab-ctl stop
   ```

1. Dump the databases from the source:

   ```shell
   /opt/gitlab/embedded/bin/pg_dump -h $SRC_PGHOST -U $SRC_PGUSER -c -C -f gitlabhq_production.sql gitlabhq_production
   /opt/gitlab/embedded/bin/pg_dump -h $SRC_PGHOST -U $SRC_PGUSER -c -C -f praefect_production.sql praefect_production
   ```

1. Restore the databases to the destination (this will overwrite any existing databases with the same names):

   ```shell
   /opt/gitlab/embedded/bin/psql -h $DST_PGHOST -U $DST_PGUSER -f praefect_production.sql postgres
   /opt/gitlab/embedded/bin/psql -h $DST_PGHOST -U $DST_PGUSER -f gitlabhq_production.sql postgres
   ```

1. Configure the GitLab application servers with the appropriate connection details
   for your destination PostgreSQL instance in your `/etc/gitlab/gitlab.rb` file:

   ```ruby
   gitlab_rails['db_host'] = '<destination postgresql host>'
   ```

   For more information on GitLab multi-node setups, refer to the [reference architectures](../reference_architectures/index.md).

1. Reconfigure for the changes to take effect:

   ```shell
   sudo gitlab-ctl reconfigure
   ```

1. Restart GitLab:

   ```shell
   sudo gitlab-ctl start
   ```
