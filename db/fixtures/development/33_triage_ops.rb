# frozen_string_literal: true

require './spec/support/sidekiq_middleware'
require './spec/support/helpers/test_env'

class Gitlab::Seeder::TriageOps
  WEBHOOK_URL = 'http://0.0.0.0:$PORT$'
  WEBHOOK_TOKEN = "triage-ops-webhook-token"

  def seed!
    puts "Updating settings to allow web hooks to localhost"
    ApplicationSetting.current_without_cache.update!(allow_local_requests_from_web_hooks_and_services: true)

    Sidekiq::Worker.skipping_transaction_check do
      Sidekiq::Testing.inline! do
        puts "Ensuring required groups"
        ensure_group('gitlab-com')
        ensure_group('gitlab-com/gl-security/appsec')
        ensure_group('gitlab-jh/jh-team')
        ensure_group('gitlab-org')
        ensure_group('gitlab-org/gitlab-core-team/community-members')
        ensure_group('gitlab-org/security')

        puts "Ensuring required projects"
        ensure_project('gitlab-org/gitlab')
        ensure_project('gitlab-org/security/gitlab')

        puts "Ensuring required bot user"
        ensure_bot_user

        puts "Setting up webhooks"
        ensure_webhook_for('gitlab-com')
        ensure_webhook_for('gitlab-org')

        puts "Ensuring work type labels"
        ensure_work_type_labels_for('gitlab-com')
        ensure_work_type_labels_for('gitlab-org')
      end
    end
  end

  private

  def ensure_bot_user
    bot = User.find_by_username('triagebot')
    bot ||= User.create!(
      username: 'triagebot',
      name: 'Triage Bot',
      email: 'triagebot@example.com',
      confirmed_at: DateTime.now,
      password: SecureRandom.hex.slice(0, 16)
    )

    ensure_group('gitlab-org').add_maintainer(bot)
    ensure_group('gitlab-com').add_maintainer(bot)

    params = {
      scopes: ['api'],
      name: "API Token #{Time.zone.now}"
    }
    response = PersonalAccessTokens::CreateService.new(current_user: bot, target_user: bot, params: params).execute

    unless response.success?
      raise "Can't create Triage Bot access token: #{response.message}"
    end

    puts "Bot with API_TOKEN=#{response[:personal_access_token].token} is present now."

    bot
  end

  def ensure_webhook_for(group_path)
    group = Group.find_by_full_path(group_path)

    hook_params = {
      enable_ssl_verification: false,
      token: WEBHOOK_TOKEN,
      url: WEBHOOK_URL.gsub("$PORT$", ENV.fetch('TRIAGE_OPS_WEBHOOK_PORT', '8091'))
    }
    # Subscribe the hook to all possible events.
    all_group_hook_events = GroupHook.triggers.values
    all_group_hook_events.each { |value| hook_params[value] = true }

    group.hooks.delete_all

    hook = group.hooks.new(hook_params)
    hook.save!

    puts "Hook with url '#{hook.url}' and token '#{hook.token}' for '#{group_path}' is present now."
  end

  def ensure_work_type_labels_for(group_path)
    label_titles = [
      'bug::availability',
      'bug::mobile',
      'bug::performance',
      'bug::vulnerability',
      'feature::addition',
      'feature::consolidation',
      'feature::enhancement',
      'feature::removal',
      'maintenance::dependency',
      'maintenance::pipelines',
      'maintenance::refactor',
      'maintenance::test-gap',
      'maintenance::usability',
      'maintenance::workflow',
      'type::bug',
      'type::feature',
      'type::maintenance',
    ]

    group = Group.find_by_full_path(group_path)

    label_titles.each do |label_title|
      color = ::Gitlab::Color.color_for(label_title[/[^:]+/])

      Labels::CreateService
        .new(title: label_title, color: "#{color}")
        .execute(group: group)
    end
  end

  def ensure_group(full_path)
    group = Group.find_by_full_path(full_path)

    return group if group

    parent_path = full_path.split('/')[0..-2].join('/')
    parent = ensure_group(parent_path) if parent_path.present?

    group_path = full_path.split('/').last

    group = Group.new(
      name: group_path.titleize,
      path: group_path,
      parent_id: parent&.id
    )
    group.description = FFaker::Lorem.sentence
    group.save!

    group.add_owner(User.first)
    group.create_namespace_settings

    group
  end

  def ensure_project(project_fullpath)
    project = Project.find_by_full_path(project_fullpath)

    return project if project

    group_path = project_fullpath.split('/')[0..-2].join('/')
    project_path = project_fullpath.split('/').last

    group = ensure_group(group_path)

    params = {
      namespace_id: group.id,
      name: project_path.titleize,
      path: project_path,
      description: FFaker::Lorem.sentence,
      visibility_level: Gitlab::VisibilityLevel::PRIVATE,
      skip_disk_validation: true
    }

    project = ::Projects::CreateService.new(User.first, params).execute

    raise "Can't create project '#{project_fullpath}' : #{project.errors.full_messages}" unless project.persisted?

    project
  end
end

if ENV['SEED_TRIAGE_OPS']
  Gitlab::Seeder.quiet do
    Gitlab::Seeder::TriageOps.new.seed!
  end
else
  puts "Skipped. Use the `SEED_TRIAGE_OPS` environment variable to enable seeding data for triage ops project."
end
