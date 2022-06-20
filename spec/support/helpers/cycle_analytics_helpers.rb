# frozen_string_literal: true

module CycleAnalyticsHelpers
  include GitHelpers

  def toggle_value_stream_dropdown
    page.find('[data-testid="dropdown-value-streams"]').click
  end

  def path_nav_stage_names_without_median
    # Returns the path names with the median value stripped out
    page.all('.gl-path-button').collect(&:text).map {|name_with_median| name_with_median.split("\n")[0] }
  end

  def fill_in_custom_stage_fields
    index = page.all('[data-testid="value-stream-stage-fields"]').length
    last_stage = page.all('[data-testid="value-stream-stage-fields"]').last

    within last_stage do
      find('[name*="custom-stage-name-"]').fill_in with: "Cool custom stage - name #{index}"
      select_dropdown_option_by_value "custom-stage-start-event-", :merge_request_created
      select_dropdown_option_by_value "custom-stage-end-event-", :merge_request_merged
    end
  end

  def select_event_label(sel)
    page.within(sel) do
      find('.dropdown-toggle').click
      page.find(".dropdown-menu").all(".dropdown-item")[1].click
    end
  end

  def fill_in_custom_label_stage_fields
    index = page.all('[data-testid="value-stream-stage-fields"]').length
    last_stage = page.all('[data-testid="value-stream-stage-fields"]').last

    within last_stage do
      find('[name*="custom-stage-name-"]').fill_in with: "Cool custom label stage - name #{index}"
      select_dropdown_option_by_value "custom-stage-start-event-", :issue_label_added
      select_dropdown_option_by_value "custom-stage-end-event-", :issue_label_removed

      select_event_label("[data-testid*='custom-stage-start-event-label-']")
      select_event_label("[data-testid*='custom-stage-end-event-label-']")
    end
  end

  def add_custom_stage_to_form
    page.find_button(s_('CreateValueStreamForm|Add another stage')).click

    fill_in_custom_stage_fields
  end

  def add_custom_label_stage_to_form
    page.find_button(s_('CreateValueStreamForm|Add another stage')).click

    fill_in_custom_label_stage_fields
  end

  def save_value_stream(custom_value_stream_name)
    fill_in 'create-value-stream-name', with: custom_value_stream_name

    page.find_button(s_('CreateValueStreamForm|Create value stream')).click
    wait_for_requests
  end

  def click_save_value_stream_button
    click_button(_('Save value stream'))
  end

  def create_custom_value_stream(custom_value_stream_name)
    toggle_value_stream_dropdown
    page.find_button(_('Create new Value Stream')).click

    add_custom_stage_to_form
    save_value_stream(custom_value_stream_name)
  end

  def wait_for_stages_to_load(selector = '[data-testid="vsa-path-navigation"]')
    expect(page).to have_selector selector
    wait_for_requests
  end

  def select_group(target_group, ready_selector = '[data-testid="vsa-path-navigation"]')
    visit group_analytics_cycle_analytics_path(target_group)

    wait_for_stages_to_load(ready_selector)
  end

  def select_value_stream(value_stream_name)
    toggle_value_stream_dropdown

    page.find('[data-testid="dropdown-value-streams"]').all('li button').find { |item| item.text == value_stream_name.to_s }.click
    wait_for_requests
  end

  def create_value_stream_group_aggregation(group)
    aggregation = Analytics::CycleAnalytics::Aggregation.safe_create_for_group(group)
    Analytics::CycleAnalytics::AggregatorService.new(aggregation: aggregation).execute
  end

  def select_group_and_custom_value_stream(group, custom_value_stream_name)
    create_value_stream_group_aggregation(group)

    select_group(group)
    select_value_stream(custom_value_stream_name)
  end

  def toggle_dropdown(field)
    page.within("[data-testid*='#{field}']") do
      find('.dropdown-toggle').click

      wait_for_requests

      expect(find('.dropdown-menu')).to have_selector('.dropdown-item')
    end
  end

  def select_dropdown_option_by_value(name, value, elem = '.dropdown-item')
    toggle_dropdown name
    page.find("[data-testid*='#{name}'] .dropdown-menu").find("#{elem}[value='#{value}']").click
  end

  def create_commit_referencing_issue(issue, branch_name: generate(:branch))
    project.repository.add_branch(user, branch_name, 'master')
    create_commit("Commit for ##{issue.iid}", issue.project, user, branch_name)
  end

  def create_commit(message, project, user, branch_name, count: 1, commit_time: nil, skip_push_handler: false)
    repository = project.repository
    oldrev = repository.commit(branch_name)&.sha || Gitlab::Git::BLANK_SHA

    if Timecop.frozen?
      mock_gitaly_multi_action_dates(repository, commit_time)
    end

    commit_shas = Array.new(count) do |index|
      commit_sha = repository.create_file(user, generate(:branch), "content", message: message, branch_name: branch_name)
      repository.commit(commit_sha)

      commit_sha
    end

    return if skip_push_handler

    Git::BranchPushService.new(
      project,
      user,
      change: {
        oldrev: oldrev,
        newrev: commit_shas.last,
        ref: 'refs/heads/master'
      }
    ).execute
  end

  def create_cycle(user, project, issue, mr, milestone, pipeline)
    issue.update!(milestone: milestone)
    pipeline.run

    ci_build = create(:ci_build, pipeline: pipeline, status: :success, author: user)

    merge_merge_requests_closing_issue(user, project, issue)
    ProcessCommitWorker.new.perform(project.id, user.id, mr.commits.last.to_hash)

    ci_build
  end

  def create_merge_request_closing_issue(user, project, issue, message: nil, source_branch: nil, commit_message: 'commit message')
    if !source_branch || project.repository.commit(source_branch).blank?
      source_branch = generate(:branch)
      project.repository.add_branch(user, source_branch, 'master')
    end

    # Cycle analytic specs often test with frozen times, which causes metrics to be
    # pinned to the current time. For example, in the plan stage, we assume that an issue
    # milestone has been created before any code has been written. We add a second
    # to ensure that the plan time is positive.
    create_commit(commit_message, project, user, source_branch, commit_time: Time.now + 1.second, skip_push_handler: true)

    opts = {
      title: 'Awesome merge_request',
      description: message || "Fixes #{issue.to_reference}",
      source_branch: source_branch,
      target_branch: 'master'
    }

    mr = MergeRequests::CreateService.new(project: project, current_user: user, params: opts).execute
    NewMergeRequestWorker.new.perform(mr, user)
    mr
  end

  def merge_merge_requests_closing_issue(user, project, issue)
    merge_requests = Issues::ReferencedMergeRequestsService
                       .new(project: project, current_user: user)
                       .closed_by_merge_requests(issue)

    merge_requests.each { |merge_request| MergeRequests::MergeService.new(project: project, current_user: user, params: { sha: merge_request.diff_head_sha }).execute(merge_request) }
  end

  def deploy_master(user, project, environment: 'production')
    dummy_job =
      case environment
      when 'production'
        dummy_production_job(user, project)
      when 'staging'
        dummy_staging_job(user, project)
      else
        raise ArgumentError
      end

    dummy_job.success! # State machine automatically update associated deployment/environment record
  end

  def dummy_production_job(user, project)
    new_dummy_job(user, project, 'production')
  end

  def dummy_staging_job(user, project)
    new_dummy_job(user, project, 'staging')
  end

  def dummy_pipeline(project)
    create(:ci_pipeline,
      sha: project.repository.commit('master').sha,
      ref: 'master',
      source: :push,
      project: project,
      protected: false)
  end

  def new_dummy_job(user, project, environment)
    create(:ci_build,
      :with_deployment,
      project: project,
      user: user,
      environment: environment,
      ref: 'master',
      tag: false,
      name: 'dummy',
      stage: 'dummy',
      pipeline: dummy_pipeline(project),
      protected: false)
  end

  def mock_gitaly_multi_action_dates(repository, commit_time)
    allow(repository.raw).to receive(:multi_action).and_wrap_original do |m, user, kargs|
      new_date = commit_time || Time.now
      branch_update = m.call(user, **kargs)

      if branch_update.newrev
        commit = rugged_repo(repository).rev_parse(branch_update.newrev)

        branch_update.newrev = commit.amend(
          update_ref: "#{Gitlab::Git::BRANCH_REF_PREFIX}#{kargs[:branch_name]}",
          author: commit.author.merge(time: new_date),
          committer: commit.committer.merge(time: new_date)
        )
      end

      branch_update
    end
  end
end
