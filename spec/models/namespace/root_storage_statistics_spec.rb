# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespace::RootStorageStatistics, type: :model do
  it { is_expected.to belong_to :namespace }
  it { is_expected.to have_one(:route).through(:namespace) }

  it { is_expected.to delegate_method(:all_projects).to(:namespace) }

  describe '#recalculate!' do
    let(:namespace) { create(:group) }
    let(:root_storage_statistics) { create(:namespace_root_storage_statistics, namespace: namespace) }

    let(:project1) { create(:project, namespace: namespace) }
    let(:project2) { create(:project, namespace: namespace) }

    let!(:stat1) { create(:project_statistics, project: project1, with_data: true, size_multiplier: 100) }
    let!(:stat2) { create(:project_statistics, project: project2, with_data: true, size_multiplier: 200) }

    shared_examples 'data refresh' do
      it 'aggregates project statistics' do
        root_storage_statistics.recalculate!

        root_storage_statistics.reload

        total_repository_size = stat1.repository_size + stat2.repository_size
        total_wiki_size = stat1.wiki_size + stat2.wiki_size
        total_lfs_objects_size = stat1.lfs_objects_size + stat2.lfs_objects_size
        total_build_artifacts_size = stat1.build_artifacts_size + stat2.build_artifacts_size
        total_packages_size = stat1.packages_size + stat2.packages_size
        total_storage_size = stat1.storage_size + stat2.storage_size

        expect(root_storage_statistics.repository_size).to eq(total_repository_size)
        expect(root_storage_statistics.wiki_size).to eq(total_wiki_size)
        expect(root_storage_statistics.lfs_objects_size).to eq(total_lfs_objects_size)
        expect(root_storage_statistics.build_artifacts_size).to eq(total_build_artifacts_size)
        expect(root_storage_statistics.packages_size).to eq(total_packages_size)
        expect(root_storage_statistics.storage_size).to eq(total_storage_size)
      end

      it 'works when there are no projects' do
        Project.delete_all

        root_storage_statistics.recalculate!

        root_storage_statistics.reload
        expect(root_storage_statistics.repository_size).to eq(0)
        expect(root_storage_statistics.wiki_size).to eq(0)
        expect(root_storage_statistics.lfs_objects_size).to eq(0)
        expect(root_storage_statistics.build_artifacts_size).to eq(0)
        expect(root_storage_statistics.packages_size).to eq(0)
        expect(root_storage_statistics.storage_size).to eq(0)
      end
    end

    it_behaves_like 'data refresh'

    context 'with subgroups' do
      let(:subgroup1) { create(:group, parent: namespace)}
      let(:subgroup2) { create(:group, parent: subgroup1)}

      let(:project1) { create(:project, namespace: subgroup1) }
      let(:project2) { create(:project, namespace: subgroup2) }

      it_behaves_like 'data refresh'
    end

    context 'with a personal namespace' do
      let(:namespace) { create(:user).namespace }

      it_behaves_like 'data refresh'
    end
  end
end
