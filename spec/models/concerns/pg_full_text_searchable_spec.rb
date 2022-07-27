# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PgFullTextSearchable do
  let(:project) { create(:project) }

  let(:model_class) do
    Class.new(ActiveRecord::Base) do
      include PgFullTextSearchable

      self.table_name = 'issues'

      belongs_to :project
      has_one :search_data, class_name: 'Issues::SearchData'

      before_validation -> { self.work_item_type_id = ::WorkItems::Type.default_issue_type.id }

      def persist_pg_full_text_search_vector(search_vector)
        Issues::SearchData.upsert({ project_id: project_id, issue_id: id, search_vector: search_vector }, unique_by: %i(project_id issue_id))
      end

      def self.name
        'Issue'
      end
    end
  end

  describe '.pg_full_text_searchable' do
    it 'sets pg_full_text_searchable_columns' do
      model_class.pg_full_text_searchable columns: [{ name: 'title', weight: 'A' }]

      expect(model_class.pg_full_text_searchable_columns).to eq({ 'title' => 'A' })
    end

    it 'raises an error when called twice' do
      model_class.pg_full_text_searchable columns: [{ name: 'title', weight: 'A' }]

      expect { model_class.pg_full_text_searchable columns: [{ name: 'title', weight: 'A' }] }.to raise_error('Full text search columns already defined!')
    end
  end

  describe 'after commit hook' do
    let(:model) { model_class.create!(project: project) }

    before do
      model_class.pg_full_text_searchable columns: [{ name: 'title', weight: 'A' }]
    end

    context 'when specified columns are changed' do
      it 'calls update_search_data!' do
        expect(model).to receive(:update_search_data!)

        model.update!(title: 'A new title')
      end
    end

    context 'when specified columns are not changed' do
      it 'does not call update_search_data!' do
        expect(model).not_to receive(:update_search_data!)

        model.update!(description: 'A new description')
      end
    end

    context 'when model is updated twice within a transaction' do
      it 'calls update_search_data!' do
        expect(model).to receive(:update_search_data!)

        model.transaction do
          model.update!(title: 'A new title')
          model.update!(updated_at: Time.current)
        end
      end
    end
  end

  describe '.pg_full_text_search' do
    let(:english) { model_class.create!(project: project, title: 'title', description: 'something english') }
    let(:with_accent) { model_class.create!(project: project, title: 'Jürgen', description: 'Ærøskøbing') }
    let(:japanese) { model_class.create!(project: project, title: '日本語 title', description: 'another english description') }

    before do
      model_class.pg_full_text_searchable columns: [{ name: 'title', weight: 'A' }, { name: 'description', weight: 'B' }]

      [english, with_accent, japanese].each(&:update_search_data!)
    end

    it 'searches across all fields' do
      expect(model_class.pg_full_text_search('title english')).to contain_exactly(english, japanese)
    end

    it 'searches for exact term with quotes' do
      expect(model_class.pg_full_text_search('"something english"')).to contain_exactly(english)
    end

    it 'ignores accents' do
      expect(model_class.pg_full_text_search('jurgen')).to contain_exactly(with_accent)
    end

    it 'does not support searching by non-Latin characters' do
      expect(model_class.pg_full_text_search('日本')).to be_empty
    end

    context 'when search term has a URL' do
      let(:with_url) { model_class.create!(project: project, title: 'issue with url', description: 'sample url,https://gitlab.com/gitlab-org/gitlab') }

      it 'allows searching by full URL, ignoring the scheme' do
        with_url.update_search_data!

        expect(model_class.pg_full_text_search('https://gitlab.com/gitlab-org/gitlab')).to contain_exactly(with_url)
        expect(model_class.pg_full_text_search('gopher://gitlab.com/gitlab-org/gitlab')).to contain_exactly(with_url)
      end
    end
  end

  describe '#update_search_data!' do
    let(:model) { model_class.create!(project: project, title: 'title', description: 'description') }

    before do
      model_class.pg_full_text_searchable columns: [{ name: 'title', weight: 'A' }, { name: 'description', weight: 'B' }]
    end

    it 'sets the correct weights' do
      model.update_search_data!

      expect(model.search_data.search_vector).to match(/'titl':1A/)
      expect(model.search_data.search_vector).to match(/'descript':2B/)
    end

    context 'with accented and non-Latin characters' do
      let(:model) { model_class.create!(project: project, title: '日本語', description: 'Jürgen') }

      it 'transliterates accented characters and removes non-Latin ones' do
        model.update_search_data!

        expect(model.search_data.search_vector).not_to match(/日本語/)
        expect(model.search_data.search_vector).to match(/jurgen/)
      end
    end

    context 'with long words' do
      let(:model) { model_class.create!(project: project, title: 'title ' + 'long/sequence+1' * 4, description: 'description ' + '@user1' * 20) }

      it 'strips words that are 50 characters or longer' do
        model.update_search_data!

        expect(model.search_data.search_vector).to match(/'titl':1A/)
        expect(model.search_data.search_vector).not_to match(/long/)
        expect(model.search_data.search_vector).not_to match(/sequence/)

        expect(model.search_data.search_vector).to match(/'descript':2B/)
        expect(model.search_data.search_vector).not_to match(/@user1/)
      end
    end

    context 'when upsert times out' do
      it 're-raises the exception' do
        expect(Issues::SearchData).to receive(:upsert).once.and_raise(ActiveRecord::StatementTimeout)

        expect { model.update_search_data! }.to raise_error(ActiveRecord::StatementTimeout)
      end
    end

    context 'with strings that go over tsvector limit', :delete do
      let(:long_string) { Array.new(30_000) { SecureRandom.hex }.join(' ') }
      let(:model) { model_class.create!(project: project, title: 'title', description: long_string) }

      it 'does not raise an exception' do
        expect(Gitlab::AppJsonLogger).to receive(:error).with(
          a_hash_including(class: model_class.name, model_id: model.id)
        )

        expect { model.update_search_data! }.not_to raise_error

        expect(model.search_data).to eq(nil)
      end
    end

    context 'when model class does not implement persist_pg_full_text_search_vector' do
      let(:model_class) do
        Class.new(ActiveRecord::Base) do
          include PgFullTextSearchable

          self.table_name = 'issues'

          belongs_to :project
          has_one :search_data, class_name: 'Issues::SearchData'

          before_validation -> { self.work_item_type_id = ::WorkItems::Type.default_issue_type.id }

          def self.name
            'Issue'
          end
        end
      end

      it 'raises an error' do
        expect { model.update_search_data! }.to raise_error(NotImplementedError)
      end
    end
  end
end
