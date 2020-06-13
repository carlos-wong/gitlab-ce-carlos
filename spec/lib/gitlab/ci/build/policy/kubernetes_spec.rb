# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Ci::Build::Policy::Kubernetes do
  let(:pipeline) { create(:ci_pipeline, project: project) }

  context 'when kubernetes service is active' do
    context 'when user configured kubernetes from CI/CD > Clusters' do
      let!(:cluster) { create(:cluster, :project, :provided_by_gcp) }
      let(:project) { cluster.project }

      it 'is satisfied by a kubernetes pipeline' do
        expect(described_class.new('active'))
          .to be_satisfied_by(pipeline)
      end
    end
  end

  context 'when kubernetes service is inactive' do
    let_it_be(:project) { create(:project) }

    it 'is not satisfied by a pipeline without kubernetes available' do
      expect(described_class.new('active'))
        .not_to be_satisfied_by(pipeline)
    end
  end

  context 'when kubernetes policy is invalid' do
    it 'raises an error' do
      expect { described_class.new('unknown') }
        .to raise_error(described_class::UnknownPolicyError)
    end
  end
end
