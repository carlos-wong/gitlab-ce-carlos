# frozen_string_literal: true

module Gitlab
  class SubmoduleLinks
    include Gitlab::Utils::StrongMemoize

    def initialize(repository)
      @repository = repository
    end

    def for(submodule, sha)
      submodule_url = submodule_url_for(sha, submodule.path)
      SubmoduleHelper.submodule_links_for_url(submodule.id, submodule_url, repository)
    end

    private

    attr_reader :repository

    def submodule_urls_for(sha)
      strong_memoize(:"submodule_urls_for_#{sha}") do
        repository.submodule_urls_for(sha)
      end
    end

    def submodule_url_for(sha, path)
      urls = submodule_urls_for(sha)
      urls && urls[path]
    end
  end
end
