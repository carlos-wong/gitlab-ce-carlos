---
comments: false
---

# Universal update guide for patch versions

## Select Version to Install

Make sure you view [this update guide](https://gitlab.com/gitlab-org/gitlab/blob/master/doc/update/patch_versions.md) from the tag (version) of GitLab you would like to install.
In most cases this should be the highest numbered production tag (without rc in it).
You can select the tag in the version dropdown in the top left corner of GitLab (below the menu bar).

### 0. Backup

It's useful to make a backup just in case things go south:

```bash
cd /home/git/gitlab

sudo -u git -H bundle exec rake gitlab:backup:create RAILS_ENV=production
```

### 1. Stop server

```bash
sudo service gitlab stop
```

### 2. Get latest code for the stable branch

In the commands below, replace `LATEST_TAG` with the latest GitLab tag you want
to update to, for example `v8.0.3`. Use `git tag -l 'v*.[0-9]' --sort='v:refname'`
to see a list of all tags. Make sure to update patch versions only (check your
current version with `cat VERSION`).

```bash
cd /home/git/gitlab

sudo -u git -H git fetch --all
sudo -u git -H git checkout -- Gemfile.lock db/schema.rb locale
sudo -u git -H git checkout LATEST_TAG -b LATEST_TAG
```

### 3. Install libs, migrations, etc

```bash
cd /home/git/gitlab

sudo -u git -H bundle install --without development test mysql --deployment

# Optional: clean up old gems
sudo -u git -H bundle clean

# Run database migrations
sudo -u git -H bundle exec rake db:migrate RAILS_ENV=production

# Compile GetText PO files
# Internationalization was added in `v9.2.0` so these commands are only
# required for versions equal or major to it.
sudo -u git -H bundle exec rake gettext:pack RAILS_ENV=production
sudo -u git -H bundle exec rake gettext:po_to_json RAILS_ENV=production

# Clean up assets and cache
sudo -u git -H bundle exec rake yarn:install gitlab:assets:clean gitlab:assets:compile cache:clear RAILS_ENV=production NODE_ENV=production NODE_OPTIONS="--max_old_space_size=4096"
```

### 4. Update GitLab Workhorse to the corresponding version

```bash
cd /home/git/gitlab

sudo -u git -H bundle exec rake "gitlab:workhorse:install[/home/git/gitlab-workhorse]" RAILS_ENV=production
```

### 5. Update Gitaly to the corresponding version

```bash
cd /home/git/gitlab

sudo -u git -H bundle exec rake "gitlab:gitaly:install[/home/git/gitaly,/home/git/repositories]" RAILS_ENV=production
```

### 6. Update GitLab Shell to the corresponding version

```bash
cd /home/git/gitlab-shell

sudo -u git -H git fetch --all --tags
sudo -u git -H git checkout v$(</home/git/gitlab/GITLAB_SHELL_VERSION) -b v$(</home/git/gitlab/GITLAB_SHELL_VERSION)
sudo -u git -H make build
```

### 7. Update GitLab Pages to the corresponding version (skip if not using pages)

```bash
cd /home/git/gitlab-pages

sudo -u git -H git fetch --all --tags
sudo -u git -H git checkout v$(</home/git/gitlab/GITLAB_PAGES_VERSION)
sudo -u git -H make
```

### 8. Install/Update `gitlab-elasticsearch-indexer` (optional) **(STARTER ONLY)**

If you're interested in using GitLab's new [Elasticsearch repository indexer](../integration/elasticsearch.md#elasticsearch-repository-indexer-beta) (currently in beta)
please follow the instructions on the document linked above and enable the
indexer usage in the GitLab admin settings.

### 9. Start application

```bash
sudo service gitlab start
sudo service nginx restart
```

### 10. Check application status

Check if GitLab and its environment are configured correctly:

```bash
cd /home/git/gitlab

sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
```

To make sure you didn't miss anything run a more thorough check with:

```bash
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production
```

If all items are green, then congratulations upgrade complete!
