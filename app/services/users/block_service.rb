# frozen_string_literal: true

module Users
  class BlockService < BaseService
    def initialize(current_user)
      @current_user = current_user
    end

    def execute(user)
      if user.block
        after_block_hook(user)
        success
      else
        messages = user.errors.full_messages
        error(messages.uniq.join('. '))
      end
    end

    private

    def after_block_hook(user)
      # overriden by EE module
    end
  end
end

Users::BlockService.prepend_if_ee('EE::Users::BlockService')
