---
stage: Package
group: Package
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Dependency Proxy **(FREE)**

> - [Moved](https://gitlab.com/gitlab-org/gitlab/-/issues/273655) from GitLab Premium to GitLab Free in 13.6.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/11582) support for private groups in GitLab 13.7.
> - Anonymous access to images in public groups is no longer available starting in GitLab 13.7.
> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/290944) support for pull-by-digest and Docker version 20.x in GitLab 13.10.

The GitLab Dependency Proxy is a local proxy you can use for your frequently-accessed
upstream images.

In the case of CI/CD, the Dependency Proxy receives a request and returns the
upstream image from a registry, acting as a pull-through cache.

## Prerequisites

To use the Dependency Proxy, it must be enabled for the GitLab instance. It's enabled by default,
but [administrators can turn it off](../../../administration/packages/dependency_proxy.md).

### Supported images and packages

The following images and packages are supported.

| Image/Package    | GitLab version |
| ---------------- | -------------- |
| Docker           | 11.11+         |

For a list of planned additions, view the
[direction page](https://about.gitlab.com/direction/package/#dependency-proxy).

## Enable or turn off the Dependency Proxy for a group

To enable or turn off the Dependency Proxy for a group:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Settings > Packages & Registries**.
1. Expand the **Dependency Proxy** section.
1. To enable the proxy, turn on **Enable Proxy**. To turn it off, turn the toggle off.

This setting only affects the Dependency Proxy for a group. Only an administrator can
[turn the Dependency Proxy on or off](../../../administration/packages/dependency_proxy.md)
for the entire GitLab instance.

## View the Dependency Proxy

To view the Dependency Proxy:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Packages & Registries > Dependency Proxy**.

The Dependency Proxy is not available for projects.

## Use the Dependency Proxy for Docker images

You can use GitLab as a source for your Docker images.

Prerequisites:

- Your images must be stored on [Docker Hub](https://hub.docker.com/).

### Authenticate with the Dependency Proxy

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/11582) in GitLab 13.7 [with a flag](../../../administration/feature_flags.md) named `dependency_proxy_for_private_groups`. Enabled by default.
> - [Removed](https://gitlab.com/gitlab-org/gitlab/-/issues/276777) the feature flag `dependency_proxy_for_private_groups` in GitLab 15.0.

Because the Dependency Proxy is storing Docker images in a space associated with your group,
you must authenticate against the Dependency Proxy.

Follow the [instructions for using images from a private registry](../../../ci/docker/using_docker_images.md#access-an-image-from-a-private-container-registry),
but instead of using `registry.example.com:5000`, use your GitLab domain with no port `gitlab.example.com`.

For example, to manually log in:

```shell
docker login gitlab.example.com --username my_username --password my_password
```

You can authenticate using:

- Your GitLab username and password.
- A [personal access token](../../../user/profile/personal_access_tokens.md) with the scope set to `read_registry` and `write_registry`.
- A [group deploy token](../../../user/project/deploy_tokens/index.md#group-deploy-token) with the scope set to `read_registry` and `write_registry`.

Users accessing the Dependency Proxy with a personal access token or username and password must
have at least the Guest role for the group they pull images from.

The Dependency Proxy follows the [Docker v2 token authentication flow](https://docs.docker.com/registry/spec/auth/token/),
issuing the client a JWT to use for the pull requests. The JWT issued as a result of authenticating
expires after some time. When the token expires, most Docker clients store your credentials and
automatically request a new token without further action.

The token expiration time is a [configurable setting](../../../administration/packages/dependency_proxy.md#changing-the-jwt-expiration).
On GitLab.com, the expiration time is 15 minutes.

#### SAML SSO

When [SSO enforcement](../../group/saml_sso/index.md#sso-enforcement)
is enabled, users must be signed-in through SSO before they can pull images through the Dependency
Proxy.

#### Authenticate within CI/CD

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/280582) in GitLab 13.7.
> - Automatic runner authentication, when using the Dependency Proxy to pull the image for the job, was [added](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/27302) in GitLab 13.9.
> - The prefix for group names containing uppercase letters was [fixed](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/54559) in GitLab 13.10.

Runners log in to the Dependency Proxy automatically. To pull through
the Dependency Proxy, use one of the [predefined variables](../../../ci/variables/predefined_variables.md):

- `CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX` pulls through the top-level group.
- `CI_DEPENDENCY_PROXY_DIRECT_GROUP_IMAGE_PREFIX` pulls through the subgroup, or direct group the
  project exists in.

Example pulling the latest alpine image:

```yaml
# .gitlab-ci.yml
image: ${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}/alpine:latest
```

There are other additional predefined CI/CD variables you can also use:

- `CI_DEPENDENCY_PROXY_USER`: A CI/CD user for logging in to the Dependency Proxy.
- `CI_DEPENDENCY_PROXY_PASSWORD`: A CI/CD password for logging in to the Dependency Proxy.
- `CI_DEPENDENCY_PROXY_SERVER`: The server for logging in to the Dependency Proxy.
- `CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX`: the image prefix for pulling images through the
  dependency proxy from the top-level group.
- `CI_DEPENDENCY_PROXY_DIRECT_GROUP_IMAGE_PREFIX`: the image prefix for pulling images through the
  dependency proxy from the direct group or subgroup that the project belongs to.

`CI_DEPENDENCY_PROXY_SERVER`, `CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX`, and
`CI_DEPENDENCY_PROXY_DIRECT_GROUP_IMAGE_PREFIX`
include the server port. If you explicitly include the Dependency Proxy
path, the port must be included, unless you have logged into the Dependency
Proxy manually without including the port:

```shell
docker pull gitlab.example.com:443/my-group/dependency_proxy/containers/alpine:latest
```

Example when using the Dependency Proxy to build an image:

```plaintext
# Dockerfile
FROM gitlab.example.com:443/my-group/dependency_proxy/containers/alpine:latest
```

```yaml
# .gitlab-ci.yml
image: docker:20.10.16

variables:
  DOCKER_HOST: tcp://docker:2375
  DOCKER_TLS_CERTDIR: ""

services:
  - docker:20.10.16-dind

build:
  image: docker:20.10.16
  before_script:
    - docker login -u $CI_DEPENDENCY_PROXY_USER -p $CI_DEPENDENCY_PROXY_PASSWORD $CI_DEPENDENCY_PROXY_SERVER
  script:
    -  docker build -t test .
```

You can also use [custom CI/CD variables](../../../ci/variables/index.md#custom-cicd-variables) to store and access your personal access token or deploy token.

### Store a Docker image in Dependency Proxy cache

To store a Docker image in Dependency Proxy storage:

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Packages & Registries > Dependency Proxy**.
1. Copy the **Dependency Proxy image prefix**.
1. Use one of these commands. In these examples, the image is `alpine:latest`.
1. You can also pull images by digest to specify exactly which version of an image to pull.

   - Pull an image by tag by adding the image to your [`.gitlab-ci.yml`](../../../ci/yaml/index.md#image) file:

     ```shell
     image: gitlab.example.com/groupname/dependency_proxy/containers/alpine:latest
     ```

   - Pull an image by digest by adding the image to your [`.gitlab-ci.yml`](../../../ci/yaml/index.md#image) file:

     ```shell
     image: ${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}/alpine@sha256:c9375e662992791e3f39e919b26f510e5254b42792519c180aad254e6b38f4dc
     ```

   - Manually pull the Docker image:

     ```shell
     docker pull gitlab.example.com/groupname/dependency_proxy/containers/alpine:latest
     ```

   - Add the URL to a `Dockerfile`:

     ```shell
     FROM gitlab.example.com/groupname/dependency_proxy/containers/alpine:latest
     ```

GitLab pulls the Docker image from Docker Hub and caches the blobs
on the GitLab server. The next time you pull the same image, GitLab gets the latest
information about the image from Docker Hub, but serves the existing blobs
from the GitLab server.

## Reduce storage usage

For information on reducing your storage use on the Dependency Proxy, see
[Reduce Dependency Proxy storage use](reduce_dependency_proxy_storage.md).

## Docker Hub rate limits and the Dependency Proxy

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/241639) in GitLab 13.7.

<i class="fa fa-youtube-play youtube" aria-hidden="true"></i>
Watch how to [use the Dependency Proxy to help avoid Docker Hub rate limits](https://youtu.be/Nc4nUo7Pq08).

In November 2020, Docker introduced
[rate limits on pull requests from Docker Hub](https://docs.docker.com/docker-hub/download-rate-limit/).
If your GitLab [CI/CD configuration](../../../ci/index.md) uses
an image from Docker Hub, each time a job runs, it may count as a pull request.
To help get around this limit, you can pull your image from the Dependency Proxy cache instead.

When you pull an image (by using a command like `docker pull` or, in a `.gitlab-ci.yml`
file, `image: foo:latest`), the Docker client makes a collection of requests:

1. The image manifest is requested. The manifest contains information about
   how to build the image.
1. Using the manifest, the Docker client requests a collection of layers, also
   known as blobs, one at a time.

The Docker Hub rate limit is based on the number of GET requests for the manifest. The Dependency Proxy
caches both the manifest and blobs for a given image, so when you request it again,
Docker Hub does not have to be contacted.

### How does GitLab know if a cached tagged image is stale?

If you are using an image tag like `alpine:latest`, the image changes
over time. Each time it changes, the manifest contains different information about which
blobs to request. The Dependency Proxy does not pull a new image each time the
manifest changes; it checks only when the manifest becomes stale.

Docker does not count HEAD requests for the image manifest towards the rate limit.
You can make a HEAD request for `alpine:latest`, view the digest (checksum)
value returned in the header, and determine if a manifest has changed.

The Dependency Proxy starts all requests with a HEAD request. If the manifest
has become stale, only then is a new image pulled.

For example, if your pipeline pulls `node:latest` every five
minutes, the Dependency Proxy caches the entire image and only updates it if
`node:latest` changes. So instead of having 360 requests for the image in six hours
(which exceeds the Docker Hub rate limit), you only have one pull request, unless
the manifest changed during that time.

### Check your Docker Hub rate limit

If you are curious about how many requests to Docker Hub you have made and how
many remain, you can run these commands from your runner, or even in a CI/CD
script:

```shell
# Note, you must have jq installed to run this command
TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq --raw-output .token) && curl --head --header "Authorization: Bearer $TOKEN" "https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest" 2>&1 | grep --ignore-case RateLimit
...
```

The output is something like:

```shell
RateLimit-Limit: 100;w=21600
RateLimit-Remaining: 98;w=21600
```

This example shows the total limit of 100 pulls in six hours, with 98 pulls remaining.

#### Check the rate limit in a CI/CD job

This example shows a GitLab CI/CD job that uses an image with `jq` and `curl` installed:

```yaml
hub_docker_quota_check:
    stage: build
    image: alpine:latest
    tags:
        - <optional_runner_tag>
    before_script: apk add curl jq
    script:
      - |
        TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq --raw-output .token) && curl --head --header "Authorization: Bearer $TOKEN" "https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest" 2>&1
```

## Troubleshooting

### Dependency Proxy Connection Failure

If a service alias is not set the `docker:20.10.16` image is unable to find the
`dind` service, and an error like the following is thrown:

```plaintext
error during connect: Get http://docker:2376/v1.39/info: dial tcp: lookup docker on 192.168.0.1:53: no such host
```

This can be resolved by setting a service alias for the Docker service:

```yaml
services:
    - name: ${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}/docker:18.09.7-dind
      alias: docker
```

### "Not Found" error when pulling image

Docker errors similar to the following may indicate that the user running the build job doesn't have
a minimum of the Guest role in the specified Dependency Proxy group:

```plaintext
ERROR: gitlab.example.com:443/group1/dependency_proxy/containers/alpine:latest: not found

failed to solve with frontend dockerfile.v0: failed to create LLB definition: gitlab.example.com:443/group1/dependency_proxy/containers/alpine:latest: not found
```
