# frozen_string_literal: true

# Helpers to send Git blobs, diffs, patches or archives through Workhorse.
# Workhorse will also serve files when using `send_file`.
module WorkhorseHelper
  # Send a Git blob through Workhorse
  def send_git_blob(repository, blob, inline: true)
    headers.store(*Gitlab::Workhorse.send_git_blob(repository, blob))

    headers['Content-Disposition'] = content_disposition_for_blob(blob, inline)

    # If enabled, this will override the values set above
    workhorse_set_content_type!

    render plain: ""
  end

  # Send a Git diff through Workhorse
  def send_git_diff(repository, diff_refs)
    headers.store(*Gitlab::Workhorse.send_git_diff(repository, diff_refs))
    headers['Content-Disposition'] = 'inline'
    head :ok
  end

  # Send a Git patch through Workhorse
  def send_git_patch(repository, diff_refs)
    headers.store(*Gitlab::Workhorse.send_git_patch(repository, diff_refs))
    headers['Content-Disposition'] = 'inline'
    head :ok
  end

  # Archive a Git repository and send it through Workhorse
  def send_git_archive(repository, **kwargs)
    headers.store(*Gitlab::Workhorse.send_git_archive(repository, **kwargs))
    head :ok
  end

  # Send an entry from artifacts through Workhorse and set safe content type
  def send_artifacts_entry(file, entry)
    headers.store(*Gitlab::Workhorse.send_artifacts_entry(file, entry))
    head :ok
  end

  def send_dependency(dependency_headers, url, filename)
    headers.store(*Gitlab::Workhorse.send_dependency(dependency_headers, url))
    headers['Content-Disposition'] =
      ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: filename)
    headers['Content-Type'] = 'application/gzip'

    head :ok
  end

  def set_workhorse_internal_api_content_type
    headers['Content-Type'] = Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE
  end

  def workhorse_set_content_type!
    headers[Gitlab::Workhorse::DETECT_HEADER] = "true"
  end

  def content_disposition_for_blob(blob, inline)
    return 'inline' if inline

    ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: blob.name)
  end
end
