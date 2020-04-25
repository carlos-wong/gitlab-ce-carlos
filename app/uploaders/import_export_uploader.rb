# frozen_string_literal: true

class ImportExportUploader < AttachmentUploader
  EXTENSION_WHITELIST = %w[tar.gz gz].freeze

  def self.workhorse_local_upload_path
    File.join(options.storage_path, 'uploads', TMP_UPLOAD_PATH)
  end

  def extension_whitelist
    EXTENSION_WHITELIST
  end

  def move_to_cache
    false
  end
end
