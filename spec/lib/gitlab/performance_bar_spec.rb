require 'spec_helper'

describe Gitlab::PerformanceBar do
  shared_examples 'allowed user IDs are cached' do
    before do
      # Warm the caches
      described_class.enabled?(user)
    end

    it 'caches the allowed user IDs in cache', :use_clean_rails_memory_store_caching do
      expect do
        expect(described_class.l1_cache_backend).to receive(:fetch).and_call_original
        expect(described_class.l2_cache_backend).not_to receive(:fetch)
        expect(described_class.enabled?(user)).to be_truthy
      end.not_to exceed_query_limit(0)
    end

    it 'caches the allowed user IDs in L1 cache for 1 minute', :use_clean_rails_memory_store_caching do
      Timecop.travel 2.minutes do
        expect do
          expect(described_class.l1_cache_backend).to receive(:fetch).and_call_original
          expect(described_class.l2_cache_backend).to receive(:fetch).and_call_original
          expect(described_class.enabled?(user)).to be_truthy
        end.not_to exceed_query_limit(0)
      end
    end

    it 'caches the allowed user IDs in L2 cache for 5 minutes', :use_clean_rails_memory_store_caching do
      Timecop.travel 6.minutes do
        expect do
          expect(described_class.l1_cache_backend).to receive(:fetch).and_call_original
          expect(described_class.l2_cache_backend).to receive(:fetch).and_call_original
          expect(described_class.enabled?(user)).to be_truthy
        end.not_to exceed_query_limit(2)
      end
    end
  end

  it { expect(described_class.l1_cache_backend).to eq(Gitlab::ThreadMemoryCache.cache_backend) }
  it { expect(described_class.l2_cache_backend).to eq(Rails.cache) }

  describe '.enabled?' do
    let(:user) { create(:user) }

    before do
      stub_application_setting(performance_bar_allowed_group_id: -1)
    end

    it 'returns false when given user is nil' do
      expect(described_class.enabled?(nil)).to be_falsy
    end

    it 'returns true when given user is an admin' do
      user = build_stubbed(:user, :admin)

      expect(described_class.enabled?(user)).to be_truthy
    end

    it 'returns false when allowed_group_id is nil' do
      expect(described_class).to receive(:allowed_group_id).and_return(nil)

      expect(described_class.enabled?(user)).to be_falsy
    end

    context 'when allowed group ID does not exist' do
      it 'returns false' do
        expect(described_class.enabled?(user)).to be_falsy
      end
    end

    context 'when allowed group exists' do
      let!(:my_group) { create(:group, path: 'my-group') }

      before do
        stub_application_setting(performance_bar_allowed_group_id: my_group.id)
      end

      context 'when user is not a member of the allowed group' do
        it 'returns false' do
          expect(described_class.enabled?(user)).to be_falsy
        end

        it_behaves_like 'allowed user IDs are cached'
      end

      context 'when user is a member of the allowed group' do
        before do
          my_group.add_developer(user)
        end

        it 'returns true' do
          expect(described_class.enabled?(user)).to be_truthy
        end

        it_behaves_like 'allowed user IDs are cached'
      end
    end

    context 'when allowed group is nested' do
      let!(:nested_my_group) { create(:group, parent: create(:group, path: 'my-org'), path: 'my-group') }

      before do
        create(:group, path: 'my-group')
        nested_my_group.add_developer(user)
        stub_application_setting(performance_bar_allowed_group_id: nested_my_group.id)
      end

      it 'returns the nested group' do
        expect(described_class.enabled?(user)).to be_truthy
      end
    end

    context 'when a nested group has the same path' do
      before do
        create(:group, :nested, path: 'my-group').add_developer(user)
      end

      it 'returns false' do
        expect(described_class.enabled?(user)).to be_falsy
      end
    end
  end
end
