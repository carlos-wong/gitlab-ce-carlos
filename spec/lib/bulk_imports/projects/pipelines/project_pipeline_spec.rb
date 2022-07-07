# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Projects::Pipelines::ProjectPipeline do
  describe '#run' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:bulk_import) { create(:bulk_import, user: user) }

    let_it_be(:entity) do
      create(
        :bulk_import_entity,
        source_type: :project_entity,
        bulk_import: bulk_import,
        source_full_path: 'source/full/path',
        destination_name: 'My Destination Project',
        destination_namespace: group.full_path
      )
    end

    let_it_be(:tracker) { create(:bulk_import_tracker, entity: entity) }
    let_it_be(:context) { BulkImports::Pipeline::Context.new(tracker) }

    let(:project_data) do
      {
        'visibility' => 'private',
        'created_at' => '2016-08-12T09:41:03'
      }
    end

    subject(:project_pipeline) { described_class.new(context) }

    before do
      allow_next_instance_of(BulkImports::Common::Extractors::GraphqlExtractor) do |extractor|
        allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: project_data))
      end

      group.add_owner(user)
    end

    it 'imports new project into destination group', :aggregate_failures do
      expect { project_pipeline.run }.to change { Project.count }.by(1)

      project_path = 'my-destination-project'
      imported_project = Project.find_by_path(project_path)

      expect(imported_project).not_to be_nil
      expect(imported_project.group).to eq(group)
      expect(imported_project.visibility).to eq(project_data['visibility'])
      expect(imported_project.created_at).to eq(project_data['created_at'])
    end
  end

  describe 'pipeline parts' do
    it { expect(described_class).to include_module(BulkImports::Pipeline) }
    it { expect(described_class).to include_module(BulkImports::Pipeline::Runner) }

    it 'has extractors' do
      expect(described_class.get_extractor)
        .to eq(
          klass: BulkImports::Common::Extractors::GraphqlExtractor,
          options: { query: BulkImports::Projects::Graphql::GetProjectQuery }
        )
    end

    it 'has transformers' do
      expect(described_class.transformers)
        .to contain_exactly(
          { klass: BulkImports::Common::Transformers::ProhibitedAttributesTransformer, options: nil },
          { klass: BulkImports::Projects::Transformers::ProjectAttributesTransformer, options: nil }
        )
    end
  end
end
