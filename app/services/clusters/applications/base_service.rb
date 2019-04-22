# frozen_string_literal: true

module Clusters
  module Applications
    class BaseService
      InvalidApplicationError = Class.new(StandardError)

      attr_reader :cluster, :current_user, :params

      def initialize(cluster, user, params = {})
        @cluster = cluster
        @current_user = user
        @params = params.dup
      end

      def execute(request)
        instantiate_application.tap do |application|
          if application.has_attribute?(:hostname)
            application.hostname = params[:hostname]
          end

          if application.has_attribute?(:email)
            application.email = params[:email]
          end

          if application.respond_to?(:oauth_application)
            application.oauth_application = create_oauth_application(application, request)
          end

          worker = worker_class(application)

          application.make_scheduled!

          worker.perform_async(application.name, application.id)
        end
      end

      protected

      def worker_class(application)
        raise NotImplementedError
      end

      def builder
        raise NotImplementedError
      end

      def project_builders
        raise NotImplementedError
      end

      def instantiate_application
        raise_invalid_application_error if invalid_application?

        builder || raise(InvalidApplicationError, "invalid application: #{application_name}")
      end

      def raise_invalid_application_error
        raise(InvalidApplicationError, "invalid application: #{application_name}")
      end

      def invalid_application?
        unknown_application? || (!cluster.project_type? && project_only_application?)
      end

      def unknown_application?
        Clusters::Cluster::APPLICATIONS.keys.exclude?(application_name)
      end

      # These applications will need extra configuration to enable them to work
      # with groups of projects
      def project_only_application?
        Clusters::Cluster::PROJECT_ONLY_APPLICATIONS.include?(application_name)
      end

      def application_name
        params[:application]
      end

      def create_oauth_application(application, request)
        oauth_application_params = {
          name: params[:application],
          redirect_uri: application.callback_url,
          scopes: 'api read_user openid',
          owner: current_user
        }

        ::Applications::CreateService.new(current_user, oauth_application_params).execute(request)
      end
    end
  end
end
