# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BranchesFinder do
  let(:user) { create(:user) }
  let(:project) { create(:project, :repository) }
  let(:repository) { project.repository }

  let(:branch_finder) { described_class.new(repository, params) }
  let(:params) { {} }

  describe '#execute' do
    subject { branch_finder.execute }

    context 'sort only' do
      context 'by name' do
        let(:params) { {} }

        it 'sorts' do
          result = subject

          expect(result.first.name).to eq("'test'")
        end
      end

      context 'by recently_updated' do
        let(:params) { { sort: 'updated_desc' } }

        it 'sorts' do
          result = subject

          recently_updated_branch = repository.branches.max do |a, b|
            repository.commit(a.dereferenced_target).committed_date <=> repository.commit(b.dereferenced_target).committed_date
          end

          expect(result.first.name).to eq(recently_updated_branch.name)
        end
      end

      context 'by last_updated' do
        let(:params) { { sort: 'updated_asc' } }

        it 'sorts' do
          result = subject

          expect(result.first.name).to eq('feature')
        end
      end
    end

    context 'filter only' do
      context 'by name' do
        let(:params) { { search: 'fix' } }

        it 'filters branches' do
          result = subject

          expect(result.first.name).to eq('fix')
          expect(result.count).to eq(1)
        end
      end

      context 'by name ignoring letter case' do
        let(:params) { { search: 'FiX' } }

        it 'filters branches' do
          result = subject

          expect(result.first.name).to eq('fix')
          expect(result.count).to eq(1)
        end
      end

      context 'with an unknown name' do
        let(:params) { { search: 'random' } }

        it 'does not find any branch' do
          result = subject

          expect(result.count).to eq(0)
        end
      end

      context 'by provided names' do
        let(:params) { { names: %w[fix csv lfs does-not-exist] } }

        it 'filters branches' do
          result = subject

          expect(result.count).to eq(3)
          expect(result.map(&:name)).to eq(%w{csv fix lfs})
        end
      end

      context 'by name that begins with' do
        let(:params) { { search: '^feature_' } }

        it 'filters branches' do
          result = subject

          expect(result.first.name).to eq('feature_conflict')
          expect(result.count).to eq(1)
        end
      end

      context 'by name that ends with' do
        let(:params) { { search: 'feature$' } }

        it 'filters branches' do
          result = subject

          expect(result.first.name).to eq('feature')
          expect(result.count).to eq(1)
        end
      end

      context 'by nonexistent name that begins with' do
        let(:params) { { search: '^nope' } }

        it 'filters branches' do
          result = subject

          expect(result.count).to eq(0)
        end
      end

      context 'by nonexistent name that ends with' do
        let(:params) { { search: 'nope$' } }

        it 'filters branches' do
          result = subject

          expect(result.count).to eq(0)
        end
      end
    end

    context 'filter and sort' do
      context 'by name and sorts by recently_updated' do
        let(:params) { { sort: 'updated_desc', search: 'feat' } }

        it 'filters branches' do
          result = subject

          expect(result.first.name).to eq('feature_conflict')
          expect(result.count).to eq(2)
        end
      end

      context 'by name and sorts by recently_updated, with exact matches first' do
        let(:params) { { sort: 'updated_desc', search: 'feature' } }

        it 'filters branches' do
          result = subject

          expect(result.first.name).to eq('feature')
          expect(result.second.name).to eq('feature_conflict')
          expect(result.count).to eq(2)
        end
      end

      context 'by name and sorts by last_updated' do
        let(:params) { { sort: 'updated_asc', search: 'feature' } }

        it 'filters branches' do
          result = subject

          expect(result.first.name).to eq('feature')
          expect(result.count).to eq(2)
        end
      end
    end

    context 'with gitaly pagination' do
      subject { branch_finder.execute(gitaly_pagination: true) }

      context 'by page_token and per_page' do
        let(:params) { { page_token: 'feature', per_page: 2 } }

        it 'filters branches' do
          result = subject

          expect(result.map(&:name)).to eq(%w(feature_conflict few-commits))
        end
      end

      context 'by next page_token and per_page' do
        let(:params) { { page_token: 'few-commits', per_page: 2 } }

        it 'filters branches' do
          result = subject

          expect(result.map(&:name)).to eq(%w(fix flatten-dir))
        end
      end

      context 'by per_page only' do
        let(:params) { { per_page: 2 } }

        it 'filters branches' do
          result = subject

          expect(result.map(&:name)).to eq(["'test'", '2-mb-file'])
        end
      end

      context 'by page_token only' do
        let(:params) { { page_token: 'feature' } }

        it 'raises an error' do
          expect do
            subject
          end.to raise_error(Gitlab::Git::CommandError, '13:could not find page token.')
        end
      end

      context 'pagination and sort' do
        context 'by per_page' do
          let(:params) { { sort: 'updated_asc', per_page: 5 } }

          it 'filters branches' do
            result = subject

            expect(result.map(&:name)).to eq(%w(feature improve/awesome merge-test markdown feature_conflict))
          end
        end

        context 'by page_token and per_page' do
          let(:params) { { sort: 'updated_asc', page_token: 'improve/awesome', per_page: 2 } }

          it 'filters branches' do
            result = subject

            expect(result.map(&:name)).to eq(%w(merge-test markdown))
          end
        end
      end

      context 'pagination and names' do
        let(:params) { { page_token: 'fix', per_page: 2, names: %w[fix csv lfs does-not-exist] } }

        it 'falls back to default execute and ignore paginations' do
          result = subject

          expect(result.count).to eq(3)
          expect(result.map(&:name)).to eq(%w{csv fix lfs})
        end
      end

      context 'pagination and search' do
        let(:params) { { page_token: 'feature', per_page: 2, search: '^f' } }

        it 'falls back to default execute and ignore paginations' do
          result = subject

          expect(result.map(&:name)).to eq(%w(feature feature_conflict few-commits fix flatten-dir))
        end
      end
    end
  end

  describe '#total' do
    subject { branch_finder.total }

    it { is_expected.to be_an(Integer) }
    it { is_expected.to eq(repository.branch_count) }
  end
end
