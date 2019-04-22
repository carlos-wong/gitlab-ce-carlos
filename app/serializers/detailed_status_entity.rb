# frozen_string_literal: true

class DetailedStatusEntity < Grape::Entity
  include RequestAwareEntity

  expose :icon, :text, :label, :group
  expose :status_tooltip, as: :tooltip
  expose :has_details?, as: :has_details
  expose :details_path

  expose :illustration do |status|
    illustration = {
        image: ActionController::Base.helpers.image_path(status.illustration[:image])
    }
    illustration = status.illustration.merge(illustration)

    illustration
  rescue NotImplementedError
    # ignored
  end

  expose :favicon do |status|
    Gitlab::Favicon.status_overlay(status.favicon)
  end

  expose :action, if: -> (status, _) { status.has_action? } do
    expose :action_icon, as: :icon
    expose :action_title, as: :title
    expose :action_path, as: :path
    expose :action_method, as: :method
    expose :action_button_title, as: :button_title
  end
end
