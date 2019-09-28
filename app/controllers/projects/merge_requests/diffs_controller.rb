# frozen_string_literal: true

class Projects::MergeRequests::DiffsController < Projects::MergeRequests::ApplicationController
  include DiffHelper
  include RendersNotes

  before_action :apply_diff_view_cookie!
  before_action :commit
  before_action :define_diff_vars
  before_action :define_diff_comment_vars

  def show
    render_diffs
  end

  def diff_for_path
    render_diffs
  end

  private

  def render_diffs
    @environment = @merge_request.environments_for(current_user).last

    note_positions = renderable_notes.map(&:position).compact
    @diffs.unfold_diff_files(note_positions)

    @diffs.write_cache

    request = {
      current_user: current_user,
      project: @merge_request.project,
      render: ->(partial, locals) { view_to_html_string(partial, locals) }
    }

    render json: DiffsSerializer.new(request).represent(@diffs, additional_attributes)
  end

  def define_diff_vars
    @merge_request_diffs = @merge_request.merge_request_diffs.viewable.order_id_desc
    @compare = commit || find_merge_request_diff_compare
    return render_404 unless @compare

    @diffs = @compare.diffs(diff_options)
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def commit
    return unless commit_id = params[:commit_id].presence
    return unless @merge_request.all_commits.exists?(sha: commit_id)

    @commit ||= @project.commit(commit_id)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  # rubocop: disable CodeReuse/ActiveRecord
  def find_merge_request_diff_compare
    @merge_request_diff =
      if diff_id = params[:diff_id].presence
        @merge_request.merge_request_diffs.viewable.find_by(id: diff_id)
      else
        @merge_request.merge_request_diff
      end

    return unless @merge_request_diff

    @comparable_diffs = @merge_request_diffs.select { |diff| diff.id < @merge_request_diff.id }

    if @start_sha = params[:start_sha].presence
      @start_version = @comparable_diffs.find { |diff| diff.head_commit_sha == @start_sha }

      unless @start_version
        @start_sha = @merge_request_diff.head_commit_sha
        @start_version = @merge_request_diff
      end
    end

    if @start_sha
      @merge_request_diff.compare_with(@start_sha)
    else
      @merge_request_diff
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def additional_attributes
    {
      environment: @environment,
      merge_request: @merge_request,
      merge_request_diff: @merge_request_diff,
      merge_request_diffs: @merge_request_diffs,
      start_version: @start_version,
      start_sha: @start_sha,
      commit: @commit,
      latest_diff: @merge_request_diff&.latest?
    }
  end

  def define_diff_comment_vars
    @new_diff_note_attrs = {
      noteable_type: 'MergeRequest',
      noteable_id: @merge_request.id,
      commit_id: @commit&.id
    }

    @diff_notes_disabled = false

    @use_legacy_diff_notes = !@merge_request.has_complete_diff_refs?

    @grouped_diff_discussions = @merge_request.grouped_diff_discussions(@compare.diff_refs)
    @notes = prepare_notes_for_rendering(@grouped_diff_discussions.values.flatten.flat_map(&:notes), @merge_request)
  end

  def renderable_notes
    define_diff_comment_vars unless @notes

    @notes
  end
end

Projects::MergeRequests::DiffsController.prepend_if_ee('EE::Projects::MergeRequests::DiffsController')
