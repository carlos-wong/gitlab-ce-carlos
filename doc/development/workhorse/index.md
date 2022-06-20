---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# GitLab Workhorse

GitLab Workhorse is a smart reverse proxy for GitLab. It handles
"large" HTTP requests such as file downloads, file uploads, Git
push/pull and Git archive downloads.

Workhorse itself is not a feature, but there are [several features in
GitLab](gitlab_features.md) that would not work efficiently without Workhorse.

The canonical source for Workhorse is
[`gitlab-org/gitlab/workhorse`](https://gitlab.com/gitlab-org/gitlab/tree/master/workhorse).
Prior to [epic #4826](https://gitlab.com/groups/gitlab-org/-/epics/4826), it was
[`gitlab-org/gitlab-workhorse`](https://gitlab.com/gitlab-org/gitlab-workhorse/tree/master),
but that repository is no longer used for development.

## Install Workhorse

To install GitLab Workhorse you need [Go 1.15 or newer](https://golang.org/dl) and
[GNU Make](https://www.gnu.org/software/make/).

To install into `/usr/local/bin` run `make install`.

```plaintext
make install
```

To install into `/foo/bin` set the PREFIX variable.

```plaintext
make install PREFIX=/foo
```

On some operating systems, such as FreeBSD, you may have to use
`gmake` instead of `make`.

*NOTE*: Some features depends on build tags, make sure to check
[Workhorse configuration](configuration.md) to enable them.

### Run time dependencies

Workhorse uses [Exiftool](https://www.sno.phy.queensu.ca/~phil/exiftool/) for
removing EXIF data (which may contain sensitive information) from uploaded
images. If you installed GitLab:

- Using the Omnibus package, you're all set.
  *NOTE* that if you are using CentOS Minimal, you may need to install `perl`
  package: `yum install perl`
- From source, make sure `exiftool` is installed:

  ```shell
  # Debian/Ubuntu
  sudo apt-get install libimage-exiftool-perl

  # RHEL/CentOS
  sudo yum install perl-Image-ExifTool
  ```

## Testing your code

Run the tests with:

```plaintext
make clean test
```

Each feature in GitLab Workhorse should have an integration test that
verifies that the feature 'kicks in' on the right requests and leaves
other requests unaffected. It is better to also have package-level tests
for specific behavior but the high-level integration tests should have
the first priority during development.

It is OK if a feature is only covered by integration tests.

<!--
## License

This code is distributed under the MIT license, see the [LICENSE](LICENSE) file.
-->
