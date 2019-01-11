# frozen_string_literal: true

module QuickActions
  class InterpretService < BaseService
    include Gitlab::Utils::StrongMemoize
    include Gitlab::QuickActions::Dsl

    attr_reader :issuable

    SHRUG = '¯\\＿(ツ)＿/¯'.freeze
    TABLEFLIP = '(╯°□°)╯︵ ┻━┻'.freeze

    # Takes an issuable and returns an array of all the available commands
    # represented with .to_h
    def available_commands(issuable)
      @issuable = issuable

      self.class.command_definitions.map do |definition|
        next unless definition.available?(self)

        definition.to_h(self)
      end.compact
    end

    # Takes a text and interprets the commands that are extracted from it.
    # Returns the content without commands, and hash of changes to be applied to a record.
    def execute(content, issuable, only: nil)
      return [content, {}] unless current_user.can?(:use_quick_actions)

      @issuable = issuable
      @updates = {}

      content, commands = extractor.extract_commands(content, only: only)
      extract_updates(commands)

      [content, @updates]
    end

    # Takes a text and interprets the commands that are extracted from it.
    # Returns the content without commands, and array of changes explained.
    def explain(content, issuable)
      return [content, []] unless current_user.can?(:use_quick_actions)

      @issuable = issuable

      content, commands = extractor.extract_commands(content)
      commands = explain_commands(commands)
      [content, commands]
    end

    private

    def extractor
      Gitlab::QuickActions::Extractor.new(self.class.command_definitions)
    end

    desc do
      "Close this #{issuable.to_ability_name.humanize(capitalize: false)}"
    end
    explanation do
      "Closes this #{issuable.to_ability_name.humanize(capitalize: false)}."
    end
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        issuable.open? &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    command :close do
      @updates[:state_event] = 'close'
    end

    desc do
      "Reopen this #{issuable.to_ability_name.humanize(capitalize: false)}"
    end
    explanation do
      "Reopens this #{issuable.to_ability_name.humanize(capitalize: false)}."
    end
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        issuable.closed? &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    command :reopen do
      @updates[:state_event] = 'reopen'
    end

    desc 'Merge (when the pipeline succeeds)'
    explanation 'Merges this merge request when the pipeline succeeds.'
    condition do
      last_diff_sha = params && params[:merge_request_diff_head_sha]
      issuable.is_a?(MergeRequest) &&
        issuable.persisted? &&
        issuable.mergeable_with_quick_action?(current_user, autocomplete_precheck: !last_diff_sha, last_diff_sha: last_diff_sha)
    end
    command :merge do
      @updates[:merge] = params[:merge_request_diff_head_sha]
    end

    desc 'Change title'
    explanation do |title_param|
      "Changes the title to \"#{title_param}\"."
    end
    params '<New title>'
    condition do
      issuable.persisted? &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    command :title do |title_param|
      @updates[:title] = title_param
    end

    desc 'Assign'
    # rubocop: disable CodeReuse/ActiveRecord
    explanation do |users|
      users = issuable.allows_multiple_assignees? ? users : users.take(1)
      "Assigns #{users.map(&:to_reference).to_sentence}."
    end
    # rubocop: enable CodeReuse/ActiveRecord
    params do
      issuable.allows_multiple_assignees? ? '@user1 @user2' : '@user'
    end
    condition do
      current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    parse_params do |assignee_param|
      extract_users(assignee_param)
    end
    command :assign do |users|
      next if users.empty?

      if issuable.allows_multiple_assignees?
        @updates[:assignee_ids] ||= issuable.assignees.map(&:id)
        @updates[:assignee_ids] += users.map(&:id)
      else
        @updates[:assignee_ids] = [users.first.id]
      end
    end

    desc do
      if issuable.allows_multiple_assignees?
        'Remove all or specific assignee(s)'
      else
        'Remove assignee'
      end
    end
    explanation do |users = nil|
      assignees = issuable.assignees
      assignees &= users if users.present? && issuable.allows_multiple_assignees?
      "Removes #{'assignee'.pluralize(assignees.size)} #{assignees.map(&:to_reference).to_sentence}."
    end
    params do
      issuable.allows_multiple_assignees? ? '@user1 @user2' : ''
    end
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        issuable.assignees.any? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    parse_params do |unassign_param|
      # When multiple users are assigned, all will be unassigned if multiple assignees are no longer allowed
      extract_users(unassign_param) if issuable.allows_multiple_assignees?
    end
    command :unassign do |users = nil|
      if issuable.allows_multiple_assignees? && users&.any?
        @updates[:assignee_ids] ||= issuable.assignees.map(&:id)
        @updates[:assignee_ids] -= users.map(&:id)
      else
        @updates[:assignee_ids] = []
      end
    end

    desc 'Set milestone'
    explanation do |milestone|
      "Sets the milestone to #{milestone.to_reference}." if milestone
    end
    params '%"milestone"'
    condition do
      current_user.can?(:"admin_#{issuable.to_ability_name}", project) &&
        find_milestones(project, state: 'active').any?
    end
    parse_params do |milestone_param|
      extract_references(milestone_param, :milestone).first ||
        find_milestones(project, title: milestone_param.strip).first
    end
    command :milestone do |milestone|
      @updates[:milestone_id] = milestone.id if milestone
    end

    desc 'Remove milestone'
    explanation do
      "Removes #{issuable.milestone.to_reference(format: :name)} milestone."
    end
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        issuable.milestone_id? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :remove_milestone do
      @updates[:milestone_id] = nil
    end

    desc 'Add label(s)'
    explanation do |labels_param|
      labels = find_label_references(labels_param)

      "Adds #{labels.join(' ')} #{'label'.pluralize(labels.count)}." if labels.any?
    end
    params '~label1 ~"label 2"'
    condition do
      parent &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", parent) &&
        find_labels.any?
    end
    command :label do |labels_param|
      label_ids = find_label_ids(labels_param)

      if label_ids.any?
        @updates[:add_label_ids] ||= []
        @updates[:add_label_ids] += label_ids

        @updates[:add_label_ids].uniq!
      end
    end

    desc 'Remove all or specific label(s)'
    explanation do |labels_param = nil|
      if labels_param.present?
        labels = find_label_references(labels_param)
        "Removes #{labels.join(' ')} #{'label'.pluralize(labels.count)}." if labels.any?
      else
        'Removes all labels.'
      end
    end
    params '~label1 ~"label 2"'
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        issuable.labels.any? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", parent)
    end
    command :unlabel do |labels_param = nil|
      if labels_param.present?
        label_ids = find_label_ids(labels_param)

        if label_ids.any?
          @updates[:remove_label_ids] ||= []
          @updates[:remove_label_ids] += label_ids

          @updates[:remove_label_ids].uniq!
        end
      else
        @updates[:label_ids] = []
      end
    end

    desc 'Replace all label(s)'
    explanation do |labels_param|
      labels = find_label_references(labels_param)
      "Replaces all labels with #{labels.join(' ')} #{'label'.pluralize(labels.count)}." if labels.any?
    end
    params '~label1 ~"label 2"'
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        issuable.labels.any? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :relabel do |labels_param|
      label_ids = find_label_ids(labels_param)

      if label_ids.any?
        @updates[:label_ids] ||= []
        @updates[:label_ids] += label_ids

        @updates[:label_ids].uniq!
      end
    end

    desc 'Copy labels and milestone from other issue or merge request'
    explanation do |source_issuable|
      "Copy labels and milestone from #{source_issuable.to_reference}."
    end
    params '#issue | !merge_request'
    condition do
      [MergeRequest, Issue].include?(issuable.class) &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    parse_params do |issuable_param|
      extract_references(issuable_param, :issue).first ||
        extract_references(issuable_param, :merge_request).first
    end
    command :copy_metadata do |source_issuable|
      if source_issuable.present? && source_issuable.project.id == issuable.project.id
        @updates[:add_label_ids] = source_issuable.labels.map(&:id)
        @updates[:milestone_id] = source_issuable.milestone.id if source_issuable.milestone
      end
    end

    desc 'Add a todo'
    explanation 'Adds a todo.'
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        !TodoService.new.todo_exist?(issuable, current_user)
    end
    command :todo do
      @updates[:todo_event] = 'add'
    end

    desc 'Mark todo as done'
    explanation 'Marks todo as done.'
    condition do
      issuable.persisted? &&
        TodoService.new.todo_exist?(issuable, current_user)
    end
    command :done do
      @updates[:todo_event] = 'done'
    end

    desc 'Subscribe'
    explanation do
      "Subscribes to this #{issuable.to_ability_name.humanize(capitalize: false)}."
    end
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        !issuable.subscribed?(current_user, project)
    end
    command :subscribe do
      @updates[:subscription_event] = 'subscribe'
    end

    desc 'Unsubscribe'
    explanation do
      "Unsubscribes from this #{issuable.to_ability_name.humanize(capitalize: false)}."
    end
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted? &&
        issuable.subscribed?(current_user, project)
    end
    command :unsubscribe do
      @updates[:subscription_event] = 'unsubscribe'
    end

    desc 'Set due date'
    explanation do |due_date|
      "Sets the due date to #{due_date.to_s(:medium)}." if due_date
    end
    params '<in 2 days | this Friday | December 31st>'
    condition do
      issuable.respond_to?(:due_date) &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    parse_params do |due_date_param|
      Chronic.parse(due_date_param).try(:to_date)
    end
    command :due do |due_date|
      @updates[:due_date] = due_date if due_date
    end

    desc 'Remove due date'
    explanation 'Removes the due date.'
    condition do
      issuable.persisted? &&
        issuable.respond_to?(:due_date) &&
        issuable.due_date? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :remove_due_date do
      @updates[:due_date] = nil
    end

    desc 'Toggle the Work In Progress status'
    explanation do
      verb = issuable.work_in_progress? ? 'Unmarks' : 'Marks'
      noun = issuable.to_ability_name.humanize(capitalize: false)
      "#{verb} this #{noun} as Work In Progress."
    end
    condition do
      issuable.respond_to?(:work_in_progress?) &&
        # Allow it to mark as WIP on MR creation page _or_ through MR notes.
        (issuable.new_record? || current_user.can?(:"update_#{issuable.to_ability_name}", issuable))
    end
    command :wip do
      @updates[:wip_event] = issuable.work_in_progress? ? 'unwip' : 'wip'
    end

    desc 'Toggle emoji award'
    explanation do |name|
      "Toggles :#{name}: emoji award." if name
    end
    params ':emoji:'
    condition do
      issuable.is_a?(Issuable) &&
        issuable.persisted?
    end
    parse_params do |emoji_param|
      match = emoji_param.match(Banzai::Filter::EmojiFilter.emoji_pattern)
      match[1] if match
    end
    command :award do |name|
      if name && issuable.user_can_award?(current_user)
        @updates[:emoji_award] = name
      end
    end

    desc 'Set time estimate'
    explanation do |time_estimate|
      time_estimate = Gitlab::TimeTrackingFormatter.output(time_estimate)

      "Sets time estimate to #{time_estimate}." if time_estimate
    end
    params '<1w 3d 2h 14m>'
    condition do
      current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    parse_params do |raw_duration|
      Gitlab::TimeTrackingFormatter.parse(raw_duration)
    end
    command :estimate do |time_estimate|
      if time_estimate
        @updates[:time_estimate] = time_estimate
      end
    end

    desc 'Add or subtract spent time'
    explanation do |time_spent, time_spent_date|
      if time_spent
        if time_spent > 0
          verb = 'Adds'
          value = time_spent
        else
          verb = 'Subtracts'
          value = -time_spent
        end

        "#{verb} #{Gitlab::TimeTrackingFormatter.output(value)} spent time."
      end
    end
    params '<time(1h30m | -1h30m)> <date(YYYY-MM-DD)>'
    condition do
      issuable.is_a?(TimeTrackable) &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", issuable)
    end
    parse_params do |raw_time_date|
      Gitlab::QuickActions::SpendTimeAndDateSeparator.new(raw_time_date).execute
    end
    command :spend do |time_spent, time_spent_date|
      if time_spent
        @updates[:spend_time] = {
          duration: time_spent,
          user_id: current_user.id,
          spent_at: time_spent_date
        }
      end
    end

    desc 'Remove time estimate'
    explanation 'Removes time estimate.'
    condition do
      issuable.persisted? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :remove_estimate do
      @updates[:time_estimate] = 0
    end

    desc 'Remove spent time'
    explanation 'Removes spent time.'
    condition do
      issuable.persisted? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :remove_time_spent do
      @updates[:spend_time] = { duration: :reset, user_id: current_user.id }
    end

    desc "Append the comment with #{SHRUG}"
    params '<Comment>'
    substitution :shrug do |comment|
      "#{comment} #{SHRUG}"
    end

    desc "Append the comment with #{TABLEFLIP}"
    params '<Comment>'
    substitution :tableflip do |comment|
      "#{comment} #{TABLEFLIP}"
    end

    desc "Lock the discussion"
    explanation "Locks the discussion"
    condition do
      [MergeRequest, Issue].include?(issuable.class) &&
        issuable.persisted? &&
        !issuable.discussion_locked? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", issuable)
    end
    command :lock do
      @updates[:discussion_locked] = true
    end

    desc "Unlock the discussion"
    explanation "Unlocks the discussion"
    condition do
      [MergeRequest, Issue].include?(issuable.class) &&
        issuable.persisted? &&
        issuable.discussion_locked? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", issuable)
    end
    command :unlock do
      @updates[:discussion_locked] = false
    end

    # This is a dummy command, so that it appears in the autocomplete commands
    desc 'CC'
    params '@user'
    command :cc

    desc 'Set target branch'
    explanation do |branch_name|
      "Sets target branch to #{branch_name}."
    end
    params '<Local branch name>'
    condition do
      issuable.respond_to?(:target_branch) &&
        (current_user.can?(:"update_#{issuable.to_ability_name}", issuable) ||
          issuable.new_record?)
    end
    parse_params do |target_branch_param|
      target_branch_param.strip
    end
    command :target_branch do |branch_name|
      @updates[:target_branch] = branch_name if project.repository.branch_exists?(branch_name)
    end

    desc 'Move issue from one column of the board to another'
    explanation do |target_list_name|
      label = find_label_references(target_list_name).first
      "Moves issue to #{label} column in the board." if label
    end
    params '~"Target column"'
    condition do
      issuable.is_a?(Issue) &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable) &&
        issuable.project.boards.count == 1
    end
    # rubocop: disable CodeReuse/ActiveRecord
    command :board_move do |target_list_name|
      label_ids = find_label_ids(target_list_name)

      if label_ids.size == 1
        label_id = label_ids.first

        # Ensure this label corresponds to a list on the board
        next unless Label.on_project_boards(issuable.project_id).where(id: label_id).exists?

        @updates[:remove_label_ids] =
          issuable.labels.on_project_boards(issuable.project_id).where.not(id: label_id).pluck(:id)
        @updates[:add_label_ids] = [label_id]
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    desc 'Mark this issue as a duplicate of another issue'
    explanation do |duplicate_reference|
      "Marks this issue as a duplicate of #{duplicate_reference}."
    end
    params '#issue'
    condition do
      issuable.is_a?(Issue) &&
        issuable.persisted? &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    command :duplicate do |duplicate_param|
      canonical_issue = extract_references(duplicate_param, :issue).first

      if canonical_issue.present?
        @updates[:canonical_issue_id] = canonical_issue.id
      end
    end

    desc 'Move this issue to another project.'
    explanation do |path_to_project|
      "Moves this issue to #{path_to_project}."
    end
    params 'path/to/project'
    condition do
      issuable.is_a?(Issue) &&
        issuable.persisted? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :move do |target_project_path|
      target_project = Project.find_by_full_path(target_project_path)

      if target_project.present?
        @updates[:target_project] = target_project
      end
    end

    desc 'Make issue confidential.'
    explanation do
      'Makes this issue confidential'
    end
    condition do
      issuable.is_a?(Issue) && current_user.can?(:"admin_#{issuable.to_ability_name}", issuable)
    end
    command :confidential do
      @updates[:confidential] = true
    end

    desc 'Tag this commit.'
    explanation do |tag_name, message|
      with_message = %{ with "#{message}"} if message.present?
      "Tags this commit to #{tag_name}#{with_message}."
    end
    params 'v1.2.3 <message>'
    parse_params do |tag_name_and_message|
      tag_name_and_message.split(' ', 2)
    end
    condition do
      issuable.is_a?(Commit) && current_user.can?(:push_code, project)
    end
    command :tag do |tag_name, message|
      @updates[:tag_name] = tag_name
      @updates[:tag_message] = message
    end

    desc 'Create a merge request.'
    explanation do |branch_name = nil|
      branch_text = branch_name ? "branch '#{branch_name}'" : 'a branch'
      "Creates #{branch_text} and a merge request to resolve this issue"
    end
    params "<branch name>"
    condition do
      issuable.is_a?(Issue) && current_user.can?(:create_merge_request_in, project) && current_user.can?(:push_code, project)
    end
    command :create_merge_request do |branch_name = nil|
      @updates[:create_merge_request] = {
        branch_name: branch_name,
        issue_iid: issuable.iid
      }
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def extract_users(params)
      return [] if params.nil?

      users = extract_references(params, :user)

      if users.empty?
        users =
          if params.strip == 'me'
            [current_user]
          else
            User.where(username: params.split(' ').map(&:strip))
          end
      end

      users
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def find_milestones(project, params = {})
      MilestonesFinder.new(params.merge(project_ids: [project.id], group_ids: [project.group&.id])).execute
    end

    def parent
      project || group
    end

    def group
      strong_memoize(:group) do
        issuable.group if issuable.respond_to?(:group)
      end
    end

    def find_labels(labels_params = nil)
      finder_params = { include_ancestor_groups: true }
      finder_params[:project_id] = project.id if project
      finder_params[:group_id] = group.id if group
      finder_params[:name] = labels_params.split if labels_params

      result = LabelsFinder.new(current_user, finder_params).execute

      extract_references(labels_params, :label) | result
    end

    def find_label_references(labels_param)
      find_labels(labels_param).map(&:to_reference)
    end

    def find_label_ids(labels_param)
      find_labels(labels_param).map(&:id)
    end

    def explain_commands(commands)
      commands.map do |name, arg|
        definition = self.class.definition_by_name(name)
        next unless definition

        definition.explain(self, arg)
      end.compact
    end

    def extract_updates(commands)
      commands.each do |name, arg|
        definition = self.class.definition_by_name(name)
        next unless definition

        definition.execute(self, arg)
      end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def extract_references(arg, type)
      return [] unless arg

      ext = Gitlab::ReferenceExtractor.new(project, current_user)

      ext.analyze(arg, author: current_user, group: group)

      ext.references(type)
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end
