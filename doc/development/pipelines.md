# Pipelines for the GitLab project

Pipelines for `gitlab-org/gitlab` and `gitlab-org/gitlab-foss` (as well as the
`dev` instance's mirrors) are configured in the usual
[`.gitlab-ci.yml`](https://gitlab.com/gitlab-org/gitlab/blob/master/.gitlab-ci.yml)
which itself includes files under
[`.gitlab/ci/`](https://gitlab.com/gitlab-org/gitlab/tree/master/.gitlab/ci)
for easier maintenance.

We're striving to [dogfood](https://about.gitlab.com/handbook/engineering/#dogfooding)
GitLab [CI/CD features and best-practices](../ci/yaml/README.md)
as much as possible.

## Stages

The current stages are:

- `sync`: This stage is used to synchronize changes from gitlab-org/gitlab to
  gitlab-org/gitlab-foss.
- `prepare`: This stage includes jobs that prepare artifacts that are needed by
  jobs in subsequent stages.
- `quick-test`: This stage includes test jobs that should run first and fail the
  pipeline early (currently used to run Geo tests when the branch name starts
  with `geo-`, `geo/`, or ends with `-geo`).
- `test`: This stage includes most of the tests, DB/migration jobs, and static analysis jobs.
- `review-prepare`: This stage includes a job that build the CNG images that are
  later used by the (Helm) Review App deployment (see
  [Review Apps](testing_guide/review_apps.md) for details).
- `review`: This stage includes jobs that deploy the GitLab and Docs Review Apps.
- `qa`: This stage includes jobs that perform QA tasks against the Review App
  that is deployed in the previous stage.
- `post-test`: This stage includes jobs that build reports or gather data from
  the previous stages' jobs (e.g. coverage, Knapsack metadata etc.).
- `pages`: This stage includes a job that deploys the various reports as
  GitLab pages (e.g. <https://gitlab-org.gitlab.io/gitlab/coverage-ruby/>,
  <https://gitlab-org.gitlab.io/gitlab/coverage-javascript/>,
  <https://gitlab-org.gitlab.io/gitlab/webpack-report/>).

## Default image

The default image is currently
`registry.gitlab.com/gitlab-org/gitlab-build-images:ruby-2.6.3-golang-1.11-git-2.22-chrome-73.0-node-12.x-yarn-1.16-postgresql-9.6-graphicsmagick-1.3.33`.

It includes Ruby 2.6.3, Go 1.11, Git 2.22, Chrome 73, Node 12, Yarn 1.16,
PostgreSQL 9.6, and Graphics Magick 1.3.33.

The images used in our pipelines are configured in the
[`gitlab-org/gitlab-build-images`](https://gitlab.com/gitlab-org/gitlab-build-images)
project, which is push-mirrored to <https://dev.gitlab.org/gitlab/gitlab-build-images>
for redundancy.

The current version of the build images can be found in the
["Used by GitLab section"](https://gitlab.com/gitlab-org/gitlab-build-images/blob/master/.gitlab-ci.yml).

## Default variables

In addition to the [predefined variables](../ci/variables/predefined_variables.md),
each pipeline includes default variables defined in
<https://gitlab.com/gitlab-org/gitlab/blob/master/.gitlab-ci.yml>.

## Common job definitions

Most of the jobs [extend from a few CI definitions](../ci/yaml/README.md#extends)
that are scoped to a single
[configuration parameter](../ci/yaml/README.md#configuration-parameters).

These common definitions are:

- `.default-tags`: Ensures a job has the `gitlab-org` tag to ensure it's using
  our dedicated runners.
- `.default-retry`: Allows a job to retry upon `unknown_failure`, `api_failure`,
  `runner_system_failure`.
- `.default-before_script`: Allows a job to use a default `before_script` definition
  suitable for Ruby/Rails tasks that may need a database running (e.g. tests).
- `.default-cache`: Allows a job to use a default `cache` definition suitable for
  Ruby/Rails and frontend tasks.
- `.default-only`: Restricts the cases where a job is created. This currently
  includes `master`, `/^[\d-]+-stable(-ee)?$/` (stable branches),
  `/^\d+-\d+-auto-deploy-\d+$/` (auto-deploy branches), `/^security\//` (security branches), `merge_requests`, `tags`.
  Note that jobs won't be created for branches with this default configuration.
- `.only:variables-canonical-dot-com`: Only creates a job if the project is
  located under <https://gitlab.com/gitlab-org>.
- `.only:variables_refs-canonical-dot-com-schedules`: Same as
  `.only:variables-canonical-dot-com` but add the condition that pipeline is scheduled.
- `.except:refs-deploy`: Don't create a job if the `ref` is an auto-deploy branch.
- `.except:refs-master-tags-stable-deploy`: Don't create a job if the `ref` is one of:
  - `master`
  - a tag
  - a stable branch
  - an auto-deploy branch
- `.only:kubernetes`: Only creates a job if a Kubernetes integration is enabled
  on the project.
- `.only-review`: This extends from:
  - `.only:variables-canonical-dot-com`
  - `.only:kubernetes`
  - `.except:refs-master-tags-stable-deploy`
- `.only-review-schedules`: This extends from:
  - `.only:variables_refs-canonical-dot-com-schedules`
  - `.only:kubernetes`
  - `.except:refs-deploy`
- `.use-pg9`: Allows a job to use the `postgres:9.6` and `redis:alpine` services.
- `.use-pg10`: Allows a job to use the `postgres:10.9` and `redis:alpine` services.
- `.use-pg9-ee`: Same as `.use-pg9` but also use the
  `docker.elastic.co/elasticsearch/elasticsearch:5.6.12` services.
- `.use-pg10-ee`: Same as `.use-pg10` but also use the
  `docker.elastic.co/elasticsearch/elasticsearch:5.6.12` services.
- `.only-ee`: Only creates a job for the `gitlab` or `gitlab-ee` project.
- `.only-ee-as-if-foss`: Same as `.only-ee` but simulate the FOSS project by
  setting the `FOSS_ONLY='1'` environment variable.

## Changes detection

If a job extends from `.default-only` (and most of the jobs should), it can restrict
the cases where it should be created
[based on the changes](../ci/yaml/README.md#onlychangesexceptchanges)
from a commit or MR by extending from the following CI definitions:

- `.only:changes-code`: Allows a job to only be created upon code-related changes.
- `.only:changes-qa`: Allows a job to only be created upon QA-related changes.
- `.only:changes-docs`: Allows a job to only be created upon docs-related changes.
- `.only:changes-graphql`: Allows a job to only be created upon GraphQL-related changes.
- `.only:changes-code-backstage`: Allows a job to only be created upon code-related or backstage-related (e.g. Danger, RuboCop, specs) changes.
- `.only:changes-code-qa`: Allows a job to only be created upon code-related or QA-related changes.
- `.only:changes-code-backstage-qa`: Allows a job to only be created upon code-related, backstage-related (e.g. Danger, RuboCop, specs) or QA-related changes.

**See <https://gitlab.com/gitlab-org/gitlab/blob/master/.gitlab/ci/global.gitlab-ci.yml>
for the list of exact patterns.**

## Directed acyclic graph

We're using the [`needs:`](../ci/yaml/README.md#needs) keyword to
execute jobs out of order for the following jobs:

```mermaid
graph RL;
  A[setup-test-env];
  B["gitlab:assets:compile pull-push-cache<br/>(master only)"];
  C[gitlab:assets:compile pull-cache];
  D["cache gems<br/>(master and tags only)"];
  E[review-build-cng];
  F[build-qa-image];
  G[review-deploy];
  G2["schedule:review-deploy<br/>(master only)"];
  H[karma];
  I[jest];
  J["compile-assets pull-push-cache<br/>(master only)"];
  K[compile-assets pull-cache];
  L[webpack-dev-server];
  M[coverage];
  N[pages];
  O[static-analysis];
  P["schedule:package-and-qa<br/>(master schedule only)"];
  Q[package-and-qa];
  R[package-and-qa-manual];
  S["RSpec<br/>(e.g. rspec unit pg9)"]
  T[retrieve-tests-metadata];

subgraph "`prepare` stage"
    A
    F
    K
    J
    T
    end

subgraph "`test` stage"
    B --> |needs| A;
    C --> |needs| A;
    D --> |needs| A;
    H -.-> |needs and depends on| A;
    H -.-> |needs and depends on| K;
    I -.-> |needs and depends on| A;
    I -.-> |needs and depends on| K;
    L -.-> |needs and depends on| A;
    L -.-> |needs and depends on| K;
    O -.-> |needs and depends on| A;
    O -.-> |needs and depends on| K;
    S -.-> |needs and depends on| A;
    S -.-> |needs and depends on| K;
    S -.-> |needs and depends on| T;
    downtime_check --> |needs and depends on| A;
    db:* --> |needs| A;
    gitlab:setup --> |needs| A;
    downtime_check --> |needs and depends on| A;
    graphql-docs-verify --> |needs| A;
    end

subgraph "`review-prepare` stage"
    E --> |needs| C;
    X["schedule:review-build-cng<br/>(master schedule only)"] --> |needs| C;
    end

subgraph "`review` stage"
    G --> |needs| E;
    G2 --> |needs| E;
    end

subgraph "`qa` stage"
    Q --> |needs| C;
    Q --> |needs| F;
    R --> |needs| C;
    R --> |needs| F;
    P --> |needs| C;
    P --> |needs| F;
    review-qa-smoke -.-> |needs and depends on| G;
    review-qa-all -.-> |needs and depends on| G;
    review-performance -.-> |needs and depends on| G;
    X2["schedule:review-performance<br/>(master only)"] -.-> |needs and depends on| G2;
    dast -.-> |needs and depends on| G;
    end

subgraph "`post-test` stage"
    M
    end

subgraph "`pages` stage"
    N -.-> |depends on| C;
    N -.-> |depends on| H;
    N -.-> |depends on| M;
    end
```

## Test jobs

Consult [GitLab tests in the Continuous Integration (CI) context](testing_guide/ci.md)
for more information.

## Review app jobs

Consult the [Review Apps](testing_guide/review_apps.md) dedicated page for more information.

---

[Return to Development documentation](README.md)
