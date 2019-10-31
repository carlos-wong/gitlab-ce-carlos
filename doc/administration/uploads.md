# Uploads administration

Uploads represent all user data that may be sent to GitLab as a single file. As an example, avatars and notes' attachments are uploads. Uploads are integral to GitLab functionality, and therefore cannot be disabled.

## Using local storage

NOTE: **Note:**
This is the default configuration

To change the location where the uploads are stored locally, follow the steps
below.

**In Omnibus installations:**

NOTE: **Note:**
For historical reasons, uploads are stored into a base directory, which by default is `uploads/-/system`. It is strongly discouraged to change this configuration option on an existing GitLab installation.

_The uploads are stored by default in `/var/opt/gitlab/gitlab-rails/uploads`._

1. To change the storage path for example to `/mnt/storage/uploads`, edit
   `/etc/gitlab/gitlab.rb` and add the following line:

   ```ruby
   gitlab_rails['uploads_storage_path'] = "/mnt/storage/"
   gitlab_rails['uploads_base_dir'] = "uploads"
   ```

1. Save the file and [reconfigure GitLab][] for the changes to take effect.

**In installations from source:**

_The uploads are stored by default in
`/home/git/gitlab/public/uploads/-/system`._

1. To change the storage path for example to `/mnt/storage/uploads`, edit
   `/home/git/gitlab/config/gitlab.yml` and add or amend the following lines:

   ```yaml
   uploads:
     storage_path: /mnt/storage
     base_dir: uploads
   ```

1. Save the file and [restart GitLab][] for the changes to take effect.

## Using object storage **(CORE ONLY)**

