# Modifying global user settings

GitLab administrators can modify user settings for the entire GitLab instance.

## Disallow users creating top-level groups

By default, new users can create top-level groups. To disable this, modify the appropriate configuration file.

For Omnibus installations, add the following to `/etc/gitlab/gitlab.rb`:

```ruby
gitlab_rails['gitlab_default_can_create_group'] = false
```

For source installations, uncomment the following line in `config/gitlab.yml`:

```yaml
# default_can_create_group: false  # default: true
```

## Disallow users changing usernames

By default, new users can change their usernames. To disable this, modify the appropriate configuration file.

For Omnibus installations, add the following to `/etc/gitlab/gitlab.rb`:

```ruby
gitlab_rails['gitlab_username_changing_enabled'] = false
```

For source installations, uncomment the following line in `config/gitlab.yml`:

```yaml
# username_changing_enabled: false # default: true - User can change their username/namespace
```
