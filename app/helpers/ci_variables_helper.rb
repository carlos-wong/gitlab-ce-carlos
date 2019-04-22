# frozen_string_literal: true

module CiVariablesHelper
  def ci_variable_protected_by_default?
    Gitlab::CurrentSettings.current_application_settings.protected_ci_variables
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
      true
    end
  end
end
