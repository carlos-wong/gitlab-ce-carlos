# frozen_string_literal: true

class SearchController < ApplicationController
  include ControllerWithCrossProjectAccessCheck
  include SearchHelper
  include RedisTracking
  include SearchRateLimitable

  RESCUE_FROM_TIMEOUT_ACTIONS = [:count, :show, :autocomplete].freeze

  track_redis_hll_event :show, name: 'i_search_total'

  around_action :allow_gitaly_ref_name_caching

  before_action :block_anonymous_global_searches, :check_scope_global_search_enabled, except: :opensearch
  skip_before_action :authenticate_user!
  requires_cross_project_access if: -> do
    search_term_present = params[:search].present? || params[:term].present?
    search_term_present && !params[:project_id].present?
  end
  before_action :check_search_rate_limit!, only: [:show, :count, :autocomplete]

  rescue_from ActiveRecord::QueryCanceled, with: :render_timeout

  layout 'search'

  feature_category :global_search
  urgency :high, [:opensearch]
  urgency :low, [:count]

  def show
    @project = search_service.project
    @group = search_service.group

    return if params[:search].blank?

    return unless search_term_valid?

    return if check_single_commit_result?

    @search_term = params[:search]
    @sort = params[:sort] || default_sort

    @search_service = Gitlab::View::Presenter::Factory.new(search_service, current_user: current_user).fabricate!
    @scope = @search_service.scope
    @without_count = @search_service.without_count?
    @show_snippets = @search_service.show_snippets?
    @search_results = @search_service.search_results
    @search_objects = @search_service.search_objects
    @search_highlight = @search_service.search_highlight
    @aggregations = @search_service.search_aggregations

    increment_search_counters
  end

  def count
    params.require([:search, :scope])

    scope = search_service.scope

    count = 0
    ApplicationRecord.with_fast_read_statement_timeout do
      count = search_service.search_results.formatted_count(scope)
    end

    # Users switching tabs will keep fetching the same tab counts so it's a
    # good idea to cache in their browser just for a short time. They can still
    # clear cache if they are seeing an incorrect count but inaccurate count is
    # not such a bad thing.
    expires_in 1.minute

    render json: { count: count }
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def autocomplete
    term = params[:term]

    @project = search_service.project
    @ref = params[:project_ref] if params[:project_ref].present?

    render json: search_autocomplete_opts(term).to_json
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def opensearch
  end

  private

  # overridden in EE
  def default_sort
    'created_desc'
  end

  def search_term_valid?
    unless search_service.valid_query_length?
      flash[:alert] = t('errors.messages.search_chars_too_long', count: Gitlab::Search::Params::SEARCH_CHAR_LIMIT)
      return false
    end

    unless search_service.valid_terms_count?
      flash[:alert] = t('errors.messages.search_terms_too_long', count: Gitlab::Search::Params::SEARCH_TERM_LIMIT)
      return false
    end

    true
  end

  def check_single_commit_result?
    return false if params[:force_search_results]
    return false unless @project.present?
    # download_code project policy grants user the read_commit ability
    return false unless Ability.allowed?(current_user, :download_code, @project)

    query = params[:search].strip.downcase
    return false unless Commit.valid_hash?(query)

    commit = @project.commit_by(oid: query)
    return false unless commit.present?

    link = search_path(safe_params.merge(force_search_results: true))
    flash[:notice] = html_escape(_("You have been redirected to the only result; see the %{a_start}search results%{a_end} instead.")) % { a_start: "<a href=\"#{link}\"><u>".html_safe, a_end: '</u></a>'.html_safe }
    redirect_to project_commit_path(@project, commit)

    true
  end

  def increment_search_counters
    Gitlab::UsageDataCounters::SearchCounter.count(:all_searches)

    return if params[:nav_source] != 'navbar'

    Gitlab::UsageDataCounters::SearchCounter.count(:navbar_searches)
  end

  def append_info_to_payload(payload)
    super

    # Merging to :metadata will ensure these are logged as top level keys
    payload[:metadata] ||= {}
    payload[:metadata]['meta.search.group_id'] = params[:group_id]
    payload[:metadata]['meta.search.project_id'] = params[:project_id]
    payload[:metadata]['meta.search.scope'] = params[:scope] || @scope
    payload[:metadata]['meta.search.filters.confidential'] = params[:confidential]
    payload[:metadata]['meta.search.filters.state'] = params[:state]
    payload[:metadata]['meta.search.force_search_results'] = params[:force_search_results]
    payload[:metadata]['meta.search.project_ids'] = params[:project_ids]
    payload[:metadata]['meta.search.search_level'] = params[:search_level]

    if search_service.abuse_detected?
      payload[:metadata]['abuse.confidence'] = Gitlab::Abuse.confidence(:certain)
      payload[:metadata]['abuse.messages'] = search_service.abuse_messages
    end
  end

  def block_anonymous_global_searches
    return unless search_service.global_search?
    return if current_user
    return unless ::Feature.enabled?(:block_anonymous_global_searches, type: :ops)

    store_location_for(:user, request.fullpath)

    redirect_to new_user_session_path, alert: _('You must be logged in to search across all of GitLab')
  end

  def check_scope_global_search_enabled
    return unless search_service.global_search?

    search_allowed = case params[:scope]
                     when 'blobs'
                       Feature.enabled?(:global_search_code_tab, current_user, type: :ops, default_enabled: :yaml)
                     when 'commits'
                       Feature.enabled?(:global_search_commits_tab, current_user, type: :ops, default_enabled: :yaml)
                     when 'issues'
                       Feature.enabled?(:global_search_issues_tab, current_user, type: :ops, default_enabled: :yaml)
                     when 'merge_requests'
                       Feature.enabled?(:global_search_merge_requests_tab, current_user, type: :ops, default_enabled: :yaml)
                     when 'wiki_blobs'
                       Feature.enabled?(:global_search_wiki_tab, current_user, type: :ops, default_enabled: :yaml)
                     when 'users'
                       Feature.enabled?(:global_search_users_tab, current_user, type: :ops, default_enabled: :yaml)
                     else
                       true
                     end

    return if search_allowed

    redirect_to search_path, alert: _('Global Search is disabled for this scope')
  end

  def render_timeout(exception)
    raise exception unless action_name.to_sym.in?(RESCUE_FROM_TIMEOUT_ACTIONS)

    log_exception(exception)

    @timeout = true

    case action_name.to_sym
    when :count
      render json: {}, status: :request_timeout
    when :autocomplete
      render json: [], status: :request_timeout
    else
      render status: :request_timeout
    end
  end
end

SearchController.prepend_mod_with('SearchController')
