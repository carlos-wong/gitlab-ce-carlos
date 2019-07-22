# frozen_string_literal: true

module DeployTokens
  class CreateService < BaseService
    def execute
      @project.deploy_tokens.create(params) do |deploy_token|
        deploy_token.username = params[:username].presence
      end
    end
  end
end
