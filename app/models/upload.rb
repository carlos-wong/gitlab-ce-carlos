# frozen_string_literal: true

class Upload < ApplicationRecord
  # Upper limit for foreground checksum processing
  CHECKSUM_THRESHOLD = 100.megabytes

  belongs_to :model, polymorphic: true # rubocop:disable Cop/PolymorphicAssociations

  validates :size, presence: true
  validates :path, presence: true
  validates :model, presence: true
  validates :uploader, presence: true

  scope :with_files_stored_locally, -> { where(store: ObjectStorage::Store::LOCAL) }
  scope :with_files_stored_remotely, -> { where(store: ObjectStorage::Store::REMOTE) }

  before_save  :calculate_checksum!, if: :foreground_checksummable?
  after_commit :schedule_checksum,   if: :checksummable?

  # as the FileUploader is not mounted, the default CarrierWave ActiveRecord
  # hooks are not executed and the file will not be deleted
  after_destroy :delete_file!, if: -> { uploader_class <= FileUploader }

  def self.hexdigest(path)
    Digest::SHA256.file(path).hexdigest
  end

  class << self
    ##
    # FastDestroyAll concerns
    def begin_fast_destroy
      {
        Uploads::Local => Uploads::Local.new.keys(with_files_stored_locally),
        Uploads::Fog => Uploads::Fog.new.keys(with_files_stored_remotely)
      }
    end

    ##
    # FastDestroyAll concerns
    def finalize_fast_destroy(keys)
      keys.each do |store_class, paths|
        store_class.new.delete_keys_async(paths)
      end
    end
  end

  def absolute_path
    raise ObjectStorage::RemoteStoreError, _("Remote object has no absolute path.") unless local?
    return path unless relative_path?

    uploader_class.absolute_path(self)
  end

  def calculate_checksum!
    self.checksum = nil
    return unless checksummable?

    self.checksum = Digest::SHA256.file(absolute_path).hexdigest
  end

  def build_uploader(mounted_as = nil)
    uploader_class.new(model, mounted_as || mount_point).tap do |uploader|
      uploader.upload = self
      uploader.retrieve_from_store!(identifier)
    end
  end

  def exist?
    exist = File.exist?(absolute_path)

    # Help sysadmins find missing upload files
    if persisted? && !exist
      if Gitlab::Sentry.enabled?
        Raven.capture_message(_("Upload file does not exist"), extra: self.attributes)
      end

      Gitlab::Metrics.counter(:upload_file_does_not_exist_total, _('The number of times an upload record could not find its file')).increment
    end

    exist
  end

  def uploader_context
    {
      identifier: identifier,
      secret: secret
    }.compact
  end

  def local?
    store == ObjectStorage::Store::LOCAL
  end

  private

  def delete_file!
    build_uploader.remove!
  end

  def checksummable?
    checksum.nil? && local? && exist?
  end

  def foreground_checksummable?
    checksummable? && size <= CHECKSUM_THRESHOLD
  end

  def schedule_checksum
    UploadChecksumWorker.perform_async(id)
  end

  def relative_path?
    !path.start_with?('/')
  end

  def uploader_class
    Object.const_get(uploader)
  end

  def identifier
    File.basename(path)
  end

  def mount_point
    super&.to_sym
  end
end

Upload.prepend_if_ee('EE::Upload')
