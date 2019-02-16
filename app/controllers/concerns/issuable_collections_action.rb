# frozen_string_literal: true

module IssuableCollectionsAction
  extend ActiveSupport::Concern
  include IssuableCollections
  include IssuesCalendar

  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def issues
    @issues = issuables_collection
              .non_archived
              .page(params[:page])

    @issuable_meta_data = issuable_meta_data(@issues, collection_type)

    respond_to do |format|
      format.html
      format.atom { render layout: 'xml.atom' }
    end
  end

  def merge_requests
    @merge_requests = issuables_collection.page(params[:page])

    @issuable_meta_data = issuable_meta_data(@merge_requests, collection_type)
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables

  def issues_calendar
    render_issues_calendar(issuables_collection)
  end

  private

  def issuable_sorting_field
    case action_name
    when 'issues'
      Issue::SORTING_PREFERENCE_FIELD
    when 'merge_requests'
      MergeRequest::SORTING_PREFERENCE_FIELD
    else
      nil
    end
  end

  def finder_type
    case action_name
    when 'issues', 'issues_calendar'
      IssuesFinder
    when 'merge_requests'
      MergeRequestsFinder
    else
      nil
    end
  end

  def finder_options
    super.merge(non_archived: true)
  end
end
