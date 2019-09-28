# frozen_string_literal: true

module Projects
  module GroupLinks
    class DestroyService < BaseService
      def execute(group_link)
        return false unless group_link

        group_link.destroy
      end
    end
  end
end

Projects::GroupLinks::DestroyService.prepend_if_ee('EE::Projects::GroupLinks::DestroyService')