> **Notes:**
>
> - [Introduced][ee-3867] in [GitLab Premium][eep] 10.5.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/17358) in [GitLab Core](https://about.gitlab.com/pricing/) 10.7.
> - Since version 11.1, we support direct_upload to S3.

If you don't want to use the local disk where GitLab is installed to store the
uploads, you can use an object storage provider like AWS S3 instead.
This configuration relies on valid AWS credentials to be configured already.

## Object Storage Settings

For source installations the following settings are nested under `uploads:` and then `object_store:`. On Omnibus GitLab installs they are prefixed by `uploads_object_store_`.

| Setting | Description | Default |
|---------|-------------|---------|
| `enabled` | Enable/disable object storage | `false` |
| `remote_directory` | The bucket name where Uploads will be stored| |
| `direct_upload` | Set to true to enable direct upload of Uploads without the need of local shared storage. Option may be removed once we decide to support only single storage for all files. | `false` |
| `background_upload` | Set to false to disable automatic upload. Option may be removed once upload is direct to S3 | `true` |
| `proxy_download` | Set to true to enable proxying all files served. Option allows to reduce egress traffic as this allows clients to download directly from remote storage instead of proxying all data | `false` |
| `connection` | Various connection options described below | |

### S3 compatible connection settings

The connection settings match those provided by [Fog](https://github.com/fog), and are as follows:

| Setting | Description | Default |
|---------|-------------|---------|
| `provider` | Always `AWS` for compatible hosts | AWS |
| `aws_access_key_id` | AWS credentials, or compatible | |
| `aws_secret_access_key` | AWS credentials, or compatible | |
| `aws_signature_version` | AWS signature version to use. 2 or 4 are valid options. Digital Ocean Spaces and other providers may need 2. | 4 |
| `enable_signature_v4_streaming` | Set to true to enable HTTP chunked transfers with [AWS v4 signatures](https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-streaming.html). Oracle Cloud S3 needs this to be false | true |
| `region` | AWS region | us-east-1 |
| `host` | S3 compatible host for when not using AWS, e.g. `localhost` or `storage.example.com` | s3.amazonaws.com |
| `endpoint` | Can be used when configuring an S3 compatible service such as [MinIO](https://min.io), by entering a URL such as `http://127.0.0.1:9000` | (optional) |
| `path_style` | Set to true to use `host/bucket_name/object` style paths instead of `bucket_name.host/object`. Leave as false for AWS S3 | false |
| `use_iam_profile` | Set to true to use IAM profile instead of access keys | false

**In Omnibus installations:**

_The uploads are stored by default in
`/var/opt/gitlab/gitlab-rails/public/uploads/-/system`._

1. Edit `/etc/gitlab/gitlab.rb` and add the following lines by replacing with
   the values you want:

   ```ruby
   gitlab_rails['uploads_object_store_enabled'] = true
   gitlab_rails['uploads_object_store_remote_directory'] = "uploads"
   gitlab_rails['uploads_object_store_connection'] = {
     'provider' => 'AWS',
     'region' => 'eu-central-1',
     'aws_access_key_id' => 'AWS_ACCESS_KEY_ID',
     'aws_secret_access_key' => 'AWS_SECRET_ACCESS_KEY'
   }
   ```

   NOTE: **Note:**
   If you are using AWS IAM profiles, be sure to omit the AWS access key and secret access key/value pairs.

   ```ruby
   gitlab_rails['uploads_object_store_connection'] = {
     'provider' => 'AWS',
     'region' => 'eu-central-1',
     'use_iam_profile' => true
   }
   ```

1. Save the file and [reconfigure GitLab][] for the changes to take effect.
1. Migrate any existing local uploads to the object storage using [`gitlab:uploads:migrate` rake task](raketasks/uploads/migrate.md).

**In installations from source:**

_The uploads are stored by default in
`/home/git/gitlab/public/uploads/-/system`._

1. Edit `/home/git/gitlab/config/gitlab.yml` and add or amend the following
   lines:

   ```yaml
   uploads:
     object_store:
       enabled: true
       remote_directory: "uploads" # The bucket name
       connection:
         provider: AWS # Only AWS supported at the moment
         aws_access_key_id: AWS_ACESS_KEY_ID
         aws_secret_access_key: AWS_SECRET_ACCESS_KEY
         region: eu-central-1
   ```

1. Save the file and [restart GitLab][] for the changes to take effect.
1. Migrate any existing local uploads to the object storage using [`gitlab:uploads:migrate` rake task](raketasks/uploads/migrate.md).

### Oracle Cloud S3 connection settings

Note that Oracle Cloud S3 must be sure to use the following settings:

| Setting | Value |
|---------|-------|
| `enable_signature_v4_streaming` | false |
| `path_style` | true |

If `enable_signature_v4_streaming` is set to `true`, you may see the
following error:

```
STREAMING-AWS4-HMAC-SHA256-PAYLOAD is not supported
```

### OpenStack compatible connection settings

The connection settings match those provided by [Fog](https://github.com/fog), and are as follows:

| Setting | Description | Default |
|---------|-------------|---------|
| `provider` | Always `OpenStack` for compatible hosts | OpenStack |
| `openstack_username` | OpenStack username | |
| `openstack_api_key` | OpenStack API key  | |
| `openstack_temp_url_key` | OpenStack key for generating temporary urls | |
| `openstack_auth_url` | OpenStack authentication endpont | |
| `openstack_region` | OpenStack region | |
| `openstack_tenant` | OpenStack tenant ID |

**In Omnibus installations:**

_The uploads are stored by default in
`/var/opt/gitlab/gitlab-rails/public/uploads/-/system`._

1. Edit `/etc/gitlab/gitlab.rb` and add the following lines by replacing with
   the values you want:

   ```ruby
   gitlab_rails['uploads_object_store_remote_directory'] = "OPENSTACK_OBJECT_CONTAINER_NAME"
   gitlab_rails['uploads_object_store_connection'] = {
    'provider' => 'OpenStack',
    'openstack_username' => 'OPENSTACK_USERNAME',
    'openstack_api_key' => 'OPENSTACK_PASSWORD',
    'openstack_temp_url_key' => 'OPENSTACK_TEMP_URL_KEY',
    'openstack_auth_url' => 'https://auth.cloud.ovh.net/v2.0/',
    'openstack_region' => 'DE1',
    'openstack_tenant' => 'TENANT_ID',
   }
   ```

1. Save the file and [reconfigure GitLab][] for the changes to take effect.
1. Migrate any existing local uploads to the object storage using [`gitlab:uploads:migrate` rake task](raketasks/uploads/migrate.md).

---

**In installations from source:**

_The uploads are stored by default in
`/home/git/gitlab/public/uploads/-/system`._

1. Edit `/home/git/gitlab/config/gitlab.yml` and add or amend the following
   lines:

   ```yaml
   uploads:
     object_store:
       enabled: true
       direct_upload: false
       background_upload: true
       proxy_download: false
       remote_directory: OPENSTACK_OBJECT_CONTAINER_NAME
       connection:
         provider: OpenStack
         openstack_username: OPENSTACK_USERNAME
         openstack_api_key: OPENSTACK_PASSWORD
         openstack_temp_url_key: OPENSTACK_TEMP_URL_KEY
         openstack_auth_url: 'https://auth.cloud.ovh.net/v2.0/'
         openstack_region: DE1
         openstack_tenant: 'TENANT_ID'
   ```

1. Save the file and [reconfigure GitLab][] for the changes to take effect.
1. Migrate any existing local uploads to the object storage using [`gitlab:uploads:migrate` rake task](raketasks/uploads/migrate.md).

[reconfigure gitlab]: restart_gitlab.md#omnibus-gitlab-reconfigure "How to reconfigure Omnibus GitLab"
[restart gitlab]: restart_gitlab.md#installations-from-source "How to restart GitLab"
[eep]: https://about.gitlab.com/pricing/ "GitLab Premium"
[ee-3867]: https://gitlab.com/gitlab-org/gitlab/merge_requests/3867
