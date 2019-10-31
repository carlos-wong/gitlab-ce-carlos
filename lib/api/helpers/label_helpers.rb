# frozen_string_literal: true

module API
  module Helpers
    module LabelHelpers
      extend Grape::API::Helpers

      params :label_create_params do
        requires :name, type: String, desc: 'The name of the label to be created'
        requires :color, type: String, desc: "The color of the label given in 6-digit hex notation with leading '#' sign (e.g. #FFAABB) or one of the allowed CSS color names"
        optional :description, type: String, desc: 'The description of label to be created'
      end

      params :label_update_params do
        optional :new_name, type: String, desc: 'The new name of the label'
        optional :color, type: String, desc: "The new color of the label given in 6-digit hex notation with leading '#' sign (e.g. #FFAABB) or one of the allowed CSS color names"
        optional :description, type: String, desc: 'The new description of label'
      end

      params :project_label_update_params do
        use :label_update_params
        optional :priority, type: Integer, desc: 'The priority of the label', allow_blank: true
        at_least_one_of :new_name, :color, :description, :priority
      end

      params :group_label_update_params do
        use :label_update_params
        at_least_one_of :new_name, :color, :description
      end

      def find_label(parent, id_or_title, include_ancestor_groups: true)
        labels = available_labels_for(parent, include_ancestor_groups: include_ancestor_groups)
        label = labels.find_by_id(id_or_title) || labels.find_by_title(id_or_title)

        label || not_found!('Label')
      end

      def get_labels(parent, entity, include_ancestor_groups: true)
        present paginate(available_labels_for(parent, include_ancestor_groups: include_ancestor_groups)),
                with: entity,
                current_user: current_user,
                parent: parent,
                with_counts: params[:with_counts]
      end

      def get_label(parent, entity, include_ancestor_groups: true)
        label = find_label(parent, params_id_or_title, include_ancestor_groups: include_ancestor_groups)

        present label, with: entity, current_user: current_user, parent: parent
      end

      def create_label(parent, entity)
        authorize! :admin_label, parent

        label = available_labels_for(parent).find_by_title(params[:name])
        conflict!('Label already exists') if label

        priority = params.delete(:priority)
        label_params = declared_params(include_missing: false)

        label = ::Labels::CreateService.new(label_params).execute(create_service_params(parent))

        if label.persisted?
          if parent.is_a?(Project)
            label.prioritize!(parent, priority) if priority
          end

          present label, with: entity, current_user: current_user, parent: parent
        else
          render_validation_error!(label)
        end
      end

      def update_label(parent, entity)
        authorize! :admin_label, parent

        label = find_label(parent, params_id_or_title, include_ancestor_groups: false)
        update_priority = params.key?(:priority)
        priority = params.delete(:priority)

        # params is used to update the label so we need to remove this field here
        params.delete(:label_id)
        params.delete(:name)

        label = ::Labels::UpdateService.new(declared_params(include_missing: false)).execute(label)
        render_validation_error!(label) unless label.valid?

        if parent.is_a?(Project) && update_priority
          if priority.nil?
            label.unprioritize!(parent)
          else
            label.prioritize!(parent, priority)
          end
        end

        present label, with: entity, current_user: current_user, parent: parent
      end

      def delete_label(parent)
        authorize! :admin_label, parent

        label = find_label(parent, params_id_or_title, include_ancestor_groups: false)

        destroy_conditionally!(label)
      end

      def promote_label(parent)
        authorize! :admin_label, parent

        label = find_label(parent, params[:name], include_ancestor_groups: false)

        begin
          group_label = ::Labels::PromoteService.new(parent, current_user).execute(label)

          if group_label
            present group_label, with: Entities::GroupLabel, current_user: current_user, parent: parent.group
          else
            render_api_error!('Failed to promote project label to group label', 400)
          end
        rescue => error
          render_api_error!(error.to_s, 400)
        end
      end

      def params_id_or_title
        @params_id_or_title ||= params[:label_id] || params[:name]
      end

      def create_service_params(parent)
        if parent.is_a?(Project)
          { project: parent }
        elsif parent.is_a?(Group)
          { group: parent }
        else
          raise TypeError, 'Parent type is not supported'
        end
      end
    end
  end
end
