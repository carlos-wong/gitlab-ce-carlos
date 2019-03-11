require 'spec_helper'

describe Gitlab::SQL::RecursiveCTE, :postgresql do
  let(:cte) { described_class.new(:cte_name) }

  describe '#to_arel' do
    it 'generates an Arel relation for the CTE body' do
      rel1 = User.where(id: 1)
      rel2 = User.where(id: 2)

      cte << rel1
      cte << rel2

      sql = cte.to_arel.to_sql
      name = ActiveRecord::Base.connection.quote_table_name(:cte_name)

      sql1, sql2 = ActiveRecord::Base.connection.unprepared_statement do
        [rel1.except(:order).to_sql, rel2.except(:order).to_sql]
      end

      expect(sql).to eq("#{name} AS (#{sql1}\nUNION\n#{sql2})")
    end
  end

  describe '#alias_to' do
    it 'returns an alias for the CTE' do
      table = Arel::Table.new(:kittens)

      source_name = ActiveRecord::Base.connection.quote_table_name(:cte_name)
      alias_name = ActiveRecord::Base.connection.quote_table_name(:kittens)

      expect(cte.alias_to(table).to_sql).to eq("#{source_name} AS #{alias_name}")
    end

    it 'replaces dots with an underscore' do
      table = Arel::Table.new('gitlab.kittens')

      source_name = ActiveRecord::Base.connection.quote_table_name(:cte_name)
      alias_name = ActiveRecord::Base.connection.quote_table_name(:gitlab_kittens)

      expect(cte.alias_to(table).to_sql).to eq("#{source_name} AS #{alias_name}")
    end
  end

  describe '#apply_to' do
    it 'applies a CTE to an ActiveRecord::Relation' do
      user = create(:user)
      cte = described_class.new(:cte_name)

      cte << User.where(id: user.id)

      relation = cte.apply_to(User.all)

      expect(relation.to_sql).to match(/WITH RECURSIVE.+cte_name/)
      expect(relation.to_a).to eq(User.where(id: user.id).to_a)
    end
  end
end
