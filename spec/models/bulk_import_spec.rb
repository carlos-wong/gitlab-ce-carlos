# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImport, type: :model do
  let_it_be(:created_bulk_import) { create(:bulk_import, :created) }
  let_it_be(:started_bulk_import) { create(:bulk_import, :started) }
  let_it_be(:finished_bulk_import) { create(:bulk_import, :finished) }
  let_it_be(:failed_bulk_import) { create(:bulk_import, :failed) }
  let_it_be(:stale_created_bulk_import) { create(:bulk_import, :created, created_at: 3.days.ago) }
  let_it_be(:stale_started_bulk_import) { create(:bulk_import, :started, created_at: 3.days.ago) }

  describe 'associations' do
    it { is_expected.to belong_to(:user).required }
    it { is_expected.to have_one(:configuration) }
    it { is_expected.to have_many(:entities) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:source_type) }
    it { is_expected.to validate_presence_of(:status) }

    it { is_expected.to define_enum_for(:source_type).with_values(%i[gitlab]) }
  end

  describe '.stale scope' do
    subject { described_class.stale }

    it { is_expected.to contain_exactly(stale_created_bulk_import, stale_started_bulk_import) }
  end

  describe '.all_human_statuses' do
    it 'returns all human readable entity statuses' do
      expect(described_class.all_human_statuses).to contain_exactly('created', 'started', 'finished', 'failed', 'timeout')
    end
  end

  describe '.min_gl_version_for_project' do
    it { expect(described_class.min_gl_version_for_project_migration).to be_a(Gitlab::VersionInfo) }
    it { expect(described_class.min_gl_version_for_project_migration.to_s).to eq('14.4.0') }
  end

  describe '#source_version_info' do
    it 'returns source_version as Gitlab::VersionInfo' do
      bulk_import = build(:bulk_import, source_version: '9.13.2')

      expect(bulk_import.source_version_info).to be_a(Gitlab::VersionInfo)
      expect(bulk_import.source_version_info.to_s).to eq(bulk_import.source_version)
    end
  end
end
