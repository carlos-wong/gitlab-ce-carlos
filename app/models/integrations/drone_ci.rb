# frozen_string_literal: true

module Integrations
  class DroneCi < BaseCi
    include HasWebHook
    include PushDataValidations
    include ReactivelyCached
    prepend EnableSslVerification
    extend Gitlab::Utils::Override

    DRONE_SAAS_HOSTNAME = 'cloud.drone.io'

    field :drone_url,
      title: -> { s_('ProjectService|Drone server URL') },
      placeholder: 'http://drone.example.com',
      exposes_secrets: true,
      required: true

    field :token,
      type: 'password',
      help: -> { s_('ProjectService|Token for the Drone project.') },
      non_empty_password_title: -> { s_('ProjectService|Enter new token') },
      non_empty_password_help: -> { s_('ProjectService|Leave blank to use your current token.') },
      required: true

    validates :drone_url, presence: true, public_url: true, if: :activated?
    validates :token, presence: true, if: :activated?

    def execute(data)
      return unless project

      case data[:object_kind]
      when 'push'
        execute_web_hook!(data) if push_valid?(data)
      when 'merge_request'
        execute_web_hook!(data) if merge_request_valid?(data)
      when 'tag_push'
        execute_web_hook!(data) if tag_push_valid?(data)
      end
    end

    def allow_target_ci?
      true
    end

    def self.supported_events
      %w(push merge_request tag_push)
    end

    def commit_status_path(sha, ref)
      Gitlab::Utils.append_path(
        drone_url,
        "gitlab/#{project.full_path}/commits/#{sha}?branch=#{Addressable::URI.encode_component(ref.to_s)}&access_token=#{token}")
    end

    def commit_status(sha, ref)
      with_reactive_cache(sha, ref) { |cached| cached[:commit_status] }
    end

    def calculate_reactive_cache(sha, ref)
      response = Gitlab::HTTP.try_get(
        commit_status_path(sha, ref),
        verify: enable_ssl_verification,
        extra_log_info: { project_id: project_id }
      )

      status =
        if response && response.code == 200 && response['status']
          case response['status']
          when 'killed'
            :canceled
          when 'failure', 'error'
            # Because drone return error if some test env failed
            :failed
          else
            response["status"]
          end
        else
          :error
        end

      { commit_status: status }
    end

    def build_page(sha, ref)
      Gitlab::Utils.append_path(
        drone_url,
        "gitlab/#{project.full_path}/redirect/commits/#{sha}?branch=#{Addressable::URI.encode_component(ref.to_s)}")
    end

    def title
      'Drone'
    end

    def description
      s_('ProjectService|Run CI/CD pipelines with Drone.')
    end

    def self.to_param
      'drone_ci'
    end

    def help
      s_('ProjectService|Run CI/CD pipelines with Drone.')
    end

    override :hook_url
    def hook_url
      [drone_url, "/hook", "?owner=#{project.namespace.full_path}", "&name=#{project.path}", "&access_token={token}"].join
    end

    def url_variables
      { 'token' => token }
    end

    override :update_web_hook!
    def update_web_hook!
      # If using a service template, project may not be available
      super if project
    end

    def enable_ssl_verification
      original_value = Gitlab::Utils.to_boolean(properties['enable_ssl_verification'])
      original_value.nil? ? (new_record? || url_is_saas?) : original_value
    end

    private

    def url_is_saas?
      parsed_url = Addressable::URI.parse(drone_url)
      parsed_url&.scheme == 'https' && parsed_url.hostname == DRONE_SAAS_HOSTNAME
    rescue Addressable::URI::InvalidURIError
      false
    end
  end
end
