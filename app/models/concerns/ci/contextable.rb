# frozen_string_literal: true

module Ci
  ##
  # This module implements methods that provide context in form of
  # essential CI/CD variables that can be used by a build / bridge job.
  #
  module Contextable
    ##
    # Variables in the environment name scope.
    #
    def scoped_variables(environment: expanded_environment_name)
      Gitlab::Ci::Variables::Collection.new.tap do |variables|
        variables.concat(predefined_variables)
        variables.concat(project.predefined_variables)
        variables.concat(pipeline.predefined_variables)
        variables.concat(runner.predefined_variables) if runnable? && runner
        variables.concat(project.deployment_variables(environment: environment)) if environment
        variables.concat(yaml_variables)
        variables.concat(user_variables)
        variables.concat(secret_group_variables)
        variables.concat(secret_project_variables(environment: environment))
        variables.concat(trigger_request.user_variables) if trigger_request
        variables.concat(pipeline.variables)
        variables.concat(pipeline.pipeline_schedule.job_variables) if pipeline.pipeline_schedule
      end
    end

    ##
    # Regular Ruby hash of scoped variables, without duplicates that are
    # possible to be present in an array of hashes returned from `variables`.
    #
    def scoped_variables_hash
      scoped_variables.to_hash
    end

    ##
    # Variables that do not depend on the environment name.
    #
    def simple_variables
      strong_memoize(:simple_variables) do
        scoped_variables(environment: nil).to_runner_variables
      end
    end

    def user_variables
      Gitlab::Ci::Variables::Collection.new.tap do |variables|
        break variables if user.blank?

        variables.append(key: 'GITLAB_USER_ID', value: user.id.to_s)
        variables.append(key: 'GITLAB_USER_EMAIL', value: user.email)
        variables.append(key: 'GITLAB_USER_LOGIN', value: user.username)
        variables.append(key: 'GITLAB_USER_NAME', value: user.name)
      end
    end

    def predefined_variables # rubocop:disable Metrics/AbcSize
      Gitlab::Ci::Variables::Collection.new.tap do |variables|
        variables.append(key: 'CI', value: 'true')
        variables.append(key: 'GITLAB_CI', value: 'true')
        variables.append(key: 'GITLAB_FEATURES', value: project.licensed_features.join(','))
        variables.append(key: 'CI_SERVER_NAME', value: 'GitLab')
        variables.append(key: 'CI_SERVER_VERSION', value: Gitlab::VERSION)
        variables.append(key: 'CI_SERVER_VERSION_MAJOR', value: Gitlab.version_info.major.to_s)
        variables.append(key: 'CI_SERVER_VERSION_MINOR', value: Gitlab.version_info.minor.to_s)
        variables.append(key: 'CI_SERVER_VERSION_PATCH', value: Gitlab.version_info.patch.to_s)
        variables.append(key: 'CI_SERVER_REVISION', value: Gitlab.revision)
        variables.append(key: 'CI_JOB_NAME', value: name)
        variables.append(key: 'CI_JOB_STAGE', value: stage)
        variables.append(key: 'CI_COMMIT_SHA', value: sha)
        variables.append(key: 'CI_COMMIT_SHORT_SHA', value: short_sha)
        variables.append(key: 'CI_COMMIT_BEFORE_SHA', value: before_sha)
        variables.append(key: 'CI_COMMIT_REF_NAME', value: ref)
        variables.append(key: 'CI_COMMIT_REF_SLUG', value: ref_slug)
        variables.append(key: "CI_COMMIT_TAG", value: ref) if tag?
        variables.append(key: "CI_PIPELINE_TRIGGERED", value: 'true') if trigger_request
        variables.append(key: "CI_JOB_MANUAL", value: 'true') if action?
        variables.append(key: "CI_NODE_INDEX", value: self.options[:instance].to_s) if self.options&.include?(:instance)
        variables.append(key: "CI_NODE_TOTAL", value: (self.options&.dig(:parallel) || 1).to_s)
        variables.concat(legacy_variables)
      end
    end

    def legacy_variables
      Gitlab::Ci::Variables::Collection.new.tap do |variables|
        variables.append(key: 'CI_BUILD_REF', value: sha)
        variables.append(key: 'CI_BUILD_BEFORE_SHA', value: before_sha)
        variables.append(key: 'CI_BUILD_REF_NAME', value: ref)
        variables.append(key: 'CI_BUILD_REF_SLUG', value: ref_slug)
        variables.append(key: 'CI_BUILD_NAME', value: name)
        variables.append(key: 'CI_BUILD_STAGE', value: stage)
        variables.append(key: "CI_BUILD_TAG", value: ref) if tag?
        variables.append(key: "CI_BUILD_TRIGGERED", value: 'true') if trigger_request
        variables.append(key: "CI_BUILD_MANUAL", value: 'true') if action?
      end
    end

    def secret_group_variables
      return [] unless project.group

      project.group.ci_variables_for(git_ref, project)
    end

    def secret_project_variables(environment: persisted_environment)
      project.ci_variables_for(ref: git_ref, environment: environment)
    end
  end
end
