# frozen_string_literal: true

module UploadsActions
  include Gitlab::Utils::StrongMemoize
  include SendFileUpload

  UPLOAD_MOUNTS = %w(avatar attachment file logo header_logo favicon).freeze

  def create
    uploader = UploadService.new(model, params[:file], uploader_class).execute

    respond_to do |format|
      if uploader
        format.json do
          render json: { link: uploader.to_h }
        end
      else
        format.json do
          render json: _('Invalid file.'), status: :unprocessable_entity
        end
      end
    end
  end

  # This should either
  #   - send the file directly
  #   - or redirect to its URL
  #
  def show
    return render_404 unless uploader&.exists?

    if cache_publicly?
      # We need to reset caching from the applications controller to get rid of the no-store value
      headers['Cache-Control'] = ''
      expires_in 5.minutes, public: true, must_revalidate: false
    else
      expires_in 0.seconds, must_revalidate: true, private: true
    end

    disposition = uploader.image_or_video? ? 'inline' : 'attachment'

    uploaders = [uploader, *uploader.versions.values]
    uploader = uploaders.find { |version| version.filename == params[:filename] }

    return render_404 unless uploader

    workhorse_set_content_type!
    send_upload(uploader, attachment: uploader.filename, disposition: disposition)
  end

  def authorize
    set_workhorse_internal_api_content_type

    authorized = uploader_class.workhorse_authorize(
      has_length: false,
      maximum_size: Gitlab::CurrentSettings.max_attachment_size.megabytes.to_i)

    render json: authorized
  rescue SocketError
    render json: _("Error uploading file"), status: :internal_server_error
  end

  private

  def uploader_class
    raise NotImplementedError
  end

  def upload_mount
    mounted_as = params[:mounted_as]
    mounted_as if UPLOAD_MOUNTS.include?(mounted_as)
  end

  def uploader_mounted?
    upload_model_class < CarrierWave::Mount::Extension && !upload_mount.nil?
  end

  def uploader
    strong_memoize(:uploader) do
      if uploader_mounted?
        model.public_send(upload_mount) # rubocop:disable GitlabSecurity/PublicSend
      else
        build_uploader_from_upload || build_uploader_from_params
      end
    end
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def build_uploader_from_upload
    return unless uploader = build_uploader

    upload_paths = uploader.upload_paths(params[:filename])
    upload = Upload.find_by(model: model, uploader: uploader_class.to_s, path: upload_paths)
    upload&.build_uploader
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def build_uploader_from_params
    return unless uploader = build_uploader

    uploader.retrieve_from_store!(params[:filename])
    uploader
  end

  def build_uploader
    return unless params[:secret] && params[:filename]

    uploader = uploader_class.new(model, secret: params[:secret])

    return unless uploader.model_valid?

    uploader
  end

  def image_or_video?
    uploader && uploader.exists? && uploader.image_or_video?
  end

  def find_model
    nil
  end

  def cache_publicly?
    false
  end

  def model
    strong_memoize(:model) { find_model }
  end

  def workhorse_authorize_request?
    action_name == 'authorize'
  end
end
