# Test Import Project

For testing, we can import our own [GitLab CE](https://gitlab.com/gitlab-org/gitlab-foss/) project (named `gitlabhq` in this case) under a group named `qa-perf-testing`. Project tarballs that can be used for testing can be found over on the [performance-data](https://gitlab.com/gitlab-org/quality/performance-data) project. A different project could be used if required.

There are several options for importing the project into your GitLab environment. They are detailed as follows with the assumption that the recommended group `qa-perf-testing` and project `gitlabhq` are being set up.

## Importing the project

There are several ways to import a project.

### Importing via UI

The first option is to simply [import the Project tarball file via the GitLab UI](../user/project/settings/import_export.md#importing-the-project):

1. Create the group `qa-perf-testing`
1. Import the [GitLab FOSS project tarball](https://gitlab.com/gitlab-org/quality/performance-data/raw/master/gitlabhq_export.tar.gz) into the Group.

It should take up to 15 minutes for the project to fully import. You can head to the project's main page for the current status.

NOTE: **Note:** This method ignores all the errors silently (including the ones related to `GITALY_DISABLE_REQUEST_LIMITS`) and is used by GitLab's users. For development and testing, check the other methods below.

### Importing via the `import-project` script

A convenient script, [`bin/import-project`](https://gitlab.com/gitlab-org/quality/performance/blob/master/bin/import-project), is provided with [performance](https://gitlab.com/gitlab-org/quality/performance) project to import the Project tarball into a GitLab environment via API from the terminal.

Note that to use the script, it will require some preparation if you haven't done so already:

1. First, set up [`Ruby`](https://www.ruby-lang.org/en/documentation/installation/) and [`Ruby Bundler`](https://bundler.io) if they aren't already available on the machine.
1. Next, install the required Ruby Gems via Bundler with `bundle install`.

For details how to use `bin/import-project`, run:

```shell
bin/import-project --help
```

The process should take up to 15 minutes for the project to import fully. The script will keep checking periodically for the status and exit once import has completed.

### Importing via GitHub

There is also an option to [import the project via GitHub](../user/project/import/github.md):

1. Create the group `qa-perf-testing`
1. Import the GitLab FOSS repository that's [mirrored on GitHub](https://github.com/gitlabhq/gitlabhq) into the group via the UI.

This method will take longer to import than the other methods and will depend on several factors. It's recommended to use the other methods.

### Importing via a rake task

[`import.rake`](https://gitlab.com/gitlab-org/gitlab/blob/master/lib/tasks/gitlab/import_export/import.rake) was introduced for importing large GitLab project exports.

As part of this script we also disable direct and background upload to avoid situations where a huge archive is being uploaded to GCS (while being inside a transaction, which can cause idle transaction timeouts).

We can simply run this script from the terminal:

Parameters:

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `username`      | string | yes | User name |
| `namespace_path` | string | yes | Namespace path |
| `project_path` | string | yes | Project name |
| `archive_path` | string | yes | Path to the exported project tarball you want to import |
| `measurement_enabled` | boolean | no | Measure execution time, number of SQL calls and GC count |

```shell
bundle exec rake "gitlab:import_export:import[root, root, testingprojectimport, /path/to/file.tar.gz, true]"
```

### Importing via the Rails console

The last option is to import a project using a Rails console:

1. Start a Ruby on Rails console:

   ```shell
   # Omnibus GitLab
   gitlab-rails console

   # For installations from source
   sudo -u git -H bundle exec rails console RAILS_ENV=production
   ```

1. Create a project and run `ProjectTreeRestorer`:

   ```ruby
   shared_class = Struct.new(:export_path) do
     def error(message)
       raise message
     end
   end

   user = User.first

   shared = shared_class.new(path)

   project = Projects::CreateService.new(user, { name: name, namespace: user.namespace }).execute
   begin
     #Enable Request store
     RequestStore.begin!
     Gitlab::ImportExport::ProjectTreeRestorer.new(user: user, shared: shared, project: project).restore
   ensure
     RequestStore.end!
     RequestStore.clear!
   end
   ```

1. In case you need the repository as well, you can restore it using:

   ```ruby
   repo_path = File.join(shared.export_path, Gitlab::ImportExport.project_bundle_filename)

   Gitlab::ImportExport::RepoRestorer.new(path_to_bundle: repo_path,
                                          shared: shared,
                                          project: project).restore
   ```

    We are storing all import failures in the `import_failures` data table.

    To make sure that the project import finished without any issues, check:

    ```ruby
    project.import_failures.all
    ```

## Performance testing

For Performance testing, we should:

- Import a quite large project, [`gitlabhq`](https://gitlab.com/gitlab-org/quality/performance-data#gitlab-performance-test-framework-data) should be a good example.
- Measure the execution time of `ProjectTreeRestorer`.
- Count the number of executed SQL queries during the restore.
- Observe the number of GC cycles happening.

You can use this [snippet](https://gitlab.com/gitlab-org/gitlab/snippets/1924954), which will restore the project, and measure the execution time of `ProjectTreeRestorer`, number of SQL queries and number of GC cycles happening.

You can execute the script from the `gdk/gitlab` directory like this:

```shell
bundle exec rails r  /path_to_sript/script.rb project_name /path_to_extracted_project request_store_enabled
```

## Troubleshooting

In this section we'll detail any known issues we've seen when trying to import a project and how to manage them.

### Gitaly calls error when importing

If you're attempting to import a large project into a development environment, you may see Gitaly throw an error about too many calls or invocations, for example:

```
Error importing repository into qa-perf-testing/gitlabhq - GitalyClient#call called 31 times from single request. Potential n+1?
```

This is due to a [n+1 calls limit being set for development setups](gitaly.md#toomanyinvocationserror-errors). You can work around this by setting `GITALY_DISABLE_REQUEST_LIMITS=1` as an environment variable, restarting your development environment and importing again.

## Access token setup

Many of the tests also require a GitLab Personal Access Token. This is due to numerous endpoints themselves requiring authentication.

[The official GitLab docs detail how to create this token](../user/profile/personal_access_tokens.md#creating-a-personal-access-token). The tests require that the token is generated by an admin user and that it has the `API` and `read_repository` permissions.

Details on how to use the Access Token with each type of test are found in their respective documentation.
