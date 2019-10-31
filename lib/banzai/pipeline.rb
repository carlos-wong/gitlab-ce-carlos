# frozen_string_literal: true

module Banzai
  module Pipeline
    def self.[](name)
      name ||= :full
      const_get("#{name.to_s.camelize}Pipeline", false)
    end
  end
end
