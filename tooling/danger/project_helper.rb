# frozen_string_literal: true

module Tooling
  module Danger
    module ProjectHelper
      CI_ONLY_RULES ||= %w[
        ce_ee_vue_templates
        ci_templates
        datateam
        feature_flag
        roulette
        sidekiq_queues
        specialization_labels
        specs
        z_metadata
      ].freeze

      # First-match win, so be sure to put more specific regex at the top...
      CATEGORIES = {
        [%r{usage_data\.rb}, %r{^(\+|-).*\s+(count|distinct_count|estimate_batch_distinct_count)\(.*\)(.*)$}] => [:database, :backend, :product_intelligence],

        %r{\A((ee|jh)/)?config/feature_flags/} => :feature_flag,

        %r{doc/api/usage_data.md} => [:product_intelligence],

        %r{\Adoc/.*(\.(md|png|gif|jpg|yml))\z} => :docs,
        %r{\A(CONTRIBUTING|LICENSE|MAINTENANCE|PHILOSOPHY|PROCESS|README)(\.md)?\z} => :docs,
        %r{\Adata/whats_new/} => :docs,
        %r{\Adb/docs/.+\.yml\z} => :docs,
        %r{\Adata/deprecations/} => :none,
        %r{\Adata/removals/} => :none,

        %r{\A((ee|jh)/)?app/finders/(.+/)?integrations/} => [:integrations_be, :database, :backend],
        [%r{\A((ee|jh)/)?db/(geo/)?(migrate|post_migrate)/}, %r{(:integrations|:\w+_tracker_data)\b}] => [:integrations_be, :database, :migration],
        [%r{\A((ee|jh)/)?(app|lib)/.+\.rb}, %r{\b(Integrations::|\.execute_(integrations|hooks))\b}] => [:integrations_be, :backend],
        %r{\A(
          ((ee|jh)/)?app/((?!.*clusters)(?!.*alert_management)(?!.*views)(?!.*assets).+/)?integration.+ |
          ((ee|jh)/)?app/((?!.*search).+/)?project_service.+ |
          ((ee|jh)/)?app/(models|helpers|workers|services|serializers|controllers)/(.+/)?(jira_connect.+|.*hook.+) |
          ((ee|jh)/)?app/controllers/(.+/)?oauth/jira/.+ |
          ((ee|jh)/)?app/services/(.+/)?jira.+ |
          ((ee|jh)/)?app/workers/(.+/)?(propagate_integration.+|irker_worker\.rb) |
          ((ee|jh)/)?lib/(.+/)?(atlassian|data_builder|hook_data|web_hooks)/.+ |
          ((ee|jh)/)?lib/(.+/)?.*integration.+ |
          ((ee|jh)/)?lib/(.+/)?api/v3/github\.rb |
          ((ee|jh)/)?lib/(.+/)?api/github/entities\.rb
        )\z}x => [:integrations_be, :backend],

        %r{\A(
          ((ee|jh)/)?app/(views|assets)/((?!.*clusters)(?!.*alerts_settings).+/)?integration.+ |
          ((ee|jh)/)?app/(views|assets)/(.+/)?jira_connect.+ |
          ((ee|jh)/)?app/(views|assets)/((?!.*filtered_search).+/)?hooks?.+
        )\z}x => [:integrations_fe, :frontend],

        %r{\A(
          app/assets/javascripts/tracking/.*\.js |
          spec/frontend/tracking/.*\.js |
          spec/frontend/tracking_spec\.js
        )\z}x => [:frontend, :product_intelligence],
        [%r{\.(vue|js)\z}, %r{trackRedis}] => [:frontend, :product_intelligence],
        %r{\A((ee|jh)/)?app/assets/} => :frontend,
        %r{\A((ee|jh)/)?app/views/.*\.svg} => :frontend,
        %r{\A((ee|jh)/)?app/views/} => [:frontend, :backend],
        %r{\A((ee|jh)/)?public/} => :frontend,
        %r{\A((ee|jh)/)?spec/(javascripts|frontend|frontend_integration)/} => :frontend,
        %r{\A((ee|jh)/)?vendor/assets/} => :frontend,
        %r{\A((ee|jh)/)?scripts/frontend/} => :frontend,
        %r{(\A|/)(
          \.babelrc |
          \.browserslistrc |
          \.eslintignore |
          \.eslintrc(\.yml)? |
          \.nvmrc |
          \.prettierignore |
          \.prettierrc |
          \.stylelintrc |
          \.haml-lint.yml |
          \.haml-lint_todo.yml |
          babel\.config\.js |
          jest\.config\.js |
          package\.json |
          yarn\.lock |
          config/.+\.js
        )\z}x => :frontend,

        %r{(\A|/)(
          \.gitlab/ci/frontend\.gitlab-ci\.yml
        )\z}x => %i[frontend tooling],

        %r{\A((ee|jh)/)?db/(geo/)?(migrate|post_migrate)/} => [:database, :migration],
        %r{\A((ee|jh)/)?db/(?!fixtures)[^/]+} => [:database],
        %r{\A((ee|jh)/)?lib/gitlab/(database|background_migration|sql|github_import)(/|\.rb)} => [:database, :backend],
        %r{\A(app/services/authorized_project_update/find_records_due_for_refresh_service)(/|\.rb)} => [:database, :backend],
        %r{\A(app/models/project_authorization|app/services/users/refresh_authorized_projects_service)(/|\.rb)} => [:database, :backend],
        %r{\A((ee|jh)/)?app/finders/} => [:database, :backend],
        %r{\Arubocop/cop/migration(/|\.rb)} => :database,

        %r{\A(\.ruby-version\z|\.nvmrc\z|\.tool-versions\z)} => :tooling,
        %r{\A(\.gitlab-ci\.yml\z|\.gitlab\/ci)} => :tooling,
        %r{\A\.codeclimate\.yml\z} => :tooling,
        %r{\Alefthook.yml\z} => :tooling,
        %r{\A\.editorconfig\z} => :tooling,
        %r{Dangerfile\z} => :tooling,
        %r{\A((ee|jh)/)?(danger/|tooling/danger/)} => :tooling,

        %r{\A((ee|jh)/)?scripts/(lib/)?glfm/.*\.rb} => [:backend],
        %r{\A((ee|jh)/)?scripts/(lib/)?glfm/.*\.js} => [:frontend],
        %r{\A((ee|jh)/)?scripts/.*\.rb} => [:backend, :tooling],
        %r{\A((ee|jh)/)?scripts/.*\.js} => [:frontend, :tooling],
        %r{\A((ee|jh)/)?scripts/} => :tooling,

        %r{\Atooling/} => :tooling,
        %r{(CODEOWNERS)} => :tooling,
        %r{(tests.yml)} => :tooling,
        %r{\A\.gitpod\.yml} => :tooling,

        %r{\Alib/gitlab/ci/templates} => :ci_template,

        %r{\A((ee|jh)/)?spec/features/} => :test,
        %r{\A((ee|jh)/)?spec/support/shared_examples/features/} => :test,
        %r{\A((ee|jh)/)?spec/support/shared_contexts/features/} => :test,
        %r{\A((ee|jh)/)?spec/support/helpers/features/} => :test,

        %r{\A((spec/)?lib/generators/gitlab/usage_metric_)} => [:product_intelligence],
        %r{\A((ee|jh)/)?lib/gitlab/usage_data_counters/.*\.yml\z} => [:product_intelligence],
        %r{\A((ee|jh)/)?config/(events|metrics)/((.*\.yml)|(schema\.json))\z} => [:product_intelligence],
        %r{\A((ee|jh)/)?lib/gitlab/usage_data(_counters)?(/|\.rb)} => [:backend, :product_intelligence],
        %r{\A((ee|jh)/)?(spec/)?lib/gitlab/usage(/|\.rb)} => [:backend, :product_intelligence],
        %r{\A(
          lib/gitlab/tracking\.rb |
          spec/lib/gitlab/tracking_spec\.rb |
          app/helpers/tracking_helper\.rb |
          spec/helpers/tracking_helper_spec\.rb |
          (spec/)?lib/generators/gitlab/usage_metric_\S+ |
          (spec/)?lib/generators/gitlab/usage_metric_definition/redis_hll_generator(_spec)?\.rb |
          lib/generators/rails/usage_metric_definition_generator\.rb |
          spec/lib/generators/usage_metric_definition_generator_spec\.rb |
          generator_templates/usage_metric_definition/metric_definition\.yml)\z}x => [:backend, :product_intelligence],
        %r{gitlab/usage_data(_spec)?\.rb} => [:product_intelligence],
        [%r{\.haml\z}, %r{data: \{ track}] => [:product_intelligence],
        [%r{\.(rb|haml)\z}, %r{Gitlab::Tracking\.(event|enabled\?|options)$}] => [:product_intelligence],
        [%r{\.(vue|js)\z}, %r{(Tracking.event|/\btrack\(/|data-track-action)}] => [:product_intelligence],

        %r{\A((ee|jh)/)?app/(?!assets|views)[^/]+} => :backend,
        %r{\A((ee|jh)/)?(bin|config|generator_templates|lib|rubocop)/} => :backend,
        %r{\A((ee|jh)/)?spec/migrations} => :database,
        %r{\A((ee|jh)/)?spec/} => :backend,
        %r{\A((ee|jh)/)?vendor/} => :backend,
        %r{\A(Gemfile|Gemfile.lock|Rakefile)\z} => :backend,
        %r{\A[A-Z_]+_VERSION\z} => :backend,
        %r{\A\.rubocop(_todo)?\.yml\z} => :backend,
        %r{\A\.rubocop_todo/.*\.yml\z} => :backend,
        %r{\Afile_hooks/} => :backend,

        %r{\A((ee|jh)/)?qa/} => :qa,

        %r{\Aworkhorse/.*} => :workhorse,

        # Files that don't fit into any category are marked with :none
        %r{\A((ee|jh)/)?changelogs/} => :none,
        %r{\Alocale/gitlab\.pot\z} => :none,

        # GraphQL auto generated doc files and schema
        %r{\Adoc/api/graphql/reference/} => :backend,

        # Fallbacks in case the above patterns miss anything
        %r{\.rb\z} => :backend,
        %r{(
          \.(md|txt)\z |
          \.markdownlint\.json
        )}x => :none, # To reinstate roulette for documentation, set to `:docs`.
        %r{\.js\z} => :frontend
      }.freeze

      def file_lines(filename)
        read_file(filename).lines(chomp: true)
      end

      private

      def read_file(filename)
        File.read(filename)
      end
    end
  end
end
