# frozen_string_literal: true

module API
  class GroupVariables < Grape::API
    include PaginationParams

    before { authenticate! }
    before { authorize! :admin_build, user_group }

    params do
      requires :id, type: String, desc: 'The ID of a group'
    end

    resource :groups, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get group-level variables' do
        success Entities::Variable
      end
      params do
        use :pagination
      end
      get ':id/variables' do
        variables = user_group.variables
        present paginate(variables), with: Entities::Variable
      end

      desc 'Get a specific variable from a group' do
        success Entities::Variable
      end
      params do
        requires :key, type: String, desc: 'The key of the variable'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      get ':id/variables/:key' do
        key = params[:key]
        variable = user_group.variables.find_by(key: key)

        break not_found!('GroupVariable') unless variable

        present variable, with: Entities::Variable
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Create a new variable in a group' do
        success Entities::Variable
      end
      params do
        requires :key, type: String, desc: 'The key of the variable'
        requires :value, type: String, desc: 'The value of the variable'
        optional :protected, type: String, desc: 'Whether the variable is protected'
        optional :masked, type: String, desc: 'Whether the variable is masked'
        optional :variable_type, type: String, values: Ci::GroupVariable.variable_types.keys, desc: 'The type of variable, must be one of env_var or file. Defaults to env_var'
      end
      post ':id/variables' do
        variable_params = declared_params(include_missing: false)

        variable = user_group.variables.create(variable_params)

        if variable.valid?
          present variable, with: Entities::Variable
        else
          render_validation_error!(variable)
        end
      end

      desc 'Update an existing variable from a group' do
        success Entities::Variable
      end
      params do
        optional :key, type: String, desc: 'The key of the variable'
        optional :value, type: String, desc: 'The value of the variable'
        optional :protected, type: String, desc: 'Whether the variable is protected'
        optional :masked, type: String, desc: 'Whether the variable is masked'
        optional :variable_type, type: String, values: Ci::GroupVariable.variable_types.keys, desc: 'The type of variable, must be one of env_var or file'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      put ':id/variables/:key' do
        variable = user_group.variables.find_by(key: params[:key])

        break not_found!('GroupVariable') unless variable

        variable_params = declared_params(include_missing: false).except(:key)

        if variable.update(variable_params)
          present variable, with: Entities::Variable
        else
          render_validation_error!(variable)
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      desc 'Delete an existing variable from a group' do
        success Entities::Variable
      end
      params do
        requires :key, type: String, desc: 'The key of the variable'
      end
      # rubocop: disable CodeReuse/ActiveRecord
      delete ':id/variables/:key' do
        variable = user_group.variables.find_by(key: params[:key])
        not_found!('GroupVariable') unless variable

        destroy_conditionally!(variable)
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
