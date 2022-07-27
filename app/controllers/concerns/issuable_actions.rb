# frozen_string_literal: true

module IssuableActions
  extend ActiveSupport::Concern
  include Gitlab::Utils::StrongMemoize
  include Gitlab::Cache::Helpers
  include SpammableActions::AkismetMarkAsSpamAction
  include SpammableActions::CaptchaCheck::HtmlFormatActionsSupport
  include SpammableActions::CaptchaCheck::JsonFormatActionsSupport

  included do
    before_action :authorize_destroy_issuable!, only: :destroy
    before_action :check_destroy_confirmation!, only: :destroy
    before_action :authorize_admin_issuable!, only: :bulk_update
  end

  def show
    respond_to do |format|
      format.html do
        @issuable_sidebar = serializer.represent(issuable, serializer: 'sidebar') # rubocop:disable Gitlab/ModuleWithInstanceVariables
        render 'show'
      end

      format.json do
        render json: serializer.represent(issuable, serializer: params[:serializer])
      end
    end
  end

  def update
    updated_issuable = update_service.execute(issuable)
    # NOTE: We only assign the instance variable on this line, and use the local variable
    # everywhere else in the method, to avoid having to add multiple `rubocop:disable` comments.
    @issuable = updated_issuable # rubocop:disable Gitlab/ModuleWithInstanceVariables

    # NOTE: This check for `is_a?(Spammable)` is necessary because not all
    # possible `issuable` types implement Spammable. Once they all implement Spammable,
    # this check can be removed.
    if updated_issuable.is_a?(Spammable)
      respond_to do |format|
        format.html do
          if updated_issuable.valid?
            # NOTE: This redirect is intentionally only performed in the case where the valid updated
            # issuable is a spammable, and intentionally is not performed below in the
            # valid non-spammable case. This preserves the legacy behavior of this action.
            redirect_to spammable_path
          else
            with_captcha_check_html_format(spammable: spammable) { render :edit }
          end
        end

        format.json do
          with_captcha_check_json_format(spammable: spammable) { render_entity_json }
        end
      end
    else
      respond_to do |format|
        format.html do
          render :edit
        end

        format.json do
          render_entity_json
        end
      end
    end
  rescue ActiveRecord::StaleObjectError
    render_conflict_response
  end

  def realtime_changes
    Gitlab::PollingInterval.set_header(response, interval: 3_000)

    response = {
      title: view_context.markdown_field(issuable, :title),
      title_text: issuable.title,
      description: view_context.markdown_field(issuable, :description),
      description_text: issuable.description,
      task_status: issuable.task_status,
      lock_version: issuable.lock_version
    }

    if issuable.edited?
      response[:updated_at] = issuable.last_edited_at.to_time.iso8601
      response[:updated_by_name] = issuable.last_edited_by.name
      response[:updated_by_path] = user_path(issuable.last_edited_by)
    end

    render json: response
  end

  def destroy
    Issuable::DestroyService.new(project: issuable.project, current_user: current_user).execute(issuable)

    name = issuable.human_class_name
    flash[:notice] = "The #{name} was successfully deleted."
    index_path = polymorphic_path([parent, issuable.class])

    respond_to do |format|
      format.html { redirect_to index_path }
      format.json do
        render json: {
          web_url: index_path
        }
      end
    end
  end

  def check_destroy_confirmation!
    return true if params[:destroy_confirm]

    error_message = "Destroy confirmation not provided for #{issuable.human_class_name}"
    exception = RuntimeError.new(error_message)
    Gitlab::ErrorTracking.track_exception(
      exception,
      project_path: issuable.project.full_path,
      issuable_type: issuable.class.name,
      issuable_id: issuable.id
    )

    index_path = polymorphic_path([parent, issuable.class])

    respond_to do |format|
      format.html do
        flash[:notice] = error_message
        redirect_to index_path
      end
      format.json do
        render json: { errors: error_message }, status: :unprocessable_entity
      end
    end
  end

  def bulk_update
    result = Issuable::BulkUpdateService.new(parent, current_user, bulk_update_params).execute(resource_name)

    if result.success?
      quantity = result.payload[:count]
      render json: { notice: "#{quantity} #{resource_name.pluralize(quantity)} updated" }
    elsif result.error?
      render json: { errors: result.message }, status: result.http_status
    end
  end

  # rubocop:disable CodeReuse/ActiveRecord
  def discussions
    notes = NotesFinder.new(current_user, finder_params_for_issuable).execute
                .inc_relations_for_view
                .includes(:noteable)
                .fresh

    if paginated_discussions
      paginated_discussions_by_type = paginated_discussions.records.group_by(&:table_name)

      notes = if paginated_discussions_by_type['notes'].present?
                notes.with_discussion_ids(paginated_discussions_by_type['notes'].map(&:discussion_id))
              else
                notes.none
              end

      response.headers['X-Next-Page-Cursor'] = paginated_discussions.cursor_for_next_page if paginated_discussions.has_next_page?
    end

    if notes_filter != UserPreference::NOTES_FILTERS[:only_comments]
      notes = ResourceEvents::MergeIntoNotesService.new(issuable, current_user, paginated_notes: paginated_discussions_by_type).execute(notes)
    end

    notes = prepare_notes_for_rendering(notes)
    notes = notes.select { |n| n.readable_by?(current_user) }

    discussions = Discussion.build_collection(notes, issuable)

    if issuable.is_a?(MergeRequest)
      render_cached(discussions, with: discussion_serializer, cache_context: -> (_) { discussion_cache_context }, context: self)
    elsif issuable.is_a?(Issue)
      render json: discussion_serializer.represent(discussions, context: self) if stale?(etag: [discussion_cache_context, discussions])
    else
      render json: discussion_serializer.represent(discussions, context: self)
    end
  end
  # rubocop:enable CodeReuse/ActiveRecord

  private

  def paginated_discussions
    return if params[:per_page].blank?
    return if issuable.instance_of?(MergeRequest) && Feature.disabled?(:paginated_mr_discussions, project)

    strong_memoize(:paginated_discussions) do
      issuable
        .discussion_root_note_ids(notes_filter: notes_filter)
        .keyset_paginate(cursor: params[:cursor], per_page: params[:per_page].to_i)
    end
  end

  def notes_filter
    strong_memoize(:notes_filter) do
      notes_filter_param = params[:notes_filter]&.to_i

      # GitLab Geo does not expect database UPDATE or INSERT statements to happen
      # on GET requests.
      # This is just a fail-safe in case notes_filter is sent via GET request in GitLab Geo.
      # In some cases, we also force the filter to not be persisted with the `persist_filter` param
      if Gitlab::Database.read_only? || params[:persist_filter] == 'false'
        notes_filter_param || current_user&.notes_filter_for(issuable)
      else
        notes_filter = current_user&.set_notes_filter(notes_filter_param, issuable) || notes_filter_param

        # We need to invalidate the cache for polling notes otherwise it will
        # ignore the filter.
        # The ideal would be to invalidate the cache for each user.
        issuable.expire_note_etag_cache if notes_filter_updated?

        notes_filter
      end
    end
  end

  def notes_filter_updated?
    current_user&.user_preference&.previous_changes&.any?
  end

  def discussion_cache_context
    [current_user&.cache_key, project.team.human_max_access(current_user&.id)].join(':')
  end

  def discussion_serializer
    DiscussionSerializer.new(project: project, noteable: issuable, current_user: current_user, note_entity: ProjectNoteEntity)
  end

  def render_conflict_response
    respond_to do |format|
      format.html do
        @conflict = true # rubocop:disable Gitlab/ModuleWithInstanceVariables
        render :edit
      end

      format.json do
        render json: {
          errors: [
            "Someone edited this #{issuable.human_class_name} at the same time you did. Please refresh your browser and make sure your changes will not unintentionally remove theirs."
          ]
        }, status: :conflict
      end
    end
  end

  def authorize_destroy_issuable!
    unless can?(current_user, :"destroy_#{issuable.to_ability_name}", issuable)
      access_denied!
    end
  end

  def authorize_admin_issuable!
    unless can?(current_user, :"admin_#{resource_name}", parent)
      access_denied!
    end
  end

  def authorize_update_issuable!
    render_404 unless can?(current_user, :"update_#{resource_name}", issuable)
  end

  def bulk_update_params
    params.require(:update).permit(bulk_update_permitted_keys)
  end

  def bulk_update_permitted_keys
    [
      :issuable_ids,
      :assignee_id,
      :milestone_id,
      :sprint_id,
      :state_event,
      :subscription_event,
      assignee_ids: [],
      add_label_ids: [],
      remove_label_ids: []
    ]
  end

  def resource_name
    @resource_name ||= controller_name.singularize
  end

  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def render_entity_json
    if @issuable.valid?
      render json: serializer.represent(@issuable)
    else
      render json: { errors: @issuable.errors.full_messages }, status: :unprocessable_entity
    end
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables

  def serializer
    raise NotImplementedError
  end

  def update_service
    raise NotImplementedError
  end

  def parent
    @project || @group # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def finder_params_for_issuable
    {
        target: @issuable,
        notes_filter: notes_filter
    }.tap { |new_params| new_params[:project] = project if respond_to?(:project, true) }
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables
end

IssuableActions.prepend_mod_with('IssuableActions')
