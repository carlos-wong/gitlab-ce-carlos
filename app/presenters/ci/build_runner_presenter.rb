# frozen_string_literal: true

module Ci
  class BuildRunnerPresenter < SimpleDelegator
    include Gitlab::Utils::StrongMemoize

    RUNNER_REMOTE_TAG_PREFIX = 'refs/tags/'
    RUNNER_REMOTE_BRANCH_PREFIX = 'refs/remotes/origin/'

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
      if git_depth_variable
        git_depth_variable[:value]
      elsif Feature.enabled?(:ci_project_git_depth, default_enabled: true)
        project.ci_default_git_depth
      end.to_i
    end

    def refspecs
      specs = []
      specs << refspec_for_pipeline_ref if merge_request_ref?
      specs << refspec_for_persistent_ref if persistent_ref_exist?

      if git_depth > 0
        specs << refspec_for_branch(ref) if branch? || legacy_detached_merge_request_pipeline?
        specs << refspec_for_tag(ref) if tag?
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

    def refspec_for_pipeline_ref
      "+#{ref}:#{ref}"
    end

    def refspec_for_persistent_ref
      "+#{persistent_ref_path}:#{persistent_ref_path}"
    end

    def persistent_ref_exist?
      pipeline.persistent_ref.exist?
    end

    def persistent_ref_path
      pipeline.persistent_ref.path
    end

    def git_depth_variable
      strong_memoize(:git_depth_variable) do
        variables&.find { |variable| variable[:key] == 'GIT_DEPTH' }
      end
    end
  end
end
