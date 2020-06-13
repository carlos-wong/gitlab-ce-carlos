# frozen_string_literal: true

class Import::GiteaController < Import::GithubController
  extend ::Gitlab::Utils::Override

  def new
    if session[access_token_key].present? && provider_url.present?
      redirect_to status_import_url
    end
  end

  def personal_access_token
    session[host_key] = params[host_key]
    super
  end

  # Must be defined or it will 404
  def status
    if blocked_url?
      session[access_token_key] = nil

      redirect_to new_import_url, alert: _('Specified URL cannot be used.')
    else
      super
    end
  end

  private

  def host_key
    :"#{provider}_host_url"
  end

  override :provider
  def provider
    :gitea
  end

  override :provider_url
  def provider_url
    session[host_key]
  end

  # Gitea is not yet an OAuth provider
  # See https://github.com/go-gitea/gitea/issues/27
  override :logged_in_with_provider?
  def logged_in_with_provider?
    false
  end

  override :provider_auth
  def provider_auth
    if session[access_token_key].blank? || provider_url.blank?
      redirect_to new_import_gitea_url,
        alert: _('You need to specify both an Access Token and a Host URL.')
    end
  end

  override :client_options
  def client_options
    { host: provider_url, api_version: 'v1' }
  end

  def blocked_url?
    Gitlab::UrlBlocker.blocked_url?(
      provider_url,
      {
        allow_localhost: allow_local_requests?,
        allow_local_network: allow_local_requests?,
        schemes: %w(http https)
      }
    )
  end

  def allow_local_requests?
    Gitlab::CurrentSettings.allow_local_requests_from_web_hooks_and_services?
  end
end
