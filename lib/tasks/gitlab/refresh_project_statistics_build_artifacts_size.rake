# frozen_string_literal: true

require 'httparty'
require 'csv'

namespace :gitlab do
  desc "GitLab | Refresh build artifacts size project statistics for given list of Project IDs from remote CSV"

  BUILD_ARTIFACTS_SIZE_REFRESH_ENQUEUE_BATCH_SIZE = 500

  task :refresh_project_statistics_build_artifacts_size, [:csv_url] => :environment do |_t, args|
    csv_url = args.csv_url

    # rubocop: disable Gitlab/HTTParty
    body = HTTParty.get(csv_url)
    # rubocop: enable Gitlab/HTTParty

    table = CSV.parse(body.to_s, headers: true)
    project_ids = table['PROJECT_ID']

    puts "Loaded #{project_ids.size} project ids to import"

    imported = 0
    missing = 0

    if project_ids.any?
      project_ids.in_groups_of(BUILD_ARTIFACTS_SIZE_REFRESH_ENQUEUE_BATCH_SIZE, false) do |ids|
        projects = Project.where(id: ids)
        Projects::BuildArtifactsSizeRefresh.enqueue_refresh(projects)

        # Take a short break to allow replication to catch up
        Kernel.sleep(1)

        imported += projects.size
        missing += ids.size - projects.size
        puts "#{imported}/#{project_ids.size} (missing projects: #{missing})"
      end
      puts 'Done.'
    else
      puts 'Project IDs must be listed in the CSV under the header PROJECT_ID'.red
    end
  end
end
