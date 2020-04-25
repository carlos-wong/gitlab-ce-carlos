# frozen_string_literal: true

module AkismetMethods
  def spammable_owner
    @user ||= User.find(spammable.author_id)
  end

  def akismet
    @akismet ||= Spam::AkismetService.new(
      spammable_owner.name,
      spammable_owner.email,
      spammable.try(:spammable_text) || spammable&.text,
      options
    )
  end
end
