# frozen_string_literal: true

require 'spec_helper'

shared_examples 'clusterable policies' do
  describe '#add_cluster?' do
    let(:current_user) { create(:user) }

    subject { described_class.new(current_user, clusterable) }

    context 'with a developer' do
      before do
        clusterable.add_developer(current_user)
      end

      it { expect_disallowed(:add_cluster) }
    end

    context 'with a maintainer' do
      before do
        clusterable.add_maintainer(current_user)
      end

      context 'with no clusters' do
        it { expect_allowed(:add_cluster) }
      end

      context 'with an existing cluster' do
        before do
          cluster
        end

        it { expect_disallowed(:add_cluster) }
      end
    end
  end
end
