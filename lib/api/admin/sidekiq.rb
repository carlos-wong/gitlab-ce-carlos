# frozen_string_literal: true

module API
  module Admin
    class Sidekiq < Grape::API
      before { authenticated_as_admin! }

      namespace 'admin' do
        namespace 'sidekiq' do
          namespace 'queues' do
            desc 'Drop jobs matching the given metadata from the Sidekiq queue'
            params do
              Labkit::Context::KNOWN_KEYS.each do |key|
                optional key, type: String, allow_blank: false
              end

              at_least_one_of(*Labkit::Context::KNOWN_KEYS)
            end
            delete ':queue_name' do
              result =
                Gitlab::SidekiqQueue
                  .new(params[:queue_name])
                  .drop_jobs!(declared_params, timeout: 30)

              present result
            rescue Gitlab::SidekiqQueue::NoMetadataError
              render_api_error!("Invalid metadata: #{declared_params}", 400)
            rescue Gitlab::SidekiqQueue::InvalidQueueError
              not_found!(params[:queue_name])
            end
          end
        end
      end
    end
  end
end
