# frozen_string_literal: true

module Gitlab
  # A GitLab-rails specific accessor for `Labkit::Logging::ApplicationContext`
  class ApplicationContext
    include Gitlab::Utils::LazyAttributes

    Attribute = Struct.new(:name, :type)

    APPLICATION_ATTRIBUTES = [
      Attribute.new(:project, Project),
      Attribute.new(:namespace, Namespace),
      Attribute.new(:user, User)
    ].freeze

    def self.with_context(args, &block)
      application_context = new(**args)
      Labkit::Context.with_context(application_context.to_lazy_hash, &block)
    end

    def self.push(args)
      application_context = new(**args)
      Labkit::Context.push(application_context.to_lazy_hash)
    end

    def initialize(**args)
      unknown_attributes = args.keys - APPLICATION_ATTRIBUTES.map(&:name)
      raise ArgumentError, "#{unknown_attributes} are not known keys" if unknown_attributes.any?

      @set_values = args.keys

      assign_attributes(args)
    end

    def to_lazy_hash
      {}.tap do |hash|
        hash[:user] = -> { username } if set_values.include?(:user)
        hash[:project] = -> { project_path } if set_values.include?(:project)
        hash[:root_namespace] = -> { root_namespace_path } if include_namespace?
      end
    end

    private

    attr_reader :set_values

    APPLICATION_ATTRIBUTES.each do |attr|
      lazy_attr_reader attr.name, type: attr.type
    end

    def assign_attributes(values)
      values.slice(*APPLICATION_ATTRIBUTES.map(&:name)).each do |name, value|
        instance_variable_set("@#{name}", value)
      end
    end

    def project_path
      project&.full_path
    end

    def username
      user&.username
    end

    def root_namespace_path
      if namespace
        namespace.full_path_components.first
      else
        project&.full_path_components&.first
      end
    end

    def include_namespace?
      set_values.include?(:namespace) || set_values.include?(:project)
    end
  end
end
