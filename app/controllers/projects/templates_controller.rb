# frozen_string_literal: true

class Projects::TemplatesController < Projects::ApplicationController
  before_action :authenticate_user!
  before_action :authorize_can_read_issuable!
  before_action :get_template_class

  def show
    template = @template_type.find(params[:key], project)

    respond_to do |format|
      format.json { render json: template.to_json }
    end
  end

  def names
    templates = @template_type.dropdown_names(project)

    respond_to do |format|
      format.json { render json: templates }
    end
  end

  private

  # User must have:
  # - `read_merge_request` to see merge request templates, or
  # - `read_issue` to see issue templates
  #
  # Note params[:template_type] has a route constraint to limit it to
  # `merge_request` or `issue`
  def authorize_can_read_issuable!
    action = [:read_, params[:template_type]].join

    authorize_action!(action)
  end

  def get_template_class
    template_types = { issue: Gitlab::Template::IssueTemplate, merge_request: Gitlab::Template::MergeRequestTemplate }.with_indifferent_access
    @template_type = template_types[params[:template_type]]
  end
end
