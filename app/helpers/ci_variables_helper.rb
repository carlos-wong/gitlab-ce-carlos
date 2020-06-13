# frozen_string_literal: true

module CiVariablesHelper
  def ci_variable_protected_by_default?
    Gitlab::CurrentSettings.current_application_settings.protected_ci_variables
  end

  def create_deploy_token_path(entity, opts = {})
    if entity.is_a?(Group)
      create_deploy_token_group_settings_ci_cd_path(entity, opts)
    else
      create_deploy_token_project_settings_repository_path(entity, opts)
    end
  end

  def revoke_deploy_token_path(entity, token)
    if entity.is_a?(Group)
      revoke_group_deploy_token_path(entity, token)
    else
      revoke_project_deploy_token_path(entity, token)
    end
  end

  def ci_variable_protected?(variable, only_key_value)
    if variable && !only_key_value
      variable.protected
    else
      ci_variable_protected_by_default?
    end
  end

  def ci_variable_masked?(variable, only_key_value)
    if variable && !only_key_value
      variable.masked
    else
      false
    end
  end

  def ci_variable_type_options
    [
      %w(Variable env_var),
      %w(File file)
    ]
  end

  def ci_variable_maskable_regex
    Maskable::REGEX.inspect.sub('\\A', '^').sub('\\z', '$').sub(/^\//, '').sub(/\/[a-z]*$/, '').gsub('\/', '/')
  end
end
