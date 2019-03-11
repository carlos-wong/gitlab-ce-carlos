---
description: 'Learn how to use GitLab Pages to deploy a static website at no additional cost.'
last_updated: 2019-03-05
---

# GitLab Pages

**GitLab Pages is a feature that allows you to publish static websites
directly from a repository in GitLab.**

You can use it either for personal or business websites, such as
portfolios, documentation, manifestos, and business presentations.
You can also attribute any license to your content.

<table class="borderless-table center fixed-table">
  <tr>
    <td style="width: 22%"><img src="img/icons/cogs.png" alt="SSGs" class="image-noshadow half-width"></td>
    <td style="width: 4%">
      <strong>
        <i class="fa fa-angle-double-right" aria-hidden="true"></i>
      </strong>
    </td>
    <td style="width: 22%"><img src="img/icons/monitor.png" alt="Websites" class="image-noshadow half-width"></td>
    <td style="width: 4%">
      <strong>
        <i class="fa fa-angle-double-right" aria-hidden="true"></i>
      </strong>
    </td>
    <td style="width: 22%"><img src="img/icons/free.png" alt="Pages is free" class="image-noshadow half-width"></td>
    <td style="width: 4%">
      <strong>
        <i class="fa fa-angle-double-right" aria-hidden="true"></i>
      </strong>
    </td>
    <td style="width: 22%"><img src="img/icons/lock.png" alt="Secure your website" class="image-noshadow half-width"></td>
  </tr>
  <tr>
    <td><em>Use any static website generator or plain HTML</em></td>
    <td></td>
    <td><em>Create websites for your projects, groups, or user account</em></td>
    <td></td>
    <td><em>Host on GitLab.com for free, or on your own GitLab instance</em></td>
    <td></td>
    <td><em>Connect your custom domain(s) and TLS certificates</em></td>
  </tr>
</table>

Pages is available for free for all GitLab.com users as well as for self-managed
instances (GitLab Core, Starter, Premium, and Ultimate).

## Overview

<div class="row">
<div class="col-md-9">
<p style="margin-top: 18px;">
To publish a website with Pages, you can use any Static Site Generator (SSG),
such as Jekyll, Hugo, Middleman, Harp, Hexo, and Brunch, just to name a few. You can also
publish any website written directly in plain HTML, CSS, and JavaScript.</p>
<p>Pages does <strong>not</strong> support dynamic server-side processing, for instance, as <code>.php</code> and <code>.asp</code> requires. See this article to learn more about
<a href="https://about.gitlab.com/2016/06/03/ssg-overview-gitlab-pages-part-1-dynamic-x-static/">static websites vs dynamic websites</a>.</p>
</div>
<div class="col-md-3"><img src="img/ssgs_pages.png" alt="Examples of SSGs supported by Pages" class="image-noshadow middle display-block"></div>
</div>

### Availability

If you're using GitLab.com, your website will be publicly available to the internet.
If you're using self-managed instances (Core, Starter, Premium, or Ultimate),
your websites will be published on your own server, according to the
[Pages admin settings](../../../administration/pages/index.md) chosen by your sysadmin,
who can opt for making them public or internal to your server.

### How it works

To use GitLab Pages, first you need to create a project in GitLab to upload your website's
files to. These projects can be either public, internal, or private, at your own choice.
GitLab will always deploy your website from a very specific folder called `public` in your
repository. Note that when you create a new project in GitLab, a [repository](../repository/index.md)
becomes available automatically.

To deploy your site, GitLab will use its built-in tool called [GitLab CI/CD](../../../ci/README.md),
that will build your site and publish it to the GitLab Pages server. The sequence of
scripts that GitLab CI/CD runs to accomplish this task is created from a file named
`.gitlab-ci.yml`, which you can [create and modify](getting_started_part_four.md) at will.

You can either use GitLab's [default domain for GitLab Pages websites](getting_started_part_one.md#gitlab-pages-domain),
`*.gitlab.io`, or your own domain (`example.com`). In that case, you'll
need admin access to your domain's registrar (or control panel) to set it up with Pages.

Optionally, when adding your own domain, you can add an SSL/TLS certificate to secure your
site under the HTTPS protocol.

## Getting started

To get started with GitLab Pages, you can either:

