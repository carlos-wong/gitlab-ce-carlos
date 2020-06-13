---
type: reference
---

# Parent-child pipelines

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/16094) in GitLab 12.7.

As pipelines grow more complex, a few related problems start to emerge:

- The staged structure, where all steps in a stage must be completed before the first
  job in next stage begins, causes arbitrary waits, slowing things down.
- Configuration for the single global pipeline becomes very long and complicated,
  making it hard to manage.
- Imports with [`include`](yaml/README.md#include) increase the complexity of the configuration, and create the potential
  for namespace collisions where jobs are unintentionally duplicated.
- Pipeline UX can become unwieldy with so many jobs and stages to work with.

Additionally, sometimes the behavior of a pipeline needs to be more dynamic. The ability
to choose to start sub-pipelines (or not) is a powerful ability, especially if the
YAML is dynamically generated.

![Parent pipeline graph expanded](img/parent_pipeline_graph_expanded_v12_6.png)

Similarly to [multi-project pipelines](multi_project_pipelines.md), a pipeline can trigger a
set of concurrently running child pipelines, but within the same project:

- Child pipelines still execute each of their jobs according to a stage sequence, but
  would be free to continue forward through their stages without waiting for unrelated
  jobs in the parent pipeline to finish.
- The configuration is split up into smaller child pipeline configurations, which are
  easier to understand. This reduces the cognitive load to understand the overall configuration.
- Imports are done at the child pipeline level, reducing the likelihood of collisions.
- Each pipeline has only relevant steps, making it easier to understand what's going on.

Child pipelines work well with other GitLab CI features:

- Use [`only: changes`](yaml/README.md#onlychangesexceptchanges) to trigger pipelines only when
  certain files change. This is useful for monorepos, for example.
- Since the parent pipeline in `.gitlab-ci.yml` and the child pipeline run as normal
  pipelines, they can have their own behaviors and sequencing in relation to triggers.

All of this will work with the [`include:`](yaml/README.md#include) feature so you can compose
the child pipeline configuration.

## Examples

The simplest case is [triggering a child pipeline](yaml/README.md#trigger) using a
local YAML file to define the pipeline configuration. In this case, the parent pipeline will
trigger the child pipeline, and continue without waiting:

```yaml
microservice_a:
  trigger:
    include: path/to/microservice_a.yml
```

You can include multiple files when composing a child pipeline:

```yaml
microservice_a:
  trigger:
    include:
      - local: path/to/microservice_a.yml
      - template: SAST.gitlab-ci.yml
```

NOTE: **Note:**
The max number of entries that are accepted for `trigger:include:` is three.

Similar to [multi-project pipelines](multi_project_pipelines.md#mirroring-status-from-triggered-pipeline),
we can set the parent pipeline to depend on the status of the child pipeline upon completion:

```yaml
microservice_a:
  trigger:
    include:
      - local: path/to/microservice_a.yml
      - template: SAST.gitlab-ci.yml
    strategy: depend
```

## Merge Request child pipelines

To trigger a child pipeline as a [Merge Request Pipeline](merge_request_pipelines/index.md) we need to:

- Set the trigger job to run on merge requests:

```yaml
# parent .gitlab-ci.yml
microservice_a:
  trigger:
    include: path/to/microservice_a.yml
  rules:
    - if: $CI_MERGE_REQUEST_ID
```

- Configure the child pipeline by either:

  - Setting all jobs in the child pipeline to evaluate in the context of a merge request:

    ```yaml
    # child path/to/microservice_a.yml
    workflow:
      rules:
        - if: $CI_MERGE_REQUEST_ID

    job1:
      script: ...

    job2:
      script: ...
    ```

  - Alternatively, setting the rule per job. For example, to create only `job1` in
    the context of merge request pipelines:

    ```yaml
    # child path/to/microservice_a.yml
    job1:
      script: ...
      rules:
        - if: $CI_MERGE_REQUEST_ID

    job2:
      script: ...
    ```

## Dynamic child pipelines

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/35632) in GitLab 12.9.

Instead of running a child pipeline from a static YAML file, you can define a job that runs
your own script to generate a YAML file, which is then [used to trigger a child pipeline](yaml/README.md#trigger-child-pipeline-with-generated-configuration-file).

This technique can be very powerful in generating pipelines targeting content that changed or to
build a matrix of targets and architectures.

## Limitations

A parent pipeline can trigger many child pipelines, but a child pipeline cannot trigger
further child pipelines. See the [related issue](https://gitlab.com/gitlab-org/gitlab/issues/29651)
for discussion on possible future improvements.

When triggering dynamic child pipelines, if the job containing the CI config artifact is not a predecessor of the
trigger job, the child pipeline will fail to be created, causing also the parent pipeline to fail.
In the future we want to validate the trigger job's dependencies [at the time the parent pipeline is created](https://gitlab.com/gitlab-org/gitlab/-/issues/209070) rather than when the child pipeline is created.
