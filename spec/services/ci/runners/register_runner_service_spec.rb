# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::RegisterRunnerService, '#execute' do
  let(:registration_token) { 'abcdefg123456' }
  let(:token) { }
  let(:args) { {} }

  before do
    stub_feature_flags(runner_registration_control: false)
    stub_application_setting(runners_registration_token: registration_token)
    stub_application_setting(valid_runner_registrars: ApplicationSetting::VALID_RUNNER_REGISTRAR_TYPES)
  end

  subject(:runner) { described_class.new.execute(token, args) }

  context 'when no token is provided' do
    let(:token) { '' }

    it 'returns nil' do
      is_expected.to be_nil
    end
  end

  context 'when invalid token is provided' do
    let(:token) { 'invalid' }

    it 'returns nil' do
      is_expected.to be_nil
    end
  end

  context 'when valid token is provided' do
    context 'with a registration token' do
      let(:token) { registration_token }

      it 'creates runner with default values' do
        is_expected.to be_an_instance_of(::Ci::Runner)
        expect(subject.persisted?).to be_truthy
        expect(subject.run_untagged).to be true
        expect(subject.active).to be true
        expect(subject.token).not_to eq(registration_token)
        expect(subject).to be_instance_type
      end

      context 'with non-default arguments' do
        let(:args) do
          {
            description: 'some description',
            active: false,
            locked: true,
            run_untagged: false,
            tag_list: %w(tag1 tag2),
            access_level: 'ref_protected',
            maximum_timeout: 600,
            name: 'some name',
            version: 'some version',
            revision: 'some revision',
            platform: 'some platform',
            architecture: 'some architecture',
            ip_address: '10.0.0.1',
            config: {
              gpus: 'some gpu config'
            }
          }
        end

        it 'creates runner with specified values', :aggregate_failures do
          is_expected.to be_an_instance_of(::Ci::Runner)
          expect(subject.active).to eq args[:active]
          expect(subject.locked).to eq args[:locked]
          expect(subject.run_untagged).to eq args[:run_untagged]
          expect(subject.tags).to contain_exactly(
            an_object_having_attributes(name: 'tag1'),
            an_object_having_attributes(name: 'tag2')
          )
          expect(subject.access_level).to eq args[:access_level]
          expect(subject.maximum_timeout).to eq args[:maximum_timeout]
          expect(subject.name).to eq args[:name]
          expect(subject.version).to eq args[:version]
          expect(subject.revision).to eq args[:revision]
          expect(subject.platform).to eq args[:platform]
          expect(subject.architecture).to eq args[:architecture]
          expect(subject.ip_address).to eq args[:ip_address]

          expect(Ci::Runner.tagged_with('tag1')).to include(subject)
          expect(Ci::Runner.tagged_with('tag2')).to include(subject)
        end
      end

      context 'with runner token expiration interval', :freeze_time do
        before do
          stub_application_setting(runner_token_expiration_interval: 5.days)
        end

        it 'creates runner with token expiration' do
          is_expected.to be_an_instance_of(::Ci::Runner)
          expect(subject.token_expires_at).to eq(5.days.from_now)
        end
      end
    end

    context 'when project token is used' do
      let(:project) { create(:project) }
      let(:token) { project.runners_token }

      it 'creates project runner' do
        is_expected.to be_an_instance_of(::Ci::Runner)
        expect(project.runners.size).to eq(1)
        is_expected.to eq(project.runners.first)
        expect(subject.token).not_to eq(registration_token)
        expect(subject.token).not_to eq(project.runners_token)
        expect(subject).to be_project_type
      end

      context 'when it exceeds the application limits' do
        before do
          create(:ci_runner, runner_type: :project_type, projects: [project], contacted_at: 1.second.ago)
          create(:plan_limits, :default_plan, ci_registered_project_runners: 1)
        end

        it 'does not create runner' do
          is_expected.to be_an_instance_of(::Ci::Runner)
          expect(subject.persisted?).to be_falsey
          expect(subject.errors.messages).to eq('runner_projects.base': ['Maximum number of ci registered project runners (1) exceeded'])
          expect(project.runners.reload.size).to eq(1)
        end
      end

      context 'when abandoned runners cause application limits to not be exceeded' do
        before do
          create(:ci_runner, runner_type: :project_type, projects: [project], created_at: 14.months.ago, contacted_at: 13.months.ago)
          create(:plan_limits, :default_plan, ci_registered_project_runners: 1)
        end

        it 'creates runner' do
          is_expected.to be_an_instance_of(::Ci::Runner)
          expect(subject.errors).to be_empty
          expect(project.runners.reload.size).to eq(2)
          expect(project.runners.recent.size).to eq(1)
        end
      end

      context 'when valid runner registrars do not include project' do
        before do
          stub_application_setting(valid_runner_registrars: ['group'])
        end

        context 'when feature flag is enabled' do
          before do
            stub_feature_flags(runner_registration_control: true)
          end

          it 'returns 403 error' do
            is_expected.to be_nil
          end
        end

        context 'when feature flag is disabled' do
          it 'registers the runner' do
            is_expected.to be_an_instance_of(::Ci::Runner)
            expect(subject.errors).to be_empty
            expect(subject.active).to be true
          end
        end
      end
    end

    context 'when group token is used' do
      let(:group) { create(:group) }
      let(:token) { group.runners_token }

      it 'creates a group runner' do
        is_expected.to be_an_instance_of(::Ci::Runner)
        expect(subject.errors).to be_empty
        expect(group.runners.reload.size).to eq(1)
        expect(subject.token).not_to eq(registration_token)
        expect(subject.token).not_to eq(group.runners_token)
        expect(subject).to be_group_type
      end

      context 'when it exceeds the application limits' do
        before do
          create(:ci_runner, runner_type: :group_type, groups: [group], contacted_at: nil, created_at: 1.month.ago)
          create(:plan_limits, :default_plan, ci_registered_group_runners: 1)
        end

        it 'does not create runner' do
          is_expected.to be_an_instance_of(::Ci::Runner)
          expect(subject.persisted?).to be_falsey
          expect(subject.errors.messages).to eq('runner_namespaces.base': ['Maximum number of ci registered group runners (1) exceeded'])
          expect(group.runners.reload.size).to eq(1)
        end
      end

      context 'when abandoned runners cause application limits to not be exceeded' do
        before do
          create(:ci_runner, runner_type: :group_type, groups: [group], created_at: 4.months.ago, contacted_at: 3.months.ago)
          create(:ci_runner, runner_type: :group_type, groups: [group], contacted_at: nil, created_at: 4.months.ago)
          create(:plan_limits, :default_plan, ci_registered_group_runners: 1)
        end

        it 'creates runner' do
          is_expected.to be_an_instance_of(::Ci::Runner)
          expect(subject.errors).to be_empty
          expect(group.runners.reload.size).to eq(3)
          expect(group.runners.recent.size).to eq(1)
        end
      end

      context 'when valid runner registrars do not include group' do
        before do
          stub_application_setting(valid_runner_registrars: ['project'])
        end

        context 'when feature flag is enabled' do
          before do
            stub_feature_flags(runner_registration_control: true)
          end

          it 'returns nil' do
            is_expected.to be_nil
          end
        end

        context 'when feature flag is disabled' do
          it 'registers the runner' do
            is_expected.to be_an_instance_of(::Ci::Runner)
            expect(subject.errors).to be_empty
            expect(subject.active).to be true
          end
        end
      end
    end

    context 'when tags are provided' do
      let(:token) { registration_token }

      let(:args) do
        { tag_list: %w(tag1 tag2) }
      end

      it 'creates runner with tags' do
        expect(runner).to be_persisted

        expect(runner.tags).to contain_exactly(
          an_object_having_attributes(name: 'tag1'),
          an_object_having_attributes(name: 'tag2')
        )
      end

      it 'creates tags in bulk' do
        expect(Gitlab::Ci::Tags::BulkInsert).to receive(:bulk_insert_tags!).and_call_original

        expect(runner).to be_persisted
      end

      context 'and tag list exceeds limit' do
        let(:args) do
          { tag_list: (1..Ci::Runner::TAG_LIST_MAX_LENGTH + 1).map { |i| "tag#{i}" } }
        end

        it 'does not create any tags' do
          expect(Gitlab::Ci::Tags::BulkInsert).not_to receive(:bulk_insert_tags!)

          expect(runner).not_to be_persisted
          expect(runner.tags).to be_empty
        end
      end
    end
  end
end
