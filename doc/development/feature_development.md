---
stage: none
group: Development
info: "See the Technical Writers assigned to Development Guidelines: https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments-to-development-guidelines"
---

# Feature development

Consult these topics for information on contributing to specific GitLab features.

## UX and Frontend guides

- [GitLab Design System](https://design.gitlab.com/), for building GitLab with
  existing CSS styles and elements
- [Frontend guidelines](fe_guide/index.md)
- [Emoji guide](fe_guide/emojis.md)

## Backend guides

### General

- [Directory structure](directory_structure.md)
- [GitLab EventStore](event_store.md) to publish/subscribe to domain events
- [GitLab utilities](utilities.md)
- [Newlines style guide](newlines_styleguide.md)
- [Logging](logging.md)
- [Dealing with email/mailers](emails.md)
- [Kubernetes integration guidelines](kubernetes.md)
- [Permissions](permissions.md)
- [Code comments](code_comments.md)
- [Windows Development on GCP](windows.md)
- [FIPS compliance](fips_compliance.md)
- [`Gemfile` guidelines](gemfile.md)
- [Ruby upgrade guidelines](ruby_upgrade.md)

### Things to be aware of

- [Gotchas](gotchas.md) to avoid
- [Avoid modules with instance variables](module_with_instance_variables.md), if
  possible
- [Guidelines for reusing abstractions](reusing_abstractions.md)
- [Ruby 3 gotchas](ruby3_gotchas.md)

### Rails Framework related

- [Routing](routing.md)
- [Rails initializers](rails_initializers.md)
- [Mass Inserting Models](mass_insert.md)
- [Issuable-like Rails models](issuable-like-models.md)
- [Issue types vs first-class types](issue_types.md)
- [DeclarativePolicy framework](policies.md)
- [Rails update guidelines](rails_update.md)

### Debugging

- [Pry debugging](pry_debugging.md)
- [Sidekiq debugging](../administration/troubleshooting/sidekiq.md)

### Git specifics

- [How Git object deduplication works in GitLab](git_object_deduplication.md)
- [Git LFS](lfs.md)

### API

- [API style guide](api_styleguide.md) for contributing to the API
- [GraphQL API style guide](api_graphql_styleguide.md) for contributing to the
  [GraphQL API](../api/graphql/index.md)

### GitLab components and features

- [Developing against interacting components or features](interacting_components.md)
- [Manage feature flags](feature_flags/index.md)
- [Licensed feature availability](licensed_feature_availability.md)
- [Accessing session data](session.md)
- [How to dump production data to staging](db_dump.md)
- [Geo development](geo.md)
- [Redis guidelines](redis.md)
  - [Adding a new Redis instance](redis/new_redis_instance.md)
- [Sidekiq guidelines](sidekiq/index.md) for working with Sidekiq workers
- [Working with Gitaly](gitaly.md)
- [Elasticsearch integration docs](elasticsearch.md)
- [Working with merge request diffs](diffs.md)
- [Approval Rules](approval_rules.md)
- [Repository mirroring](repository_mirroring.md)
- [Uploads development guide](uploads/index.md)
- [Auto DevOps development guide](auto_devops.md)
- [Renaming features](renaming_features.md)
- [Code Intelligence](code_intelligence/index.md)
- [Feature categorization](feature_categorization/index.md)
- [Wikis development guide](wikis.md)
- [Image scaling guide](image_scaling.md)
- [Cascading Settings](cascading_settings.md)
- [Shell commands](shell_commands.md) in the GitLab codebase
- [Value Stream Analytics development guide](value_stream_analytics.md)
- [Application limits](application_limits.md)

### Import and Export

- [Working with the GitHub importer](github_importer.md)
- [Import/Export development documentation](import_export.md)
- [Test Import Project](import_project.md)
- [Group migration](bulk_import.md)
- [Export to CSV](export_csv.md)

## Performance guides

- [Performance guidelines](performance.md) for writing code, benchmarks, and
  certain patterns to avoid.
- [Caching guidelines](caching.md) for using caching in Rails under a GitLab environment.
- [Merge request performance guidelines](merge_request_performance_guidelines.md)
  for ensuring merge requests do not negatively impact GitLab performance
- [Profiling](profiling.md) a URL or tracking down N+1 queries using Bullet.
- [Cached queries guidelines](cached_queries.md), for tracking down N+1 queries
  masked by query caching, memory profiling and why should we avoid cached
  queries.

## Database guides

See [database guidelines](database/index.md).

## Integration guides

- [Integrations development guide](integrations/index.md)
- [Jira Connect app](integrations/jira_connect.md)
- [Security Scanners](integrations/secure.md)
- [Secure Partner Integration](integrations/secure_partner_integration.md)
- [How to run Jenkins in development environment](integrations/jenkins.md)
- [How to run local `Codesandbox` integration for Web IDE Live Preview](integrations/codesandbox.md)

## Testing guides

- [Testing standards and style guidelines](testing_guide/index.md)
- [Frontend testing standards and style guidelines](testing_guide/frontend_testing.md)

## Refactoring guides

- [Refactoring guidelines](refactoring_guide/index.md)

## Deprecation guides

- [Deprecation guidelines](deprecation_guidelines/index.md)

## Documentation guides

- [Writing documentation](documentation/index.md)
- [Documentation style guide](documentation/styleguide/index.md)
- [Markdown](../user/markdown.md)

## Internationalization (i18n) guides

- [Introduction](i18n/index.md)
- [Externalization](i18n/externalization.md)
- [Translation](i18n/translation.md)

## Product Intelligence guides

- [Product Intelligence guide](https://about.gitlab.com/handbook/product/product-intelligence-guide/)
- [Service Ping guide](service_ping/index.md)
- [Snowplow guide](snowplow/index.md)

## Experiment guide

- [Introduction](experiment_guide/index.md)

## Build guides

- [Building a package for testing purposes](build_test_package.md)

## Compliance

- [Licensing](licensing.md) for ensuring license compliance

## Domain-specific guides

- [CI/CD development documentation](cicd/index.md)

## Technical Reference by Group

- [Create: Source Code BE](backend/create_source_code_be/index.md)

## Other development guides

- [Defining relations between files using projections](projections.md)
- [Reference processing](reference_processing.md)
- [Compatibility with multiple versions of the application running at the same time](multi_version_compatibility.md)
- [Features inside `.gitlab/`](features_inside_dot_gitlab.md)
- [Dashboards for stage groups](stage_group_observability/index.md)
- [Preventing transient bugs](transient/prevention-patterns.md)
- [GitLab Application SLIs](application_slis/index.md)
- [Spam protection and CAPTCHA development guide](spam_protection_and_captcha/index.md)

## Other GitLab Development Kit (GDK) guides

- [Run full Auto DevOps cycle in a GDK instance](https://gitlab.com/gitlab-org/gitlab-development-kit/blob/main/doc/howto/auto_devops.md)
- [Using GitLab Runner with the GDK](https://gitlab.com/gitlab-org/gitlab-development-kit/blob/main/doc/howto/runner.md)
- [Using the Web IDE terminal with the GDK](https://gitlab.com/gitlab-org/gitlab-development-kit/-/blob/main/doc/howto/web_ide_terminal_gdk_setup.md)
