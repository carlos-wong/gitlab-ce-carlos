require 'spec_helper'

describe Types::PermissionTypes::BasePermissionType do
  let(:permitable) { double('permittable') }
  let(:current_user) { build(:user) }
  let(:context) { { current_user: current_user } }
  subject(:test_type) do
    Class.new(described_class) do
      graphql_name 'TestClass'

      permission_field :do_stuff, resolve: -> (_, _, _) { true }
      ability_field(:read_issue)
      abilities :admin_issue
    end
  end

  describe '.permission_field' do
    it 'adds a field for the required permission' do
      is_expected.to have_graphql_field(:do_stuff)
    end
  end

  describe '.ability_field' do
    it 'adds a field for the required permission' do
      is_expected.to have_graphql_field(:read_issue)
    end

    it 'does not add a resolver block if another resolving param is passed' do
      expected_keywords = {
        name: :resolve_using_hash,
        hash_key: :the_key,
        type: GraphQL::BOOLEAN_TYPE,
        description: "custom description",
        null: false
      }
      expect(test_type).to receive(:field).with(expected_keywords)

      test_type.ability_field :resolve_using_hash, hash_key: :the_key, description: "custom description"
    end
  end

  describe '.abilities' do
    it 'adds a field for the passed permissions' do
      is_expected.to have_graphql_field(:admin_issue)
    end
  end
end
