# frozen_string_literal: true

module Projects
  module Settings
    class IntegrationsController < Projects::ApplicationController
      include ::Integrations::Params
      include ::InternalRedirect

      before_action :authorize_admin_project!
      before_action :ensure_integration_enabled, only: [:edit, :update, :test]
      before_action :integration, only: [:edit, :update, :test]
      before_action :default_integration, only: [:edit, :update]
      before_action :web_hook_logs, only: [:edit, :update]
      before_action -> { check_rate_limit!(:project_testing_integration, scope: [@project, current_user]) }, only: :test

      respond_to :html

      layout "project_settings"

      feature_category :integrations
      urgency :low, [:test]

      def index
        @integrations = @project.find_or_initialize_integrations
      end

      def edit
      end

      def update
        attributes = integration_params[:integration]

        if use_inherited_settings?(attributes)
          integration.inherit_from_id = default_integration.id

          if saved = integration.save(context: :manual_change)
            BulkUpdateIntegrationService.new(default_integration, [integration]).execute
          end
        else
          attributes[:inherit_from_id] = nil
          integration.attributes = attributes
          saved = integration.save(context: :manual_change)
        end

        respond_to do |format|
          format.html do
            if saved
              redirect_to redirect_path, notice: success_message
            else
              render 'edit'
            end
          end

          format.json do
            status = saved ? :ok : :unprocessable_entity

            render json: serialize_as_json, status: status
          end
        end
      end

      def test
        if integration.testable?
          render json: integration_test_response, status: :ok
        else
          render json: {}, status: :not_found
        end
      end

      private

      def redirect_path
        safe_redirect_path(params[:redirect_to]).presence ||
          edit_project_settings_integration_path(project, integration)
      end

      def integration_test_response
        unless integration.update(integration_params[:integration])
          return {
            error: true,
            message: _('Validations failed.'),
            service_response: integration.errors.full_messages.join(','),
            test_failed: false
          }
        end

        result = ::Integrations::Test::ProjectService.new(integration, current_user, params[:event]).execute

        unless result[:success]
          return {
            error: true,
            message: s_('Integrations|Connection failed. Check your integration settings.'),
            service_response: result[:message].to_s,
            test_failed: true
          }
        end

        result[:data].presence || {}
      rescue *Gitlab::HTTP::HTTP_ERRORS => e
        {
          error: true,
          message: s_('Integrations|Connection failed. Check your integration settings.'),
          service_response: e.message,
          test_failed: true
        }
      end

      def success_message
        if integration.active?
          format(s_('Integrations|%{integration} settings saved and active.'), integration: integration.title)
        else
          format(s_('Integrations|%{integration} settings saved, but not active.'), integration: integration.title)
        end
      end

      def integration
        @integration ||= project.find_or_initialize_integration(params[:id])
      end

      def default_integration
        @default_integration ||= Integration.default_integration(integration.type, project)
      end

      def web_hook_logs
        return unless integration.service_hook.present?

        @web_hook_logs ||= integration.service_hook.web_hook_logs.recent.page(params[:page])
      end

      def ensure_integration_enabled
        render_404 unless integration
      end

      def serialize_as_json
        integration
          .as_json(only: integration.json_fields)
          .merge(errors: integration.errors.as_json)
      end

      def use_inherited_settings?(attributes)
        default_integration && attributes[:inherit_from_id] == default_integration.id.to_s
      end
    end
  end
end
