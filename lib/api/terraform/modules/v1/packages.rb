# frozen_string_literal: true

module API
  module Terraform
    module Modules
      module V1
        class Packages < ::API::Base
          include ::API::Helpers::Authentication
          helpers ::API::Helpers::PackagesHelpers
          helpers ::API::Helpers::Packages::BasicAuthHelpers

          SEMVER_REGEX = Gitlab::Regex.semver_regex

          TERRAFORM_MODULE_REQUIREMENTS = {
            module_namespace: API::NO_SLASH_URL_PART_REGEX,
            module_name: API::NO_SLASH_URL_PART_REGEX,
            module_system: API::NO_SLASH_URL_PART_REGEX
          }.freeze

          TERRAFORM_MODULE_VERSION_REQUIREMENTS = {
            module_version: SEMVER_REGEX
          }.freeze

          feature_category :infrastructure_as_code
          urgency :low

          after_validation do
            require_packages_enabled!
          end

          helpers do
            params :module_name do
              requires :module_name, type: String, desc: "", regexp: API::NO_SLASH_URL_PART_REGEX
              requires :module_system, type: String, regexp: API::NO_SLASH_URL_PART_REGEX
            end

            params :module_version do
              requires :module_version, type: String, desc: 'Module version', regexp: SEMVER_REGEX
            end

            def module_namespace
              strong_memoize(:module_namespace) do
                find_namespace(params[:module_namespace])
              end
            end

            def finder_params
              {
                package_type: :terraform_module,
                package_name: "#{params[:module_name]}/#{params[:module_system]}",
                exact_name: true
              }.tap do |finder_params|
                finder_params[:package_version] = params[:module_version] if params.has_key?(:module_version)
              end
            end

            def packages
              strong_memoize(:packages) do
                ::Packages::GroupPackagesFinder.new(
                  current_user,
                  module_namespace,
                  finder_params
                ).execute
              end
            end

            def package
              strong_memoize(:package) do
                packages.first
              end
            end

            def package_file
              strong_memoize(:package_file) do
                package.installable_package_files.first
              end
            end
          end

          params do
            requires :module_namespace, type: String, desc: "Group's ID or slug", regexp: API::NO_SLASH_URL_PART_REGEX
            includes :module_name
          end

          namespace 'packages/terraform/modules/v1/:module_namespace/:module_name/:module_system', requirements: TERRAFORM_MODULE_REQUIREMENTS do
            authenticate_with do |accept|
              accept.token_types(:personal_access_token, :deploy_token, :job_token)
                    .sent_through(:http_bearer_token)
            end

            after_validation do
              authorize_read_package!(package || module_namespace)
            end

            get 'versions' do
              presenter = ::Terraform::ModulesPresenter.new(packages, params[:module_system])
              present presenter, with: ::API::Entities::Terraform::ModuleVersions
            end

            get 'download' do
              latest_version = packages.order_version.last&.version

              render_api_error!({ error: "No version found for #{params[:module_name]} module" }, :not_found) if latest_version.nil?

              download_path = api_v4_packages_terraform_modules_v1_module_version_download_path(
                {
                  module_namespace: params[:module_namespace],
                  module_name: params[:module_name],
                  module_system: params[:module_system],
                  module_version: latest_version
                },
                true
              )

              redirect(download_path)
            end

            get do
              latest_package = packages.order_version.last

              render_api_error!({ error: "No version found for #{params[:module_name]} module" }, :not_found) if latest_package&.version.nil?

              presenter = ::Terraform::ModuleVersionPresenter.new(latest_package, params[:module_system])
              present presenter, with: ::API::Entities::Terraform::ModuleVersion
            end

            params do
              includes :module_version
            end

            namespace '*module_version', requirements: TERRAFORM_MODULE_VERSION_REQUIREMENTS do
              after_validation do
                not_found! unless package && package_file
              end

              get 'download' do
                module_file_path = api_v4_packages_terraform_modules_v1_module_version_file_path(
                  module_namespace: params[:module_namespace],
                  module_name: params[:module_name],
                  module_system: params[:module_system],
                  module_version: params[:module_version]
                )

                if token_from_namespace_inheritable
                  jwt_token = Gitlab::TerraformRegistryToken.from_token(token_from_namespace_inheritable).encoded
                end

                header 'X-Terraform-Get', module_file_path.sub(%r{module_version/file$}, "#{params[:module_version]}/file?token=#{jwt_token}&archive=tgz")
                status :no_content
              end

              namespace 'file' do
                authenticate_with do |accept|
                  accept.token_types(:deploy_token_from_jwt, :job_token_from_jwt, :personal_access_token_from_jwt).sent_through(:token_param)
                end

                get do
                  track_package_event('pull_package', :terraform_module, project: package.project, namespace: module_namespace, user: current_user)

                  present_carrierwave_file!(package_file.file)
                end
              end

              # This endpoint has to be the last within namespace '*module_version' block
              # due to how the route matching works in grape
              # format: false is required, otherwise grape splits the semver version into 2 params:
              # params[:module_version] and params[:format],
              # thus leading to an invalid/not found module version
              get format: false do
                presenter = ::Terraform::ModuleVersionPresenter.new(package, params[:module_system])
                present presenter, with: ::API::Entities::Terraform::ModuleVersion
              end
            end
          end

          params do
            requires :id, type: String, desc: 'The ID or full path of a project'
            includes :module_name
            includes :module_version
          end

          resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
            namespace ':id/packages/terraform/modules/:module_name/:module_system/*module_version/file' do
              authenticate_with do |accept|
                accept.token_types(:deploy_token).sent_through(:http_deploy_token_header)
                accept.token_types(:job_token).sent_through(:http_job_token_header)
                accept.token_types(:personal_access_token).sent_through(:http_private_token_header)
              end

              desc 'Workhorse authorize Terraform Module package file' do
                detail 'This feature was introduced in GitLab 13.11'
              end

              put 'authorize' do
                authorize_workhorse!(
                  subject: authorized_user_project,
                  maximum_size: authorized_user_project.actual_limits.terraform_module_max_file_size
                )
              end

              desc 'Upload Terraform Module package file' do
                detail 'This feature was introduced in GitLab 13.11'
              end

              params do
                requires :file, type: ::API::Validations::Types::WorkhorseFile, desc: 'The package file to be published (generated by Multipart middleware)'
              end

              put do
                authorize_upload!(authorized_user_project)
                bad_request!('File is too large') if authorized_user_project.actual_limits.exceeded?(:terraform_module_max_file_size, params[:file].size)

                create_package_file_params = {
                  module_name: params['module_name'],
                  module_system: params['module_system'],
                  module_version: params['module_version'],
                  file: params['file'],
                  build: current_authenticated_job
                }

                result = ::Packages::TerraformModule::CreatePackageService
                  .new(authorized_user_project, current_user, create_package_file_params)
                  .execute

                render_api_error!(result[:message], result[:http_status]) if result[:status] == :error

                track_package_event('push_package', :terraform_module, project: authorized_user_project, user: current_user, namespace: authorized_user_project.namespace)

                created!
              rescue ObjectStorage::RemoteStoreError => e
                Gitlab::ErrorTracking.track_exception(e, extra: { file_name: params[:file_name], project_id: authorized_user_project.id })

                forbidden!
              end
            end
          end
        end
      end
    end
  end
end
