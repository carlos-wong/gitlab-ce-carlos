# frozen_string_literal: true

require 'spec_helper'

describe Releases::DestroyService do
  let(:project) { create(:project, :repository) }
  let(:mainatiner) { create(:user) }
  let(:repoter) { create(:user) }
  let(:tag) { 'v1.1.0' }
  let!(:release) { create(:release, project: project, tag: tag) }
  let(:service) { described_class.new(project, user, params) }
  let(:params) { { tag: tag } }
  let(:user) { mainatiner }

  before do
    project.add_maintainer(mainatiner)
    project.add_reporter(repoter)
  end

  describe '#execute' do
    subject { service.execute }

    context 'when there is a release' do
      it 'removes the release' do
        expect { subject }.to change { project.releases.count }.by(-1)
      end

      it 'returns the destroyed object' do
        is_expected.to include(status: :success, release: release)
      end
    end

    context 'when tag does not exist in the repository' do
      let(:tag) { 'v1.1.1' }

      it 'removes the orphaned release' do
        expect { subject }.to change { project.releases.count }.by(-1)
      end
    end

    context 'when release is not found' do
      let!(:release) { }

      it 'returns an error' do
        is_expected.to include(status: :error,
                               message: 'Release does not exist',
                               http_status: 404)
      end
    end

    context 'when user does not have permission' do
      let(:user) { repoter }

      it 'returns an error' do
        is_expected.to include(status: :error,
                               message: 'Access Denied',
                               http_status: 403)
      end
    end
  end
end
