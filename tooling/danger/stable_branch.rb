# frozen_string_literal: true

module Tooling
  module Danger
    module StableBranch
      VersionApiError = Class.new(StandardError)

      STABLE_BRANCH_REGEX = %r{\A(?<version>\d+-\d+)-stable-ee\z}.freeze
      FAILING_PACKAGE_AND_TEST_STATUSES = %w[manual canceled].freeze

      # rubocop:disable Lint/MixedRegexpCaptureTypes
      VERSION_REGEX = %r{
        \A(?<major>\d+)
        \.(?<minor>\d+)
        (\.(?<patch>\d+))?
        (-(?<rc>rc(?<rc_number>\d*)))?
        (-\h+\.\h+)?
        (-ee|\.ee\.\d+)?\z
      }x.freeze
      # rubocop:enable Lint/MixedRegexpCaptureTypes

      MAINTENANCE_POLICY_URL = 'https://docs.gitlab.com/ee/policy/maintenance.html'

      MAINTENANCE_POLICY_MESSAGE = <<~MSG
      See the [release and maintenance policy](#{MAINTENANCE_POLICY_URL}) for more information.
      MSG

      FEATURE_ERROR_MESSAGE = <<~MSG
      This MR includes the `type::feature` label. Features do not qualify for patch releases. #{MAINTENANCE_POLICY_MESSAGE}
      MSG

      BUG_ERROR_MESSAGE = <<~MSG
      This branch is meant for backporting bug fixes. If this MR qualifies please add the `type::bug` label. #{MAINTENANCE_POLICY_MESSAGE}
      MSG

      VERSION_WARNING_MESSAGE = <<~MSG
      Backporting to older releases requires an [exception request process](https://docs.gitlab.com/ee/policy/maintenance.html#backporting-to-older-releases)
      MSG

      FAILED_VERSION_REQUEST_MESSAGE = <<~MSG
      There was a problem checking if this is a qualified version for backporting. Re-running this job may fix the problem.
      MSG

      PIPELINE_EXPEDITE_ERROR_MESSAGE = <<~MSG
      ~"pipeline:expedite" is not allowed on stable branches because it causes the `e2e:package-and-test-ee` job to be skipped.
      MSG

      NEEDS_PACKAGE_AND_TEST_MESSAGE = <<~MSG
      The `e2e:package-and-test-ee` job is not present, has been canceled, or needs to be automatically triggered.
      Please ensure the job is present in the latest pipeline, if necessary, retry the `danger-review` job.
      Read the "QA e2e:package-and-test-ee" section for more details.
      MSG

      WARN_PACKAGE_AND_TEST_MESSAGE = <<~MSG
      **The `e2e:package-and-test-ee` job needs to succeed or have approval from a Software Engineer in Test.**
      Read the "QA e2e:package-and-test-ee" section for more details.
      MSG

      # rubocop:disable Style/SignalException
      def check!
        return unless valid_stable_branch?

        fail FEATURE_ERROR_MESSAGE if has_feature_label?
        fail BUG_ERROR_MESSAGE unless bug_fixes_only?

        warn VERSION_WARNING_MESSAGE unless targeting_patchable_version?

        return if has_flaky_failure_label? || has_only_documentation_changes?

        fail PIPELINE_EXPEDITE_ERROR_MESSAGE if has_pipeline_expedite_label?

        status = package_and_test_bridge_and_pipeline_status

        if status.nil? || FAILING_PACKAGE_AND_TEST_STATUSES.include?(status) # rubocop:disable Style/GuardClause
          fail NEEDS_PACKAGE_AND_TEST_MESSAGE
        else
          warn WARN_PACKAGE_AND_TEST_MESSAGE unless status == 'success'
        end
      end
      # rubocop:enable Style/SignalException

      def encourage_package_and_qa_execution?
        valid_stable_branch? &&
          !has_only_documentation_changes? &&
          !has_flaky_failure_label?
      end

      def valid_stable_branch?
        !!stable_target_branch && !helper.security_mr?
      end

      private

      def package_and_test_bridge_and_pipeline_status
        mr_head_pipeline_id = gitlab.mr_json.dig('head_pipeline', 'id')
        return unless mr_head_pipeline_id

        bridge = package_and_test_bridge(mr_head_pipeline_id)

        return unless bridge

        if bridge['status'] == 'created'
          bridge['status']
        else
          bridge.fetch('downstream_pipeline')&.fetch('status')
        end
      end

      def package_and_test_bridge(mr_head_pipeline_id)
        gitlab
          .api
          .pipeline_bridges(helper.mr_target_project_id, mr_head_pipeline_id)
          &.find { |bridge| bridge['name'].include?('package-and-test') }
      end

      def stable_target_branch
        helper.mr_target_branch.match(STABLE_BRANCH_REGEX)
      end

      def has_feature_label?
        helper.mr_has_labels?('type::feature')
      end

      def has_bug_label?
        helper.mr_has_labels?('type::bug')
      end

      def has_pipeline_expedite_label?
        helper.mr_has_labels?('pipeline:expedite')
      end

      def has_flaky_failure_label?
        helper.mr_has_labels?('failure::flaky-test')
      end

      def bug_fixes_only?
        has_bug_label? || has_only_documentation_changes?
      end

      def has_only_documentation_changes?
        categories_changed = helper.changes_by_category.keys
        return false unless categories_changed.size == 1
        return true if categories_changed.first == :docs

        false
      end

      def targeting_patchable_version?
        raise VersionApiError if last_three_minor_versions.empty?

        last_three_minor_versions.include?(targeted_version)
      rescue VersionApiError
        warn FAILED_VERSION_REQUEST_MESSAGE
        true
      end

      def last_three_minor_versions
        return [] unless versions

        current_version = versions.first.match(VERSION_REGEX)
        version_1 = previous_minor_version(current_version)
        version_2 = previous_minor_version(version_1)

        [
          version_to_minor_string(current_version),
          version_to_minor_string(version_1),
          version_to_minor_string(version_2)
        ]
      end

      def targeted_version
        stable_target_branch[1].tr('-', '.')
      end

      def versions(page = 1)
        version_api_endpoint = "https://version.gitlab.com/api/v1/versions?per_page=50&page=#{page}"
        response = HTTParty.get(version_api_endpoint) # rubocop:disable Gitlab/HTTParty

        raise VersionApiError unless response.success?

        version_list = response.parsed_response.map { |v| v['version'] } # rubocop:disable Rails/Pluck

        version_list.sort_by { |v| Gem::Version.new(v) }.reverse
      end

      def previous_minor_version(version)
        previous_minor = version[:minor].to_i - 1

        return "#{version[:major]}.#{previous_minor}".match(VERSION_REGEX) if previous_minor >= 0

        fetch_last_minor_version_for_major(version[:major].to_i - 1)
      end

      def fetch_last_minor_version_for_major(major)
        page = 1
        last_minor_version = nil

        while last_minor_version.nil?
          last_minor_version = versions(page).find do |version|
            version.split('.').first.to_i == major
          end

          break if page > 10

          page += 1
        end

        raise VersionApiError if last_minor_version.nil?

        last_minor_version.match(VERSION_REGEX)
      end

      def version_to_minor_string(version)
        "#{version[:major]}.#{version[:minor]}"
      end
    end
  end
end
