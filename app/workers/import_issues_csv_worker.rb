# frozen_string_literal: true

class ImportIssuesCsvWorker
  include ApplicationWorker

  feature_category :issue_tracking
  worker_resource_boundary :cpu
  weight 2

  sidekiq_retries_exhausted do |job|
    Upload.find(job['args'][2]).destroy
  end

  def perform(current_user_id, project_id, upload_id)
    @user = User.find(current_user_id)
    @project = Project.find(project_id)
    @upload = Upload.find(upload_id)

    importer = Issues::ImportCsvService.new(@user, @project, @upload.retrieve_uploader)
    importer.execute

    @upload.destroy
  end
end
