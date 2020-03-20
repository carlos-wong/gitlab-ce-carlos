# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20200114112932_add_temporary_partial_index_on_project_id_to_services.rb')

describe AddTemporaryPartialIndexOnProjectIdToServices, :migration do
  let(:migration) { described_class.new }

  describe '#up' do
    it 'creates temporary partial index on type' do
      expect { migration.up }.to change { migration.index_exists?(:services, :project_id, name: described_class::INDEX_NAME) }.from(false).to(true)
    end
  end

  describe '#down' do
    it 'removes temporary partial index on type' do
      migration.up

      expect { migration.down }.to change { migration.index_exists?(:services, :project_id, name: described_class::INDEX_NAME) }.from(true).to(false)
    end
  end
end
