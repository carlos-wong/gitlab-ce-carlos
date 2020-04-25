# frozen_string_literal: true

module API
  module Entities
    class UserStatus < Grape::Entity
      expose :emoji
      expose :message
      expose :message_html do |entity|
        MarkupHelper.markdown_field(entity, :message)
      end
    end
  end
end
