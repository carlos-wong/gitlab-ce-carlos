# Geo Frequently Asked Questions **(PREMIUM ONLY)**

## What are the minimum requirements to run Geo?

The requirements are listed [on the index page](index.md#requirements-for-running-geo)

## How does Geo know which projects to sync?

On each **secondary** node, there is a read-only replicated copy of the GitLab database.
A **secondary** node also has a tracking database where it stores which projects have been synced.
Geo compares the two databases to find projects that are not yet tracked.

At the start, this tracking database is empty, so Geo will start trying to update from every project that it can see in the GitLab database.

For each project to sync:

1. Geo will issue a `git fetch geo --mirror` to get the latest information from the **primary** node.
   If there are no changes, the sync will be fast and end quickly. Otherwise, it will pull the latest commits.
1. The **secondary** node will update the tracking database to store the fact that it has synced projects A, B, C, etc.
1. Repeat until all projects are synced.

When someone pushes a commit to the **primary** node, it generates an event in the GitLab database that the repository has changed.
The **secondary** node sees this event, marks the project in question as dirty, and schedules the project to be resynced.

To ensure that problems with pipelines (for example, syncs failing too many times or jobs being lost) don't permanently stop projects syncing, Geo also periodically checks the tracking database for projects that are marked as dirty. This check happens when
the number of concurrent syncs falls below `repos_max_capacity` and there are no new projects waiting to be synced.

Geo also has a checksum feature which runs a SHA256 sum across all the Git references to the SHA values.
If the refs don't match between the **primary** node and the **secondary** node, then the **secondary** node will mark that project as dirty and try to resync it.
So even if we have an outdated tracking database, the validation should activate and find discrepancies in the repository state and resync.

## Can I use Geo in a disaster recovery situation?

Yes, but there are limitations to what we replicate (see
[What data is replicated to a **secondary** node?](#what-data-is-replicated-to-a-secondary-node)).

Read the documentation for [Disaster Recovery](../disaster_recovery/index.md).

## What data is replicated to a **secondary** node?

We currently replicate project repositories, LFS objects, generated
attachments / avatars and the whole database. This means user accounts,
issues, merge requests, groups, project data, etc., will be available for
query.

## Can I `git push` to a **secondary** node?

Yes!  Pushing directly to a **secondary** node (for both HTTP and SSH, including Git LFS) was [introduced](https://about.gitlab.com/blog/2018/09/22/gitlab-11-3-released/) in [GitLab Premium](https://about.gitlab.com/pricing/#self-managed) 11.3.

## How long does it take to have a commit replicated to a **secondary** node?

All replication operations are asynchronous and are queued to be dispatched. Therefore, it depends on a lot of
factors including the amount of traffic, how big your commit is, the
connectivity between your nodes, your hardware, etc.

## What if the SSH server runs at a different port?

That's totally fine. We use HTTP(s) to fetch repository changes from the **primary** node to all **secondary** nodes.

## Is this possible to set up a Docker Registry for a **secondary** node that mirrors the one on the **primary** node?

Yes. See [Docker Registry for a **secondary** node](docker_registry.md).
