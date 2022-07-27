# frozen_string_literal: true

module QuickActions
  class InterpretService < BaseService
    include Gitlab::Utils::StrongMemoize
    include Gitlab::QuickActions::Dsl
    include Gitlab::QuickActions::IssueActions
    include Gitlab::QuickActions::IssuableActions
    include Gitlab::QuickActions::IssueAndMergeRequestActions
    include Gitlab::QuickActions::MergeRequestActions
    include Gitlab::QuickActions::CommitActions
    include Gitlab::QuickActions::CommonActions
    include Gitlab::QuickActions::RelateActions

    attr_reader :quick_action_target

    # Counts how many commands have been executed.
    # Used to display relevant feedback on UI when a note
    # with only commands has been processed.
    attr_accessor :commands_executed_count

    # Takes an quick_action_target and returns an array of all the available commands
    # represented with .to_h
    def available_commands(quick_action_target)
      @quick_action_target = quick_action_target

      self.class.command_definitions.map do |definition|
        next unless definition.available?(self)

        definition.to_h(self)
      end.compact
    end

    # Takes a text and interprets the commands that are extracted from it.
    # Returns the content without commands, a hash of changes to be applied to a record
    # and a string containing the execution_message to show to the user.
    def execute(content, quick_action_target, only: nil)
      return [content, {}, ''] unless current_user.can?(:use_quick_actions)

      @quick_action_target = quick_action_target
      @updates = {}
      @execution_message = {}

      content, commands = extractor.extract_commands(content, only: only)
      extract_updates(commands)

      [content, @updates, execution_messages_for(commands), command_names(commands)]
    end

    # Takes a text and interprets the commands that are extracted from it.
    # Returns the content without commands, and array of changes explained.
    def explain(content, quick_action_target)
      return [content, []] unless current_user.can?(:use_quick_actions)

      @quick_action_target = quick_action_target

      content, commands = extractor.extract_commands(content)
      commands = explain_commands(commands)
      [content, commands]
    end

    private

    def failed_parse(message)
      raise Gitlab::QuickActions::CommandDefinition::ParseError, message
    end

    def extractor
      Gitlab::QuickActions::Extractor.new(self.class.command_definitions)
    end

    # Find users for commands like /assign
    #
    # eg. /assign me and @jane and jack
    def extract_users(params)
      Gitlab::QuickActions::UsersExtractor
        .new(current_user, project: project, group: group, target: quick_action_target, text: params)
        .execute

    rescue Gitlab::QuickActions::UsersExtractor::Error => err
      extract_users_failed(err)
    end

    def extract_users_failed(err)
      case err
      when Gitlab::QuickActions::UsersExtractor::MissingError
        failed_parse(format(_("Failed to find users for %{missing}"), missing: err.message))
      when Gitlab::QuickActions::UsersExtractor::TooManyRefsError
        failed_parse(format(_('Too many references. Quick actions are limited to at most %{max_count} user references'),
                 max_count: err.limit))
      when Gitlab::QuickActions::UsersExtractor::TooManyFoundError
        failed_parse(format(_("Too many users found. Quick actions are limited to at most %{max_count} users"),
                 max_count: err.limit))
      else
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(err)
        failed_parse(_('Something went wrong'))
      end
    end

    def find_milestones(project, params = {})
      group_ids = project.group.self_and_ancestors.select(:id) if project.group

      MilestonesFinder.new(params.merge(project_ids: [project.id], group_ids: group_ids)).execute
    end

    def parent
      project || group
    end

    def group
      strong_memoize(:group) do
        quick_action_target.group if quick_action_target.respond_to?(:group)
      end
    end

    def find_labels(labels_params = nil)
      extract_references(labels_params, :label) | find_labels_by_name_no_tilde(labels_params)
    end

    def find_labels_by_name_no_tilde(labels_params)
      return Label.none if label_with_tilde?(labels_params)

      finder_params = { include_ancestor_groups: true }
      finder_params[:project_id] = project.id if project
      finder_params[:group_id] = group.id if group
      finder_params[:name] = extract_label_names(labels_params) if labels_params

      LabelsFinder.new(current_user, finder_params).execute
    end

    def label_with_tilde?(labels_params)
      labels_params&.include?('~')
    end

    def extract_label_names(labels_params)
      # '"A" "A B C" A B' => ["A", "A B C", "A", "B"]
      labels_params.scan(/"([^"]+)"|([^ ]+)/).flatten.compact
    end

    def find_label_references(labels_param, format = :id)
      labels_to_reference(find_labels(labels_param), format)
    end

    def labels_to_reference(labels, format = :id)
      labels.map { |l| l.to_reference(format: format) }
    end

    def find_label_ids(labels_param)
      find_labels(labels_param).map(&:id)
    end

    def explain_commands(commands)
      map_commands(commands, :explain)
    end

    def execution_messages_for(commands)
      map_commands(commands, :execute_message).join(' ')
    end

    def map_commands(commands, method)
      commands.map do |name, arg|
        definition = self.class.definition_by_name(name)
        next unless definition

        case method
        when :explain
          definition.explain(self, arg)
        when :execute_message
          @execution_message[name.to_sym] || definition.execute_message(self, arg)
        end
      end.compact
    end

    def command_names(commands)
      commands.flatten.map do |name|
        definition = self.class.definition_by_name(name)
        next unless definition

        name
      end.compact
    end

    def extract_updates(commands)
      commands.each do |name, arg|
        definition = self.class.definition_by_name(name)
        next unless definition

        definition.execute(self, arg)
        usage_ping_tracking(definition.name, arg)
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

    def usage_ping_tracking(quick_action_name, arg)
      Gitlab::UsageDataCounters::QuickActionActivityUniqueCounter.track_unique_action(
        quick_action_name.to_s,
        args: arg&.strip,
        user: current_user
      )
    end

    def can?(ability, object)
      Ability.allowed?(current_user, ability, object)
    end
  end
end

QuickActions::InterpretService.prepend_mod_with('QuickActions::InterpretService')
