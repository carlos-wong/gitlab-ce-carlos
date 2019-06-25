# frozen_string_literal: true

module Lfs
  # Usage: Calling `new_file` check to see if a file should be in LFS and
  #        return a transformed result with `content` and `encoding` to commit.
  #
  #        For LFS an LfsObject linked to the project is stored and an LFS
  #        pointer returned. If the file isn't in LFS the untransformed content
  #        is returned to save in the commit.
  #
  # transformer = Lfs::FileTransformer.new(project, repository, @branch_name)
  # content_or_lfs_pointer = transformer.new_file(file_path, content).content
  # create_transformed_commit(content_or_lfs_pointer)
  #
  class FileTransformer
    attr_reader :project, :repository, :repository_type, :branch_name

    def initialize(project, repository, branch_name)
      @project = project
      @repository = repository
      @repository_type = repository.repo_type.name
      @branch_name = branch_name
    end

    def new_file(file_path, file_content, encoding: nil)
      if project.lfs_enabled? && lfs_file?(file_path)
        file_content = parse_file_content(file_content, encoding: encoding)
        lfs_pointer_file = Gitlab::Git::LfsPointerFile.new(file_content)
        lfs_object = create_lfs_object!(lfs_pointer_file, file_content)

        link_lfs_object!(lfs_object)

        Result.new(content: lfs_pointer_file.pointer, encoding: 'text')
      else
        Result.new(content: file_content, encoding: encoding)
      end
    end

    class Result
      attr_reader :content, :encoding

      def initialize(content:, encoding:)
        @content = content
        @encoding = encoding
      end
    end

    private

    def lfs_file?(file_path)
      cached_attributes.attributes(file_path)['filter'] == 'lfs'
    end

    def cached_attributes
      @cached_attributes ||= Gitlab::Git::AttributesAtRefParser.new(repository, branch_name)
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def create_lfs_object!(lfs_pointer_file, file_content)
      LfsObject.find_or_create_by(oid: lfs_pointer_file.sha256, size: lfs_pointer_file.size) do |lfs_object|
        lfs_object.file = CarrierWaveStringFile.new(file_content)
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def link_lfs_object!(lfs_object)
      LfsObjectsProject.safe_find_or_create_by!(
        project: project,
        lfs_object: lfs_object,
        repository_type: repository_type
      )
    end

    def parse_file_content(file_content, encoding: nil)
      return file_content.read if file_content.respond_to?(:read)
      return Base64.decode64(file_content) if encoding == 'base64'

      file_content
    end
  end
end
