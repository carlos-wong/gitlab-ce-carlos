# frozen_string_literal: true

module Pages
  class VirtualDomain
    def initialize(projects:, cache: nil, trim_prefix: nil, domain: nil)
      @projects = projects
      @cache = cache
      @trim_prefix = trim_prefix
      @domain = domain
    end

    def certificate
      domain&.certificate
    end

    def key
      domain&.key
    end

    def lookup_paths
      paths = projects.map do |project|
        project.pages_lookup_path(trim_prefix: trim_prefix, domain: domain)
      end

      # TODO: remove in https://gitlab.com/gitlab-org/gitlab/-/issues/328715
      paths = paths.select(&:source)

      paths.sort_by(&:prefix).reverse
    end

    def cache_key
      @cache_key ||= cache&.cache_key
    end

    private

    attr_reader :projects, :trim_prefix, :domain, :cache
  end
end
