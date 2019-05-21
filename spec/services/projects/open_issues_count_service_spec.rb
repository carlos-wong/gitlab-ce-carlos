# frozen_string_literal: true

require 'spec_helper'

describe Projects::OpenIssuesCountService do
  describe '#count' do
    let(:project) { create(:project) }

    context 'when user is nil' do
      it 'does not include confidential issues in the issue count' do
        create(:issue, :opened, project: project)
        create(:issue, :opened, confidential: true, project: project)

        expect(described_class.new(project).count).to eq(1)
      end
    end

    context 'when user is provided' do
      let(:user) { create(:user) }

      context 'when user can read confidential issues' do
        before do
          project.add_reporter(user)
        end

        it 'returns the right count with confidential issues' do
          create(:issue, :opened, project: project)
          create(:issue, :opened, confidential: true, project: project)

          expect(described_class.new(project, user).count).to eq(2)
        end

        it 'uses total_open_issues_count cache key' do
          expect(described_class.new(project, user).cache_key_name).to eq('total_open_issues_count')
        end
      end

      context 'when user cannot read confidential issues' do
        before do
          project.add_guest(user)
        end

        it 'does not include confidential issues' do
          create(:issue, :opened, project: project)
          create(:issue, :opened, confidential: true, project: project)

          expect(described_class.new(project, user).count).to eq(1)
        end

        it 'uses public_open_issues_count cache key' do
          expect(described_class.new(project, user).cache_key_name).to eq('public_open_issues_count')
        end
      end
    end

    context '#refresh_cache', :use_clean_rails_memory_store_caching do
      let(:subject) { described_class.new(project) }

      before do
        create(:issue, :opened, project: project)
        create(:issue, :opened, project: project)
        create(:issue, :opened, confidential: true, project: project)
      end

      context 'when cache is empty' do
        it 'refreshes cache keys correctly' do
          subject.refresh_cache

          expect(Rails.cache.read(subject.cache_key(described_class::PUBLIC_COUNT_KEY))).to eq(2)
          expect(Rails.cache.read(subject.cache_key(described_class::TOTAL_COUNT_KEY))).to eq(3)
        end
      end

      context 'when cache is outdated' do
        before do
          subject.refresh_cache
        end

        it 'refreshes cache keys correctly' do
          create(:issue, :opened, project: project)
          create(:issue, :opened, confidential: true, project: project)

          subject.refresh_cache

          expect(Rails.cache.read(subject.cache_key(described_class::PUBLIC_COUNT_KEY))).to eq(3)
          expect(Rails.cache.read(subject.cache_key(described_class::TOTAL_COUNT_KEY))).to eq(5)
        end
      end
    end
  end
end
