# frozen_string_literal: true

class Import::GitlabController < Import::BaseController
  extend ::Gitlab::Utils::Override

  MAX_PROJECT_PAGES = 15
  PER_PAGE_PROJECTS = 100

  before_action :verify_gitlab_import_enabled
  before_action :gitlab_auth, except: :callback

  rescue_from OAuth2::Error, with: :gitlab_unauthorized

  def callback
    session[:gitlab_access_token] = client.get_token(params[:code], callback_import_gitlab_url(namespace_id: params[:namespace_id]))
    redirect_to status_import_gitlab_url(namespace_id: params[:namespace_id])
  end

  # We need to re-expose controller's internal method 'status' as action.
  # rubocop:disable Lint/UselessMethodDefinition
  def status
    super
  end
  # rubocop:enable Lint/UselessMethodDefinition

  def create
    repo = client.project(params[:repo_id].to_i)
    target_namespace = find_or_create_namespace(repo['namespace']['path'], client.user['username'])

    if current_user.can?(:create_projects, target_namespace)
      project = Gitlab::GitlabImport::ProjectCreator.new(repo, target_namespace, current_user, access_params).execute

      if project.persisted?
        render json: ProjectSerializer.new.represent(project, serializer: :import)
      else
        render json: { errors: project_save_error(project) }, status: :unprocessable_entity
      end
    else
      render json: { errors: _('This namespace has already been taken! Please choose another one.') }, status: :unprocessable_entity
    end
  end

  protected

  override :importable_repos
  def importable_repos
    client.projects(starting_page: 1, page_limit: MAX_PROJECT_PAGES, per_page: PER_PAGE_PROJECTS).to_a
  end

  override :incompatible_repos
  def incompatible_repos
    []
  end

  override :provider_name
  def provider_name
    :gitlab
  end

  override :provider_url
  def provider_url
    'https://gitlab.com'
  end

  private

  def client
    @client ||= Gitlab::GitlabImport::Client.new(session[:gitlab_access_token])
  end

  def verify_gitlab_import_enabled
    render_404 unless gitlab_import_enabled?
  end

  def gitlab_auth
    if session[:gitlab_access_token].blank?
      go_to_gitlab_for_permissions
    end
  end

  def go_to_gitlab_for_permissions
    redirect_to client.authorize_url(callback_import_gitlab_url(namespace_id: params[:namespace_id]))
  end

  def gitlab_unauthorized
    go_to_gitlab_for_permissions
  end

  def access_params
    { gitlab_access_token: session[:gitlab_access_token] }
  end
end
