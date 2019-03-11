# GitLab QA - End-to-end tests for GitLab

This directory contains [end-to-end tests](doc/development/testing_guide/end_to_end_tests.md)
for GitLab. It includes the test framework and the tests themselves.

The tests can be found in `qa/specs/features` (not to be confused with the unit
tests for the test framework, which are in `spec/`).

It is part of the [GitLab QA project](https://gitlab.com/gitlab-org/gitlab-qa).

## What is it?

GitLab QA is an end-to-end tests suite for GitLab.

These are black-box and entirely click-driven end-to-end tests you can run
against any existing instance.

## How does it work?

1. When we release a new version of GitLab, we build a Docker images for it.
1. Along with GitLab Docker Images we also build and publish GitLab QA images.
1. GitLab QA project uses these images to execute end-to-end tests.

## Validating GitLab views / partials / selectors in merge requests

We recently added a new CI job that is going to be triggered for every push
event in CE and EE projects. The job is called `qa:selectors` and it will
verify coupling between page objects implemented as a part of GitLab QA
and corresponding views / partials / selectors in CE / EE.

Whenever `qa:selectors` job fails in your merge request, you are supposed to
fix [page objects](qa/page/README.md). You should also trigger end-to-end tests
using `package-and-qa` manual action, to test if everything works fine.

## How can I use it?

You can use GitLab QA to exercise tests on any live instance! For example, the
following call would login to a local [GDK] instance and run all specs in
`qa/specs/features`:

```
bin/qa Test::Instance::All http://localhost:3000
```

Note: If you want to run tests requiring SSH against GDK, you
will need to [modify your GDK setup](https://gitlab.com/gitlab-org/gitlab-qa/blob/master/docs/run_qa_against_gdk.md).

### Writing tests

1. [Using page objects](qa/page/README.md)

### Running specific tests

You can also supply specific tests to run as another parameter. For example, to
run the repository-related specs, you can execute:

```
bin/qa Test::Instance::All http://localhost qa/specs/features/repository/
```

Since the arguments would be passed to `rspec`, you could use all `rspec`
options there. For example, passing `--backtrace` and also line number:

```
bin/qa Test::Instance::All http://localhost qa/specs/features/project/create_spec.rb:3 --backtrace
```

### Overriding the authenticated user

Unless told otherwise, the QA tests will run as the default `root` user seeded
by the GDK.

If you need to authenticate as a different user, you can provide the
`GITLAB_USERNAME` and `GITLAB_PASSWORD` environment variables:

```
GITLAB_USERNAME=jsmith GITLAB_PASSWORD=password bin/qa Test::Instance::All https://gitlab.example.com
```

If your user doesn't have permission to default sandbox group
`gitlab-qa-sandbox`, you could also use another sandbox group by giving
`GITLAB_SANDBOX_NAME`:

```
GITLAB_USERNAME=jsmith GITLAB_PASSWORD=password GITLAB_SANDBOX_NAME=jsmith-qa-sandbox bin/qa Test::Instance::All https://gitlab.example.com
```

All [supported environment variables are here](https://gitlab.com/gitlab-org/gitlab-qa/blob/master/docs/what_tests_can_be_run.md#supported-environment-variables).

### Sending additional cookies

The environment variable `QA_COOKIES` can be set to send additional cookies
on every request. This is necessary on gitlab.com to direct traffic to the
canary fleet. To do this set `QA_COOKIES="gitlab_canary=true"`.

To set multiple cookies, separate them with the `;` character, for example: `QA_COOKIES="cookie1=value;cookie2=value2"`


### Building a Docker image to test

Once you have made changes to the CE/EE repositories, you may want to build a
Docker image to test locally instead of waiting for the `gitlab-ce-qa` or
`gitlab-ee-qa` nightly builds. To do that, you can run from this directory:

```sh
docker build -t gitlab/gitlab-ce-qa:nightly .
```

[GDK]: https://gitlab.com/gitlab-org/gitlab-development-kit/

### Quarantined tests

Tests can be put in quarantine by assigning `:quarantine` metadata. This means
they will be skipped unless run with `--tag quarantine`. This can be used for
tests that are expected to fail while a fix is in progress (similar to how
[`skip` or `pending`](https://relishapp.com/rspec/rspec-core/v/3-8/docs/pending-and-skipped-examples)
 can be used).

```
bin/qa Test::Instance::All http://localhost --tag quarantine
```

If `quarantine` is used with other tags, tests will only be run if they have at
least one of the tags other than `quarantine`. This is different from how RSpec
tags usually work, where all tags are inclusive.

For example, suppose one test has `:smoke` and `:quarantine` metadata, and
another test has `:ldap` and `:quarantine` metadata. If the tests are run with
`--tag smoke --tag quarantine`, only the first test will run. The test with
`:ldap` will not run even though it also has `:quarantine`.
