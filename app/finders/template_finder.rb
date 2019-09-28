# frozen_string_literal: true

class TemplateFinder
  include Gitlab::Utils::StrongMemoize

  prepend_if_ee('::EE::TemplateFinder') # rubocop: disable Cop/InjectEnterpriseEditionModule

  VENDORED_TEMPLATES = HashWithIndifferentAccess.new(
    dockerfiles: ::Gitlab::Template::DockerfileTemplate,
    gitignores: ::Gitlab::Template::GitignoreTemplate,
    gitlab_ci_ymls: ::Gitlab::Template::GitlabCiYmlTemplate
  ).freeze

  class << self
    def build(type, project, params = {})
      if type.to_s == 'licenses'
        LicenseTemplateFinder.new(project, params) # rubocop: disable CodeReuse/Finder
      else
        new(type, project, params)
      end
    end
  end

  attr_reader :type, :project, :params

  attr_reader :vendored_templates
  private :vendored_templates

  def initialize(type, project, params = {})
    @type = type
    @project = project
    @params = params

    @vendored_templates = VENDORED_TEMPLATES.fetch(type)
  end

  def execute
    if params[:name]
      vendored_templates.find(params[:name])
    else
      vendored_templates.all
    end
  end
end
