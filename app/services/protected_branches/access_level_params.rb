# frozen_string_literal: true

module ProtectedBranches
  class AccessLevelParams
    attr_reader :type, :params

    def initialize(type, params)
      @type = type
      @params = params_with_default(params)
    end

    def access_levels
      ce_style_access_level
    end

    private

    def params_with_default(params)
      params[:"#{type}_access_level"] ||= Gitlab::Access::MAINTAINER if use_default_access_level?(params)
      params
    end

    def use_default_access_level?(params)
      true
    end

    def ce_style_access_level
      access_level = params[:"#{type}_access_level"]

      return [] unless access_level

      [{ access_level: access_level }]
    end
  end
end

ProtectedBranches::AccessLevelParams.prepend_if_ee('EE::ProtectedBranches::AccessLevelParams')
