# frozen_string_literal: true

require 'spec_helper'

describe Deployments::FinishedWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow(ProjectServiceWorker).to receive(:perform_async)
    end

    it 'executes project services for deployment_hooks' do
      deployment = create(:deployment)
      project = deployment.project
      service = create(:service, type: 'SlackService', project: project, deployment_events: true, active: true)

      worker.perform(deployment.id)

      expect(ProjectServiceWorker).to have_received(:perform_async).with(service.id, an_instance_of(Hash))
    end

    it 'does not execute an inactive service' do
      deployment = create(:deployment)
      project = deployment.project
      create(:service, type: 'SlackService', project: project, deployment_events: true, active: false)

      worker.perform(deployment.id)

      expect(ProjectServiceWorker).not_to have_received(:perform_async)
    end

    it 'does nothing if a deployment with the given id does not exist' do
      worker.perform(0)

      expect(ProjectServiceWorker).not_to have_received(:perform_async)
    end
  end
end
