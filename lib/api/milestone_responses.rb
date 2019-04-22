# frozen_string_literal: true

module API
  module MilestoneResponses
    extend ActiveSupport::Concern

    included do
      helpers do
        params :optional_params do
          optional :description, type: String, desc: 'The description of the milestone'
          optional :due_date, type: String, desc: 'The due date of the milestone. The ISO 8601 date format (%Y-%m-%d)'
          optional :start_date, type: String, desc: 'The start date of the milestone. The ISO 8601 date format (%Y-%m-%d)'
        end

        params :list_params do
          optional :state, type: String, values: %w[active closed all], default: 'all',
                           desc: 'Return "active", "closed", or "all" milestones'
          optional :iids, type: Array[Integer], desc: 'The IIDs of the milestones'
          optional :title, type: String, desc: 'The title of the milestones'
          optional :search, type: String, desc: 'The search criteria for the title or description of the milestone'
          use :pagination
        end

        params :update_params do
          requires :milestone_id, type: Integer, desc: 'The milestone ID number'
          optional :title, type: String, desc: 'The title of the milestone'
          optional :state_event, type: String, values: %w[close activate],
                                 desc: 'The state event of the milestone '
          use :optional_params
          at_least_one_of :title, :description, :start_date, :due_date, :state_event
        end

        def list_milestones_for(parent)
          milestones = parent.milestones.order_id_desc
          milestones = Milestone.filter_by_state(milestones, params[:state])
          milestones = filter_by_iid(milestones, params[:iids]) if params[:iids].present?
          milestones = filter_by_title(milestones, params[:title]) if params[:title]
          milestones = filter_by_search(milestones, params[:search]) if params[:search]

          present paginate(milestones), with: Entities::Milestone
        end

        def get_milestone_for(parent)
          milestone = parent.milestones.find(params[:milestone_id])
          present milestone, with: Entities::Milestone
        end

        def create_milestone_for(parent)
          milestone = ::Milestones::CreateService.new(parent, current_user, declared_params).execute

          if milestone.valid?
            present milestone, with: Entities::Milestone
          else
            render_api_error!("Failed to create milestone #{milestone.errors.messages}", 400)
          end
        end

        def update_milestone_for(parent)
          milestone = parent.milestones.find(params.delete(:milestone_id))

          milestone_params = declared_params(include_missing: false)
          milestone = ::Milestones::UpdateService.new(parent, current_user, milestone_params).execute(milestone)

          if milestone.valid?
            present milestone, with: Entities::Milestone
          else
            render_api_error!("Failed to update milestone #{milestone.errors.messages}", 400)
          end
        end

        def milestone_issuables_for(parent, type)
          milestone = parent.milestones.find(params[:milestone_id])

          finder_klass, entity = get_finder_and_entity(type)

          params = build_finder_params(milestone, parent)

          issuables = finder_klass.new(current_user, params).execute
          present paginate(issuables), with: entity, current_user: current_user
        end

        def build_finder_params(milestone, parent)
          finder_params = { milestone_title: milestone.title, sort: 'label_priority' }

          if parent.is_a?(Group)
            finder_params.merge(group_id: parent.id)
          else
            finder_params.merge(project_id: parent.id)
          end
        end

        def get_finder_and_entity(type)
          if type == :issue
            [IssuesFinder, Entities::IssueBasic]
          else
            [MergeRequestsFinder, Entities::MergeRequestBasic]
          end
        end
      end
    end
  end
end
