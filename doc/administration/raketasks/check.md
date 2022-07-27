---
stage: Systems
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Integrity check Rake task **(FREE SELF)**

GitLab provides Rake tasks to check the integrity of various components.
See also the [check GitLab configuration Rake task](maintenance.md#check-gitlab-configuration).

## Repository integrity

Even though Git is very resilient and tries to prevent data integrity issues,
there are times when things go wrong. The following Rake tasks intend to
help GitLab administrators diagnose problem repositories so they can be fixed.

These Rake tasks use three different methods to determine the integrity of Git
repositories.

1. Git repository file system check ([`git fsck`](https://git-scm.com/docs/git-fsck)).
   This step verifies the connectivity and validity of objects in the repository.
1. Check for `config.lock` in the repository directory.
1. Check for any branch/references lock files in `refs/heads`.

The existence of `config.lock` or reference locks
alone do not necessarily indicate a problem. Lock files are routinely created
and removed as Git and GitLab perform operations on the repository. They serve
to prevent data integrity issues. However, if a Git operation is interrupted these
locks may not be cleaned up properly.

The following symptoms may indicate a problem with repository integrity. If users
experience these symptoms you may use the Rake tasks described below to determine
exactly which repositories are causing the trouble.

- Receiving an error when trying to push code - `remote: error: cannot lock ref`
- A 500 error when viewing the GitLab dashboard or when accessing a specific project.

### Check project code repositories

This task loops through the project code repositories and runs the integrity check
described previously. If a project uses a pool repository, that is also checked.
Other types of Git repositories [are not checked](https://gitlab.com/gitlab-org/gitaly/-/issues/3643).

**Omnibus Installation**

```shell
sudo gitlab-rake gitlab:git:fsck
```

**Source Installation**

```shell
sudo -u git -H bundle exec rake gitlab:git:fsck RAILS_ENV=production
```

## Checksum of repository refs

One Git repository can be compared to another by checksumming all refs of each
repository. If both repositories have the same refs, and if both repositories
pass an integrity check, then we can be confident that both repositories are the
same.

For example, this can be used to compare a backup of a repository against the
source repository.

### Check all GitLab repositories

This task loops through all repositories on the GitLab server and outputs
checksums in the format `<PROJECT ID>,<CHECKSUM>`.

- If a repository doesn't exist, the project ID is a blank checksum.
- If a repository exists but is empty, the output checksum is `0000000000000000000000000000000000000000`.
- Projects which don't exist are skipped.

**Omnibus Installation**

```shell
sudo gitlab-rake gitlab:git:checksum_projects
```

**Source Installation**

```shell
sudo -u git -H bundle exec rake gitlab:git:checksum_projects RAILS_ENV=production
```

For example, if:

- Project with ID#2 doesn't exist, it is skipped.
- Project with ID#4 doesn't have a repository, its checksum is blank.
- Project with ID#5 has an empty repository, its checksum is `0000000000000000000000000000000000000000`.

The output would then look something like:

```plaintext
1,cfa3f06ba235c13df0bb28e079bcea62c5848af2
3,3f3fb58a8106230e3a6c6b48adc2712fb3b6ef87
4,
5,0000000000000000000000000000000000000000
6,6c6b48adc2712fb3b6ef87cfa3f06ba235c13df0
```

### Check specific GitLab repositories

Optionally, specific project IDs can be checksummed by setting an environment
variable `CHECKSUM_PROJECT_IDS` with a list of comma-separated integers, for example:

```shell
sudo CHECKSUM_PROJECT_IDS="1,3" gitlab-rake gitlab:git:checksum_projects
```

## Uploaded files integrity

Various types of files can be uploaded to a GitLab installation by users.
These integrity checks can detect missing files. Additionally, for locally
stored files, checksums are generated and stored in the database upon upload,
and these checks verify them against current files.

Integrity checks are supported for the following types of file:

- CI artifacts (introduced in GitLab 10.7.0)
- LFS objects (introduced in GitLab 10.6.0)
- User uploads (introduced in GitLab 10.6.0)

**Omnibus Installation**

```shell
sudo gitlab-rake gitlab:artifacts:check
sudo gitlab-rake gitlab:lfs:check
sudo gitlab-rake gitlab:uploads:check
```

**Source Installation**

```shell
sudo -u git -H bundle exec rake gitlab:artifacts:check RAILS_ENV=production
sudo -u git -H bundle exec rake gitlab:lfs:check RAILS_ENV=production
sudo -u git -H bundle exec rake gitlab:uploads:check RAILS_ENV=production
```

These tasks also accept some environment variables which you can use to override
certain values:

Variable  | Type    | Description
--------- | ------- | -----------
`BATCH`   | integer | Specifies the size of the batch. Defaults to 200.
`ID_FROM` | integer | Specifies the ID to start from, inclusive of the value.
`ID_TO`   | integer | Specifies the ID value to end at, inclusive of the value.
`VERBOSE` | boolean | Causes failures to be listed individually, rather than being summarized.

```shell
sudo gitlab-rake gitlab:artifacts:check BATCH=100 ID_FROM=50 ID_TO=250
sudo gitlab-rake gitlab:lfs:check BATCH=100 ID_FROM=50 ID_TO=250
sudo gitlab-rake gitlab:uploads:check BATCH=100 ID_FROM=50 ID_TO=250
```

Example output:

```shell
$ sudo gitlab-rake gitlab:uploads:check
Checking integrity of Uploads
- 1..1350: Failures: 0
- 1351..2743: Failures: 0
- 2745..4349: Failures: 2
- 4357..5762: Failures: 1
- 5764..7140: Failures: 2
- 7142..8651: Failures: 0
- 8653..10134: Failures: 0
- 10135..11773: Failures: 0
- 11777..13315: Failures: 0
Done!
```

Example verbose output:

```shell
$ sudo gitlab-rake gitlab:uploads:check VERBOSE=1
Checking integrity of Uploads
- 1..1350: Failures: 0
- 1351..2743: Failures: 0
- 2745..4349: Failures: 2
  - Upload: 3573: #<Errno::ENOENT: No such file or directory @ rb_sysopen - /opt/gitlab/embedded/service/gitlab-rails/public/uploads/user-foo/project-bar/7a77cc52947bfe188adeff42f890bb77/image.png>
  - Upload: 3580: #<Errno::ENOENT: No such file or directory @ rb_sysopen - /opt/gitlab/embedded/service/gitlab-rails/public/uploads/user-foo/project-bar/2840ba1ba3b2ecfa3478a7b161375f8a/pug.png>
- 4357..5762: Failures: 1
  - Upload: 4636: #<Google::Apis::ServerError: Server error>
- 5764..7140: Failures: 2
  - Upload: 5812: #<NoMethodError: undefined method `hashed_storage?' for nil:NilClass>
  - Upload: 5837: #<NoMethodError: undefined method `hashed_storage?' for nil:NilClass>
- 7142..8651: Failures: 0
- 8653..10134: Failures: 0
- 10135..11773: Failures: 0
- 11777..13315: Failures: 0
Done!
```

## LDAP check

The LDAP check Rake task tests the bind DN and password credentials
(if configured) and lists a sample of LDAP users. This task is also
executed as part of the `gitlab:check` task, but can run independently.
See [LDAP Rake Tasks - LDAP Check](ldap.md#check) for details.

## Verify database values can be decrypted using the current secrets

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/20069) in GitLab 13.1.

This task runs through all possible encrypted values in the
database, verifying that they are decryptable using the current
secrets file (`gitlab-secrets.json`).

Automatic resolution is not yet implemented. If you have values that
cannot be decrypted, you can follow steps to reset them, see our
documentation on what to do [when the secrets file is lost](../../raketasks/backup_restore.md#when-the-secrets-file-is-lost).

This can take a very long time, depending on the size of your
database, as it checks all rows in all tables.

**Omnibus Installation**

```shell
sudo gitlab-rake gitlab:doctor:secrets
```

**Source Installation**

```shell
bundle exec rake gitlab:doctor:secrets RAILS_ENV=production
```

**Example output**

```plaintext
I, [2020-06-11T17:17:54.951815 #27148]  INFO -- : Checking encrypted values in the database
I, [2020-06-11T17:18:12.677708 #27148]  INFO -- : - ApplicationSetting failures: 0
I, [2020-06-11T17:18:12.823692 #27148]  INFO -- : - User failures: 0
[...] other models possibly containing encrypted data
I, [2020-06-11T17:18:14.938335 #27148]  INFO -- : - Group failures: 1
I, [2020-06-11T17:18:15.559162 #27148]  INFO -- : - Operations::FeatureFlagsClient failures: 0
I, [2020-06-11T17:18:15.575533 #27148]  INFO -- : - ScimOauthAccessToken failures: 0
I, [2020-06-11T17:18:15.575678 #27148]  INFO -- : Total: 1 row(s) affected
I, [2020-06-11T17:18:15.575711 #27148]  INFO -- : Done!
```

### Verbose mode

To get more detailed information about which rows and columns can't be
decrypted, you can pass a `VERBOSE` environment variable:

**Omnibus Installation**

```shell
sudo gitlab-rake gitlab:doctor:secrets VERBOSE=1
```

**Source Installation**

```shell
bundle exec rake gitlab:doctor:secrets RAILS_ENV=production VERBOSE=1
```

**Example verbose output**

<!-- vale gitlab.SentenceSpacing = NO -->

```plaintext
I, [2020-06-11T17:17:54.951815 #27148]  INFO -- : Checking encrypted values in the database
I, [2020-06-11T17:18:12.677708 #27148]  INFO -- : - ApplicationSetting failures: 0
I, [2020-06-11T17:18:12.823692 #27148]  INFO -- : - User failures: 0
[...] other models possibly containing encrypted data
D, [2020-06-11T17:19:53.224344 #27351] DEBUG -- : > Something went wrong for Group[10].runners_token: Validation failed: Route can't be blank
I, [2020-06-11T17:19:53.225178 #27351]  INFO -- : - Group failures: 1
D, [2020-06-11T17:19:53.225267 #27351] DEBUG -- :   - Group[10]: runners_token
I, [2020-06-11T17:18:15.559162 #27148]  INFO -- : - Operations::FeatureFlagsClient failures: 0
I, [2020-06-11T17:18:15.575533 #27148]  INFO -- : - ScimOauthAccessToken failures: 0
I, [2020-06-11T17:18:15.575678 #27148]  INFO -- : Total: 1 row(s) affected
I, [2020-06-11T17:18:15.575711 #27148]  INFO -- : Done!
```

<!-- vale gitlab.SentenceSpacing = YES -->

## Troubleshooting

The following are solutions to problems you might discover using the Rake tasks documented
above.

### Dangling objects

The `gitlab-rake gitlab:git:fsck` task can find dangling objects such as:

```plaintext
dangling blob a12...
dangling commit b34...
dangling tag c56...
dangling tree d78...
```

To delete them, try [running housekeeping](../housekeeping.md).

If the issue persists, try triggering garbage collection via the
[Rails Console](../operations/rails_console.md#starting-a-rails-console-session):

```ruby
p = Project.find_by_path("project-name")
Repositories::HousekeepingService.new(p, :gc).execute
```

If the dangling objects are younger than the 2 weeks default grace period,
and you don't want to wait until they expire automatically, run:

```ruby
Repositories::HousekeepingService.new(p, :prune).execute
```

### Delete references to missing remote uploads

`gitlab-rake gitlab:uploads:check VERBOSE=1` detects remote objects that do not exist because they were
deleted externally but their references still exist in the GitLab database.

Example output with error message:

```shell
$ sudo gitlab-rake gitlab:uploads:check VERBOSE=1
Checking integrity of Uploads
- 100..434: Failures: 2
- Upload: 100: Remote object does not exist
- Upload: 101: Remote object does not exist
Done!
```

To delete these references to remote uploads that were deleted externally, open the [GitLab Rails Console](../operations/rails_console.md#starting-a-rails-console-session) and run:

```ruby
uploads_deleted=0
Upload.find_each do |upload|
  next if upload.retrieve_uploader.file.exists?
  uploads_deleted=uploads_deleted + 1
  p upload                            ### allow verification before destroy
  # p upload.destroy!                 ### uncomment to actually destroy
end
p "#{uploads_deleted} remote objects were destroyed."
```

### Delete references to missing artifacts

`gitlab-rake gitlab:artifacts:check VERBOSE=1` detects when artifacts (or `job.log` files):

- Are deleted outside of GitLab.
- Have references still in the GitLab database.

When this scenario is detected, the Rake task displays an error message. For example:

```shell
Checking integrity of Job artifacts
- 1..15: Failures: 2
  - Job artifact: 9: #<Errno::ENOENT: No such file or directory @ rb_sysopen - /var/opt/gitlab/gitlab-rails/shared/artifacts/4b/22/4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a/2022_06_30/8/9/job.log>
  - Job artifact: 15: Remote object does not exist
Done!

```

To delete these references to missing local and/or remote artifacts (`job.log` files):

1. Open the [GitLab Rails Console](../operations/rails_console.md#starting-a-rails-console-session).
1. Run the following Ruby code:

   ```ruby
   artifacts_deleted = 0
   ::Ci::JobArtifact.find_each do |artifact|                      ### Iterate artifacts
   #  next if artifact.file.filename != "job.log"                 ### Uncomment if only `job.log` files' references are to be processed
     next if artifact.file.file.exists?                           ### Skip if the file reference is valid
     artifacts_deleted += 1
     puts "#{artifact.id}  #{artifact.file.path} is missing."     ### Allow verification before destroy
   #  artifact.destroy!                                           ### Uncomment to actually destroy
   end
   puts "Count of identified/destroyed invalid references: #{artifacts_deleted}"
   ```

### Delete references to missing LFS objects

If `gitlab-rake gitlab:lfs:check VERBOSE=1` detects LFS objects that exist in the database
but not on disk, [follow the procedure in the LFS documentation](../lfs/index.md#missing-lfs-objects)
to remove the database entries.
