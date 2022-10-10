# frozen_string_literal: true

module Integrations
  class Jenkins < BaseCi
    include HasWebHook

    prepend EnableSslVerification
    extend Gitlab::Utils::Override

    field :jenkins_url,
      title: -> { s_('ProjectService|Jenkins server URL') },
      required: true,
      placeholder: 'http://jenkins.example.com',
      help: -> { s_('The URL of the Jenkins server.') }

    field :project_name,
      required: true,
      placeholder: 'my_project_name',
      help: -> { s_('The name of the Jenkins project. Copy the name from the end of the URL to the project.') }

    field :username,
      help: -> { s_('The username for the Jenkins server.') }

    field :password,
      type: 'password',
      help: -> { s_('The password for the Jenkins server.') },
      non_empty_password_title: -> { s_('ProjectService|Enter new password.') },
      non_empty_password_help: -> { s_('ProjectService|Leave blank to use your current password.') }

    before_validation :reset_password

    validates :jenkins_url, presence: true, addressable_url: true, if: :activated?
    validates :project_name, presence: true, if: :activated?
    validates :username, presence: true, if: ->(service) { service.activated? && service.password_touched? && service.password.present? }

    default_value_for :merge_requests_events, false
    default_value_for :tag_push_events, false

    def reset_password
      # don't reset the password if a new one is provided
      if (jenkins_url_changed? || username.blank?) && !password_touched?
        self.password = nil
      end
    end

    def execute(data)
      return unless supported_events.include?(data[:object_kind])

      execute_web_hook!(data, "#{data[:object_kind]}_hook")
    end

    def test(data)
      begin
        result = execute(data)
        return { success: false, result: result[:message] } if result[:http_status] != 200
      rescue StandardError => e
        return { success: false, result: e }
      end

      { success: true, result: result[:message] }
    end

    override :hook_url
    def hook_url
      url = URI.parse(jenkins_url)
      url.path = File.join(url.path || '/', "project/#{project_name}")
      url.user = ERB::Util.url_encode(username) unless username.blank?
      url.password = ERB::Util.url_encode(password) unless password.blank?
      url.to_s
    end

    def url_variables
      {}
    end

    def self.supported_events
      %w(push merge_request tag_push)
    end

    def title
      'Jenkins'
    end

    def description
      s_('Run CI/CD pipelines with Jenkins.')
    end

    def help
      docs_link = ActionController::Base.helpers.link_to _('Learn more.'), Rails.application.routes.url_helpers.help_page_url('integration/jenkins'), target: '_blank', rel: 'noopener noreferrer'
      s_('Run CI/CD pipelines with Jenkins when you push to a repository, or when a merge request is created, updated, or merged. %{docs_link}').html_safe % { docs_link: docs_link.html_safe }
    end

    def self.to_param
      'jenkins'
    end
  end
end
