# frozen_string_literal: true

class Import::GithubController < Import::BaseController
  before_action :verify_import_enabled
  before_action :provider_auth, only: [:status, :jobs, :create]

  rescue_from Octokit::Unauthorized, with: :provider_unauthorized

  def new
    if github_import_configured? && logged_in_with_provider?
      go_to_provider_for_permissions
    elsif session[access_token_key]
      redirect_to status_import_url
    end
  end

  def callback
    session[access_token_key] = client.get_token(params[:code])
    redirect_to status_import_url
  end

  def personal_access_token
    session[access_token_key] = params[:personal_access_token]&.strip
    redirect_to status_import_url
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def status
    @repos = client.repos
    @already_added_projects = find_already_added_projects(provider)
    already_added_projects_names = @already_added_projects.pluck(:import_source)

    @repos.reject! { |repo| already_added_projects_names.include? repo.full_name }
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def jobs
    render json: find_jobs(provider)
  end

  def create
    repo = client.repo(params[:repo_id].to_i)
    project_name = params[:new_name].presence || repo.name
    namespace_path = params[:target_namespace].presence || current_user.namespace_path
    target_namespace = find_or_create_namespace(namespace_path, current_user.namespace_path)

    if can?(current_user, :create_projects, target_namespace)
      project = Gitlab::LegacyGithubImport::ProjectCreator
                  .new(repo, project_name, target_namespace, current_user, access_params, type: provider)
                  .execute(extra_project_attrs)

      if project.persisted?
        render json: ProjectSerializer.new.represent(project)
      else
        render json: { errors: project_save_error(project) }, status: :unprocessable_entity
      end
    else
      render json: { errors: 'This namespace has already been taken! Please choose another one.' }, status: :unprocessable_entity
    end
  end

  private

  def client
    @client ||= Gitlab::LegacyGithubImport::Client.new(session[access_token_key], client_options)
  end

  def verify_import_enabled
    render_404 unless import_enabled?
  end

  def go_to_provider_for_permissions
    redirect_to client.authorize_url(callback_import_url)
  end

  def import_enabled?
    __send__("#{provider}_import_enabled?") # rubocop:disable GitlabSecurity/PublicSend
  end

  def new_import_url
    public_send("new_import_#{provider}_url", extra_import_params) # rubocop:disable GitlabSecurity/PublicSend
  end

  def status_import_url
    public_send("status_import_#{provider}_url", extra_import_params) # rubocop:disable GitlabSecurity/PublicSend
  end

  def callback_import_url
    public_send("users_import_#{provider}_callback_url", extra_import_params) # rubocop:disable GitlabSecurity/PublicSend
  end

  def provider_unauthorized
    session[access_token_key] = nil
    redirect_to new_import_url,
      alert: "Access denied to your #{Gitlab::ImportSources.title(provider.to_s)} account."
  end

  def access_token_key
    :"#{provider}_access_token"
  end

  def access_params
    { github_access_token: session[access_token_key] }
  end

  # The following methods are overridden in subclasses
  def provider
    :github
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def logged_in_with_provider?
    current_user.identities.exists?(provider: provider)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def provider_auth
    if session[access_token_key].blank?
      go_to_provider_for_permissions
    end
  end

  def client_options
    {}
  end

  def extra_project_attrs
    {}
  end

  def extra_import_params
    {}
  end
end
