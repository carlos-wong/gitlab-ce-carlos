# frozen_string_literal: true

require 'spec_helper'

describe Ci::UpdateBuildQueueService do
  let(:project) { create(:project, :repository) }
  let(:build) { create(:ci_build, pipeline: pipeline) }
  let(:pipeline) { create(:ci_pipeline, project: project) }

  shared_examples 'refreshes runner' do
    it 'ticks runner queue value' do
      expect { subject.execute(build) }.to change { runner.ensure_runner_queue_value }
    end
  end

  shared_examples 'does not refresh runner' do
    it 'ticks runner queue value' do
      expect { subject.execute(build) }.not_to change { runner.ensure_runner_queue_value }
    end
  end

  shared_examples 'matching build' do
    context 'when there is a online runner that can pick build' do
      before do
        runner.update!(contacted_at: 30.minutes.ago)
      end

      it_behaves_like 'refreshes runner'
    end
  end

  shared_examples 'mismatching tags' do
    context 'when there is no runner that can pick build due to tag mismatch' do
      before do
        build.tag_list = [:docker]
      end

      it_behaves_like 'does not refresh runner'
    end
  end

  shared_examples 'recent runner queue' do
    context 'when there is runner with expired cache' do
      before do
        runner.update!(contacted_at: Ci::Runner.recent_queue_deadline)
      end

      context 'when ci_update_queues_for_online_runners is enabled' do
        before do
          stub_feature_flags(ci_update_queues_for_online_runners: true)
        end

        it_behaves_like 'does not refresh runner'
      end

      context 'when ci_update_queues_for_online_runners is disabled' do
        before do
          stub_feature_flags(ci_update_queues_for_online_runners: false)
        end

        it_behaves_like 'refreshes runner'
      end
    end
  end

  context 'when updating specific runners' do
    let(:runner) { create(:ci_runner, :project, projects: [project]) }

    it_behaves_like 'matching build'
    it_behaves_like 'mismatching tags'
    it_behaves_like 'recent runner queue'

    context 'when the runner is assigned to another project' do
      let(:another_project) { create(:project) }
      let(:runner) { create(:ci_runner, :project, projects: [another_project]) }

      it_behaves_like 'does not refresh runner'
    end
  end

  context 'when updating shared runners' do
    let(:runner) { create(:ci_runner, :instance) }

    it_behaves_like 'matching build'
    it_behaves_like 'mismatching tags'
    it_behaves_like 'recent runner queue'

    context 'when there is no runner that can pick build due to being disabled on project' do
      before do
        build.project.shared_runners_enabled = false
      end

      it_behaves_like 'does not refresh runner'
    end
  end

  context 'when updating group runners' do
    let(:group) { create(:group) }
    let(:project) { create(:project, group: group) }
    let(:runner) { create(:ci_runner, :group, groups: [group]) }

    it_behaves_like 'matching build'
    it_behaves_like 'mismatching tags'
    it_behaves_like 'recent runner queue'

    context 'when there is no runner that can pick build due to being disabled on project' do
      before do
        build.project.group_runners_enabled = false
      end

      it_behaves_like 'does not refresh runner'
    end
  end
end
