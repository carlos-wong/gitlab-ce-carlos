# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::WorkItemResolver do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:developer) { create(:user) }
    let_it_be(:project) { create(:project, :private).tap { |project| project.add_developer(developer) } }
    let_it_be(:work_item) { create(:work_item, project: project) }

    let(:current_user) { developer }

    subject(:resolved_work_item) { resolve_work_item('id' => work_item.to_gid.to_s) }

    context 'when the user can read the work item' do
      it { is_expected.to eq(work_item) }
    end

    context 'when the user can not read the work item' do
      let(:current_user) { create(:user) }

      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolved_work_item
        end
      end
    end

    context 'when the work_items feature flag is disabled' do
      before do
        stub_feature_flags(work_items: false)
      end

      it { is_expected.to be_nil }
    end
  end

  private

  def resolve_work_item(args = {})
    resolve(described_class, args: args, ctx: { current_user: current_user })
  end
end
