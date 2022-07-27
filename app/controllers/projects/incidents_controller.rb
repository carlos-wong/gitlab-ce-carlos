# frozen_string_literal: true

class Projects::IncidentsController < Projects::ApplicationController
  include IssuableActions
  include Gitlab::Utils::StrongMemoize

  before_action :authorize_read_issue!
  before_action :load_incident, only: [:show]
  before_action do
    push_frontend_feature_flag(:incident_timeline, @project)
    push_force_frontend_feature_flag(:work_items, @project&.work_items_feature_flag_enabled?)
    push_frontend_feature_flag(:work_items_mvc_2)
    push_frontend_feature_flag(:work_items_hierarchy, @project)
  end

  feature_category :incident_management
  urgency :low

  def index
  end

  private

  def incident
    strong_memoize(:incident) do
      incident_finder
        .execute
        .inc_relations_for_view
        .iid_in(params[:id])
        .without_order
        .first
    end
  end

  def load_incident
    @issue = incident # needed by rendered view
    return render_404 unless can?(current_user, :read_issue, incident)

    @noteable = incident
    @note = incident.project.notes.new(noteable: issuable)
  end

  alias_method :issuable, :incident

  def incident_finder
    IssuesFinder.new(current_user, project_id: @project.id, issue_types: :incident)
  end

  def serializer
    IssueSerializer.new(current_user: current_user, project: incident.project)
  end
end

Projects::IncidentsController.prepend_mod
