# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::ObjectImporter, :aggregate_failures do
  let(:worker) do
    Class.new do
      def self.name
        'DummyWorker'
      end

      include(Gitlab::GithubImport::ObjectImporter)

      def object_type
        :dummy
      end

      def representation_class
        MockRepresantation
      end
    end.new
  end

  let_it_be(:project) { create(:project, :import_started) }
  let_it_be(:project2) { create(:project, :import_canceled) }

  let(:importer_class) { double(:importer_class, name: 'klass_name') }
  let(:importer_instance) { double(:importer_instance) }
  let(:client) { double(:client) }
  let(:github_identifiers) do
    {
      some_id: 1,
      some_type: '_some_type_'
    }
  end

  let(:representation_class) do
    Class.new do
      include Gitlab::GithubImport::Representation::ToHash
      include Gitlab::GithubImport::Representation::ExposeAttribute

      def self.from_json_hash(raw_hash)
        new(Gitlab::GithubImport::Representation.symbolize_hash(raw_hash))
      end

      attr_reader :attributes

      def initialize(attributes)
        @attributes = attributes
      end

      def github_identifiers
        {
          some_id: 1,
          some_type: '_some_type_'
        }
      end
    end
  end

  let(:stubbed_representation) { representation_class }

  before do
    stub_const('MockRepresantation', stubbed_representation)
  end

  describe '#import', :clean_gitlab_redis_cache do
    before do
      expect(worker)
        .to receive(:importer_class)
        .at_least(:once)
        .and_return(importer_class)
    end

    it 'imports the object' do
      expect(importer_class)
        .to receive(:new)
        .with(instance_of(MockRepresantation), project, client)
        .and_return(importer_instance)

      expect(importer_instance)
        .to receive(:execute)

      expect(Gitlab::GithubImport::Logger)
        .to receive(:info)
        .with(
          {
            github_identifiers: github_identifiers,
            message: 'starting importer',
            project_id: project.id,
            importer: 'klass_name'
          }
        )

      expect(Gitlab::GithubImport::Logger)
        .to receive(:info)
        .with(
          {
            github_identifiers: github_identifiers,
            message: 'importer finished',
            project_id: project.id,
            importer: 'klass_name'
          }
        )

      worker.import(project, client, { 'number' => 10, 'github_id' => 1 })

      expect(Gitlab::GithubImport::ObjectCounter.summary(project)).to eq({
        'fetched' => {},
        'imported' => { 'dummy' => 1 }
      })
    end

    it 'logs info if the import state is canceled' do
      expect(project2.import_state.status).to eq('canceled')

      expect(importer_class).not_to receive(:new)

      expect(importer_instance).not_to receive(:execute)

      expect(Gitlab::GithubImport::Logger)
        .to receive(:info)
        .with(
          {
            github_identifiers: nil,
            message: 'project import canceled',
            project_id: project2.id,
            importer: 'klass_name'
          }
        )

      worker.import(project2, client, { 'number' => 11, 'github_id' => 2 } )
    end

    it 'logs error when the import fails' do
      expect(importer_class)
        .to receive(:new)
        .with(instance_of(MockRepresantation), project, client)
        .and_return(importer_instance)

      exception = StandardError.new('some error')
      expect(importer_instance)
        .to receive(:execute)
        .and_raise(exception)

      expect(Gitlab::GithubImport::Logger)
        .to receive(:info)
        .with(
          {
            github_identifiers: github_identifiers,
            message: 'starting importer',
            project_id: project.id,
            importer: 'klass_name'
          }
        )

      expect(Gitlab::Import::ImportFailureService)
        .to receive(:track)
        .with(
          project_id: project.id,
          exception: exception,
          error_source: 'klass_name'
        )
        .and_call_original

      worker.import(project, client, { 'number' => 10, 'github_id' => 1 })

      expect(project.import_state.reload.status).to eq('started')

      expect(project.import_failures).not_to be_empty
      expect(project.import_failures.last.exception_class).to eq('StandardError')
      expect(project.import_failures.last.exception_message).to eq('some error')
    end

    context 'without github_identifiers defined' do
      let(:stubbed_representation) { representation_class.instance_eval { undef_method :github_identifiers } }

      it 'logs error when representation does not have a github_id' do
        expect(importer_class).not_to receive(:new)

        expect(Gitlab::Import::ImportFailureService)
          .to receive(:track)
          .with(
            project_id: project.id,
            exception: a_kind_of(NoMethodError),
            error_source: 'klass_name',
            fail_import: true
          )
          .and_call_original

        expect { worker.import(project, client, { 'number' => 10 }) }
          .to raise_error(NoMethodError, /^undefined method `github_identifiers/)
      end
    end
  end
end
