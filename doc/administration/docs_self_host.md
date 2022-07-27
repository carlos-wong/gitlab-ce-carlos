---
stage: Systems
group: Distribution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Host the GitLab product documentation **(FREE SELF)**

If you are not able to access the GitLab product documentation at `docs.gitlab.com`,
you can host the documentation yourself instead.

Prerequisites:

- The version of the product documentation site must be the same as the version of
  your GitLab installation.

## Documentation self-hosting options

To host the GitLab product documentation, you can use:

- A Docker container
- GitLab Pages
- Your own web server

After you create a website by using one of these methods, you redirect the UI links
in the product to point to your website.

NOTE:
The website you create must be hosted under a subdirectory that matches
your installed GitLab version (for example, `14.5/`). The
[Docker images](https://gitlab.com/gitlab-org/gitlab-docs/container_registry/631635)
use this version by default.

The following examples use GitLab 14.5.

### Self-host the product documentation with Docker

The documentation website is served under the port `4000` inside the container.
In the following example, we expose this on the host under the same port.

Make sure you either:

- Allow port `4000` in your firewall.
- Use a different port. In following examples, replace the leftmost `4000` with the port different port.

To run the GitLab product documentation website in a Docker container:

1. On the server where you host GitLab, or on any other server that your GitLab instance
   can communicate with:

   - If you use plain Docker, run:

     ```shell
     docker run --detach --name gitlab_docs -it --rm -p 4000:4000 registry.gitlab.com/gitlab-org/gitlab-docs:14.5
     ```

   - If you host your GitLab instance using
     [Docker compose](../install/docker.md#install-gitlab-using-docker-compose),
     add the following to your existing `docker-compose.yaml`:

     ```yaml
     version: '3.6'
     services:
       gitlab_docs:
         image: registry.gitlab.com/gitlab-org/gitlab-docs:14.5
         hostname: 'https://docs.gitlab.example.com:4000'
         ports:
           - '4000:4000'
     ```

     Then, pull the changes:

     ```shell
     docker-compose up -d
     ```

1. Visit `http://0.0.0.0:4000` to view the documentation website and verify
   it works.
1. [Redirect the help links to the new Docs site](#redirect-the-help-links-to-the-new-docs-site).

### Self-host the product documentation with GitLab Pages

You can use GitLab Pages to host the GitLab product documentation.

Prerequisite:

- Ensure the Pages site URL does not use a subfolder. Because of how the docs
  site is pre-compiled, the CSS and JavaScript files are relative to the
  main domain or subdomain. For example, URLs like `https://example.com/docs/`
  are not supported.

To host the product documentation site with GitLab Pages:

1. [Create a blank project](../user/project/working_with_projects.md#create-a-blank-project).
1. Create a new or edit your existing `.gitlab-ci.yml` file, and add the following
   `pages` job, while ensuring the version is the same as your GitLab installation:

   ```yaml
   image: registry.gitlab.com/gitlab-org/gitlab-docs:14.5
   pages:
     script:
     - mkdir public
     - cp -a /usr/share/nginx/html/* public/
     artifacts:
       paths:
       - public
   ```

1. Optional. Set the GitLab Pages domain name. Depending on the type of the
   GitLab Pages website, you have two options:

   | Type of website         | [Default domain](../user/project/pages/getting_started_part_one.md#gitlab-pages-default-domain-names) | [Custom domain](../user/project/pages/custom_domains_ssl_tls_certification/index.md) |
   |-------------------------|----------------|---------------|
   | [Project website](../user/project/pages/getting_started_part_one.md#project-website-examples) | Not supported | Supported |
   | [User or group website](../user/project/pages/getting_started_part_one.md#user-and-group-website-examples) | Supported | Supported |

1. [Redirect the help links to the new Docs site](#redirect-the-help-links-to-the-new-docs-site).

### Self-host the product documentation on your own web server

Because the product documentation site is static, you can take the contents of
`/usr/share/nginx/html` from inside the container, and use your own web server to host
the docs wherever you want.

The `html` directory should be served as is and it has the following structure:

```plaintext
├── 14.5/
├── index.html
```

In this example:

- `14.5/` is the directory where the documentation is hosted.
- `index.html` is a simple HTML file that redirects to the directory containing the documentation. In this
   case, `14.5/`.

To extract the HTML files of the Docs site:

1. Create the container that holds the HTML files of the documentation website:

   ```shell
   docker create -it --name gitlab_docs registry.gitlab.com/gitlab-org/gitlab-docs:14.5
   ```

1. Copy the website under `/srv/gitlab/`:

   ```shell
   docker cp gitlab-docs:/usr/share/nginx/html /srv/gitlab/
   ```

   You end up with a `/srv/gitlab/html/` directory that holds the documentation website.

1. Remove the container:

   ```shell
   docker rm -f gitlab_docs
   ```

1. Point your web server to serve the contents of `/srv/gitlab/html/`.
1. [Redirect the help links to the new Docs site](#redirect-the-help-links-to-the-new-docs-site).

## Redirect the `/help` links to the new Docs site

After your local product documentation site is running,
[redirect the help links](../user/admin_area/settings/help_page.md#redirect-help-pages)
in the GitLab application to your local site, by using the fully qualified domain
name as the docs URL. For example, if you used the
[Docker method](#self-host-the-product-documentation-with-docker), enter `http://0.0.0.0:4000`.

You don't need to append the version. GitLab detects it and appends it to
documentation URL requests as needed. For example, if your GitLab version is
14.5:

- The GitLab Docs URL becomes `http://0.0.0.0:4000/14.5/`.
- The link in GitLab displays as `<instance_url>/help/user/admin_area/settings/help_page#destination-requirements`.
- When you select the link, you are redirected to
`http://0.0.0.0:4000/14.5/ee/user/admin_area/settings/help_page/#destination-requirements`.

To test the setting, select a **Learn more** link within the GitLab application.

## Upgrade the product documentation to a later version

Upgrading the Docs site to a later version requires downloading the newer Docker image tag.

### Upgrade using Docker

To upgrade to a later version [using Docker](#self-host-the-product-documentation-with-docker):

- If you use plain Docker:

  1. Stop the running container:

     ```shell
     sudo docker stop gitlab_docs
     ```

  1. Remove the existing container:

     ```shell
     sudo docker rm gitlab_docs
     ```

  1. Pull the new image. For example, 14.6:

     ```shell
     docker run --detach --name gitlab_docs -it --rm -p 4000:4000 registry.gitlab.com/gitlab-org/gitlab-docs:14.6
     ```

- If you use Docker compose:

  1. Change the version in `docker-compose.yaml`, for example 14.6:

     ```yaml
     version: '3.6'
     services:
       gitlab_docs:
         image: registry.gitlab.com/gitlab-org/gitlab-docs:14.6
         hostname: 'https://docs.gitlab.example.com:4000'
         ports:
           - '4000:4000'
     ```

  1. Pull the changes:

     ```shell
     docker-compose up -d
     ```

### Upgrade using GitLab Pages

To upgrade to a later version [using GitLab Pages](#self-host-the-product-documentation-with-gitlab-pages):

1. Edit your existing `.gitlab-ci.yml` file, and replace the `image`'s version number:

   ```yaml
   image: registry.gitlab.com/gitlab-org/gitlab-docs:14.5
   ```

1. Commit the changes, push, and GitLab Pages pulls the new Docs site version.

### Upgrade using your own web-server

To upgrade to a later version [using your own web-server](#self-host-the-product-documentation-on-your-own-web-server):

1. Copy the HTML files of the Docs site:

   ```shell
   docker create -it --name gitlab_docs registry.gitlab.com/gitlab-org/gitlab-docs:14.6
   docker cp gitlab_docs:/usr/share/nginx/html /srv/gitlab/
   docker rm -f gitlab_docs
   ```

1. Optional. Remove the old site:

   ```shell
   rm -r /srv/gitlab/html/14.5/
   ```

## Known issues

If you self-host the product documentation:

- The version dropdown displays additional versions that don't exist. Selecting
  these versions displays a `404 Not Found` page.
- The search displays results from `docs.gitlab.com` and not the local site.
- By default, the landing page redirects to the
  respective version (for example, `/14.5/`). This causes the landing page <https://docs.gitlab.com> to not be displayed.
