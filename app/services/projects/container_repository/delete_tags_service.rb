# frozen_string_literal: true

module Projects
  module ContainerRepository
    class DeleteTagsService < BaseService
      def execute(container_repository)
        return error('access denied') unless can?(current_user, :destroy_container_image, project)

        tag_names = params[:tags]
        return error('not tags specified') if tag_names.blank?

        smart_delete(container_repository, tag_names)
      end

      private

      # Replace a tag on the registry with a dummy tag.
      # This is a hack as the registry doesn't support deleting individual
      # tags. This code effectively pushes a dummy image and assigns the tag to it.
      # This way when the tag is deleted only the dummy image is affected.
      # See https://gitlab.com/gitlab-org/gitlab/issues/15737 for a discussion
      def smart_delete(container_repository, tag_names)
        # generates the blobs for the dummy image
        dummy_manifest = container_repository.client.generate_empty_manifest(container_repository.path)
        return error('could not generate manifest') if dummy_manifest.nil?

        # update the manifests of the tags with the new dummy image
        deleted_tags = []
        tag_digests = []

        tag_names.each do |name|
          digest = container_repository.client.put_tag(container_repository.path, name, dummy_manifest)
          next unless digest

          deleted_tags << name
          tag_digests << digest
        end

        # make sure the digests are the same (it should always be)
        tag_digests.uniq!

        # rubocop: disable CodeReuse/ActiveRecord
        Gitlab::Sentry.track_exception(ArgumentError.new('multiple tag digests')) if tag_digests.many?

        # Deletes the dummy image
        # All created tag digests are the same since they all have the same dummy image.
        # a single delete is sufficient to remove all tags with it
        if tag_digests.any? && container_repository.delete_tag_by_digest(tag_digests.first)
          success(deleted: deleted_tags)
        else
          error('could not delete tags')
        end
      end
    end
  end
end
