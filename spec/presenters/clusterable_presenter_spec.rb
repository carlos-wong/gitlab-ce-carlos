# frozen_string_literal: true

require 'spec_helper'

describe ClusterablePresenter do
  include Gitlab::Routing.url_helpers

  describe '.fabricate' do
    let(:project) { create(:project) }

    subject { described_class.fabricate(project) }

    it 'creates an object from a descendant presenter' do
      expect(subject).to be_kind_of(ProjectClusterablePresenter)
    end
  end

  shared_examples 'appropriate member permissions' do
    context 'with a developer' do
      before do
        clusterable.add_developer(user)
      end

      it { is_expected.to be_falsy }
    end

    context 'with a maintainer' do
      before do
        clusterable.add_maintainer(user)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#can_create_cluster?' do
    let(:user) { create(:user) }

    subject { described_class.new(clusterable).can_create_cluster? }

    before do
      allow(clusterable).to receive(:current_user).and_return(user)
    end

    context 'when clusterable is a group' do
      let(:clusterable) { create(:group) }

      it_behaves_like 'appropriate member permissions'
    end

    context 'when clusterable is a project' do
      let(:clusterable) { create(:project, :repository) }

      it_behaves_like 'appropriate member permissions'
    end
  end

  describe '#can_add_cluster?' do
    let(:user) { create(:user) }

    subject { described_class.new(clusterable).can_add_cluster? }

    before do
      clusterable.add_maintainer(user)

      allow(clusterable).to receive(:current_user).and_return(user)
    end

    context 'when clusterable is a group' do
      let(:clusterable) { create(:group) }

      it_behaves_like 'appropriate member permissions'
    end

    context 'when clusterable is a project' do
      let(:clusterable) { create(:project, :repository) }

      it_behaves_like 'appropriate member permissions'
    end
  end
end
