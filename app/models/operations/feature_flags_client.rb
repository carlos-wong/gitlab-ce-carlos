# frozen_string_literal: true

module Operations
  class FeatureFlagsClient < ApplicationRecord
    include TokenAuthenticatable

    DEFAULT_UNLEASH_API_VERSION = 1

    self.table_name = 'operations_feature_flags_clients'

    belongs_to :project

    validates :project, presence: true
    validates :token, presence: true

    add_authentication_token_field :token, encrypted: :required

    attr_accessor :unleash_app_name

    before_validation :ensure_token!

    def self.find_for_project_and_token(project, token)
      return unless project
      return unless token

      where(project_id: project).find_by_token(token)
    end

    def self.update_last_feature_flag_updated_at!(project)
      where(project: project).update_all(last_feature_flag_updated_at: Time.current)
    end

    def unleash_api_version
      DEFAULT_UNLEASH_API_VERSION
    end

    def unleash_api_features
      return [] unless unleash_app_name.present?

      Operations::FeatureFlag.for_unleash_client(project, unleash_app_name)
    end

    def unleash_api_cache_key
      "api_version:#{unleash_api_version}:" \
        "app_name:#{unleash_app_name}:" \
        "updated_at:#{last_feature_flag_updated_at.to_i}"
    end
  end
end