- [Create a project from scratch](getting_started_part_two.md#create-a-project-from-scratch).
- [Copy an existing example project](getting_started_part_two.md#fork-a-project-to-get-started-from).
- Use a bundled project template that is ready to go ([introduced](https://gitlab.com/gitlab-org/gitlab-ce/issues/47857)
in GitLab 11.8), as follows:

1. From the top navigation, click the **+** button and select **New project**.
1. Select **Create from Template**.
1. Choose one of the templates starting with **Pages**:

    ![Project templates for Pages](img/pages_project_templates_11-8.png)

1. From the left sidebar, navigate to your project's **CI/CD > Pipelines**
and click **Run pipeline** to trigger GitLab CI/CD to build and deploy your
site to the server.
1. Once the pipeline has finished successfully, find the link to visit your
website from your project's **Settings > Pages**.

Your website is then visible on your domain, and you can modify yourfiles
as you wish. For every modification pushed to your repository, GitLab CI/CD
will run a new pipeline to publish your changes to the server.

_Advanced options:_

- [Use a custom domain](getting_started_part_three.md#adding-your-custom-domain-to-gitlab-pages)
- Apply [SSL/TLS certification](getting_started_part_three.md#ssltls-certificates) to your custom domain

## Explore GitLab Pages

To learn more about GitLab Pages, read the following tutorials:

- [Static websites and GitLab Pages domains](getting_started_part_one.md): Understand what is a static website, and how GitLab Pages default domains work
- [Projects for GitLab Pages and URL structure](getting_started_part_two.md): Forking projects and creating new ones from scratch, understanding URLs structure and baseurls
- [GitLab Pages custom domains and SSL/TLS Certificates](getting_started_part_three.md): How to add custom domains and subdomains to your website, configure DNS records and SSL/TLS certificates
- [Creating and Tweaking GitLab CI/CD for GitLab Pages](getting_started_part_four.md): Understand how to create your own `.gitlab-ci.yml` for your site
- [Technical aspects, custom 404 pages, limitations](introduction.md)

### GitLab Pages with Static Site Generators (SSGs)

To understand more about SSGs, their advantages, and how to get the most from them
with Pages, read through this series:

- [SSGs part 1: Static vs dynamic websites](https://about.gitlab.com/2016/06/03/ssg-overview-gitlab-pages-part-1-dynamic-x-static/)
- [SSGs part 2: Modern static site generators](https://about.gitlab.com/2016/06/10/ssg-overview-gitlab-pages-part-2/)
- [SSGs part 3: Build any SSG site with GitLab Pages](https://about.gitlab.com/2016/06/17/ssg-overview-gitlab-pages-part-3-examples-ci/)

### GitLab Pages with SSL/TLS certificates

If you're using GitLab Pages default domain (`.gitlab.io`), your website will be
automatically secure and available under HTTPS. If you're using your own domain, you can
optionally secure it with SSL/TLS certificates. You can read the following
tutorials to learn how to use these third-party certificates with GitLab Pages:

- [CloudFlare](https://about.gitlab.com/2017/02/07/setting-up-gitlab-pages-with-cloudflare-certificates/)
- [Let's Encrypt](lets_encrypt_for_gitlab_pages.md)

## Advanced use

There are quite some great examples of GitLab Pages websites built for some
specific reasons. These examples can teach you some advanced techniques
to use and adapt to your own needs:

- [Posting to your GitLab Pages blog from iOS](https://about.gitlab.com/2016/08/19/posting-to-your-gitlab-pages-blog-from-ios/)
- [GitLab CI: Run jobs sequentially, in parallel, or build a custom pipeline](https://about.gitlab.com/2016/07/29/the-basics-of-gitlab-ci/)
- [GitLab CI: Deployment & environments](https://about.gitlab.com/2016/08/26/ci-deployment-and-environments/)
- [Building a new GitLab docs site with Nanoc, GitLab CI, and GitLab Pages](https://about.gitlab.com/2016/12/07/building-a-new-gitlab-docs-site-with-nanoc-gitlab-ci-and-gitlab-pages/)
- [Publish code coverage reports with GitLab Pages](https://about.gitlab.com/2016/11/03/publish-code-coverage-report-with-gitlab-pages/)

## Admin GitLab Pages for CE and EE

Enable and configure GitLab Pages on your own instance (GitLab Community Edition and Enterprise Editions) with
the [admin guide](../../../administration/pages/index.md).

**<i class="fa fa-youtube-play youtube" aria-hidden="true"></i> Watch a [video tutorial](https://www.youtube.com/watch?v=dD8c7WNcc6s) for getting started with GitLab Pages admin!**

## More information about GitLab Pages

- Announcement (2016-12-24): ["We're bringing GitLab Pages to CE"](https://about.gitlab.com/2016/12/24/were-bringing-gitlab-pages-to-community-edition/)
- Announcement (2017-03-06): ["We are changing the IP of GitLab Pages on GitLab.com"](https://about.gitlab.com/2017/03/06/we-are-changing-the-ip-of-gitlab-pages-on-gitlab-com/)
