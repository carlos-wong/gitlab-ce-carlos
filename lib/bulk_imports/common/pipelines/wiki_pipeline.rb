# frozen_string_literal: true

module BulkImports
  module Common
    module Pipelines
      class WikiPipeline
        include Pipeline

        def extract(*)
          url = url_from_parent_path(context.entity.source_full_path) if source_wiki_exists?

          BulkImports::Pipeline::ExtractedData.new(data: { url: url })
        end

        def transform(_, data)
          data&.slice(:url)
        end

        def load(context, data)
          return unless data&.dig(:url)

          wiki = context.portable.wiki
          url = data[:url].sub("://", "://oauth2:#{context.configuration.access_token}@")

          Gitlab::UrlBlocker.validate!(url, schemes: %w[http https], allow_local_network: allow_local_requests?, allow_localhost: allow_local_requests?)

          wiki.ensure_repository
          wiki.repository.fetch_as_mirror(url)
        end

        private

        def url_from_parent_path(parent_path)
          wiki_path = parent_path + ".wiki.git"
          root = context.configuration.url
          Gitlab::Utils.append_path(root, wiki_path)
        end

        def allow_local_requests?
          Gitlab::CurrentSettings.allow_local_requests_from_web_hooks_and_services?
        end

        def source_wiki_exists?
          wikis = client.get(context.entity.wikis_url_path).parsed_response

          wikis.any?
        end

        def client
          BulkImports::Clients::HTTP.new(url: context.configuration.url, token: context.configuration.access_token)
        end
      end
    end
  end
end
