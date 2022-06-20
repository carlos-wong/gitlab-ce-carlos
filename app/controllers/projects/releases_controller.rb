# frozen_string_literal: true

class Projects::ReleasesController < Projects::ApplicationController
  # Authorize
  before_action :require_non_empty_project, except: [:index]
  before_action :release, only: %i[edit show update downloads]
  before_action :authorize_read_release!
  before_action :authorize_update_release!, only: %i[edit update]
  before_action :authorize_create_release!, only: :new
  before_action :validate_suffix_path, :fetch_latest_tag, only: :latest_permalink

  feature_category :release_orchestration

  def index
    respond_to do |format|
      format.html do
        require_non_empty_project
      end
      format.json { render json: releases }
    end
  end

  def downloads
    redirect_to link.url
  end

  def latest_permalink
    unless @latest_tag.present?
      return render_404
    end

    query_parameters_except_order_by = request.query_parameters.except(:order_by)

    redirect_url = project_release_url(@project, @latest_tag)
    redirect_url += "/#{params[:suffix_path]}" if params[:suffix_path]
    redirect_url += "?#{query_parameters_except_order_by.compact.to_param}" if query_parameters_except_order_by.present?

    redirect_to redirect_url
  end

  private

  def releases(params = {})
    ReleasesFinder.new(@project, current_user, params).execute
  end

  def authorize_update_release!
    access_denied! unless can?(current_user, :update_release, release)
  end

  def release
    @release ||= project.releases.find_by_tag!(sanitized_tag_name)
  end

  def link
    release.links.find_by_filepath!(sanitized_filepath)
  end

  def sanitized_filepath
    "/#{CGI.unescape(params[:filepath])}"
  end

  def sanitized_tag_name
    CGI.unescape(params[:tag])
  end

  # Default order_by is 'released_at', which is set in ReleasesFinder.
  # Also if the passed order_by is invalid, we reject and default to 'released_at'.
  def fetch_latest_tag
    allowed_values = ['released_at']

    params.reject! { |key, value| key.to_sym == :order_by && !allowed_values.any?(value) }

    @latest_tag = releases(order_by: params[:order_by]).first&.tag
  end

  def validate_suffix_path
    Gitlab::Utils.check_path_traversal!(params[:suffix_path]) if params[:suffix_path]
  end
end
