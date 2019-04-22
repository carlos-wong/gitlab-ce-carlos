# frozen_string_literal: true

module Ci
  class BuildRunnerPresenter < SimpleDelegator
    include Gitlab::Utils::StrongMemoize

    DEFAULT_GIT_DEPTH_MERGE_REQUEST = 10
    RUNNER_REMOTE_TAG_PREFIX = 'refs/tags/'.freeze
    RUNNER_REMOTE_BRANCH_PREFIX = 'refs/remotes/origin/'.freeze

    def artifacts
      return unless options[:artifacts]

      list = []
      list << create_archive(options[:artifacts])
      list << create_reports(options[:artifacts][:reports], expire_in: options[:artifacts][:expire_in])
      list.flatten.compact
    end

    def ref_type
      if tag
        'tag'
      else
        'branch'
      end
    end

    def git_depth
      strong_memoize(:git_depth) do
        git_depth = variables&.find { |variable| variable[:key] == 'GIT_DEPTH' }&.dig(:value)
        git_depth ||= DEFAULT_GIT_DEPTH_MERGE_REQUEST if merge_request_ref?
        git_depth.to_i
      end
    end

    def refspecs
      specs = []

      if git_depth > 0
        specs << refspec_for_branch(ref) if branch? || legacy_detached_merge_request_pipeline?
        specs << refspec_for_tag(ref) if tag?
        specs << refspec_for_merge_request_ref if merge_request_ref?
      else
        specs << refspec_for_branch
        specs << refspec_for_tag
      end

      specs
    end

    private

    def create_archive(artifacts)
      return unless artifacts[:untracked] || artifacts[:paths]

      {
        artifact_type: :archive,
        artifact_format: :zip,
        name: artifacts[:name],
        untracked: artifacts[:untracked],
        paths: artifacts[:paths],
        when: artifacts[:when],
        expire_in: artifacts[:expire_in]
      }
    end

    def create_reports(reports, expire_in:)
      return unless reports&.any?

      reports.map do |report_type, report_paths|
        {
          artifact_type: report_type.to_sym,
          artifact_format: ::Ci::JobArtifact::TYPE_AND_FORMAT_PAIRS.fetch(report_type.to_sym),
          name: ::Ci::JobArtifact::DEFAULT_FILE_NAMES.fetch(report_type.to_sym),
          paths: report_paths,
          when: 'always',
          expire_in: expire_in
        }
      end
    end

    def refspec_for_branch(ref = '*')
      "+#{Gitlab::Git::BRANCH_REF_PREFIX}#{ref}:#{RUNNER_REMOTE_BRANCH_PREFIX}#{ref}"
    end

    def refspec_for_tag(ref = '*')
      "+#{Gitlab::Git::TAG_REF_PREFIX}#{ref}:#{RUNNER_REMOTE_TAG_PREFIX}#{ref}"
    end

    def refspec_for_merge_request_ref
      "+#{ref}:#{ref}"
    end
  end
end
