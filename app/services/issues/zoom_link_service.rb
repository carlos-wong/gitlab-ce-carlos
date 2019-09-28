# frozen_string_literal: true

module Issues
  class ZoomLinkService < Issues::BaseService
    def initialize(issue, user)
      super(issue.project, user)

      @issue = issue
    end

    def add_link(link)
      if can_add_link? && (link = parse_link(link))
        success(_('Zoom meeting added'), append_to_description(link))
      else
        error(_('Failed to add a Zoom meeting'))
      end
    end

    def can_add_link?
      available? && !link_in_issue_description?
    end

    def remove_link
      if can_remove_link?
        success(_('Zoom meeting removed'), remove_from_description)
      else
        error(_('Failed to remove a Zoom meeting'))
      end
    end

    def can_remove_link?
      available? && link_in_issue_description?
    end

    def parse_link(link)
      Gitlab::ZoomLinkExtractor.new(link).links.last
    end

    private

    attr_reader :issue

    def issue_description
      issue.description || ''
    end

    def success(message, description)
      ServiceResponse
        .success(message: message, payload: { description: description })
    end

    def error(message)
      ServiceResponse.error(message: message)
    end

    def append_to_description(link)
      "#{issue_description}\n\n#{link}"
    end

    def remove_from_description
      link = parse_link(issue_description)
      return issue_description unless link

      issue_description.delete_suffix(link).rstrip
    end

    def link_in_issue_description?
      link = extract_link_from_issue_description
      return unless link

      Gitlab::ZoomLinkExtractor.new(link).match?
    end

    def extract_link_from_issue_description
      issue_description[/(\S+)\z/, 1]
    end

    def available?
      feature_enabled? && can?
    end

    def feature_enabled?
      Feature.enabled?(:issue_zoom_integration, project)
    end

    def can?
      current_user.can?(:update_issue, project)
    end
  end
end
