---
stage: Package
group: Package
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Debian API **(FREE SELF)**

> - Debian API [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/42670) in GitLab 13.5.
> - Debian group API [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/66188) in GitLab 14.2.
> - [Deployed behind a feature flag](../../user/feature_flags.md), disabled by default.

This is the API documentation for [Debian](../../user/packages/debian_repository/index.md).

WARNING:
This API is used by the Debian related package clients such as [dput](https://manpages.debian.org/stable/dput-ng/dput.1.en.html)
and [apt-get](https://manpages.debian.org/stable/apt/apt-get.8.en.html),
and is generally not meant for manual consumption. This API is under development and is not ready
for production use due to limited functionality.

For instructions on how to upload and install Debian packages from the GitLab
package registry, see the [Debian registry documentation](../../user/packages/debian_repository/index.md).

NOTE:
The Debian registry is not FIPS compliant and is disabled when [FIPS mode](../../development/fips_compliance.md) is enabled.
These endpoints will all return `404 Not Found`.

NOTE:
These endpoints do not adhere to the standard API authentication methods.
See the [Debian registry documentation](../../user/packages/debian_repository/index.md)
for details on which headers and token types are supported.

## Enable the Debian API

The Debian API is behind a feature flag that is disabled by default.
[GitLab administrators with access to the GitLab Rails console](../../administration/feature_flags.md)
can opt to enable it. To enable it, follow the instructions in
[Enable the Debian API](../../user/packages/debian_repository/index.md#enable-the-debian-api).

## Enable the Debian group API

The Debian group API is behind a feature flag that is disabled by default.
[GitLab administrators with access to the GitLab Rails console](../../administration/feature_flags.md)
can opt to enable it. To enable it, follow the instructions in
[Enable the Debian group API](../../user/packages/debian_repository/index.md#enable-the-debian-group-api).

## Upload a package file

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/62028) in GitLab 14.0.

Upload a Debian package file:

```plaintext
PUT projects/:id/packages/debian/:file_name
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`        | string | yes | The ID or full path of the project.  |
| `file_name` | string | yes | The name of the Debian package file. |

```shell
curl --request PUT \
     --upload-file path/to/mypkg.deb \
     --header "Private-Token: <personal_access_token>" \
     "https://gitlab.example.com/api/v4/projects/1/packages/debian/mypkg.deb"
```

## Download a package

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/64923) in GitLab 14.2.

Download a package file.

```plaintext
GET projects/:id/packages/debian/pool/:distribution/:letter/:package_name/:package_version/:file_name
```

| Attribute         | Type   | Required | Description |
| ----------------- | ------ | -------- | ----------- |
| `distribution`    | string | yes      | The codename or suite of the Debian distribution. |
| `letter`          | string | yes      | The Debian Classification (first-letter or lib-first-letter). |
| `package_name`    | string | yes      | The source package name. |
| `package_version` | string | yes      | The source package version. |
| `file_name`       | string | yes      | The filename. |

```shell
curl --header "Private-Token: <personal_access_token>" "https://gitlab.example.com/api/v4/projects/1/packages/pool/my-distro/a/my-pkg/1.0.0/example_1.0.0~alpha2_amd64.deb"
```

Write the output to a file:

```shell
curl --header "Private-Token: <personal_access_token>" \
     "https://gitlab.example.com/api/v4/projects/1/packages/pool/my-distro/a/my-pkg/1.0.0/example_1.0.0~alpha2_amd64.deb" \
     --remote-name
```

This writes the downloaded file using the remote filename in the current directory.

## Route prefix

The remaining endpoints described are two sets of identical routes that each make requests in
different scopes:

- Use the project-level prefix to make requests in a single project's scope.
- Use the group-level prefix to make requests in a single group's scope.

The examples in this document all use the project-level prefix.

### Project-level

```plaintext
 /projects/:id/packages/debian`
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | string | yes | The project ID or full project path. |

### Group-level

```plaintext
 /groups/:id/-/packages/debian`
```

| Attribute | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id`      | string | yes | The project ID or full group path. |

## Download a distribution Release file

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/64067) in GitLab 14.1.

Download a Debian distribution file.

```plaintext
GET <route-prefix>/dists/*distribution/Release
```

| Attribute         | Type   | Required | Description |
| ----------------- | ------ | -------- | ----------- |
| `distribution`    | string | yes      | The codename or suite of the Debian distribution. |

```shell
curl --header "Private-Token: <personal_access_token>" "https://gitlab.example.com/api/v4/projects/1/packages/debian/dists/my-distro/Release"
```

Write the output to a file:

```shell
curl --header "Private-Token: <personal_access_token>" \
     "https://gitlab.example.com/api/v4/projects/1/packages/debian/dists/my-distro/Release" \
     --remote-name
```

This writes the downloaded file using the remote filename in the current directory.

## Download a signed distribution Release file

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/64067) in GitLab 14.1.

Download a signed Debian distribution file.

```plaintext
GET <route-prefix>/dists/*distribution/InRelease
```

| Attribute         | Type   | Required | Description |
| ----------------- | ------ | -------- | ----------- |
| `distribution`    | string | yes      | The codename or suite of the Debian distribution. |

```shell
curl --header "Private-Token: <personal_access_token>" "https://gitlab.example.com/api/v4/projects/1/packages/debian/dists/my-distro/InRelease"
```

Write the output to a file:

```shell
curl --header "Private-Token: <personal_access_token>" \
     "https://gitlab.example.com/api/v4/projects/1/packages/debian/dists/my-distro/InRelease" \
     --remote-name
```

This writes the downloaded file using the remote filename in the current directory.

## Download a release file signature

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/64923) in GitLab 14.2.

Download a Debian release file signature.

```plaintext
GET <route-prefix>/dists/*distribution/Release.gpg
```

| Attribute         | Type   | Required | Description |
| ----------------- | ------ | -------- | ----------- |
| `distribution`    | string | yes      | The codename or suite of the Debian distribution. |

```shell
curl --header "Private-Token: <personal_access_token>" "https://gitlab.example.com/api/v4/projects/1/packages/debian/dists/my-distro/Release.gpg"
```

Write the output to a file:

```shell
curl --header "Private-Token: <personal_access_token>" \
     "https://gitlab.example.com/api/v4/projects/1/packages/debian/dists/my-distro/Release.gpg" \
     --remote-name
```

This writes the downloaded file using the remote filename in the current directory.

## Download a binary file's index

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/64923) in GitLab 14.2.

Download a distribution index.

```plaintext
GET <route-prefix>/dists/*distribution/:component/binary-:architecture/Packages
```

| Attribute         | Type   | Required | Description |
| ----------------- | ------ | -------- | ----------- |
| `distribution`    | string | yes      | The codename or suite of the Debian distribution. |
| `component`       | string | yes      | The distribution component name. |
| `architecture`    | string | yes      | The distribution architecture type. |

```shell
curl --header "Private-Token: <personal_access_token>" "https://gitlab.example.com/api/v4/projects/1/packages/debian/dists/my-distro/main/amd64/Packages"
```

Write the output to a file:

```shell
curl --header "Private-Token: <personal_access_token>" \
     "https://gitlab.example.com/api/v4/projects/1/packages/debian/dists/my-distro/main/amd64/Packages" \
     --remote-name
```

This writes the downloaded file using the remote filename in the current directory.
