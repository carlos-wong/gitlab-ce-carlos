# File hooks

> Introduced in GitLab 10.6.
> Until 12.8 the feature name was Plugins.

With custom file hooks, GitLab administrators can introduce custom integrations
without modifying GitLab's source code.

NOTE: **Note:**
Instead of writing and supporting your own file hook you can make changes
directly to the GitLab source code and contribute back upstream. This way we can
ensure functionality is preserved across versions and covered by tests.

NOTE: **Note:**
File hooks must be configured on the filesystem of the GitLab server. Only GitLab
server administrators will be able to complete these tasks. Explore
[system hooks] or [webhooks] as an option if you do not have filesystem access.

A file hook will run on each event so it's up to you to filter events or projects
within a file hook code. You can have as many file hooks as you want. Each file hook will
be triggered by GitLab asynchronously in case of an event. For a list of events
see the [system hooks] documentation.

## Setup

The file hooks must be placed directly into the `plugins` directory, subdirectories
will be ignored. There is an
[`example` directory inside `plugins`](https://gitlab.com/gitlab-org/gitlab/tree/master/plugins/examples)
where you can find some basic examples.

Follow the steps below to set up a custom hook:

1. On the GitLab server, navigate to the plugin directory.
   For an installation from source the path is usually
   `/home/git/gitlab/plugins/`. For Omnibus installs the path is
   usually `/opt/gitlab/embedded/service/gitlab-rails/plugins`.

    For [highly available] configurations, your hook file should exist on each
    application server.

1. Inside the `plugins` directory, create a file with a name of your choice,
   without spaces or special characters.
1. Make the hook file executable and make sure it's owned by the Git user.
1. Write the code to make the file hook function as expected. That can be
   in any language, and ensure the 'shebang' at the top properly reflects the
   language type. For example, if the script is in Ruby the shebang will
   probably be `#!/usr/bin/env ruby`.
1. The data to the file hook will be provided as JSON on STDIN. It will be exactly
   same as for [system hooks]

That's it! Assuming the file hook code is properly implemented, the hook will fire
as appropriate. The file hooks file list is updated for each event, there is no
need to restart GitLab to apply a new file hook.

If a file hook executes with non-zero exit code or GitLab fails to execute it, a
message will be logged to:

- `gitlab-rails/plugin.log` in an Omnibus installation.
- `log/plugin.log` in a source installation.

## Creating file hooks

Below is an example that will only response on the event `project_create` and
will inform the admins from the GitLab instance that a new project has been created.

```ruby
# By using the embedded ruby version we eliminate the possibility that our chosen language
# would be unavailable from
#!/opt/gitlab/embedded/bin/ruby
require 'json'
require 'mail'

# The incoming variables are in JSON format so we need to parse it first.
ARGS = JSON.parse(STDIN.read)

# We only want to trigger this file hook on the event project_create
return unless ARGS['event_name'] == 'project_create'

# We will inform our admins of our gitlab instance that a new project is created
Mail.deliver do
  from    'info@gitlab_instance.com'
  to      'admin@gitlab_instance.com'
  subject "new project " + ARGS['name']
  body    ARGS['owner_name'] + 'created project ' + ARGS['name']
end
```

## Validation

Writing your own file hook can be tricky and it's easier if you can check it
without altering the system. A rake task is provided so that you can use it
in a staging environment to test your file hook before using it in production.
The rake task will use a sample data and execute each of file hook. The output
should be enough to determine if the system sees your file hook and if it was
executed without errors.

```bash
# Omnibus installations
sudo gitlab-rake file_hooks:validate

# Installations from source
cd /home/git/gitlab
bundle exec rake file_hooks:validate RAILS_ENV=production
```

Example of output:

```
Validating file hooks from /plugins directory
* /home/git/gitlab/plugins/save_to_file.clj succeed (zero exit code)
* /home/git/gitlab/plugins/save_to_file.rb failure (non-zero exit code)
```

[system hooks]: ../system_hooks/system_hooks.md
[webhooks]: ../user/project/integrations/webhooks.md
[highly available]: ./high_availability/README.md
