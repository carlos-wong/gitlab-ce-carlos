# GitLab Developers Guide to Working with Gitaly

[Gitaly](https://gitlab.com/gitlab-org/gitaly) is a high-level Git RPC service used by GitLab CE/EE,
Workhorse and GitLab-Shell.

## Beginner's guide

Start by reading the gitaly repository's
[Beginner's guide to Gitaly contributions](https://gitlab.com/gitlab-org/gitaly/blob/master/doc/beginners_guide.md).
It describes how to setup gitaly, the various components of gitaly and what they do, and how to run its test suites.

## Developing new Git features

To read or write Git data, a request has to be made to Gitaly. This means that
if you're developing a new feature where you need data that's not yet available
in `lib/gitlab/git` changes have to be made to Gitaly.

> This is a new process that is not clearly defined yet. If you want
to contribute a Git feature and you're getting stuck, reach out to the
Gitaly team or `@jacobvosmaer-gitlab`.

By 'new feature' we mean any method or class in `lib/gitlab/git` that is
called from outside `lib/gitlab/git`. For new methods that are called
from inside `lib/gitlab/git`, see 'Modifying existing Git features'
below.

There should be no new code that touches Git repositories via
disk access (e.g. Rugged, `git`, `rm -rf`) anywhere outside
`lib/gitlab/git`.

The process for adding new Gitaly features is:

- exploration / prototyping
- design and create a new Gitaly RPC [in gitaly-proto](https://gitlab.com/gitlab-org/gitaly-proto)
- release a new version of gitaly-proto
- write implementation and tests for the RPC [in Gitaly](https://gitlab.com/gitlab-org/gitaly), in Go or Ruby
- release a new version of Gitaly
- write client code in gitlab-ce/ee, gitlab-workhorse or gitlab-shell that calls the new Gitaly RPC

These steps often overlap. It is possible to use an unreleased version
of Gitaly and gitaly-proto during testing and development.

- See the [Gitaly repo](https://gitlab.com/gitlab-org/gitaly/blob/master/CONTRIBUTING.md#development-and-testing-with-a-custom-gitaly-proto) for instructions on writing server side code with an unreleased protocol.
- See [below](#running-tests-with-a-locally-modified-version-of-gitaly) for instructions on running gitlab-ce tests with a modified version of Gitaly.
- In GDK run `gdk install` and restart `gdk run` (or `gdk run app`) to use a locally modified Gitaly version for development

### Gitaly-ruby

It is possible to implement and test RPC's in Gitaly using Ruby code,
in
[gitaly-ruby](https://gitlab.com/gitlab-org/gitaly/tree/master/ruby).
This should make it easier to contribute for developers who are less
comfortable writing Go code.

There is documentation for this approach in [the Gitaly
repo](https://gitlab.com/gitlab-org/gitaly/blob/master/doc/ruby_endpoint.md).

## Gitaly-Related Test Failures

If your test-suite is failing with Gitaly issues, as a first step, try running:

```shell
rm -rf tmp/tests/gitaly
```

During rspec tests, the Gitaly instance will write logs to `gitlab/log/gitaly-test.log`.

## Legacy Rugged code

While Gitaly can handle all Git access, many of GitLab customers still
run Gitaly atop NFS. The legacy Rugged implementation for Git calls may
be faster than the Gitaly RPC due to N+1 Gitaly calls and other
reasons. See [the
issue](https://gitlab.com/gitlab-org/gitlab-ce/issues/57317) for more
details.

Until GitLab has eliminated most of these inefficiencies or the use of
NFS is discontinued for Git data, Rugged implementations of some of the
most commonly-used RPCs can be enabled via feature flags:

* `rugged_find_commit`
* `rugged_get_tree_entries`
* `rugged_tree_entry`
* `rugged_commit_is_ancestor`
* `rugged_commit_tree_entry`
* `rugged_list_commits_by_oid`

A convenience Rake task can be used to enable or disable these flags
all together. To enable:

```sh
bundle exec rake gitlab:features:enable_rugged
```

To disable:

```sh
bundle exec rake gitlab:features:disable_rugged
```

Most of this code exists in the `lib/gitlab/git/rugged_impl` directory.

NOTE: **Note:** You should NOT need to add or modify code related to
Rugged unless explicitly discussed with the [Gitaly
Team](https://gitlab.com/groups/gl-gitaly/group_members). This code will
NOT work on GitLab.com or other GitLab instances that do not use NFS.

## `TooManyInvocationsError` errors

During development and testing, you may experience `Gitlab::GitalyClient::TooManyInvocationsError` failures.
The `GitalyClient` will attempt to block against potential n+1 issues by raising this error
when Gitaly is called more than 30 times in a single Rails request or Sidekiq execution.

As a temporary measure, export `GITALY_DISABLE_REQUEST_LIMITS=1` to suppress the error. This will disable the n+1 detection
in your development environment.

Please raise an issue in the GitLab CE or EE repositories to report the issue. Include the labels ~Gitaly
~performance ~"technical debt". Please ensure that the issue contains the full stack trace and error message of the
`TooManyInvocationsError`. Also include any known failing tests if possible.

Isolate the source of the n+1 problem. This will normally be a loop that results in Gitaly being called for each
element in an array. If you are unable to isolate the problem, please contact a member
of the [Gitaly Team](https://gitlab.com/groups/gl-gitaly/group_members) for assistance.

Once the source has been found, wrap it in an `allow_n_plus_1_calls` block, as follows:

```ruby
# n+1: link to n+1 issue
Gitlab::GitalyClient.allow_n_plus_1_calls do
  # original code
  commits.each { |commit| ... }
end
```

Once the code is wrapped in this block, this code-path will be excluded from n+1 detection.

## Request counts

Commits and other git data, is now fetched through Gitaly. These fetches can,
much like with a database, be batched. This improves performance for the client
and for Gitaly itself and therefore for the users too. To keep performance stable
and guard performance regressions, Gitaly calls can be counted and the call count
can be tested against. This requires the `:request_store` flag to be set.

```ruby
describe 'Gitaly Request count tests' do
  context 'when the request store is activated', :request_store do
    it 'correctly counts the gitaly requests made' do
      expect { subject }.to change { Gitlab::GitalyClient.get_request_count }.by(10)
    end
  end
end
```

## Running tests with a locally modified version of Gitaly

Normally, gitlab-ce/ee tests use a local clone of Gitaly in
`tmp/tests/gitaly` pinned at the version specified in
`GITALY_SERVER_VERSION`. The `GITALY_SERVER_VERSION` file supports
`=my-branch` syntax to use a custom branch in gitlab-org/gitaly. If
you want to run tests locally against a modified version of Gitaly you
can replace `tmp/tests/gitaly` with a symlink. This is much faster
because the `=my-branch` syntax forces a Gitaly re-install each time
you run `rspec`.

```shell
rm -rf tmp/tests/gitaly
ln -s /path/to/gitaly tmp/tests/gitaly
```

Make sure you run `make` in your local Gitaly directory before running
tests. Otherwise, Gitaly will fail to boot.

If you make changes to your local Gitaly in between test runs you need
to manually run `make` again.

Note that CI tests will not use your locally modified version of
Gitaly. To use a custom Gitaly version in CI you need to update
GITALY_SERVER_VERSION. You can use the format `=revision` to use a
non-tagged commit from <https://gitlab.com/gitlab-org/gitaly> in CI.

To use a different Gitaly repository, e.g., if your changes are present
on a fork, you can specify a `GITALY_REPO_URL` environment variable when
running tests:

```shell
GITALY_REPO_URL=https://gitlab.com/nick.thomas/gitaly bundle exec rspec spec/lib/gitlab/git/repository_spec.rb
```

If your fork of Gitaly is private, you can generate a [Deploy Token](../user/project/deploy_tokens/index.md)
and specify it in the URL:

```shell
GITALY_REPO_URL=https://gitlab+deploy-token-1000:token-here@gitlab.com/nick.thomas/gitaly bundle exec rspec spec/lib/gitlab/git/repository_spec.rb
```

To use a custom Gitaly repository in CI, for instance if you want your
GitLab fork to always use your own Gitaly fork, set `GITALY_REPO_URL`
as a [CI environment variable](../ci/variables/README.md#gitlab-cicd-environment-variables).

---

[Return to Development documentation](README.md)

## Wrapping RPCs in Feature Flags

Here are the steps to gate a new feature in Gitaly behind a feature flag.

### Gitaly

1. Create a package scoped flag name:

   ```go
   var findAllTagsFeatureFlag = "go-find-all-tags"
   ```

1. Create a switch in the code using the `featureflag` package:

   ```go
   if featureflag.IsEnabled(ctx, findAllTagsFeatureFlag) {
     // go implementation
   } else {
     // ruby implementation
   }
   ```

1. Create prometheus metrics:

   ```go
   var	findAllTagsRequests = prometheus.NewCounterVec(
   		prometheus.CounterOpts{
   			Name: "gitaly_find_all_tags_requests_total",
   			Help: "Counter of go vs ruby implementation of FindAllTags",
   		},
   		[]string{"implementation"},
   	)
   )

   func init() {
   	prometheus.Register(findAllTagsRequests)
   }

   if featureflag.IsEnabled(ctx, findAllTagsFeatureFlag) {
   	findAllTagsRequests.WithLabelValues("go").Inc()
     // go implementation
   } else {
   	findAllTagsRequests.WithLabelValues("ruby").Inc()
     // ruby implementation
   }
   ```

1. Set headers in tests:

   ```go
   import (
     "google.golang.org/grpc/metadata"

     "gitlab.com/gitlab-org/gitaly/internal/featureflag"
   )

   //...

   md := metadata.New(map[string]string{featureflag.HeaderKey(findAllTagsFeatureFlag): "true"})
   ctx = metadata.NewOutgoingContext(context.Background(), md)

   c, err = client.FindAllTags(ctx, rpcRequest)
   require.NoError(t, err)
   ```

### Gitlab-Rails

1. Add feature flag to `lib/gitlab/gitaly_client.rb` (in gitlab-rails):

   ```ruby
   SERVER_FEATURE_FLAGS = %w[go-find-all-tags].freeze
   ```

1. Test in rails console by setting feature flag:

   ```ruby
   Feature.enable('gitaly_go-find-all-tags')
   ```
