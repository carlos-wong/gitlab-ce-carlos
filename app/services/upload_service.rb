# frozen_string_literal: true

class UploadService
  def initialize(model, file, uploader_class = FileUploader, **uploader_context)
    @model, @file, @uploader_class, @uploader_context = model, file, uploader_class, uploader_context
  end

  def execute
    return unless @file && @file.size <= max_attachment_size

    uploader = @uploader_class.new(@model, nil, @uploader_context)
    uploader.store!(@file)

    uploader
  end

  private

  def max_attachment_size
    Gitlab::CurrentSettings.max_attachment_size.megabytes.to_i
  end
end
