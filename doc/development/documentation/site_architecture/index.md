---
description: "Learn how GitLab's documentation website is architectured."
---

# Documentation site architecture

Learn how we build and architecture [`gitlab-docs`](https://gitlab.com/gitlab-com/gitlab-docs)
and deploy it to <https://docs.gitlab.com>.

## Repository

While the source of the documentation content is stored in GitLab's respective product
repositories, the source that is used to build the documentation site _from that content_
is located at https://gitlab.com/gitlab-com/gitlab-docs. See the README there for
detailed information.

## Assets

To provide an optimized site structure, design, and a search-engine friendly
website, along with a discoverable documentation, we use a few assets for
the GitLab Documentation website.

### Libraries

- [Bootstrap 3.3 components](https://getbootstrap.com/docs/3.3/components/)
- [Bootstrap 3.3 JS](https://getbootstrap.com/docs/3.3/javascript/)
- [jQuery](https://jquery.com/) 3.2.1
- [Clipboard JS](https://clipboardjs.com/)
- [Font Awesome 4.7.0](https://fontawesome.com/v4.7.0/icons/)

### SEO

- [Schema.org](https://schema.org/)
- [Google Analytics](https://marketingplatform.google.com/about/analytics/)
- [Google Tag Manager](https://developers.google.com/tag-manager/)

## Global nav

To understand how the global nav (left sidebar) is built, please
read through the [global navigation](global_nav.md) doc.

## Deployment

The docs site is deployed to production with GitLab Pages, and previewed in
merge requests with Review Apps.

The deployment aspects will be soon transfered from the [original document](https://gitlab.com/gitlab-com/gitlab-docs/blob/master/README.md)
to this page.

<!--
## Repositories

TBA

## Search engine

TBA

## Versions

TBA

## Helpers

TBA
-->
