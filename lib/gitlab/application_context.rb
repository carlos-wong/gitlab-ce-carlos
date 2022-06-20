# frozen_string_literal: true

module Gitlab
  # A GitLab-rails specific accessor for `Labkit::Logging::ApplicationContext`
  class ApplicationContext
    include Gitlab::Utils::LazyAttributes
    include Gitlab::Utils::StrongMemoize

    Attribute = Struct.new(:name, :type)

    LOG_KEY = Labkit::Context::LOG_KEY
    KNOWN_KEYS = [
      :user,
      :project,
      :root_namespace,
      :client_id,
      :caller_id,
      :remote_ip,
      :job_id,
      :pipeline_id,
      :related_class,
      :feature_category
    ].freeze
    private_constant :KNOWN_KEYS

    APPLICATION_ATTRIBUTES = [
      Attribute.new(:project, Project),
      Attribute.new(:namespace, Namespace),
      Attribute.new(:user, User),
      Attribute.new(:runner, ::Ci::Runner),
      Attribute.new(:caller_id, String),
      Attribute.new(:remote_ip, String),
      Attribute.new(:job, ::Ci::Build),
      Attribute.new(:related_class, String),
      Attribute.new(:feature_category, String)
    ].freeze

    def self.known_keys
      KNOWN_KEYS
    end

    def self.with_context(args, &block)
      application_context = new(**args)
      application_context.use(&block)
    end

    def self.with_raw_context(attributes = {}, &block)
      Labkit::Context.with_context(attributes, &block)
    end

    def self.push(args)
      application_context = new(**args)
      Labkit::Context.push(application_context.to_lazy_hash)
    end

    def self.current
      Labkit::Context.current.to_h
    end

    def self.current_context_include?(attribute_name)
      current.include?(Labkit::Context.log_key(attribute_name))
    end

    def self.current_context_attribute(attribute_name)
      Labkit::Context.current&.get_attribute(attribute_name)
    end

    def initialize(**args)
      unknown_attributes = args.keys - APPLICATION_ATTRIBUTES.map(&:name)
      raise ArgumentError, "#{unknown_attributes} are not known keys" if unknown_attributes.any?

      @set_values = args.keys

      assign_attributes(args)
    end

    def to_lazy_hash
      {}.tap do |hash|
        hash[:user] = -> { username } if include_user?
        hash[:project] = -> { project_path } if include_project?
        hash[:root_namespace] = -> { root_namespace_path } if include_namespace?
        hash[:client_id] = -> { client } if include_client?
        hash[:caller_id] = caller_id if set_values.include?(:caller_id)
        hash[:remote_ip] = remote_ip if set_values.include?(:remote_ip)
        hash[:related_class] = related_class if set_values.include?(:related_class)
        hash[:feature_category] = feature_category if set_values.include?(:feature_category)
        hash[:pipeline_id] = -> { job&.pipeline_id } if set_values.include?(:job)
        hash[:job_id] = -> { job&.id } if set_values.include?(:job)
      end
    end

    def use
      Labkit::Context.with_context(to_lazy_hash) { yield }
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
      associated_routable = project || runner_project || job_project
      associated_routable&.full_path
    end

    def username
      associated_user = user || job_user
      associated_user&.username
    end

    def root_namespace_path
      associated_routable = namespace || project || runner_project || runner_group || job_project
      associated_routable&.full_path_components&.first
    end

    def include_namespace?
      set_values.include?(:namespace) || set_values.include?(:project) || set_values.include?(:runner) || set_values.include?(:job)
    end

    def include_client?
      set_values.include?(:user) || set_values.include?(:runner) || set_values.include?(:remote_ip)
    end

    def include_user?
      set_values.include?(:user) || set_values.include?(:job)
    end

    def include_project?
      set_values.include?(:project) || set_values.include?(:runner) || set_values.include?(:job)
    end

    def client
      if runner
        "runner/#{runner.id}"
      elsif user
        "user/#{user.id}"
      else
        "ip/#{remote_ip}"
      end
    end

    def runner_project
      strong_memoize(:runner_project) do
        next unless runner&.project_type?

        runner_projects = runner.runner_projects.take(2) # rubocop: disable CodeReuse/ActiveRecord
        runner_projects.first.project if runner_projects.one?
      end
    end

    def runner_group
      strong_memoize(:runner_group) do
        next unless runner&.group_type?

        runner.groups.first
      end
    end

    def job_project
      strong_memoize(:job_project) do
        job&.project
      end
    end

    def job_user
      strong_memoize(:job_user) do
        job&.user
      end
    end
  end
end

Gitlab::ApplicationContext.prepend_mod_with('Gitlab::ApplicationContext')
