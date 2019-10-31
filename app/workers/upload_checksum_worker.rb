# frozen_string_literal: true

class UploadChecksumWorker
  include ApplicationWorker

  feature_category :geo_replication

  def perform(upload_id)
    upload = Upload.find(upload_id)
    upload.calculate_checksum!
    upload.save!
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("UploadChecksumWorker: couldn't find upload #{upload_id}, skipping") # rubocop:disable Gitlab/RailsLogger
  end
end
