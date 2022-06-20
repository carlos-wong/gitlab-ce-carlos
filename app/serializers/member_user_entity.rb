# frozen_string_literal: true

class MemberUserEntity < UserEntity
  unexpose :path
  unexpose :state
  unexpose :status_tooltip_html

  expose :created_at
  expose :last_activity_on

  expose :avatar_url do |user|
    user.avatar_url(size: Member::AVATAR_SIZE, only_path: false)
  end

  expose :blocked do |user|
    user.blocked?
  end

  expose :two_factor_enabled do |user|
    user.two_factor_enabled?
  end

  expose :status, if: -> (user) { user.status.present? } do
    expose :emoji do |user|
      user.status.emoji
    end
  end
end

MemberUserEntity.prepend_mod_with('MemberUserEntity')
