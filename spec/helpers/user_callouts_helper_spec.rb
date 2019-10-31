# frozen_string_literal: true

require "spec_helper"

describe UserCalloutsHelper do
  let(:user) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '.show_gke_cluster_integration_callout?' do
    let(:project) { create(:project) }

    subject { helper.show_gke_cluster_integration_callout?(project) }

    context 'when user can create a cluster' do
      before do
        allow(helper).to receive(:can?).with(anything, :create_cluster, anything)
          .and_return(true)
      end

      context 'when user has not dismissed' do
        before do
          allow(helper).to receive(:user_dismissed?).and_return(false)
        end

        it { is_expected.to be true }
      end

      context 'when user dismissed' do
        before do
          allow(helper).to receive(:user_dismissed?).and_return(true)
        end

        it { is_expected.to be false }
      end
    end

    context 'when user can not create a cluster' do
      before do
        allow(helper).to receive(:can?).with(anything, :create_cluster, anything)
          .and_return(false)
      end

      it { is_expected.to be false }
    end
  end

  describe '.render_flash_user_callout' do
    it 'renders the flash_user_callout partial' do
      expect(helper).to receive(:render)
        .with(/flash_user_callout/, flash_type: :warning, message: 'foo', feature_name: 'bar')

      helper.render_flash_user_callout(:warning, 'foo', 'bar')
    end
  end
end
