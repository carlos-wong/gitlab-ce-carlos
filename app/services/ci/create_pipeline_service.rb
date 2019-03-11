# frozen_string_literal: true

module Ci
  class CreatePipelineService < BaseService
    attr_reader :pipeline

    CreateError = Class.new(StandardError)

    SEQUENCE = [Gitlab::Ci::Pipeline::Chain::Build,
                Gitlab::Ci::Pipeline::Chain::RemoveUnwantedChatJobs,
                Gitlab::Ci::Pipeline::Chain::Validate::Abilities,
                Gitlab::Ci::Pipeline::Chain::Validate::Repository,
                Gitlab::Ci::Pipeline::Chain::Validate::Config,
                Gitlab::Ci::Pipeline::Chain::Skip,
                Gitlab::Ci::Pipeline::Chain::Limit::Size,
                Gitlab::Ci::Pipeline::Chain::Populate,
                Gitlab::Ci::Pipeline::Chain::Create,
                Gitlab::Ci::Pipeline::Chain::Limit::Activity].freeze

    def execute(source, ignore_skip_ci: false, save_on_errors: true, trigger_request: nil, schedule: nil, merge_request: nil, **options, &block)
      @pipeline = Ci::Pipeline.new

      command = Gitlab::Ci::Pipeline::Chain::Command.new(
        source: source,
        origin_ref: params[:ref],
        checkout_sha: params[:checkout_sha],
        after_sha: params[:after],
        before_sha: params[:before],          # The base SHA of the source branch (i.e merge_request.diff_base_sha).
        source_sha: params[:source_sha],      # The HEAD SHA of the source branch (i.e merge_request.diff_head_sha).
        target_sha: params[:target_sha],      # The HEAD SHA of the target branch.
        trigger_request: trigger_request,
        schedule: schedule,
        merge_request: merge_request,
        ignore_skip_ci: ignore_skip_ci,
        save_incompleted: save_on_errors,
        seeds_block: block,
        variables_attributes: params[:variables_attributes],
        project: project,
        current_user: current_user,
        push_options: params[:push_options],
        chat_data: params[:chat_data],
        **extra_options(options))

      sequence = Gitlab::Ci::Pipeline::Chain::Sequence
        .new(pipeline, command, SEQUENCE)

      sequence.build! do |pipeline, sequence|
        schedule_head_pipeline_update

        if sequence.complete?
          cancel_pending_pipelines if project.auto_cancel_pending_pipelines?
          pipeline_created_counter.increment(source: source)

          pipeline.process!
        end
      end

      pipeline
    end

    def execute!(*args, &block)
      execute(*args, &block).tap do |pipeline|
        unless pipeline.persisted?
          raise CreateError, pipeline.errors.full_messages.join(',')
        end
      end
    end

    private

    def commit
      @commit ||= project.commit(origin_sha || origin_ref)
    end

    def sha
      commit.try(:id)
    end

    def cancel_pending_pipelines
      Gitlab::OptimisticLocking.retry_lock(auto_cancelable_pipelines) do |cancelables|
        cancelables.find_each do |cancelable|
          cancelable.auto_cancel_running(pipeline)
        end
      end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def auto_cancelable_pipelines
      project.ci_pipelines
        .where(ref: pipeline.ref)
        .where.not(id: pipeline.id)
        .where.not(sha: project.commit(pipeline.ref).try(:id))
        .created_or_pending
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def pipeline_created_counter
      @pipeline_created_counter ||= Gitlab::Metrics
        .counter(:pipelines_created_total, "Counter of pipelines created")
    end

    def schedule_head_pipeline_update
      related_merge_requests.each do |merge_request|
        UpdateHeadPipelineForMergeRequestWorker.perform_async(merge_request.id)
      end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def related_merge_requests
      pipeline.project.source_of_merge_requests.opened.where(source_branch: pipeline.ref)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def extra_options(options = {})
      # In Ruby 2.4, even when options is empty, f(**options) doesn't work when f
      # doesn't have any parameters. We reproduce the Ruby 2.5 behavior by
      # checking explicitly that no arguments are given.
      raise ArgumentError if options.any?

      {} # overridden in EE
    end
  end
end
