# frozen_string_literal: true

module Integrations
  class Field
    SECRET_NAME = %r/token|key|password|passphrase|secret/.freeze

    BOOLEAN_ATTRIBUTES = %i[required api_only exposes_secrets].freeze

    ATTRIBUTES = %i[
      section type placeholder choices value checkbox_label
      title help
      non_empty_password_help
      non_empty_password_title
    ].concat(BOOLEAN_ATTRIBUTES).freeze

    TYPES = %w[text textarea password checkbox select].freeze

    attr_reader :name, :integration_class

    def initialize(name:, integration_class:, type: 'text', api_only: false, **attributes)
      @name = name.to_s.freeze
      @integration_class = integration_class

      attributes[:type] = SECRET_NAME.match?(@name) ? 'password' : type
      attributes[:api_only] = api_only
      @attributes = attributes.freeze

      invalid_attributes = attributes.keys - ATTRIBUTES
      if invalid_attributes.present?
        raise ArgumentError, "Invalid attributes #{invalid_attributes.inspect}"
      elsif !TYPES.include?(self[:type])
        raise ArgumentError, "Invalid type #{self[:type].inspect}"
      end
    end

    def [](key)
      return name if key == :name

      value = @attributes[key]
      return integration_class.class_exec(&value) if value.respond_to?(:call)

      value
    end

    def secret?
      self[:type] == 'password'
    end

    ATTRIBUTES.each do |name|
      define_method(name) { self[name] }
    end

    BOOLEAN_ATTRIBUTES.each do |name|
      define_method("#{name}?") { !!self[name] }
    end

    TYPES.each do |type|
      define_method("#{type}?") { self[:type] == type }
    end
  end
end
