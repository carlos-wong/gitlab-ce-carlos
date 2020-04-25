# frozen_string_literal: true

module API
  module Entities
    class Blob < Grape::Entity
      expose :basename
      expose :data
      expose :path
      # TODO: :filename was renamed to :path but both still return the full path,
      # in the future we can only return the filename here without the leading
      # directory path.
      # https://gitlab.com/gitlab-org/gitlab/issues/34521
      expose :filename, &:path
      expose :id
      expose :ref
      expose :startline
      expose :project_id
    end
  end
end
