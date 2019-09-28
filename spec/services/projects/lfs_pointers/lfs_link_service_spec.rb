# frozen_string_literal: true
require 'spec_helper'

describe Projects::LfsPointers::LfsLinkService do
  let!(:project) { create(:project, lfs_enabled: true) }
  let!(:lfs_objects_project) { create_list(:lfs_objects_project, 2, project: project) }
  let(:new_oids) { { 'oid1' => 123, 'oid2' => 125 } }
  let(:all_oids) { LfsObject.pluck(:oid, :size).to_h.merge(new_oids) }
  let(:new_lfs_object) { create(:lfs_object) }
  let(:new_oid_list) { all_oids.merge(new_lfs_object.oid => new_lfs_object.size) }

  subject { described_class.new(project) }

  before do
    allow(project).to receive(:lfs_enabled?).and_return(true)
  end

  describe '#execute' do
    it 'links existing lfs objects to the project' do
      expect(project.all_lfs_objects.count).to eq 2

      linked = subject.execute(new_oid_list.keys)

      expect(project.all_lfs_objects.count).to eq 3
      expect(linked.size).to eq 3
    end

    it 'returns linked oids' do
      linked = lfs_objects_project.map(&:lfs_object).map(&:oid) << new_lfs_object.oid

      expect(subject.execute(new_oid_list.keys)).to eq linked
    end

    it 'links in batches' do
      stub_const("#{described_class}::BATCH_SIZE", 3)

      expect(Gitlab::Import::Logger)
        .to receive(:info)
        .with(class: described_class.name,
              project_id: project.id,
              project_path: project.full_path,
              lfs_objects_linked_count: 7,
              iterations: 3)

      lfs_objects = create_list(:lfs_object, 7)
      linked = subject.execute(lfs_objects.pluck(:oid))

      expect(project.all_lfs_objects.count).to eq 9
      expect(linked.size).to eq 7
    end
  end
end
