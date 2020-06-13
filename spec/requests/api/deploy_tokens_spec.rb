# frozen_string_literal: true

require 'spec_helper'

describe API::DeployTokens do
  let_it_be(:user)          { create(:user) }
  let_it_be(:creator)       { create(:user) }
  let_it_be(:project)       { create(:project, creator_id: creator.id) }
  let_it_be(:group)         { create(:group) }
  let!(:deploy_token) { create(:deploy_token, projects: [project]) }
  let!(:group_deploy_token) { create(:deploy_token, :group, groups: [group]) }

  shared_examples 'with feature flag disabled' do
    context 'disabled feature flag' do
      before do
        stub_feature_flags(deploy_tokens_api: false)
      end

      it { is_expected.to have_gitlab_http_status(:service_unavailable) }
    end
  end

  describe 'GET /deploy_tokens' do
    subject do
      get api('/deploy_tokens', user)
      response
    end

    it_behaves_like 'with feature flag disabled'

    context 'when unauthenticated' do
      let(:user) { nil }

      it { is_expected.to have_gitlab_http_status(:unauthorized) }
    end

    context 'when authenticated as non-admin user' do
      let(:user) { creator }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when authenticated as admin' do
      let(:user) { create(:admin) }

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns all deploy tokens' do
        subject

        expect(response).to include_pagination_headers
        expect(response).to match_response_schema('public_api/v4/deploy_tokens')
      end
    end
  end

  describe 'GET /projects/:id/deploy_tokens' do
    subject do
      get api("/projects/#{project.id}/deploy_tokens", user)
      response
    end

    context 'when unauthenticated' do
      let(:user) { nil }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when authenticated as non-admin user' do
      before do
        project.add_developer(user)
      end

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when authenticated as maintainer' do
      let!(:other_deploy_token) { create(:deploy_token) }

      before do
        project.add_maintainer(user)
      end

      it_behaves_like 'with feature flag disabled'

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns all deploy tokens for the project' do
        subject

        expect(response).to include_pagination_headers
        expect(response).to match_response_schema('public_api/v4/deploy_tokens')
      end

      it 'does not return deploy tokens for other projects' do
        subject

        token_ids = json_response.map { |token| token['id'] }
        expect(token_ids).not_to include(other_deploy_token.id)
      end
    end
  end

  describe 'GET /groups/:id/deploy_tokens' do
    subject do
      get api("/groups/#{group.id}/deploy_tokens", user)
      response
    end

    context 'when unauthenticated' do
      let(:user) { nil }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when authenticated as non-admin user' do
      before do
        group.add_developer(user)
      end

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when authenticated as maintainer' do
      let!(:other_deploy_token) { create(:deploy_token, :group) }

      before do
        group.add_maintainer(user)
      end

      it_behaves_like 'with feature flag disabled'

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns all deploy tokens for the group' do
        subject

        expect(response).to include_pagination_headers
        expect(response).to match_response_schema('public_api/v4/deploy_tokens')
      end

      it 'does not return deploy tokens for other groups' do
        subject

        token_ids = json_response.map { |token| token['id'] }
        expect(token_ids).not_to include(other_deploy_token.id)
      end
    end
  end

  describe 'DELETE /projects/:id/deploy_tokens/:token_id' do
    subject do
      delete api("/projects/#{project.id}/deploy_tokens/#{deploy_token.id}", user)
      response
    end

    context 'when unauthenticated' do
      let(:user) { nil }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when authenticated as non-admin user' do
      before do
        project.add_developer(user)
      end

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when authenticated as maintainer' do
      before do
        project.add_maintainer(user)
      end

      it { is_expected.to have_gitlab_http_status(:no_content) }

      it 'deletes the deploy token' do
        expect { subject }.to change { project.deploy_tokens.count }.by(-1)
      end

      context 'invalid request' do
        it 'returns not found with invalid group id' do
          delete api("/projects/bad_id/deploy_tokens/#{group_deploy_token.id}", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns bad_request with invalid token id' do
          delete api("/projects/#{project.id}/deploy_tokens/123abc", user)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end

  context 'deploy token creation' do
    shared_examples 'creating a deploy token' do |entity, unauthenticated_response|
      let(:params) do
        {
          name: 'Foo',
          expires_at: 1.year.from_now,
          scopes: [
            'read_repository'
          ],
          username: 'Bar'
        }
      end

      context 'when unauthenticated' do
        let(:user) { nil }

        it { is_expected.to have_gitlab_http_status(unauthenticated_response) }
      end

      context 'when authenticated as non-admin user' do
        before do
          send(entity).add_developer(user)
        end

        it { is_expected.to have_gitlab_http_status(:forbidden) }
      end

      context 'when authenticated as maintainer' do
        before do
          send(entity).add_maintainer(user)
        end

        it 'creates the deploy token' do
          expect { subject }.to change { DeployToken.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/deploy_token')
        end

        context 'with an invalid scope' do
          before do
            params[:scopes] = %w[read_repository all_access]
          end

          it { is_expected.to have_gitlab_http_status(:bad_request) }
        end
      end
    end

    describe 'POST /projects/:id/deploy_tokens' do
      subject do
        post api("/projects/#{project.id}/deploy_tokens", user), params: params
        response
      end

      it_behaves_like 'creating a deploy token', :project, :not_found
    end

    describe 'POST /groups/:id/deploy_tokens' do
      subject do
        post api("/groups/#{group.id}/deploy_tokens", user), params: params
        response
      end

      it_behaves_like 'creating a deploy token', :group, :forbidden
    end
  end

  describe 'DELETE /groups/:id/deploy_tokens/:token_id' do
    subject do
      delete api("/groups/#{group.id}/deploy_tokens/#{group_deploy_token.id}", user)
      response
    end

    context 'when unauthenticated' do
      let(:user) { nil }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when authenticated as non-admin user' do
      before do
        group.add_developer(user)
      end

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when authenticated as maintainer' do
      before do
        group.add_maintainer(user)
      end

      it 'deletes the deploy token' do
        expect { subject }.to change { group.deploy_tokens.count }.by(-1)

        expect(group.deploy_tokens).to be_empty
      end

      context 'invalid request' do
        it 'returns bad request with invalid group id' do
          delete api("/groups/bad_id/deploy_tokens/#{group_deploy_token.id}", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns not found with invalid deploy token id' do
          delete api("/groups/#{group.id}/deploy_tokens/bad_id", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
