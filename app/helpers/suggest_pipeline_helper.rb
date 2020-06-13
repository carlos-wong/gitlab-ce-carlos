# frozen_string_literal: true

module SuggestPipelineHelper
  def should_suggest_gitlab_ci_yml?
    Feature.enabled?(:suggest_pipeline) &&
      current_user &&
      params[:suggest_gitlab_ci_yml] == 'true'
  end
end
