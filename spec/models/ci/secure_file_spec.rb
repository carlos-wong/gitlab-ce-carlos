# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::SecureFile do
  before do
    stub_ci_secure_file_object_storage
  end

  let(:sample_file) { fixture_file('ci_secure_files/upload-keystore.jks') }

  subject { create(:ci_secure_file, file: CarrierWaveStringFile.new(sample_file)) }

  it { is_expected.to be_a FileStoreMounter }

  it { is_expected.to belong_to(:project).required }

  it_behaves_like 'having unique enum values'

  it_behaves_like 'includes Limitable concern' do
    subject { build(:ci_secure_file, project: create(:project)) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:checksum) }
    it { is_expected.to validate_presence_of(:file_store) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:permissions) }
    it { is_expected.to validate_presence_of(:project_id) }
    context 'unique filename' do
      let_it_be(:project1) { create(:project) }

      it 'ensures the file name is unique within a given project' do
        file1 = create(:ci_secure_file, project: project1, name: 'file1')
        expect do
          create(:ci_secure_file, project: project1, name: 'file1')
        end.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Name has already been taken')

        expect(project1.secure_files.where(name: 'file1').count).to be 1
        expect(project1.secure_files.find_by(name: 'file1').id).to eq(file1.id)
      end

      it 'allows duplicate file names in different projects' do
        create(:ci_secure_file, project: project1)
        expect do
          create(:ci_secure_file, project: create(:project))
        end.not_to raise_error
      end
    end
  end

  describe '#permissions' do
    it 'defaults to read_only file permssions' do
      expect(subject.permissions).to eq('read_only')
    end
  end

  describe '#checksum' do
    it 'computes SHA256 checksum on the file before encrypted' do
      expect(subject.checksum).to eq(Digest::SHA256.hexdigest(sample_file))
    end
  end

  describe '#checksum_algorithm' do
    it 'returns the configured checksum_algorithm' do
      expect(subject.checksum_algorithm).to eq('sha256')
    end
  end

  describe '#file' do
    it 'returns the saved file' do
      expect(Base64.encode64(subject.file.read)).to eq(Base64.encode64(sample_file))
    end
  end
end
