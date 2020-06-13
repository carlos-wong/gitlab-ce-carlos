# Frontend Development Guidelines

This document describes various guidelines to ensure consistency and quality
across GitLab's frontend team.

## Overview

GitLab is built on top of [Ruby on Rails](https://rubyonrails.org) using [Haml][haml] and also a JavaScript based Frontend with [Vue.js](https://vuejs.org).
Be wary of [the limitations that come with using Hamlit][hamlit-limits]. We also use [SCSS](https://sass-lang.com) and plain JavaScript with
modern ECMAScript standards supported through [Babel][babel] and ES module support through [webpack][webpack].

Working with our frontend assets requires Node (v10.13.0 or greater) and Yarn
(v1.10.0 or greater). You can find information on how to install these on our
[installation guide][install].

### Browser Support

For our currently-supported browsers, see our [requirements][requirements].

Use [BrowserStack](https://www.browserstack.com/) to test with our supported browsers. Login to BrowserStack with the credentials saved in GitLab's [shared 1Password account](https://about.gitlab.com/handbook/security/#1password-for-teams).

## Initiatives

Current high-level frontend goals are listed on [Frontend Epics](https://gitlab.com/groups/gitlab-org/-/epics?label_name%5B%5D=frontend).

## Principles

[High-level guidelines](principles.md) for contributing to GitLab.

## Development Process

How we [plan and execute](development_process.md) the work on the frontend.

## Architecture

How we go about [making fundamental design decisions](architecture.md) in GitLab's frontend team
or make changes to our frontend development guidelines.

## Testing

How we write [frontend tests](../testing_guide/frontend_testing.md), run the GitLab test suite, and debug test related
issues.

## Pajamas Design System

Reusable components with technical and usage guidelines can be found in our
[Pajamas Design System](https://design.gitlab.com/).

## Design Patterns

Common JavaScript [design patterns](design_patterns.md) in GitLab's codebase.

## Vue.js Best Practices

Vue specific [design patterns and practices](vue.md).

## Vuex

[Vuex](vuex.md) specific design patterns and practices.

## Axios

[Axios](axios.md) specific practices and gotchas.

## GraphQL

How to use [GraphQL](graphql.md).

## Icons and Illustrations

How we use SVG for our [Icons and Illustrations](icons.md).

## Dependencies

General information about frontend [dependencies](dependencies.md) and how we manage them.

## Frontend FAQ

Read the [frontend's FAQ](frontend_faq.md) for common small pieces of helpful information.

## Style Guides

See the relevant style guides for our guidelines and for information on linting:

- [JavaScript](style/javascript.md). Our guide is based on
the excellent [Airbnb][airbnb-js-style-guide] style guide with a few small
changes.
- [SCSS](style/scss.md): our SCSS conventions which are enforced through [`scss-lint`](https://github.com/brigade/scss-lint).
- [HTML](style/html.md). Guidelines for writing HTML code consistent with the rest of the codebase.
- [Vue](style/vue.md). Guidelines and conventions for Vue code may be found here.

## [Tooling](tooling.md)

Our code is automatically formatted with [Prettier](https://prettier.io) to follow our guidelines. Read our [Tooling guide](tooling.md) for more detail.

## [Performance](performance.md)

Best practices for monitoring and maximizing frontend performance.

## [Security](security.md)

Frontend security practices.

## [Accessibility](accessibility.md)

Our accessibility standards and resources.

## [Internationalization (i18n) and Translations](../i18n/externalization.md)

Frontend internationalization support is described in [this document](../i18n/).
The [externalization part of the guide](../i18n/externalization.md) explains the helpers/methods available.

[haml]: http://haml.info/
[hamlit]: https://github.com/k0kubun/hamlit
[hamlit-limits]: https://github.com/k0kubun/hamlit/blob/master/REFERENCE.md#limitations
[babel]: https://babeljs.io/
[webpack]: https://webpack.js.org/
[jquery]: https://jquery.com/
[axios]: https://github.com/axios/axios
[airbnb-js-style-guide]: https://github.com/airbnb/javascript
[install]: ../../install/installation.md#4-node
[requirements]: ../../install/requirements.md#supported-web-browsers
