# frozen_string_literal: true

module PackagesHelper
  include ::API::Helpers::RelatedResourcesHelpers

  def package_sort_path(options = {})
    "#{request.path}?#{options.to_param}"
  end

  def nuget_package_registry_url(project_id)
    expose_url(api_v4_projects_packages_nuget_index_path(id: project_id, format: '.json'))
  end

  def package_registry_instance_url(registry_type)
    expose_url("api/#{::API::API.version}/packages/#{registry_type}")
  end

  def package_registry_project_url(project_id, registry_type = :maven)
    project_api_path = expose_path(api_v4_projects_path(id: project_id))
    package_registry_project_path = "#{project_api_path}/packages/#{registry_type}"
    expose_url(package_registry_project_path)
  end

  def package_from_presenter(package)
    presenter = ::Packages::Detail::PackagePresenter.new(package)

    presenter.detail_view.to_json
  end

  def pypi_registry_url(project_id)
    full_url = expose_url(api_v4_projects_packages_pypi_simple_package_name_path({ id: project_id, package_name: '' }, true))
    full_url.sub!('://', '://__token__:<your_personal_token>@')
  end

  def composer_registry_url(group_id)
    expose_url(api_v4_group___packages_composer_packages_path(id: group_id, format: '.json'))
  end

  def composer_config_repository_name(group_id)
    "#{Gitlab.config.gitlab.host}/#{group_id}"
  end

  def track_package_event(event_name, scope, **args)
    ::Packages::CreateEventService.new(nil, current_user, event_name: event_name, scope: scope).execute
    category = args.delete(:category) || self.class.name
    ::Gitlab::Tracking.event(category, event_name.to_s, **args)
  end

  def show_cleanup_policy_link(project)
    Gitlab.com? &&
    Gitlab.config.registry.enabled &&
    project.feature_available?(:container_registry, current_user) &&
    project.container_expiration_policy.nil? &&
    project.container_repositories.exists?
  end
end
