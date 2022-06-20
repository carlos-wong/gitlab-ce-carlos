---
stage: Package
group: Package
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Composer packages in the Package Registry **(FREE)**

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/15886) in GitLab 13.2.
> - [Moved](https://gitlab.com/gitlab-org/gitlab/-/issues/221259) from GitLab Premium to GitLab Free in 13.3.
> - Support for Composer 2.0 [added](https://gitlab.com/gitlab-org/gitlab/-/issues/259840) in GitLab 13.10.
> - Deploy token support [added](https://gitlab.com/gitlab-org/gitlab/-/issues/240897) in GitLab 14.6.

WARNING:
The Composer package registry for GitLab is under development and isn't ready for production use due to
limited functionality. This [epic](https://gitlab.com/groups/gitlab-org/-/epics/6817) details the remaining
work and timelines to make it production ready.

Publish [Composer](https://getcomposer.org/) packages in your project's Package Registry.
Then, install the packages whenever you need to use them as a dependency.

For documentation of the specific API endpoints that the Composer
client uses, see the [Composer API documentation](../../../api/packages/composer.md).

Composer v2.0 is recommended. Composer v1.0 is supported, but it has lower performance when working
in groups with very large numbers of packages.

## Create a Composer package

If you do not have a Composer package, create one and check it in to
a repository. This example shows a GitLab repository, but the repository
can be any public or private repository.

WARNING:
If you are using a GitLab repository, the project must have been created from
a group's namespace, rather than a user's namespace. Composer packages
[can't be published to projects created from a user's namespace](https://gitlab.com/gitlab-org/gitlab/-/issues/235467).

1. Create a directory called `my-composer-package` and change to that directory:

   ```shell
   mkdir my-composer-package && cd my-composer-package
   ```

1. Run [`composer init`](https://getcomposer.org/doc/03-cli.md#init) and answer the prompts.

   For namespace, enter your unique [namespace](../../../user/group/index.md#namespaces), like your GitLab username or group name.

   A file called `composer.json` is created:

   ```json
   {
     "name": "<namespace>/composer-test",
     "description": "Library XY",
     "type": "library",
     "license": "GPL-3.0-only",
     "authors": [
        {
            "name": "John Doe",
            "email": "john@example.com"
        }
     ],
     "require": {}
   }
   ```

1. Run Git commands to tag the changes and push them to your repository:

   ```shell
   git init
   git add composer.json
   git commit -m 'Composer package test'
   git tag v1.0.0
   git remote add origin git@gitlab.example.com:<namespace>/<project-name>.git
   git push --set-upstream origin main
   git push origin v1.0.0
   ```

The package is now in your GitLab Package Registry.

## Publish a Composer package by using the API

Publish a Composer package to the Package Registry,
so that anyone who can access the project can use the package as a dependency.

Prerequisites:

- A package in a GitLab repository. Composer packages should be versioned based on
  the [Composer specification](https://getcomposer.org/doc/04-schema.md#version).
  If the version is not valid, for example, it has three dots (`1.0.0.0`), an
  error (`Validation failed: Version is invalid`) occurs when you publish.
- A valid `composer.json` file.
- The Packages feature is enabled in a GitLab repository.
- The project ID, which is on the project's home page.
- One of the following token types:
  - A [personal access token](../../../user/profile/personal_access_tokens.md) with the scope set to `api`.
  - A [deploy token](../../project/deploy_tokens/index.md)
    with the scope set to `write_package_registry`.

To publish the package with a personal access token:

- Send a `POST` request to the [Packages API](../../../api/packages.md).

  For example, you can use `curl`:

  ```shell
  curl --data tag=<tag> "https://__token__:<personal-access-token>@gitlab.example.com/api/v4/projects/<project_id>/packages/composer"
  ```

  - `<personal-access-token>` is your personal access token.
  - `<project_id>` is your project ID.
  - `<tag>` is the Git tag name of the version you want to publish.
     To publish a branch, use `branch=<branch>` instead of `tag=<tag>`.

To publish the package with a deploy token:

- Send a `POST` request to the [Packages API](../../../api/packages.md).

  For example, you can use `curl`:

  ```shell
  curl --data tag=<tag> --header "Deploy-Token: <deploy-token>" "https://gitlab.example.com/api/v4/projects/<project_id>/packages/composer"
  ```

  - `<deploy-token>` is your deploy token
  - `<project_id>` is your project ID.
  - `<tag>` is the Git tag name of the version you want to publish.
     To publish a branch, use `branch=<branch>` instead of `tag=<tag>`.

You can view the published package by going to **Packages & Registries > Package Registry** and
selecting the **Composer** tab.

## Publish a Composer package by using CI/CD

You can publish a Composer package to the Package Registry as part of your CI/CD process.

1. Specify a `CI_JOB_TOKEN` in your `.gitlab-ci.yml` file:

   ```yaml
   stages:
     - deploy

   deploy:
     stage: deploy
     script:
       - apk add curl
       - 'curl --header "Job-Token: $CI_JOB_TOKEN" --data tag=<tag> "${CI_API_V4_URL}/projects/$CI_PROJECT_ID/packages/composer"'
   ```

1. Run the pipeline.

To view the published package, go to **Packages & Registries > Package Registry** and select the **Composer** tab.

### Use a CI/CD template

A more detailed Composer CI/CD file is also available as a `.gitlab-ci.yml` template:

1. On the left sidebar, select **Project information**.
1. Above the file list, select **Set up CI/CD**. If this button is not available, select **CI/CD Configuration** and then **Edit**.
1. From the **Apply a template** list, select **Composer**.

WARNING:
Do not save unless you want to overwrite the existing CI/CD file.

## Publishing packages with the same name or version

When you publish:

- The same package with different data, it overwrites the existing package.
- The same package with the same data, a `400 Bad request` error occurs.

## Install a Composer package

> Authorization to [download a package archive](../../../api/packages/composer.md#download-a-package-archive) was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/331601) in GitLab 14.10.

Install a package from the Package Registry so you can use it as a dependency.

Prerequisites:

- A package in the Package Registry.
- The group ID, which is on the group's home page.
- One of the following token types:
  - A [personal access token](../../../user/profile/personal_access_tokens.md)
    with the scope set to, at minimum, `api`.
  - A [deploy token](../../project/deploy_tokens/index.md)
    with the scope set to `read_package_registry`, `write_package_registry`, or both.

To install a package:

1. Add the Package Registry URL to your project's `composer.json` file, along with the package name and version you want to install:

   - Connect to the Package Registry for your group:

   ```shell
   composer config repositories.<group_id> composer https://gitlab.example.com/api/v4/group/<group_id>/-/packages/composer/
   ```

   - Set the required package version:

   ```shell
   composer require <package_name>:<version>
   ```

   Result in the `composer.json` file:

   ```json
   {
     ...
     "repositories": {
       "<group_id>": {
         "type": "composer",
         "url": "https://gitlab.example.com/api/v4/group/<group_id>/-/packages/composer/"
       },
       ...
     },
     "require": {
       ...
       "<package_name>": "<version>"
     },
     ...
   }
   ```

   You can unset this with the command:

   ```shell
   composer config --unset repositories.<group_id>
   ```

   - `<group_id>` is the group ID.
   - `<package_name>` is the package name defined in your package's `composer.json` file.
   - `<version>` is the package version.

1. Create an `auth.json` file with your GitLab credentials:

   Using a personal access token:

   ```shell
   composer config gitlab-token.<DOMAIN-NAME> <personal_access_token>
   ```

   Result in the `auth.json` file:

   ```json
   {
     ...
     "gitlab-token": {
       "<DOMAIN-NAME>": "<personal_access_token>",
       ...
     }
   }
   ```

   Using a deploy token:

   ```shell
   composer config gitlab-token.<DOMAIN-NAME> <deploy_token_username> <deploy_token>
   ```

   Result in the `auth.json` file:

   ```json
   {
     ...
     "gitlab-token": {
       "<DOMAIN-NAME>": {
         "username": "<deploy_token_username>",
         "token": "<deploy_token>",
       ...
     }
   }
   ```

   You can unset this with the command:

   ```shell
   composer config --unset --auth gitlab-token.<DOMAIN-NAME>
   ```

   - `<DOMAIN-NAME>` is the GitLab instance URL `gitlab.com` or `gitlab.example.com`.
   - `<personal_access_token>` with the scope set to `api`, or `<deploy_token>` with the scope set
     to `read_package_registry` and/or `write_package_registry`.

1. If you are on a GitLab self-managed instance, add `gitlab-domains` to `composer.json`.

   ```shell
   composer config gitlab-domains gitlab01.example.com gitlab02.example.com
   ```

   Result in the `composer.json` file:

   ```json
   {
     ...
     "repositories": [
       { "type": "composer", "url": "https://gitlab.example.com/api/v4/group/<group_id>/-/packages/composer/" }
     ],
     "config": {
       ...
       "gitlab-domains": ["gitlab01.example.com", "gitlab02.example.com"]
     },
     "require": {
       ...
       "<package_name>": "<version>"
     },
     ...
   }
   ```

   You can unset this with the command:

   ```shell
   composer config --unset gitlab-domains
   ```

   NOTE:
   On GitLab.com, Composer uses the GitLab token from `auth.json` as a private token by default.
   Without the `gitlab-domains` definition in `composer.json`, Composer uses the GitLab token
   as basic-auth, with the token as a username and a blank password. This results in a 401 error.

1. With the `composer.json` and `auth.json` files configured, you can install the package by running:

   ```shell
   composer update
   ```

   Or to install the single package:

   ```shell
   composer req <package-name>:<package-version>
   ```

   If successful, you should see output indicating that the package installed successfully.

   You can also install from source (by pulling the Git repository directly) using the
   `--prefer-source` option:

   ```shell
   composer update --prefer-source
   ```

WARNING:
Never commit the `auth.json` file to your repository. To install packages from a CI/CD job,
consider using the [`composer config`](https://getcomposer.org/doc/articles/handling-private-packages.md#satis) tool with your access token
stored in a [GitLab CI/CD variable](../../../ci/variables/index.md) or in
[HashiCorp Vault](../../../ci/secrets/index.md).

### Working with Deploy Tokens

Although Composer packages are accessed at the group level, a group or project deploy token can be
used to access them:

- A group deploy token has access to all packages published to projects in that group or its
  subgroups.
- A project deploy token only has access to packages published to that particular project.

## Troubleshooting

### Caching

To improve performance, Composer caches files related to a package. Note that Composer doesn't remove data by
itself. The cache grows as new packages are installed. If you encounter issues, clear the cache with
this command:

```shell
composer clearcache
```

### Authorization requirement when using `composer install`

In GitLab 14.9 and earlier, you did not require authorization to use `composer install` if you already had a generated `composer.lock`.
If you committed your `composer.lock`, you could do a `composer install` in CI without setting up credentials.

In GitLab 14.10 and later, authorization is required for the [downloading a package archive](../../../api/packages/composer.md#download-a-package-archive) endpoint.
If you encounter a credentials prompt when you are using `composer install`, follow the instructions in the [install a composer package](#install-a-composer-package) section to create an `auth.json` file.

## Supported CLI commands

The GitLab Composer repository supports the following Composer CLI commands:

- `composer install`: Install Composer dependencies.
- `composer update`: Install the latest version of Composer dependencies.
