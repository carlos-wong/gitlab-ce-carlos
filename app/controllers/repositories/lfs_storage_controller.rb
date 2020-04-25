# frozen_string_literal: true

module Repositories
  class LfsStorageController < Repositories::GitHttpClientController
    include LfsRequest
    include WorkhorseRequest
    include SendFileUpload

    skip_before_action :verify_workhorse_api!, only: :download

    def download
      lfs_object = LfsObject.find_by_oid(oid)
      unless lfs_object && lfs_object.file.exists?
        render_lfs_not_found
        return
      end

      send_upload(lfs_object.file, send_params: { content_type: "application/octet-stream" })
    end

    def upload_authorize
      set_workhorse_internal_api_content_type

      authorized = LfsObjectUploader.workhorse_authorize(has_length: true)
      authorized.merge!(LfsOid: oid, LfsSize: size)

      render json: authorized
    end

    def upload_finalize
      if store_file!(oid, size)
        head 200
      else
        render plain: 'Unprocessable entity', status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordInvalid
      render_lfs_forbidden
    rescue UploadedFile::InvalidPathError
      render_lfs_forbidden
    rescue ObjectStorage::RemoteStoreError
      render_lfs_forbidden
    end

    private

    def download_request?
      action_name == 'download'
    end

    def upload_request?
      %w[upload_authorize upload_finalize].include? action_name
    end

    def oid
      params[:oid].to_s
    end

    def size
      params[:size].to_i
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def store_file!(oid, size)
      object = LfsObject.find_by(oid: oid, size: size)
      unless object&.file&.exists?
        object = create_file!(oid, size)
      end

      return unless object

      link_to_project!(object)
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def create_file!(oid, size)
      uploaded_file = UploadedFile.from_params(
        params, :file, LfsObjectUploader.workhorse_local_upload_path)
      return unless uploaded_file

      LfsObject.create!(oid: oid, size: size, file: uploaded_file)
    end

    def link_to_project!(object)
      return unless object

      LfsObjectsProject.safe_find_or_create_by!(
        project: project,
        lfs_object: object
      )
    end
  end
end
