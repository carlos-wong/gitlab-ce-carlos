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
      else
        project.ci_default_git_depth
      end.to_i
    end

    def runner_variables
      variables.sort_and_expand_all(keep_undefined: true).to_runner_variables
    end

    def refspecs
      specs = []
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

    # rubocop: disable CodeReuse/ActiveRecord
    def all_dependencies
      dependencies = super
      ActiveRecord::Associations::Preloader.new.preload(dependencies, :job_artifacts_archive)
      dependencies
    end
    # rubocop: enable CodeReuse/ActiveRecord

    private

    def create_archive(artifacts)
      return unless artifacts[:untracked] || artifacts[:paths]

      BuildArtifact.for_archive(artifacts).to_h.tap do |artifact|
        artifact.delete(:exclude) unless artifact[:exclude].present?
      end
    end

    def create_reports(reports, expire_in:)
      return unless reports&.any?

      reports.map { |report| BuildArtifact.for_report(report, expire_in).to_h.compact }
    end

    BuildArtifact = Struct.new(:name, :untracked, :paths, :exclude, :when, :expire_in, :artifact_type, :artifact_format, keyword_init: true) do
      def self.for_archive(artifacts)
        self.new(
          artifact_type: :archive,
          artifact_format: :zip,
          name: artifacts[:name],
          untracked: artifacts[:untracked],
          paths: artifacts[:paths],
          when: artifacts[:when],
          expire_in: artifacts[:expire_in],
          exclude: artifacts[:exclude]
        )
      end

      def self.for_report(report, expire_in)
        type, params = report

        if type == :coverage_report
          artifact_type = params[:coverage_format].to_sym
          paths = [params[:path]]
        else
          artifact_type = type
          paths = params
        end

        self.new(
          artifact_type: artifact_type,
          artifact_format: ::Ci::JobArtifact::TYPE_AND_FORMAT_PAIRS.fetch(artifact_type),
          name: ::Ci::JobArtifact::DEFAULT_FILE_NAMES.fetch(artifact_type),
          paths: paths,
          when: 'always',
          expire_in: expire_in
        )
      end
    end

    def refspec_for_branch(ref = '*')
      "+#{Gitlab::Git::BRANCH_REF_PREFIX}#{ref}:#{RUNNER_REMOTE_BRANCH_PREFIX}#{ref}"
    end

    def refspec_for_tag(ref = '*')
      "+#{Gitlab::Git::TAG_REF_PREFIX}#{ref}:#{RUNNER_REMOTE_TAG_PREFIX}#{ref}"
    end

    def refspec_for_persistent_ref
      "+#{pipeline.persistent_ref.path}:#{pipeline.persistent_ref.path}"
    end

    def persistent_ref_exist?
      ##
      # Persistent refs for pipelines definitely exist from GitLab 12.4,
      # hence, we don't need to check the ref existence before passing it to runners.
      # Checking refs pressurizes gitaly node and should be avoided.
      # Issue: https://gitlab.com/gitlab-com/gl-infra/production/-/issues/2143
      return true if Feature.enabled?(:ci_skip_persistent_ref_existence_check)

      pipeline.persistent_ref.exist?
    end

    def git_depth_variable
      strong_memoize(:git_depth_variable) do
        variables&.find { |variable| variable[:key] == 'GIT_DEPTH' }
      end
    end
  end
end

Ci::BuildRunnerPresenter.prepend_mod_with('Ci::BuildRunnerPresenter')
