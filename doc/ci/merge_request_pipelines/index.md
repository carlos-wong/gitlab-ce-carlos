# Pipelines for merge requests

NOTE: **Note**:
As of GitLab 11.10, pipelines for merge requests require GitLab Runner 11.9
or higher due to the [recent refspecs
changes](https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/25504).
Anything lower will cause the pipeline to fail.

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ce/issues/15310) in GitLab 11.6.

Usually, when you create a new merge request, a pipeline runs with the
new change and checks if it's qualified to be merged into a target branch. This
pipeline should contain only necessary jobs for validating the new changes.
For example, unit tests, lint checks, and [Review Apps](../review_apps/index.md)
are often used in this cycle.

With pipelines for merge requests, you can design a specific pipeline structure
for when you are running a pipeline in a merge request. This
could be either adding or removing steps in the pipeline, to make sure that
your pipelines are as efficient as possible.

## Configuring pipelines for merge requests

To configure pipelines for merge requests, add the `only: merge_requests` parameter to
the jobs that you want to run only for merge requests.

Then, when developers create or update merge requests, a pipeline runs
every time a commit is pushed to GitLab.

NOTE: **Note**:
If you use this feature with [merge when pipeline succeeds](../../user/project/merge_requests/merge_when_pipeline_succeeds.md),
pipelines for merge requests take precedence over the other regular pipelines.

For example, consider the following [`.gitlab-ci.yml`](../yaml/README.md):

```yaml
build:
  stage: build
  script: ./build
  only:
  - master

test:
  stage: test
  script: ./test
  only:
  - merge_requests

deploy:
  stage: deploy
  script: ./deploy
  only:
  - master
```

After the merge request is updated with new commits:

- GitLab detects that changes have occurred and creates a new pipeline for the merge request.
- The pipeline fetches the latest code from the source branch and run tests against it.

In the above example, the pipeline contains only a `test` job.
Since the `build` and `deploy` jobs don't have the `only: merge_requests` parameter,
they will not run in the merge request.

Pipelines tagged with the **detached** badge indicate that they were triggered
when a merge request was created or updated. For example:

![Merge request page](img/merge_request.png)

## Pipelines for Merged Results **[PREMIUM]**

> [Introduced](https://gitlab.com/gitlab-org/gitlab-ee/issues/7380) in [GitLab Premium](https://about.gitlab.com/pricing/) 11.10.

It's possible for your source and target branches to diverge, which can result
in the scenario that source branch's pipeline was green, the target's pipeline was green,
but the combined output fails. By having your merge request pipeline automatically
create a new ref that contains the merge result of the source and target branch
(then running a pipeline on that ref), we can better test that the combined result
is also valid.

From GitLab 11.10, pipelines for merge requests run by default
on this merged result. That is, where the source and target branches are combined into a
new ref and a pipeline for this ref validates the result prior to merging.

![Merge request pipeline as the head pipeline](img/merge_request_pipeline.png)

There are some cases where creating a combined ref is not possible or not wanted.
For example, a source branch that has conflicts with the target branch
or a merge request that is still in WIP status. In this case, the merge request pipeline falls back to a "detached" state
and runs on the source branch ref as if it was a regular pipeline.

The detached state serves to warn you that you are working in a situation
subjected to merge problems, and helps to highlight that you should
get out of WIP status or resolve merge conflicts as soon as possible.

### Enabling Pipelines for Merged Results

This feature disabled by default until we resolve issues with [contention handling](https://gitlab.com/gitlab-org/gitlab-ee/issues/9186). It can be enabled at the project level:

1. Visit your project's **Settings > General** and expand **Merge requests**.
1. Check **Merge pipelines will try to validate the post-merge result prior to merging**.
1. Click **Save changes** button.

![Merge request pipeline config](img/merge_request_pipeline_config.png)

### Pipelines for Merged Result's limitations

- This feature requires [GitLab Runner](https://gitlab.com/gitlab-org/gitlab-runner) 11.9 or newer.
- This feature requires [Gitaly](https://gitlab.com/gitlab-org/gitaly) 1.21.0 or newer.
- After the merge request pipeline succeeds, if the target branch has moved forward, the result of the pipeline is stale and must be retried. In busy repos, this can become a problem as it is highly probable that the target branch will have moved ahead. Improvements are [planned](https://gitlab.com/gitlab-org/gitlab-ee/issues/9186) for future versions of GitLab.
- Forking/cross-repo workflows are not currently supported. To follow progress, see [#9713](https://gitlab.com/gitlab-org/gitlab-ee/issues/9713).
- This feature is not available for [fast forward merges](../../user/project/merge_requests/fast_forward_merge.md) yet. To follow progress, see [#58226](https://gitlab.com/gitlab-org/gitlab-ce/issues/58226).

## Excluding certain jobs

The behavior of the `only: merge_requests` parameter is such that _only_ jobs with
that parameter are run in the context of a merge request; no other jobs will be run.

However, you may want to reverse this behavior, having all of your jobs to run _except_
for one or two.

Consider the following pipeline, with jobs `A`, `B`, and `C`. Imagine you want:

- All pipelines to always run `A` and `B`.
- `C` to run only for merge requests.

To achieve this, you can configure your `.gitlab-ci.yml` file as follows:

``` yaml
.only-default: &only-default
  only:
    - master
    - merge_requests
    - tags

A:
  <<: *only-default
  script:
    - ...

B:
  <<: *only-default
  script:
    - ...

C:
  script:
    - ...
  only:
    - merge_requests
```

Therefore:

- Since `A` and `B` are getting the `only:` rule to execute in all cases, they will always run.
- Since `C` specifies that it should only run for merge requests, it will not run for any pipeline
  except a merge request pipeline.

As you can see, this will help you avoid a lot of boilerplate where you'd need
to add that `only:` rule to all of your jobs in order to make them always run. You
can use this for scenarios like having only pipelines with merge requests get a
Review App set up, helping to save resources.

## Important notes about merge requests from forked projects

Note that the current behavior is subject to change. In the usual contribution
flow, external contributors follow the following steps:

1. Fork a parent project.
1. Create a merge request from the forked project that targets the `master` branch
   in the parent project.
1. A pipeline runs on the merge request.
1. A maintainer from the parent project checks the pipeline result, and merge
   into a target branch if the latest pipeline has passed.

Currently, those pipelines are created in a **forked** project, not in the
parent project. This means you cannot completely trust the pipeline result,
because, technically, external contributors can disguise their pipeline results
by tweaking their GitLab Runner in the forked project.

There are multiple reasons about why GitLab doesn't allow those pipelines to be
created in the parent project, but one of the biggest reasons is security concern.
External users could steal secret variables from the parent project by modifying
`.gitlab-ci.yml`, which could be some sort of credentials. This should not happen.

We're discussing a secure solution of running pipelines for merge requests
that submitted from forked projects,
see [the issue about the permission extension](https://gitlab.com/gitlab-org/gitlab-ce/issues/23902).

## Additional predefined variables

By using pipelines for merge requests, GitLab exposes additional predefined variables to the pipeline jobs.
Those variables contain information of the associated merge request, so that it's useful
to integrate your job with [GitLab Merge Request API](../../api/merge_requests.md).

You can find the list of avilable variables in [the reference sheet](../variables/predefined_variables.md).
The variable names begin with the `CI_MERGE_REQUEST_` prefix.
