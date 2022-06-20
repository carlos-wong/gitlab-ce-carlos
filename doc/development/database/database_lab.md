---
stage: Enablement
group: Database
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Database Lab and Postgres.ai

Internal users at GitLab have access to the Database Lab Engine (DLE) and
[postgres.ai](https://console.postgres.ai/) for testing performance of database queries
on replicated production data. Unlike a typical read-only production replica, in the DLE you can
also create, update, and delete rows. You can also test the performance of
schema changes, like additional indexes or columns, in an isolated copy of production data.

## Access Database Lab Engine

Access to the DLE is helpful for:

- Database reviewers and maintainers.
- Engineers who work on merge requests that have large effects on databases.

To access the DLE's services, you can:

- Perform query testing in the `#database_lab` Slack channel, or in the Postgres.ai web console.
  Employees access both services with their GitLab Google account. Query testing
  provides `EXPLAIN` (analyze, buffers) plans for queries executed there.
- Migration testing by triggering a job as a part of a merge request.
- Direct `psql` access to DLE instead of a production replica. Available to authorized users only.
  To request `psql` access, file an [access request](https://about.gitlab.com/handbook/business-technology/team-member-enablement/onboarding-access-requests/access-requests/#individual-or-bulk-access-request).

For more assistance, use the `#database` Slack channel.

NOTE:
If you need only temporary access to a production replica, instead of a Database Lab
clone, follow the runbook procedure for connecting to the
[database console with Teleport](https://gitlab.com/gitlab-com/runbooks/-/blob/master/docs/Teleport/Connect_to_Database_Console_via_Teleport.md).
This procedure is similar to [Rails console access with Teleport](https://gitlab.com/gitlab-com/runbooks/-/blob/master/docs/Teleport/Connect_to_Rails_Console_via_Teleport.md#how-to-use-teleport-to-connect-to-rails-console).

### Query testing

You can access Database Lab's query analysis features either:

- In the `#database_lab` Slack channel. Shows everyone's commands and results, but
  your own commands are still isolated in their own clone.
- In [the Postgres.ai web console](https://console.postgres.ai/GitLab/joe-instances).
  Shows only the commands you run.

#### Generate query plans

Query plans are an essential part of the database review process. These plans
enable us to decide quickly if a given query can be performant on GitLab.com.
Running the `explain` command generates an `explain` plan and a link to the Postgres.ai
console with more query analysis. For example, running `EXPLAIN SELECT * FROM application_settings`
does the following:

1. Runs `explain (analyze, buffers) select * from application_settings;` against a database clone.
1. Responds with timing and buffer details from the run.
1. Provides a [detailed, shareable report on the results](https://console.postgres.ai/shared/24d543c9-893b-4ff6-8deb-a8f902f85a53).

#### Making schema changes

Sometimes when testing queries, a contributor may realize that the query needs an index
or other schema change to make added queries more performant. To test the query, run the `exec` command.
For example, running this command:

```sql
exec CREATE INDEX on application_settings USING btree (instance_administration_project_id)
```

creates the specified index on the table. You can [test queries](#generate-query-plans) leveraging
the new index. `exec` does not return any results, only the time required to execute the query.

#### Reset the clone

After many changes, such as after a destructive query or an ineffective index,
you must start over. To reset your designated clone, run `reset`.

### Migration testing

For information on testing migrations, review our
[database migration testing documentation](database_migration_pipeline.md).

### Access the console with `psql`

Team members with [`psql` access](#access-database-lab-engine), can gain direct access
to a clone via `psql`. Access to `psql` enables you to see data, not just metadata.

To connect to a clone using `psql`:

1. Create a clone from the [desired instance](https://console.postgres.ai/gitlab/instances/).
   1. Provide a **Clone ID**: Something that uniquely identifies your clone, such as `yourname-testing-gitlabissue`.
   1. Provide a **Database username** and **Database password**: Connects `psql` to your clone.
   1. Select **Enable deletion protection** if you want to preserve your clone. Avoid selecting this option.
      Clones are removed after 12 hours.
1. In the **Clone details** page of the Postgres.ai web interface, copy and run
   the command to start SSH port forwarding for the clone.
1. In the **Clone details** page of the Postgres.ai web interface, copy and run the `psql` connection string.
   Use the password provided at setup.

After you connect, use clone like you would any `psql` console in production, but with
the added benefit and safety of an isolated writeable environment.
