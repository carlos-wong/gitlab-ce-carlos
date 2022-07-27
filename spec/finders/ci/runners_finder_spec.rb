# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnersFinder do
  context 'admin' do
    let_it_be(:admin) { create(:user, :admin) }

    describe '#execute' do
      context 'with 2 runners' do
        let_it_be(:runner1) { create(:ci_runner, active: true) }
        let_it_be(:runner2) { create(:ci_runner, active: false) }

        context 'with empty params' do
          it 'returns all runners' do
            expect(Ci::Runner).to receive(:with_tags).and_call_original
            expect(described_class.new(current_user: admin, params: {}).execute).to match_array [runner1, runner2]
          end
        end

        context 'with nil group' do
          it 'returns all runners' do
            expect(Ci::Runner).to receive(:with_tags).and_call_original
            expect(described_class.new(current_user: admin, params: { group: nil }).execute).to match_array [runner1, runner2]
          end
        end

        context 'with preload param set to :tag_name true' do
          it 'requests tags' do
            expect(Ci::Runner).to receive(:with_tags).and_call_original
            expect(described_class.new(current_user: admin, params: { preload: { tag_name: true } }).execute).to match_array [runner1, runner2]
          end
        end

        context 'with preload param set to :tag_name false' do
          it 'does not request tags' do
            expect(Ci::Runner).not_to receive(:with_tags)
            expect(described_class.new(current_user: admin, params: { preload: { tag_name: false } }).execute).to match_array [runner1, runner2]
          end
        end
      end

      context 'filtering' do
        context 'by search term' do
          it 'calls Ci::Runner.search' do
            expect(Ci::Runner).to receive(:search).with('term').and_call_original

            described_class.new(current_user: admin, params: { search: 'term' }).execute
          end
        end

        context 'by upgrade status' do
          let(:upgrade_status) {}

          let_it_be(:runner1) { create(:ci_runner, version: 'a') }
          let_it_be(:runner2) { create(:ci_runner, version: 'b') }
          let_it_be(:runner3) { create(:ci_runner, version: 'c') }
          let_it_be(:runner_version_recommended) do
            create(:ci_runner_version, version: 'a', status: :recommended)
          end

          let_it_be(:runner_version_not_available) do
            create(:ci_runner_version, version: 'b', status: :not_available)
          end

          let_it_be(:runner_version_available) do
            create(:ci_runner_version, version: 'c', status: :available)
          end

          def execute
            described_class.new(current_user: admin, params: { upgrade_status: upgrade_status }).execute
          end

          Ci::RunnerVersion.statuses.keys.map(&:to_sym).each do |status|
            context "set to :#{status}" do
              let(:upgrade_status) { status }

              it "calls with_upgrade_status scope with corresponding :#{status} status" do
                if [:available, :not_available, :recommended].include?(status)
                  expected_result = Ci::Runner.with_upgrade_status(status)
                end

                expect(Ci::Runner).to receive(:with_upgrade_status).with(status).and_call_original

                result = execute

                expect(result).to match_array(expected_result) if expected_result
              end
            end
          end

          context 'set to an invalid value' do
            let(:upgrade_status) { :some_invalid_status }

            it 'does not call with_upgrade_status' do
              expect(Ci::Runner).not_to receive(:with_upgrade_status)

              expect(execute).to match_array(Ci::Runner.all)
            end
          end

          context 'set to nil' do
            let(:upgrade_status) { nil }

            it 'does not call with_upgrade_status' do
              expect(Ci::Runner).not_to receive(:with_upgrade_status)

              expect(execute).to match_array(Ci::Runner.all)
            end
          end
        end

        context 'by status' do
          Ci::Runner::AVAILABLE_STATUSES.each do |status|
            it "calls the corresponding :#{status} scope on Ci::Runner" do
              expect(Ci::Runner).to receive(status.to_sym).and_call_original

              described_class.new(current_user: admin, params: { status_status: status }).execute
            end
          end
        end

        context 'by active status' do
          it 'with active set as false calls the corresponding scope on Ci::Runner with false' do
            expect(Ci::Runner).to receive(:active).with(false).and_call_original

            described_class.new(current_user: admin, params: { active: false }).execute
          end

          it 'with active set as true calls the corresponding scope on Ci::Runner with true' do
            expect(Ci::Runner).to receive(:active).with(true).and_call_original

            described_class.new(current_user: admin, params: { active: true }).execute
          end
        end

        context 'by runner type' do
          it 'calls the corresponding scope on Ci::Runner' do
            expect(Ci::Runner).to receive(:project_type).and_call_original

            described_class.new(current_user: admin, params: { type_type: 'project_type' }).execute
          end
        end

        context 'by tag_name' do
          it 'calls the corresponding scope on Ci::Runner' do
            expect(Ci::Runner).to receive(:tagged_with).with(%w[tag1 tag2]).and_call_original

            described_class.new(current_user: admin, params: { tag_name: %w[tag1 tag2] }).execute
          end
        end
      end

      context 'sorting' do
        let_it_be(:runner1) { create :ci_runner, created_at: '2018-07-12 07:00', contacted_at: 1.minute.ago, token_expires_at: '2022-02-15 07:00' }
        let_it_be(:runner2) { create :ci_runner, created_at: '2018-07-12 08:00', contacted_at: 3.minutes.ago, token_expires_at: '2022-02-15 06:00' }
        let_it_be(:runner3) { create :ci_runner, created_at: '2018-07-12 09:00', contacted_at: 2.minutes.ago }

        subject do
          described_class.new(current_user: admin, params: params).execute
        end

        shared_examples 'sorts by created_at descending' do
          it 'sorts by created_at descending' do
            is_expected.to eq [runner3, runner2, runner1]
          end
        end

        context 'without sort param' do
          let(:params) { {} }

          it_behaves_like 'sorts by created_at descending'
        end

        %w(created_date created_at_desc).each do |sort|
          context "with sort param equal to #{sort}" do
            let(:params) { { sort: sort } }

            it_behaves_like 'sorts by created_at descending'
          end
        end

        context 'with sort param equal to created_at_asc' do
          let(:params) { { sort: 'created_at_asc' } }

          it 'sorts by created_at ascending' do
            is_expected.to eq [runner1, runner2, runner3]
          end
        end

        context 'with sort param equal to contacted_asc' do
          let(:params) { { sort: 'contacted_asc' } }

          it 'sorts by contacted_at ascending' do
            is_expected.to eq [runner2, runner3, runner1]
          end
        end

        context 'with sort param equal to contacted_desc' do
          let(:params) { { sort: 'contacted_desc' } }

          it 'sorts by contacted_at descending' do
            is_expected.to eq [runner1, runner3, runner2]
          end
        end

        context 'with sort param equal to token_expires_at_asc' do
          let(:params) { { sort: 'token_expires_at_asc' } }

          it 'sorts by contacted_at ascending' do
            is_expected.to eq [runner2, runner1, runner3]
          end
        end

        context 'with sort param equal to token_expires_at_desc' do
          let(:params) { { sort: 'token_expires_at_desc' } }

          it 'sorts by contacted_at descending' do
            is_expected.to eq [runner3, runner1, runner2]
          end
        end
      end

      context 'by non admin user' do
        it 'returns no runners' do
          user = create :user
          create :ci_runner, active: true
          create :ci_runner, active: false

          expect(described_class.new(current_user: user, params: {}).execute).to be_empty
        end
      end

      context 'when user is nil' do
        it 'returns no runners' do
          user = nil
          create :ci_runner, active: true
          create :ci_runner, active: false

          expect(described_class.new(current_user: user, params: {}).execute).to be_empty
        end
      end
    end
  end

  context 'group' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group_1) { create(:group, parent: group) }
    let_it_be(:sub_group_2) { create(:group, parent: group) }
    let_it_be(:sub_group_3) { create(:group, parent: sub_group_1) }
    let_it_be(:sub_group_4) { create(:group, parent: sub_group_3) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:project_2) { create(:project, group: group) }
    let_it_be(:project_3) { create(:project, group: sub_group_1) }
    let_it_be(:project_4) { create(:project, group: sub_group_2) }
    let_it_be(:project_5) { create(:project, group: sub_group_3) }
    let_it_be(:project_6) { create(:project, group: sub_group_4) }
    let_it_be(:runner_instance) { create(:ci_runner, :instance, contacted_at: 13.minutes.ago) }
    let_it_be(:runner_group) { create(:ci_runner, :group, contacted_at: 12.minutes.ago) }
    let_it_be(:runner_sub_group_1) { create(:ci_runner, :group, active: false, contacted_at: 11.minutes.ago) }
    let_it_be(:runner_sub_group_2) { create(:ci_runner, :group, contacted_at: 10.minutes.ago) }
    let_it_be(:runner_sub_group_3) { create(:ci_runner, :group, contacted_at: 9.minutes.ago) }
    let_it_be(:runner_sub_group_4) { create(:ci_runner, :group, contacted_at: 8.minutes.ago) }
    let_it_be(:runner_project_1) { create(:ci_runner, :project, contacted_at: 7.minutes.ago, projects: [project])}
    let_it_be(:runner_project_2) { create(:ci_runner, :project, contacted_at: 6.minutes.ago, projects: [project_2])}
    let_it_be(:runner_project_3) { create(:ci_runner, :project, contacted_at: 5.minutes.ago, description: 'runner_project_search', projects: [project, project_2])}
    let_it_be(:runner_project_4) { create(:ci_runner, :project, contacted_at: 4.minutes.ago, projects: [project_3])}
    let_it_be(:runner_project_5) { create(:ci_runner, :project, contacted_at: 3.minutes.ago, tag_list: %w[runner_tag], projects: [project_4])}
    let_it_be(:runner_project_6) { create(:ci_runner, :project, contacted_at: 2.minutes.ago, projects: [project_5])}
    let_it_be(:runner_project_7) { create(:ci_runner, :project, contacted_at: 1.minute.ago, projects: [project_6])}

    let(:target_group) { nil }
    let(:membership) { nil }
    let(:extra_params) { {} }
    let(:params) { { group: target_group, membership: membership }.merge(extra_params).reject { |_, v| v.nil? } }

    before do
      group.runners << runner_group
      sub_group_1.runners << runner_sub_group_1
      sub_group_2.runners << runner_sub_group_2
      sub_group_3.runners << runner_sub_group_3
      sub_group_4.runners << runner_sub_group_4
    end

    describe '#execute' do
      subject { described_class.new(current_user: user, params: params).execute }

      shared_examples 'membership equal to :descendants' do
        it 'returns all descendant runners' do
          expect(subject).to eq([runner_project_7, runner_project_6, runner_project_5,
                                 runner_project_4, runner_project_3, runner_project_2,
                                 runner_project_1, runner_sub_group_4, runner_sub_group_3,
                                 runner_sub_group_2, runner_sub_group_1, runner_group])
        end
      end

      context 'with user as group owner' do
        before do
          group.add_owner(user)
        end

        context 'with :group as target group' do
          let(:target_group) { group }

          context 'passing no params' do
            it_behaves_like 'membership equal to :descendants'
          end

          context 'with :descendants membership' do
            let(:membership) { :descendants }

            it_behaves_like 'membership equal to :descendants'
          end

          context 'with :direct membership' do
            let(:membership) { :direct }

            it 'returns runners belonging to group' do
              expect(subject).to eq([runner_group])
            end
          end

          context 'with unknown membership' do
            let(:membership) { :unsupported }

            it 'raises an error' do
              expect { subject }.to raise_error(ArgumentError, 'Invalid membership filter')
            end
          end

          context 'with nil group' do
            let(:target_group) { nil }

            it 'returns no runners' do
              # Query should run against all runners, however since user is not admin, query returns no results
              expect(subject).to eq([])
            end
          end

          context 'with sort param' do
            let(:extra_params) { { sort: 'contacted_asc' } }

            it 'sorts by specified attribute' do
              expect(subject).to eq([runner_group, runner_sub_group_1, runner_sub_group_2,
                                     runner_sub_group_3, runner_sub_group_4, runner_project_1,
                                     runner_project_2, runner_project_3, runner_project_4,
                                     runner_project_5, runner_project_6, runner_project_7])
            end
          end

          context 'filtering' do
            context 'by search term' do
              let(:extra_params) { { search: 'runner_project_search' } }

              it 'returns correct runner' do
                expect(subject).to match_array([runner_project_3])
              end
            end

            context 'by active status' do
              let(:extra_params) { { active: false } }

              it 'returns correct runner' do
                expect(subject).to match_array([runner_sub_group_1])
              end
            end

            context 'by status' do
              let(:extra_params) { { status_status: 'paused' } }

              it 'returns correct runner' do
                expect(subject).to match_array([runner_sub_group_1])
              end
            end

            context 'by tag_name' do
              let(:extra_params) { { tag_name: %w[runner_tag] } }

              it 'returns correct runner' do
                expect(subject).to match_array([runner_project_5])
              end
            end

            context 'by runner type' do
              let(:extra_params) { { type_type: 'project_type' } }

              it 'returns correct runners' do
                expect(subject).to eq([runner_project_7, runner_project_6,
                                       runner_project_5, runner_project_4,
                                       runner_project_3, runner_project_2, runner_project_1])
              end
            end
          end
        end
      end

      context 'when user is not group owner' do
        where(:user_permission) do
          [:maintainer, :developer, :reporter, :guest]
        end

        with_them do
          before do
            create(:group_member, user_permission, group: group, user: user)
          end

          it 'returns no runners' do
            expect(subject).to be_empty
          end
        end
      end

      context 'when user has no access' do
        it 'returns no runners' do
          expect(subject).to be_empty
        end
      end

      context 'when user is nil' do
        let_it_be(:user) { nil }

        it 'returns no runners' do
          expect(subject).to be_empty
        end
      end
    end

    describe '#sort_key' do
      subject { described_class.new(current_user: user, params: params.merge(group: group)).sort_key }

      context 'without params' do
        it 'returns created_at_desc' do
          expect(subject).to eq('created_at_desc')
        end
      end

      context 'with params' do
        let(:extra_params) { { sort: 'contacted_asc' } }

        it 'returns contacted_asc' do
          expect(subject).to eq('contacted_asc')
        end
      end
    end
  end
end
