# frozen_string_literal: true

class JiraService < IssueTrackerService
  include Gitlab::Routing
  include ApplicationHelper
  include ActionView::Helpers::AssetUrlHelper

  validates :url, public_url: true, presence: true, if: :activated?
  validates :api_url, public_url: true, allow_blank: true
  validates :username, presence: true, if: :activated?
  validates :password, presence: true, if: :activated?

  validates :jira_issue_transition_id,
            format: { with: Gitlab::Regex.jira_transition_id_regex, message: "transition ids can have only numbers which can be split with , or ;" },
            allow_blank: true

  # JIRA cloud version is deprecating authentication via username and password.
  # We should use username/password for JIRA server and email/api_token for JIRA cloud,
  # for more information check: https://gitlab.com/gitlab-org/gitlab-ce/issues/49936.
  prop_accessor :username, :password, :url, :api_url, :jira_issue_transition_id, :title, :description

  before_update :reset_password

  alias_method :project_url, :url

  # When these are false GitLab does not create cross reference
  # comments on JIRA except when an issue gets transitioned.
  def self.supported_events
    %w(commit merge_request)
  end

  # {PROJECT-KEY}-{NUMBER} Examples: JIRA-1, PROJECT-1
  def self.reference_pattern(only_long: true)
    @reference_pattern ||= /(?<issue>\b([A-Z][A-Z0-9_]+-)\d+)/
  end

  def initialize_properties
    super do
      self.properties = {
        title: issues_tracker['title'],
        url: issues_tracker['url'],
        api_url: issues_tracker['api_url']
      }
    end
  end

  def reset_password
    self.password = nil if reset_password?
  end

  def options
    url = URI.parse(client_url)

    {
      username: self.username,
      password: self.password,
      site: URI.join(url, '/').to_s, # Intended to find the root
      context_path: url.path.chomp('/'),
      auth_type: :basic,
      read_timeout: 120,
      use_cookies: true,
      additional_cookies: ['OBBasicAuth=fromDialog'],
      use_ssl: url.scheme == 'https'
    }
  end

  def client
    @client ||= JIRA::Client.new(options)
  end

  def help
    "You need to configure JIRA before enabling this service. For more details
    read the
    [JIRA service documentation](#{help_page_url('user/project/integrations/jira')})."
  end

  def title
    if self.properties && self.properties['title'].present?
      self.properties['title']
    else
      'JIRA'
    end
  end

  def description
    if self.properties && self.properties['description'].present?
      self.properties['description']
    else
      'Jira issue tracker'
    end
  end

  def self.to_param
    'jira'
  end

  def fields
    [
      { type: 'text', name: 'url', title: 'Web URL', placeholder: 'https://jira.example.com', required: true },
      { type: 'text', name: 'api_url', title: 'JIRA API URL', placeholder: 'If different from Web URL' },
      { type: 'text', name: 'username', title: 'Username or Email', placeholder: 'Use a username for server version and an email for cloud version', required: true },
      { type: 'password', name: 'password', title: 'Password or API token', placeholder: 'Use a password for server version and an API token for cloud version', required: true },
      { type: 'text', name: 'jira_issue_transition_id', title: 'Transition ID(s)', placeholder: 'Use , or ; to separate multiple transition IDs' }
    ]
  end

  def issues_url
    "#{url}/browse/:id"
  end

  def new_issue_url
    "#{url}/secure/CreateIssue.jspa"
  end

  def execute(push)
    # This method is a no-op, because currently JiraService does not
    # support any events.
  end

  def close_issue(entity, external_issue)
    issue = jira_request { client.Issue.find(external_issue.iid) }

    return if issue.nil? || has_resolution?(issue) || !jira_issue_transition_id.present?

    commit_id = if entity.is_a?(Commit)
                  entity.id
                elsif entity.is_a?(MergeRequest)
                  entity.diff_head_sha
                end

    commit_url = build_entity_url(:commit, commit_id)

    # Depending on the JIRA project's workflow, a comment during transition
    # may or may not be allowed. Refresh the issue after transition and check
    # if it is closed, so we don't have one comment for every commit.
    issue = jira_request { client.Issue.find(issue.key) } if transition_issue(issue)
    add_issue_solved_comment(issue, commit_id, commit_url) if has_resolution?(issue)
  end

  def create_cross_reference_note(mentioned, noteable, author)
    unless can_cross_reference?(noteable)
      return "Events for #{noteable.model_name.plural.humanize(capitalize: false)} are disabled."
    end

    jira_issue = jira_request { client.Issue.find(mentioned.id) }

    return unless jira_issue.present?

    noteable_id   = noteable.respond_to?(:iid) ? noteable.iid : noteable.id
    noteable_type = noteable_name(noteable)
    entity_url    = build_entity_url(noteable_type, noteable_id)

    data = {
      user: {
        name: author.name,
        url: resource_url(user_path(author))
      },
      project: {
        name: project.full_path,
        url: resource_url(namespace_project_path(project.namespace, project)) # rubocop:disable Cop/ProjectPathHelper
      },
      entity: {
        name: noteable_type.humanize.downcase,
        url: entity_url,
        title: noteable.title
      }
    }

    add_comment(data, jira_issue)
  end

  def test(_)
    result = test_settings
    success = result.present?
    result = @error if @error && !success

    { success: success, result: result }
  end

  # JIRA does not need test data.
  # We are requesting the project that belongs to the project key.
  def test_data(user = nil, project = nil)
    nil
  end

  def test_settings
    return unless client_url.present?

    # Test settings by getting the project
    jira_request { client.ServerInfo.all.attrs }
  end

  private

  def can_cross_reference?(noteable)
    case noteable
    when Commit then commit_events
    when MergeRequest then merge_requests_events
    else true
    end
  end

  # jira_issue_transition_id can have multiple values split by , or ;
  # the issue is transitioned at the order given by the user
  # if any transition fails it will log the error message and stop the transition sequence
  def transition_issue(issue)
    jira_issue_transition_id.scan(Gitlab::Regex.jira_transition_id_regex).each do |transition_id|
      issue.transitions.build.save!(transition: { id: transition_id })
    rescue => error
      log_error("Issue transition failed", error: error.message, client_url: client_url)
      return false
    end
  end

  def add_issue_solved_comment(issue, commit_id, commit_url)
    link_title   = "Solved by commit #{commit_id}."
    comment      = "Issue solved with [#{commit_id}|#{commit_url}]."
    link_props   = build_remote_link_props(url: commit_url, title: link_title, resolved: true)
    send_message(issue, comment, link_props)
  end

  def add_comment(data, issue)
    user_name    = data[:user][:name]
    user_url     = data[:user][:url]
    entity_name  = data[:entity][:name]
    entity_url   = data[:entity][:url]
    entity_title = data[:entity][:title]
    project_name = data[:project][:name]

    message      = "[#{user_name}|#{user_url}] mentioned this issue in [a #{entity_name} of #{project_name}|#{entity_url}]:\n'#{entity_title.chomp}'"
    link_title   = "#{entity_name.capitalize} - #{entity_title}"
    link_props   = build_remote_link_props(url: entity_url, title: link_title)

    unless comment_exists?(issue, message)
      send_message(issue, message, link_props)
    end
  end

  def has_resolution?(issue)
    issue.respond_to?(:resolution) && issue.resolution.present?
  end

  def comment_exists?(issue, message)
    comments = jira_request { issue.comments }

    comments.present? && comments.any? { |comment| comment.body.include?(message) }
  end

  def send_message(issue, message, remote_link_props)
    return unless client_url.present?

    jira_request do
      remote_link = find_remote_link(issue, remote_link_props[:object][:url])
      if remote_link
        remote_link.save!(remote_link_props)
      elsif issue.comments.build.save!(body: message)
        new_remote_link = issue.remotelink.build
        new_remote_link.save!(remote_link_props)
      end

      log_info("Successfully posted", client_url: client_url)
      "SUCCESS: Successfully posted to http://jira.example.net."
    end
  end

  def find_remote_link(issue, url)
    links = jira_request { issue.remotelink.all }

    links.find { |link| link.object["url"] == url }
  end

  def build_remote_link_props(url:, title:, resolved: false)
    status = {
      resolved: resolved
    }

    {
      GlobalID: 'GitLab',
      relationship: 'mentioned on',
      object: {
        url: url,
        title: title,
        status: status,
        icon: {
          title: 'GitLab', url16x16: asset_url(Gitlab::Favicon.main, host: gitlab_config.url)
        }
      }
    }
  end

  def resource_url(resource)
    "#{Settings.gitlab.base_url.chomp("/")}#{resource}"
  end

  def build_entity_url(noteable_type, entity_id)
    polymorphic_url(
      [
        self.project.namespace.becomes(Namespace),
        self.project,
        noteable_type.to_sym
      ],
      id:   entity_id,
      host: Settings.gitlab.base_url
    )
  end

  def noteable_name(noteable)
    name = noteable.model_name.singular

    # ProjectSnippet inherits from Snippet class so it causes
    # routing error building the URL.
    name == "project_snippet" ? "snippet" : name
  end

  # Handle errors when doing JIRA API calls
  def jira_request
    yield

  rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, URI::InvalidURIError, JIRA::HTTPError, OpenSSL::SSL::SSLError => e
    @error = e.message
    log_error("Error sending message", client_url: client_url, error: @error)
    nil
  end

  def client_url
    api_url.present? ? api_url : url
  end

  def reset_password?
    # don't reset the password if a new one is provided
    return false if password_touched?
    return true if api_url_changed?
    return false if api_url.present?

    url_changed?
  end

  def self.event_description(event)
    case event
    when "merge_request", "merge_request_events"
      "JIRA comments will be created when an issue gets referenced in a merge request."
    when "commit", "commit_events"
      "JIRA comments will be created when an issue gets referenced in a commit."
    end
  end
end
