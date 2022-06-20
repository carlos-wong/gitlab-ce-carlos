# frozen_string_literal: true

module API
  class AlertManagementAlerts < ::API::Base
    feature_category :incident_management

    params do
      requires :id, type: String, desc: 'The ID of a project'
      requires :alert_iid, type: Integer, desc: 'The IID of the Alert'
    end

    resource :projects, requirements: ::API::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      namespace ':id/alert_management_alerts/:alert_iid/metric_images' do
        post 'authorize' do
          authorize!(:upload_alert_management_metric_image, find_project_alert(request.params[:alert_iid]))

          require_gitlab_workhorse!
          ::Gitlab::Workhorse.verify_api_request!(request.headers)
          status 200
          content_type ::Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE

          params = {
            has_length: false,
            maximum_size: ::AlertManagement::MetricImage::MAX_FILE_SIZE.to_i
          }

          ::MetricImageUploader.workhorse_authorize(**params)
        end

        desc 'Upload a metric image for an alert' do
          success Entities::MetricImage
        end
        params do
          requires :file, type: ::API::Validations::Types::WorkhorseFile, desc: 'The image file to be uploaded'
          optional :url, type: String, desc: 'The url to view more metric info'
          optional :url_text, type: String, desc: 'A description of the image or URL'
        end
        post do
          require_gitlab_workhorse!
          bad_request!('File is too large') if max_file_size_exceeded?

          alert = find_project_alert(params[:alert_iid])

          authorize!(:upload_alert_management_metric_image, alert)

          upload = ::AlertManagement::MetricImages::UploadService.new(
            alert,
            current_user,
            params.slice(:file, :url, :url_text)
          ).execute

          if upload.success?
            present upload.payload[:metric],
              with: Entities::MetricImage,
              current_user: current_user,
              project: user_project
          else
            render_api_error!(upload.message, upload.http_status)
          end
        end

        desc 'Metric Images for alert'
        get do
          alert = find_project_alert(params[:alert_iid])

          if can?(current_user, :read_alert_management_metric_image, alert)
            present alert.metric_images.order_created_at_asc, with: Entities::MetricImage
          else
            render_api_error!('Alert not found', 404)
          end
        end

        desc 'Update a metric image for an alert' do
          success Entities::MetricImage
        end
        params do
          requires :metric_image_id, type: Integer, desc: 'The ID of metric image'
          optional :url, type: String, desc: 'The url to view more metric info'
          optional :url_text, type: String, desc: 'A description of the image or URL'
        end
        put ':metric_image_id' do
          alert = find_project_alert(params[:alert_iid])

          authorize!(:update_alert_management_metric_image, alert)

          render_api_error!('Feature not available', 403) unless alert.metric_images_available?

          metric_image = alert.metric_images.find_by_id(params[:metric_image_id])

          render_api_error!('Metric image not found', 404) unless metric_image

          if metric_image.update(params.slice(:url, :url_text))
            present metric_image, with: Entities::MetricImage, current_user: current_user, project: user_project
          else
            unprocessable_entity!('Metric image could not be updated')
          end
        end

        desc 'Remove a metric image for an alert' do
          success Entities::MetricImage
        end
        params do
          requires :metric_image_id, type: Integer, desc: 'The ID of metric image'
        end
        delete ':metric_image_id' do
          alert = find_project_alert(params[:alert_iid])

          authorize!(:destroy_alert_management_metric_image, alert)

          render_api_error!('Feature not available', 403) unless alert.metric_images_available?

          metric_image = alert.metric_images.find_by_id(params[:metric_image_id])

          render_api_error!('Metric image not found', 404) unless metric_image

          if metric_image.destroy
            no_content!
          else
            unprocessable_entity!('Metric image could not be deleted')
          end
        end
      end
    end

    helpers do
      def find_project_alert(iid, project_id = nil)
        project = project_id ? find_project!(project_id) : user_project

        ::AlertManagement::AlertsFinder.new(current_user, project, { iid: [iid] }).execute.first
      end

      def max_file_size_exceeded?
        params[:file].size > ::AlertManagement::MetricImage::MAX_FILE_SIZE
      end
    end
  end
end
