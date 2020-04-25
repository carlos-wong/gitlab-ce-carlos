# frozen_string_literal: true

class MergeRequestContextCommit < ApplicationRecord
  include CachedCommit
  include ShaAttribute

  belongs_to :merge_request
  has_many :diff_files, class_name: 'MergeRequestContextCommitDiffFile'

  sha_attribute :sha

  validates :sha, presence: true
  validates :sha, uniqueness: { message: 'has already been added' }

  # delete all MergeRequestContextCommit & MergeRequestContextCommitDiffFile for given merge_request & commit SHAs
  def self.delete_bulk(merge_request, commits)
    commit_ids = commits.map(&:sha)
    merge_request.merge_request_context_commits.where(sha: commit_ids).delete_all
  end

  # create MergeRequestContextCommit by given commit sha and it's diff file record
  def self.bulk_insert(*args)
    Gitlab::Database.bulk_insert('merge_request_context_commits', *args)
  end

  def to_commit
    # Here we are storing the commit sha because to_hash removes the sha parameter and we lose
    # the reference, this happens because we are storing the ID in db and the Commit class replaces
    # id with sha and removes it, so in our case it will be some incremented integer which is not
    # what we want
    commit_hash = attributes.except('id').to_hash
    commit_hash['id'] = sha
    Commit.from_hash(commit_hash, merge_request.target_project)
  end
end
