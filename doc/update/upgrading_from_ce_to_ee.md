---
comments: false
---

# Upgrading from Community Edition to Enterprise Edition from source

NOTE: **NOTE** In the past we used separate documents for upgrading from
Community Edition to Enterprise Edition. These documents can be found in the
[`doc/update` directory of Enterprise Edition's source
code][old-ee-upgrade-docs].

If you want to upgrade the version only, for example 11.8 to 11.9, *without* changing the
GitLab edition you are using (Community or Enterprise), see the
[Upgrading from source](upgrading_from_source.md) documentation.

## General upgrading steps

This guide assumes you have a correctly configured and tested installation of
GitLab Community Edition. If you run into any trouble or if you have any
questions please contact us at [support@gitlab.com].

In all examples, replace `EE_BRANCH` with the Enterprise Edition branch for the
version you are using, and `CE_BRANCH` with the Community Edition branch.
Branch names use the format `major-minor-stable-ee` for Enterprise Edition, and
`major-minor-stable` for Community Edition. For example, for 11.8.0 you would
use the following branches:

* Enterprise Edition: `11-8-stable-ee`
* Community Edition: `11-8-stable`

### 0. Backup

Make a backup just in case something goes wrong:

```bash
cd /home/git/gitlab
sudo -u git -H bundle exec rake gitlab:backup:create RAILS_ENV=production
```

For installations using MySQL, this may require granting "LOCK TABLES"
privileges to the GitLab user on the database version.

### 1. Stop server

```bash
sudo service gitlab stop
```

### 2. Get the EE code

```bash
cd /home/git/gitlab
sudo -u git -H git remote add -f ee https://gitlab.com/gitlab-org/gitlab-ee.git
sudo -u git -H git checkout EE_BRANCH
```

### 3. Install libs, migrations, etc.

```bash
cd /home/git/gitlab

# MySQL installations (note: the line below states '--without postgres')
sudo -u git -H bundle install --without postgres development test --deployment

# PostgreSQL installations (note: the line below states '--without mysql')
sudo -u git -H bundle install --without mysql development test --deployment

# Run database migrations
sudo -u git -H bundle exec rake db:migrate RAILS_ENV=production

# Clean up assets and cache
sudo -u git -H bundle exec rake assets:clean assets:precompile cache:clear RAILS_ENV=production
```

### 4. Install `gitlab-elasticsearch-indexer` (optional) **[STARTER ONLY]**

If you're interested in using GitLab's new [elasticsearch repository
indexer](../integration/elasticsearch.md) (currently in beta) please follow the instructions on the
document linked above and enable the indexer usage in the GitLab admin settings.

### 5. Start application

```bash
sudo service gitlab start
sudo service nginx restart
```

### 6. Check application status

Check if GitLab and its environment are configured correctly:

```bash
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
```

To make sure you didn't miss anything run a more thorough check with:

```bash
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production
```

If all items are green, then congratulations upgrade complete!

## Things went south? Revert to previous version (Community Edition)

### 1. Revert the code to the previous version

```bash
cd /home/git/gitlab
sudo -u git -H git checkout CE_BRANCH
```

### 2. Restore from the backup

```bash
cd /home/git/gitlab
sudo -u git -H bundle exec rake gitlab:backup:restore RAILS_ENV=production
```

## Version specific steps

Certain versions of GitLab may require you to perform additional steps when
upgrading from Community Edition to Enterprise Edition. Should such steps be
necessary, they will listed per version below.

<!--
Example:

### 11.8.0

Additional instructions here.
-->

[support@gitlab.com]: mailto:support@gitlab.com
[old-ee-upgrade-docs]: https://gitlab.com/gitlab-org/gitlab-ee/tree/11-8-stable-ee/doc/update
