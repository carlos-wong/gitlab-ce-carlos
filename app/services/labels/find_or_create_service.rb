# frozen_string_literal: true

module Labels
  class FindOrCreateService
    def initialize(current_user, parent, params = {})
      @current_user = current_user
      @parent = parent
      @available_labels = params.delete(:available_labels)
      @params = params.dup.with_indifferent_access
    end

    def execute(skip_authorization: false, find_only: false)
      @skip_authorization = skip_authorization
      find_or_create_label(find_only: find_only)
    end

    private

    attr_reader :current_user, :parent, :params, :skip_authorization

    def available_labels
      @available_labels ||= LabelsFinder.new(
        current_user,
        "#{parent_type}_id".to_sym => parent.id,
        include_ancestor_groups: include_ancestor_groups?,
        only_group_labels: parent_is_group?
      ).execute(skip_authorization: skip_authorization)
    end

    # Only creates the label if current_user can do so, if the label does not exist
    # and the user can not create the label, nil is returned
    # rubocop: disable CodeReuse/ActiveRecord
    def find_or_create_label(find_only: false)
      new_label = available_labels.find_by(title: title)

      return new_label if find_only

      if new_label.nil? && (skip_authorization || Ability.allowed?(current_user, :admin_label, parent))
        create_params = params.except(:include_ancestor_groups)
        new_label = Labels::CreateService.new(create_params).execute(parent_type.to_sym => parent)
      end

      new_label
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def title
      params[:title] || params[:name]
    end

    def parent_type
      parent.model_name.param_key
    end

    def parent_is_group?
      parent_type == "group"
    end

    def include_ancestor_groups?
      params[:include_ancestor_groups] == true
    end
  end
end
