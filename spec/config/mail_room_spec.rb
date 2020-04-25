# frozen_string_literal: true

require 'spec_helper'

describe 'mail_room.yml' do
  include StubENV

  let(:mailroom_config_path) { 'config/mail_room.yml' }
  let(:gitlab_config_path) { 'config/mail_room.yml' }
  let(:queues_config_path) { 'config/redis.queues.yml' }

  let(:configuration) do
    vars = {
      'MAIL_ROOM_GITLAB_CONFIG_FILE' => absolute_path(gitlab_config_path),
      'GITLAB_REDIS_QUEUES_CONFIG_FILE' => absolute_path(queues_config_path)
    }
    cmd = "puts ERB.new(File.read(#{absolute_path(mailroom_config_path).inspect})).result"

    output, status = Gitlab::Popen.popen(%W(ruby -rerb -e #{cmd}), absolute_path('config'), vars)
    raise "Error interpreting #{mailroom_config_path}: #{output}" unless status.zero?

    YAML.load(output)
  end

  before do
    stub_env('GITLAB_REDIS_QUEUES_CONFIG_FILE', absolute_path(queues_config_path))
    clear_queues_raw_config
  end

  after do
    clear_queues_raw_config
  end

  context 'when incoming email is disabled' do
    let(:gitlab_config_path) { 'spec/fixtures/config/mail_room_disabled.yml' }

    it 'contains no configuration' do
      expect(configuration[:mailboxes]).to be_nil
    end
  end

  context 'when both incoming email and service desk email are enabled' do
    let(:gitlab_config_path) { 'spec/fixtures/config/mail_room_enabled.yml' }
    let(:queues_config_path) { 'spec/fixtures/config/redis_queues_new_format_host.yml' }
    let(:gitlab_redis_queues) { Gitlab::Redis::Queues.new(Rails.env) }

    it 'contains the intended configuration' do
      expected_mailbox = {
        host: 'imap.gmail.com',
        port: 993,
        ssl: true,
        start_tls: false,
        email: 'gitlab-incoming@gmail.com',
        password: '[REDACTED]',
        name: 'inbox',
        idle_timeout: 60
      }
      expected_options = {
        redis_url: gitlab_redis_queues.url,
        sentinels: gitlab_redis_queues.sentinels
      }

      expect(configuration[:mailboxes].length).to eq(2)
      expect(configuration[:mailboxes]).to all(include(expected_mailbox))
      expect(configuration[:mailboxes].map { |m| m[:delivery_options] }).to all(include(expected_options))
      expect(configuration[:mailboxes].map { |m| m[:arbitration_options] }).to all(include(expected_options))
    end
  end

  def clear_queues_raw_config
    Gitlab::Redis::Queues.remove_instance_variable(:@_raw_config)
  rescue NameError
    # raised if @_raw_config was not set; ignore
  end

  def absolute_path(path)
    Rails.root.join(path).to_s
  end
end
