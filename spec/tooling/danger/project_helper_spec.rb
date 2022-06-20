# frozen_string_literal: true

require 'rspec-parameterized'
require 'gitlab-dangerfiles'
require 'danger'
require 'danger/plugins/internal/helper'
require 'gitlab/dangerfiles/spec_helper'

require_relative '../../../danger/plugins/project_helper'
require_relative '../../../spec/support/helpers/stub_env'

RSpec.describe Tooling::Danger::ProjectHelper do
  include StubENV
  include_context "with dangerfile"

  let(:fake_danger) { DangerSpecHelper.fake_danger.include(described_class) }
  let(:fake_helper) { Danger::Helper.new(project_helper) }

  subject(:project_helper) { fake_danger.new(git: fake_git) }

  before do
    allow(project_helper).to receive(:helper).and_return(fake_helper)
    allow(fake_helper).to receive(:config).and_return(double(files_to_category: described_class::CATEGORIES))
  end

  describe '#categories_for_file' do
    using RSpec::Parameterized::TableSyntax

    before do
      allow(fake_git).to receive(:diff_for_file).with(instance_of(String)) { double(:diff, patch: "+ count(User.active)") }
    end

    where(:path, :expected_categories) do
      'usage_data.rb'   | [:database, :backend, :product_intelligence]
      'doc/foo.md'      | [:docs]
      'CONTRIBUTING.md' | [:docs]
      'LICENSE'         | [:docs]
      'MAINTENANCE.md'  | [:docs]
      'PHILOSOPHY.md'   | [:docs]
      'PROCESS.md'      | [:docs]
      'README.md'       | [:docs]

      'ee/doc/foo'      | [:unknown]
      'ee/README'       | [:unknown]

      'app/assets/foo'                   | [:frontend]
      'app/views/foo'                    | [:frontend, :backend]
      'public/foo'                       | [:frontend]
      'scripts/frontend/foo'             | [:frontend]
      'spec/frontend/bar'                | [:frontend]
      'spec/frontend_integration/bar'    | [:frontend]
      'vendor/assets/foo'                | [:frontend]
      'babel.config.js'                  | [:frontend]
      'jest.config.js'                   | [:frontend]
      'package.json'                     | [:frontend]
      'yarn.lock'                        | [:frontend]
      'config/foo.js'                    | [:frontend]
      'config/deep/foo.js'               | [:frontend]

      'ee/app/assets/foo'                | [:frontend]
      'ee/app/views/foo'                 | [:frontend, :backend]
      'ee/spec/frontend/bar'             | [:frontend]
      'ee/spec/frontend_integration/bar' | [:frontend]

      '.gitlab/ci/frontend.gitlab-ci.yml' | %i[frontend tooling]

      'app/models/foo'             | [:backend]
      'bin/foo'                    | [:backend]
      'config/foo'                 | [:backend]
      'lib/foo'                    | [:backend]
      'rubocop/foo'                | [:backend]
      '.rubocop.yml'               | [:backend]
      '.rubocop_todo.yml'          | [:backend]
      '.rubocop_todo/cop/name.yml' | [:backend]
      'spec/foo'                   | [:backend]
      'spec/foo/bar'               | [:backend]

      'ee/app/foo'      | [:backend]
      'ee/bin/foo'      | [:backend]
      'ee/spec/foo'     | [:backend]
      'ee/spec/foo/bar' | [:backend]

      'spec/migrations/foo'    | [:database]
      'ee/spec/migrations/foo' | [:database]

      'spec/features/foo'                            | [:test]
      'ee/spec/features/foo'                         | [:test]
      'spec/support/shared_examples/features/foo'    | [:test]
      'ee/spec/support/shared_examples/features/foo' | [:test]
      'spec/support/shared_contexts/features/foo'    | [:test]
      'ee/spec/support/shared_contexts/features/foo' | [:test]
      'spec/support/helpers/features/foo'            | [:test]
      'ee/spec/support/helpers/features/foo'         | [:test]

      'generator_templates/foo' | [:backend]
      'vendor/languages.yml'    | [:backend]
      'file_hooks/examples/'    | [:backend]

      'Gemfile'        | [:backend]
      'Gemfile.lock'   | [:backend]
      'Rakefile'       | [:backend]
      'FOO_VERSION'    | [:backend]

      'Dangerfile'                                            | [:tooling]
      'danger/bundle_size/Dangerfile'                         | [:tooling]
      'ee/danger/bundle_size/Dangerfile'                      | [:tooling]
      'danger/bundle_size/'                                   | [:tooling]
      'ee/danger/bundle_size/'                                | [:tooling]
      '.gitlab-ci.yml'                                        | [:tooling]
      '.gitlab/ci/cng.gitlab-ci.yml'                          | [:tooling]
      '.gitlab/ci/ee-specific-checks.gitlab-ci.yml'           | [:tooling]
      'scripts/foo'                                           | [:tooling]
      'tooling/danger/foo'                                    | [:tooling]
      'ee/tooling/danger/foo'                                 | [:tooling]
      'lefthook.yml'                                          | [:tooling]
      '.editorconfig'                                         | [:tooling]
      'tooling/bin/find_foss_tests'                           | [:tooling]
      '.codeclimate.yml'                                      | [:tooling]
      '.gitlab/CODEOWNERS'                                    | [:tooling]

      'lib/gitlab/ci/templates/Security/SAST.gitlab-ci.yml'   | [:ci_template]
      'lib/gitlab/ci/templates/dotNET-Core.yml'               | [:ci_template]

      'ee/FOO_VERSION' | [:unknown]

      'db/schema.rb'                                              | [:database]
      'db/structure.sql'                                          | [:database]
      'db/migrate/foo'                                            | [:database, :migration]
      'db/post_migrate/foo'                                       | [:database, :migration]
      'ee/db/geo/migrate/foo'                                     | [:database, :migration]
      'ee/db/geo/post_migrate/foo'                                | [:database, :migration]
      'app/models/project_authorization.rb'                       | [:database, :backend]
      'app/services/users/refresh_authorized_projects_service.rb' | [:database, :backend]
      'app/services/authorized_project_update/find_records_due_for_refresh_service.rb' | [:database, :backend]
      'lib/gitlab/background_migration.rb'                        | [:database, :backend]
      'lib/gitlab/background_migration/foo'                       | [:database, :backend]
      'ee/lib/gitlab/background_migration/foo'                    | [:database, :backend]
      'lib/gitlab/database.rb'                                    | [:database, :backend]
      'lib/gitlab/database/foo'                                   | [:database, :backend]
      'ee/lib/gitlab/database/foo'                                | [:database, :backend]
      'lib/gitlab/github_import.rb'                               | [:database, :backend]
      'lib/gitlab/github_import/foo'                              | [:database, :backend]
      'lib/gitlab/sql/foo'                                        | [:database, :backend]
      'rubocop/cop/migration/foo'                                 | [:database]

      'db/fixtures/foo.rb'                                 | [:backend]
      'ee/db/fixtures/foo.rb'                              | [:backend]

      'qa/foo' | [:qa]
      'ee/qa/foo' | [:qa]

      'workhorse/main.go' | [:workhorse]
      'workhorse/internal/upload/upload.go' | [:workhorse]

      'locale/gitlab.pot' | [:none]

      'FOO'          | [:unknown]
      'foo'          | [:unknown]

      'foo/bar.rb'  | [:backend]
      'foo/bar.js'  | [:frontend]
      'foo/bar.txt' | [:none]
      'foo/bar.md'  | [:none]

      'ee/config/metrics/counts_7d/20210216174919_g_analytics_issues_weekly.yml' | [:product_intelligence]
      'lib/gitlab/usage_data_counters/aggregated_metrics/common.yml' | [:product_intelligence]
      'lib/gitlab/usage_data_counters/hll_redis_counter.rb' | [:backend, :product_intelligence]
      'lib/gitlab/tracking.rb' | [:backend, :product_intelligence]
      'lib/gitlab/usage/service_ping_report.rb' | [:backend, :product_intelligence]
      'lib/gitlab/usage/metrics/key_path_processor.rb' | [:backend, :product_intelligence]
      'spec/lib/gitlab/tracking_spec.rb' | [:backend, :product_intelligence]
      'app/helpers/tracking_helper.rb' | [:backend, :product_intelligence]
      'spec/helpers/tracking_helper_spec.rb' | [:backend, :product_intelligence]
      'lib/generators/rails/usage_metric_definition_generator.rb' | [:backend, :product_intelligence]
      'spec/lib/generators/usage_metric_definition_generator_spec.rb' | [:backend, :product_intelligence]
      'config/metrics/schema.json' | [:product_intelligence]
      'app/assets/javascripts/tracking/foo.js' | [:frontend, :product_intelligence]
      'spec/frontend/tracking/foo.js' | [:frontend, :product_intelligence]
      'spec/frontend/tracking_spec.js' | [:frontend, :product_intelligence]
      'lib/gitlab/usage_database/foo.rb' | [:backend]
      'config/metrics/counts_7d/test_metric.yml' | [:product_intelligence]
      'config/events/snowplow_event.yml' | [:product_intelligence]
      'config/metrics/schema.json' | [:product_intelligence]
      'doc/api/usage_data.md' | [:product_intelligence]
      'spec/lib/gitlab/usage_data_spec.rb' | [:product_intelligence]
      'spec/lib/gitlab/usage/service_ping_report.rb' | [:backend, :product_intelligence]
      'spec/lib/gitlab/usage/metrics/key_path_processor.rb' | [:backend, :product_intelligence]

      'app/models/integration.rb' | [:integrations_be, :backend]
      'ee/app/models/integrations/github.rb' | [:integrations_be, :backend]
      'ee/app/models/ee/integrations/jira.rb' | [:integrations_be, :backend]
      'app/models/integrations/chat_message/pipeline_message.rb' | [:integrations_be, :backend]
      'app/models/jira_connect_subscription.rb' | [:integrations_be, :backend]
      'app/models/hooks/service_hook.rb' | [:integrations_be, :backend]
      'ee/app/models/ee/hooks/system_hook.rb' | [:integrations_be, :backend]
      'app/services/concerns/integrations/project_test_data.rb' | [:integrations_be, :backend]
      'ee/app/services/ee/integrations/test/project_service.rb' | [:integrations_be, :backend]
      'app/controllers/concerns/integrations/actions.rb' | [:integrations_be, :backend]
      'ee/app/controllers/concerns/ee/integrations/params.rb' | [:integrations_be, :backend]
      'ee/app/controllers/projects/integrations/jira/issues_controller.rb' | [:integrations_be, :backend]
      'app/controllers/projects/hooks_controller.rb' | [:integrations_be, :backend]
      'app/controllers/admin/hook_logs_controller.rb' | [:integrations_be, :backend]
      'app/controllers/groups/settings/integrations_controller.rb' | [:integrations_be, :backend]
      'app/controllers/jira_connect/branches_controller.rb' | [:integrations_be, :backend]
      'app/controllers/oauth/jira/authorizations_controller.rb' | [:integrations_be, :backend]
      'ee/app/finders/projects/integrations/jira/by_ids_finder.rb' | [:integrations_be, :database, :backend]
      'app/workers/jira_connect/sync_merge_request_worker.rb' | [:integrations_be, :backend]
      'app/workers/propagate_integration_inherit_worker.rb' | [:integrations_be, :backend]
      'app/workers/web_hooks/log_execution_worker.rb' | [:integrations_be, :backend]
      'app/workers/web_hook_worker.rb' | [:integrations_be, :backend]
      'app/workers/project_service_worker.rb' | [:integrations_be, :backend]
      'lib/atlassian/jira_connect/serializers/commit_entity.rb' | [:integrations_be, :backend]
      'lib/api/entities/project_integration.rb' | [:integrations_be, :backend]
      'lib/gitlab/hook_data/note_builder.rb' | [:integrations_be, :backend]
      'lib/gitlab/data_builder/note.rb' | [:integrations_be, :backend]
      'lib/gitlab/web_hooks/recursion_detection.rb' | [:integrations_be, :backend]
      'ee/lib/ee/gitlab/integrations/sti_type.rb' | [:integrations_be, :backend]
      'ee/lib/ee/api/helpers/integrations_helpers.rb' | [:integrations_be, :backend]
      'ee/app/serializers/integrations/jira_serializers/issue_entity.rb' | [:integrations_be, :backend]
      'app/serializers/jira_connect/app_data_serializer.rb' | [:integrations_be, :backend]
      'lib/api/github/entities.rb' | [:integrations_be, :backend]
      'lib/api/v3/github.rb' | [:integrations_be, :backend]
      'app/models/clusters/integrations/elastic_stack.rb' | [:backend]
      'app/controllers/clusters/integrations_controller.rb' | [:backend]
      'app/services/clusters/integrations/prometheus_health_check_service.rb' | [:backend]
      'app/graphql/types/alert_management/integration_type.rb' | [:backend]

      'app/views/jira_connect/branches/new.html.haml' | [:integrations_fe, :frontend]
      'app/views/layouts/jira_connect.html.haml' | [:integrations_fe, :frontend]
      'app/assets/javascripts/jira_connect/branches/pages/index.vue' | [:integrations_fe, :frontend]
      'ee/app/views/projects/integrations/jira/issues/show.html.haml' | [:integrations_fe, :frontend]
      'ee/app/assets/javascripts/integrations/zentao/issues_list/graphql/queries/get_zentao_issues.query.graphql' | [:integrations_fe, :frontend]
      'app/assets/javascripts/pages/projects/settings/integrations/show/index.js' | [:integrations_fe, :frontend]
      'ee/app/assets/javascripts/pages/groups/hooks/index.js' | [:integrations_fe, :frontend]
      'app/views/clusters/clusters/_integrations_tab.html.haml' | [:frontend, :backend]
      'app/assets/javascripts/alerts_settings/graphql/fragments/integration_item.fragment.graphql' | [:frontend]
      'app/assets/javascripts/filtered_search/droplab/hook_input.js' | [:frontend]

      'app/views/layouts/header/_default.html.haml' | [:frontend, :backend]
      'app/views/layouts/header/_default.html.erb'  | [:frontend, :backend]
    end

    with_them do
      subject { project_helper.helper.categories_for_file(path) }

      it { is_expected.to eq(expected_categories) }
    end

    context 'having specific changes' do
      where(:expected_categories, :patch, :changed_files) do
        [:product_intelligence]                      | '+data-track-action'                           | ['components/welcome.vue']
        [:product_intelligence]                      | '+ data: { track_label:'                       | ['admin/groups/_form.html.haml']
        [:product_intelligence]                      | '+ Gitlab::Tracking.event'                     | ['dashboard/todos_controller.rb', 'admin/groups/_form.html.haml']
        [:database, :backend, :product_intelligence] | '+ count(User.active)'                         | ['usage_data.rb', 'lib/gitlab/usage_data.rb', 'ee/lib/ee/gitlab/usage_data.rb']
        [:database, :backend, :product_intelligence] | '+ estimate_batch_distinct_count(User.active)' | ['usage_data.rb']
        [:backend, :product_intelligence]            | '+ alt_usage_data(User.active)'                | ['lib/gitlab/usage_data.rb']
        [:backend, :product_intelligence]            | '+ count(User.active)'                         | ['lib/gitlab/usage_data/topology.rb']
        [:backend, :product_intelligence]            | '+ foo_count(User.active)'                     | ['lib/gitlab/usage_data.rb']
        [:backend]                                   | '+ count(User.active)'                         | ['user.rb']
        [:integrations_be, :database, :migration]    | '+ add_column :integrations, :foo, :text'      | ['db/migrate/foo.rb']
        [:integrations_be, :database, :migration]    | '+ create_table :zentao_tracker_data do |t|'   | ['ee/db/post_migrate/foo.rb']
        [:integrations_be, :backend]                 | '+ Integrations::Foo'                          | ['app/foo/bar.rb']
        [:integrations_be, :backend]                 | '+ project.execute_hooks(foo, :bar)'           | ['ee/lib/ee/foo.rb']
        [:integrations_be, :backend]                 | '+ project.execute_integrations(foo, :bar)'    | ['app/foo.rb']
      end

      with_them do
        it 'has the correct categories' do
          changed_files.each do |file|
            allow(fake_git).to receive(:diff_for_file).with(file) { double(:diff, patch: patch) }

            expect(project_helper.helper.categories_for_file(file)).to eq(expected_categories)
          end
        end
      end
    end
  end

  describe '#file_lines' do
    let(:filename) { 'spec/foo_spec.rb' }
    let(:file_spy) { spy }

    it 'returns the chomped file lines' do
      expect(project_helper).to receive(:read_file).with(filename).and_return(file_spy)

      project_helper.file_lines(filename)

      expect(file_spy).to have_received(:lines).with(chomp: true)
    end
  end
end
