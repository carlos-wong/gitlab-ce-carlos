# frozen_string_literal: true

module API
  class ProjectStatistics < Grape::API
    before do
      authenticate!
      not_found! unless user_project.daily_statistics_enabled?
      authorize! :daily_statistics, user_project
    end

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get the list of project fetch statistics for the last 30 days'
      get ":id/statistics" do
        statistic_finder = ::Projects::DailyStatisticsFinder.new(user_project)

        present statistic_finder, with: Entities::ProjectDailyStatistics
      end
    end
  end
end
