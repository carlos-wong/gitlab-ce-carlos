desc 'Run local Danger rules'
task :danger_local do
  require 'gitlab_danger'
  require 'gitlab/popen'

  puts("#{GitlabDanger.local_warning_message}\n")

  # _status will _always_ be 0, regardless of failure or success :(
  output, _status = Gitlab::Popen.popen(%w{danger dry_run})

  if output.empty?
    puts(GitlabDanger.success_message)
  else
    puts(output)
    exit(1)
  end
end
