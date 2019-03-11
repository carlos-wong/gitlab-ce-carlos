# frozen_string_literal: true

module Ci
  class GroupVariable < ActiveRecord::Base
    extend Gitlab::Ci::Model
    include HasVariable
    include Presentable
    include Maskable

    belongs_to :group, class_name: "::Group"

    alias_attribute :secret_value, :value

    validates :key, uniqueness: {
      scope: :group_id,
      message: "(%{value}) has already been taken"
    }

    scope :unprotected, -> { where(protected: false) }
  end
end
