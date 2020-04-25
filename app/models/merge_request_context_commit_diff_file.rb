# frozen_string_literal: true

class MergeRequestContextCommitDiffFile < ApplicationRecord
  include Gitlab::EncodingHelper
  include ShaAttribute
  include DiffFile

  belongs_to :merge_request_context_commit, inverse_of: :diff_files

  sha_attribute :sha
  alias_attribute :id, :sha

  # create MergeRequestContextCommitDiffFile by given diff file record(s)
  def self.bulk_insert(*args)
    Gitlab::Database.bulk_insert('merge_request_context_commit_diff_files', *args)
  end
end
