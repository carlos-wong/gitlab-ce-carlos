# frozen_string_literal: true

module Projects
  module Security
    class ConfigurationController < Projects::ApplicationController
      include SecurityAndCompliancePermissions

      feature_category :static_application_security_testing, [:show]
      urgency :low, [:show]

      def show
        render_403 unless can?(current_user, :read_security_configuration, project)

        @configuration ||= configuration_presenter

        respond_to do |format|
          format.html
          format.json do
            render status: :ok, json: configuration.to_h
          end
        end
      end

      private

      def configuration
        if unify_configuration_enabled?
          configuration_presenter
        else
          {}
        end
      end

      def configuration_presenter
        ::Projects::Security::ConfigurationPresenter.new(project,
                                                         **presenter_attributes,
                                                         current_user: current_user)
      end

      def presenter_attributes
        {}
      end

      def unify_configuration_enabled?
        Feature.enabled?(:unify_security_configuration, project, default_enabled: :yaml)
      end
    end
  end
end

Projects::Security::ConfigurationController.prepend_mod_with('Projects::Security::ConfigurationController')
