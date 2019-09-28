# frozen_string_literal: true

module DeployKeys
  class CreateService < Keys::BaseService
    def execute(project: nil)
      DeployKey.create(params.merge(user: user))
    end
  end
end

DeployKeys::CreateService.prepend_if_ee('::EE::DeployKeys::CreateService')
