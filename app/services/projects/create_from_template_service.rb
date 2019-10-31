# frozen_string_literal: true

module Projects
  class CreateFromTemplateService < BaseService
    include Gitlab::Utils::StrongMemoize

    attr_reader :template_name

    def initialize(user, params)
      @current_user, @params = user, params.to_h.dup
      @template_name = @params.delete(:template_name).presence
    end

    def execute
      return project unless validate_template!

      file = built_in_template&.file

      override_params = params.dup
      params[:file] = file

      GitlabProjectsImportService.new(current_user, params, override_params).execute
    ensure
      file&.close
    end

    private

    def validate_template!
      return true if built_in_template

      project.errors.add(:template_name, _("'%{template_name}' is unknown or invalid" % { template_name: template_name }))
      false
    end

    def built_in_template
      strong_memoize(:built_in_template) do
        Gitlab::ProjectTemplate.find(template_name)
      end
    end

    def project
      @project ||= ::Project.new(namespace_id: params[:namespace_id])
    end
  end
end

Projects::CreateFromTemplateService.prepend_if_ee('EE::Projects::CreateFromTemplateService')
