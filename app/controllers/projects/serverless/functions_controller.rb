# frozen_string_literal: true

module Projects
  module Serverless
    class FunctionsController < Projects::ApplicationController
      include ProjectUnauthorized

      before_action :authorize_read_cluster!

      def index
        respond_to do |format|
          format.json do
            functions = finder.execute

            if functions.any?
              render json: serialize_function(functions)
            else
              head :no_content
            end
          end

          format.html do
            @installed = finder.installed?
            render
          end
        end
      end

      def show
        @service = serialize_function(finder.service(params[:environment_id], params[:id]))
        @prometheus = finder.has_prometheus?(params[:environment_id])

        return not_found if @service.nil?

        respond_to do |format|
          format.json do
            render json: @service
          end

          format.html
        end
      end

      def metrics
        respond_to do |format|
          format.json do
            metrics = finder.invocation_metrics(params[:environment_id], params[:id])

            if metrics.nil?
              head :no_content
            else
              render json: metrics
            end
          end
        end
      end

      private

      def finder
        Projects::Serverless::FunctionsFinder.new(project)
      end

      def serialize_function(function)
        Projects::Serverless::ServiceSerializer.new(current_user: @current_user, project: project).represent(function)
      end
    end
  end
end
