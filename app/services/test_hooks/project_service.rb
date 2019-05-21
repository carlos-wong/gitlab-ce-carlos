# frozen_string_literal: true

module TestHooks
  class ProjectService < TestHooks::BaseService
    attr_writer :project

    def project
      @project ||= hook.project
    end

    private

    def push_events_data
      throw(:validation_error, s_('TestHooks|Ensure the project has at least one commit.')) if project.empty_repo?

      Gitlab::DataBuilder::Push.build_sample(project, current_user)
    end

    alias_method :tag_push_events_data, :push_events_data

    def note_events_data
      note = project.notes.first
      throw(:validation_error, s_('TestHooks|Ensure the project has notes.')) unless note.present?

      Gitlab::DataBuilder::Note.build(note, current_user)
    end

    def issues_events_data
      issue = project.issues.first
      throw(:validation_error, s_('TestHooks|Ensure the project has issues.')) unless issue.present?

      issue.to_hook_data(current_user)
    end

    alias_method :confidential_issues_events_data, :issues_events_data

    def merge_requests_events_data
      merge_request = project.merge_requests.first
      throw(:validation_error, s_('TestHooks|Ensure the project has merge requests.')) unless merge_request.present?

      merge_request.to_hook_data(current_user)
    end

    def job_events_data
      build = project.builds.first
      throw(:validation_error, s_('TestHooks|Ensure the project has CI jobs.')) unless build.present?

      Gitlab::DataBuilder::Build.build(build)
    end

    def pipeline_events_data
      pipeline = project.ci_pipelines.first
      throw(:validation_error, s_('TestHooks|Ensure the project has CI pipelines.')) unless pipeline.present?

      Gitlab::DataBuilder::Pipeline.build(pipeline)
    end

    def wiki_page_events_data
      page = project.wiki.list_pages(limit: 1).first
      if !project.wiki_enabled? || page.blank?
        throw(:validation_error, s_('TestHooks|Ensure the wiki is enabled and has pages.'))
      end

      Gitlab::DataBuilder::WikiPage.build(page, current_user, 'create')
    end
  end
end
