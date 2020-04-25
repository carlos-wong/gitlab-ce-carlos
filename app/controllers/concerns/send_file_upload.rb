# frozen_string_literal: true

module SendFileUpload
  def send_upload(file_upload, send_params: {}, redirect_params: {}, attachment: nil, proxy: false, disposition: 'attachment')
    if attachment
      response_disposition = ActionDispatch::Http::ContentDisposition.format(disposition: disposition, filename: attachment)

      # Response-Content-Type will not override an existing Content-Type in
      # Google Cloud Storage, so the metadata needs to be cleared on GCS for
      # this to work. However, this override works with AWS.
      redirect_params[:query] = { "response-content-disposition" => response_disposition,
                                  "response-content-type" => guess_content_type(attachment) }
      # By default, Rails will send uploads with an extension of .js with a
      # content-type of text/javascript, which will trigger Rails'
      # cross-origin JavaScript protection.
      send_params[:content_type] = 'text/plain' if File.extname(attachment) == '.js'

      send_params.merge!(filename: attachment, disposition: disposition)
    end

    if file_upload.file_storage?
      send_file file_upload.path, send_params
    elsif file_upload.class.proxy_download_enabled? || proxy
      headers.store(*Gitlab::Workhorse.send_url(file_upload.url(**redirect_params)))
      head :ok
    else
      redirect_to file_upload.url(**redirect_params)
    end
  end

  def guess_content_type(filename)
    types = MIME::Types.type_for(filename)

    if types.present?
      types.first.content_type
    else
      "application/octet-stream"
    end
  end
end
