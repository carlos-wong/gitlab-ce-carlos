# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Adding a Note' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let(:noteable) { create(:merge_request, source_project: project, target_project: project) }
  let(:project) { create(:project, :repository) }
  let(:discussion) { nil }
  let(:head_sha) { nil }
  let(:body) { 'Body text' }
  let(:mutation) do
    variables = {
      noteable_id: GitlabSchema.id_from_object(noteable).to_s,
      discussion_id: (GitlabSchema.id_from_object(discussion).to_s if discussion),
      merge_request_diff_head_sha: head_sha.presence,
      body: body
    }

    graphql_mutation(:create_note, variables)
  end

  def mutation_response
    graphql_mutation_response(:create_note)
  end

  it_behaves_like 'a Note mutation when the user does not have permission'

  context 'when the user has permission' do
    before do
      project.add_developer(current_user)
    end

    it_behaves_like 'a working GraphQL mutation'

    it_behaves_like 'a Note mutation that creates a Note'

    it_behaves_like 'a Note mutation when there are active record validation errors'

    it_behaves_like 'a Note mutation when the given resource id is not for a Noteable'

    it_behaves_like 'a Note mutation when there are rate limit validation errors'

    it 'returns the note' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['note']['body']).to eq('Body text')
    end

    describe 'creating Notes in reply to a discussion' do
      context 'when the user does not have permission to create notes on the discussion' do
        let(:discussion) { create(:discussion_note).to_discussion }

        it_behaves_like 'a mutation that returns top-level errors',
          errors: ["The discussion does not exist or you don't have permission to perform this action"]
      end

      context 'when the user has permission to create notes on the discussion' do
        let(:discussion) { create(:discussion_note, project: project).to_discussion }

        it 'creates a Note in a discussion' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['note']['discussion']['id']).to eq(discussion.to_global_id.to_s)
        end

        context 'when the discussion_id is not for a Discussion' do
          let(:discussion) { create(:issue) }

          it_behaves_like 'a mutation that returns top-level errors' do
            let(:match_errors) { include(/ does not represent an instance of Discussion/) }
          end
        end
      end
    end

    context 'for an issue' do
      let(:noteable) { create(:issue, project: project) }
      let(:mutation) do
        variables = {
          noteable_id: GitlabSchema.id_from_object(noteable).to_s,
          body: body,
          confidential: true
        }

        graphql_mutation(:create_note, variables)
      end

      before do
        project.add_developer(current_user)
      end

      it_behaves_like 'a Note mutation with confidential notes'
    end

    context 'when body only contains quick actions' do
      let(:head_sha) { noteable.diff_head_sha }
      let(:body) { '/merge' }

      before do
        project.add_developer(current_user)
      end

      # NOTE: Known issue https://gitlab.com/gitlab-org/gitlab/-/issues/346557
      it 'returns a nil note and info about the command in errors' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response).to include(
          'errors' => [/Merged this merge request/],
          'note' => nil
        )
      end

      it 'starts the merge process' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { noteable.reload.merge_jid.present? }.from(false).to(true)
      end
    end
  end
end
