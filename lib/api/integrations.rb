# frozen_string_literal: true
module API
  class Integrations < ::API::Base
    feature_category :integrations

    integrations = Helpers::IntegrationsHelpers.integrations
    integration_classes = Helpers::IntegrationsHelpers.integration_classes

    if Gitlab.dev_or_test_env?
      integrations['mock-ci'] = [
        {
          required: true,
          name: :mock_service_url,
          type: String,
          desc: 'URL to the mock integration'
        }
      ]
      integrations['mock-deployment'] = []
      integrations['mock-monitoring'] = []

      integration_classes += Helpers::IntegrationsHelpers.development_integration_classes
    end

    INTEGRATIONS = integrations.freeze

    integration_classes.each do |integration|
      event_names = integration.try(:event_names) || next
      event_names.each do |event_name|
        INTEGRATIONS[integration.to_param.tr("_", "-")] << {
          required: false,
          name: event_name.to_sym,
          type: String,
          desc: IntegrationsHelper.integration_event_description(integration, event_name)
        }
      end
    end

    TRIGGER_INTEGRATIONS = {
      'mattermost-slash-commands' => [
        {
          name: :token,
          type: String,
          desc: 'The Mattermost token'
        }
      ],
      'slack-slash-commands' => [
        {
          name: :token,
          type: String,
          desc: 'The Slack token'
        }
      ]
    }.freeze

    helpers do
      def integration_attributes(integration)
        integration.fields.inject([]) do |arr, hash|
          arr << hash[:name].to_sym
        end
      end
    end

    # The API officially documents only the `:id/integrations` API paths.
    # We support the older `id:/services` path for backwards-compatibility in API V4.
    # The support for `:id/services` can be dropped if we create an API V5.
    [':id/services', ':id/integrations'].each do |path|
      params do
        requires :id, type: String, desc: 'The ID of a project'
      end
      resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
        before { authenticate! }
        before { authorize_admin_project }

        desc 'Get all active project integrations' do
          success Entities::ProjectIntegrationBasic
        end
        get path do
          integrations = user_project.integrations.active

          present integrations, with: Entities::ProjectIntegrationBasic
        end

        INTEGRATIONS.each do |slug, settings|
          desc "Set #{slug} integration for project"
          params do
            settings.each do |setting|
              if setting[:required]
                requires setting[:name], type: setting[:type], desc: setting[:desc]
              else
                optional setting[:name], type: setting[:type], desc: setting[:desc]
              end
            end
          end
          put "#{path}/#{slug}" do
            integration = user_project.find_or_initialize_integration(slug.underscore)
            params = declared_params(include_missing: false).merge(active: true)

            if integration.update(params)
              present integration, with: Entities::ProjectIntegration
            else
              render_api_error!('400 Bad Request', 400)
            end
          end
        end

        desc "Delete an integration from a project"
        params do
          requires :slug, type: String, values: INTEGRATIONS.keys, desc: 'The name of the integration'
        end
        delete "#{path}/:slug" do
          integration = user_project.find_or_initialize_integration(params[:slug].underscore)

          destroy_conditionally!(integration) do
            attrs = integration_attributes(integration).index_with do |attr|
              column = integration.column_for_attribute(attr)
              if column.is_a?(ActiveRecord::ConnectionAdapters::NullColumn)
                nil
              else
                column.default
              end
            end.merge(active: false)

            render_api_error!('400 Bad Request', 400) unless integration.update(attrs)
          end
        end

        desc 'Get the integration settings for a project' do
          success Entities::ProjectIntegration
        end
        params do
          requires :slug, type: String, values: INTEGRATIONS.keys, desc: 'The name of the integration'
        end
        get "#{path}/:slug" do
          integration = user_project.find_or_initialize_integration(params[:slug].underscore)

          not_found!('Integration') unless integration&.persisted?

          present integration, with: Entities::ProjectIntegration
        end
      end

      TRIGGER_INTEGRATIONS.each do |integration_slug, settings|
        helpers do
          def slash_command_integration(project, integration_slug, params)
            project.integrations.active.find do |integration|
              integration.try(:token) == params[:token] && integration.to_param == integration_slug.underscore
            end
          end
        end

        params do
          requires :id, type: String, desc: 'The ID of a project'
        end
        resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          desc "Trigger a slash command for #{integration_slug}" do
            detail 'Added in GitLab 8.13'
          end
          params do
            settings.each do |setting|
              requires setting[:name], type: setting[:type], desc: setting[:desc]
            end
          end
          post "#{path}/#{integration_slug.underscore}/trigger", urgency: :low do
            project = find_project(params[:id])

            # This is not accurate, but done to prevent leakage of the project names
            not_found!('Integration') unless project

            integration = slash_command_integration(project, integration_slug, params)
            result = integration.try(:trigger, params)

            if result
              status result[:status] || 200
              present result
            else
              not_found!('Integration')
            end
          end
        end
      end
    end
  end
end

API::Integrations.prepend_mod_with('API::Integrations')
