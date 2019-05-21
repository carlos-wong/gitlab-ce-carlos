# frozen_string_literal: true

require 'spec_helper'

describe TestHooks::SystemService do
  let(:current_user) { create(:user) }

  describe '#execute' do
    let(:project) { create(:project, :repository) }
    let(:hook)    { create(:system_hook) }
    let(:service) { described_class.new(hook, current_user, trigger) }
    let(:success_result) { { status: :success, http_status: 200, message: 'ok' } }

    before do
      allow(Project).to receive(:first).and_return(project)
    end

    context 'hook with not implemented test' do
      let(:trigger) { 'not_implemented_events' }

      it 'returns error message' do
        expect(hook).not_to receive(:execute)
        expect(service.execute).to include({ status: :error, message: 'Testing not available for this hook' })
      end
    end

    context 'push_events' do
      let(:trigger) { 'push_events' }
      let(:trigger_key) { :push_hooks }

      it 'executes hook' do
        allow(project).to receive(:empty_repo?).and_return(false)
        expect(Gitlab::DataBuilder::Push).to receive(:sample_data).and_call_original

        expect(hook).to receive(:execute).with(Gitlab::DataBuilder::Push::SAMPLE_DATA, trigger_key).and_return(success_result)
        expect(service.execute).to include(success_result)
      end
    end

    context 'tag_push_events' do
      let(:trigger) { 'tag_push_events' }
      let(:trigger_key) { :tag_push_hooks }

      it 'executes hook' do
        allow(project.repository).to receive(:tags).and_return(['tag'])
        expect(Gitlab::DataBuilder::Push).to receive(:sample_data).and_call_original

        expect(hook).to receive(:execute).with(Gitlab::DataBuilder::Push::SAMPLE_DATA, trigger_key).and_return(success_result)
        expect(service.execute).to include(success_result)
      end
    end

    context 'repository_update_events' do
      let(:trigger) { 'repository_update_events' }
      let(:trigger_key) { :repository_update_hooks }

      it 'executes hook' do
        allow(project).to receive(:empty_repo?).and_return(false)
        expect(Gitlab::DataBuilder::Repository).to receive(:sample_data).and_call_original

        expect(hook).to receive(:execute).with(Gitlab::DataBuilder::Repository::SAMPLE_DATA, trigger_key).and_return(success_result)
        expect(service.execute).to include(success_result)
      end
    end

    context 'merge_requests_events' do
      let(:trigger) { 'merge_requests_events' }

      it 'returns error message if the user does not have any repository with a merge request' do
        expect(hook).not_to receive(:execute)
        expect(service.execute).to include({ status: :error, message: 'Ensure one of your projects has merge requests.' })
      end

      it 'executes hook' do
        trigger_key = :merge_request_hooks
        sample_data = { data: 'sample' }
        create(:project_member, user: current_user, project: project)
        create(:merge_request, source_project: project)
        allow_any_instance_of(MergeRequest).to receive(:to_hook_data).and_return(sample_data)

        expect(hook).to receive(:execute).with(sample_data, trigger_key).and_return(success_result)
        expect(service.execute).to include(success_result)
      end
    end
  end
end
