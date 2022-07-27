# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::WidgetInterface do
  include GraphqlHelpers

  it 'exposes the expected fields' do
    expected_fields = %i[type]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe ".resolve_type" do
    using RSpec::Parameterized::TableSyntax

    where(:widget_class, :widget_type_name) do
      WorkItems::Widgets::Description | Types::WorkItems::Widgets::DescriptionType
      WorkItems::Widgets::Hierarchy   | Types::WorkItems::Widgets::HierarchyType
      WorkItems::Widgets::Assignees   | Types::WorkItems::Widgets::AssigneesType
    end

    with_them do
      it 'knows the correct type for objects' do
        expect(
          described_class.resolve_type(widget_class.new(build(:work_item)), {})
        ).to eq(widget_type_name)
      end
    end

    it 'raises an error for an unknown type' do
      project = build(:project)

      expect { described_class.resolve_type(project, {}) }
        .to raise_error("Unknown GraphQL type for widget #{project}")
    end
  end
end
