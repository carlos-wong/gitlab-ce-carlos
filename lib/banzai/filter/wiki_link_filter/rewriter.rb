# frozen_string_literal: true

module Banzai
  module Filter
    class WikiLinkFilter < HTML::Pipeline::Filter
      class Rewriter
        def initialize(link_string, wiki:, slug:)
          @uri = Addressable::URI.parse(link_string)
          @wiki_base_path = wiki && wiki.wiki_base_path
          @slug = slug
        end

        def apply_rules
          # Special case: relative URLs beginning with `/uploads/` refer to
          # user-uploaded files will be handled elsewhere.
          return @uri.to_s if public_upload?

          # Special case: relative URLs beginning with Wikis::CreateAttachmentService::ATTACHMENT_PATH
          # refer to user-uploaded files to the wiki repository.
          unless repository_upload?
            apply_file_link_rules!
            apply_hierarchical_link_rules!
          end

          apply_relative_link_rules!
          @uri.to_s
        end

        private

        # Of the form 'file.md'
        def apply_file_link_rules!
          @uri = Addressable::URI.join(@slug, @uri) if @uri.extname.present?
        end

        # Of the form `./link`, `../link`, or similar
        def apply_hierarchical_link_rules!
          @uri = Addressable::URI.join(@slug, @uri) if @uri.to_s[0] == '.'
        end

        # Any link _not_ of the form `http://example.com/`
        def apply_relative_link_rules!
          if @uri.relative? && @uri.path.present?
            link = ::File.join(@wiki_base_path, @uri.path)
            link = "#{link}##{@uri.fragment}" if @uri.fragment
            @uri = Addressable::URI.parse(link)
          end
        end

        def public_upload?
          @uri.relative? && @uri.path.starts_with?('/uploads/')
        end

        def repository_upload?
          @uri.relative? && @uri.path.starts_with?(Wikis::CreateAttachmentService::ATTACHMENT_PATH)
        end
      end
    end
  end
end
