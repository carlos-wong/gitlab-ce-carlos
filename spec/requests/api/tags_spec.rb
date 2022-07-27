# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Tags do
  let(:user) { create(:user) }
  let(:guest) { create(:user).tap { |u| project.add_guest(u) } }
  let(:project) { create(:project, :repository, creator: user, path: 'my.project') }
  let(:tag_name) { project.repository.find_tag('v1.1.0').name }
  let(:tag_message) { project.repository.find_tag('v1.1.0').message }

  let(:project_id) { project.id }
  let(:current_user) { nil }

  before do
    project.add_developer(user)
  end

  describe 'GET /projects/:id/repository/tags', :use_clean_rails_memory_store_caching do
    before do
      stub_feature_flags(tag_list_keyset_pagination: false)
    end

    let(:route) { "/projects/#{project_id}/repository/tags" }

    context 'sorting' do
      let(:current_user) { user }

      it 'sorts by descending order by default' do
        get api(route, current_user)

        desc_order_tags = project.repository.tags.sort_by { |tag| tag.dereferenced_target.committed_date }
        desc_order_tags.reverse!.map! { |tag| tag.dereferenced_target.id }

        expect(json_response.map { |tag| tag['commit']['id'] }).to eq(desc_order_tags)
      end

      it 'sorts by ascending order if specified' do
        get api("#{route}?sort=asc", current_user)

        asc_order_tags = project.repository.tags.sort_by { |tag| tag.dereferenced_target.committed_date }
        asc_order_tags.map! { |tag| tag.dereferenced_target.id }

        expect(json_response.map { |tag| tag['commit']['id'] }).to eq(asc_order_tags)
      end

      it 'sorts by name in descending order when requested' do
        get api("#{route}?order_by=name", current_user)

        ordered_by_name = project.repository.tags.map { |tag| tag.name }.sort.reverse

        expect(json_response.map { |tag| tag['name'] }).to eq(ordered_by_name)
      end

      it 'sorts by name in ascending order when requested' do
        get api("#{route}?order_by=name&sort=asc", current_user)

        ordered_by_name = project.repository.tags.map { |tag| tag.name }.sort

        expect(json_response.map { |tag| tag['name'] }).to eq(ordered_by_name)
      end
    end

    context 'searching' do
      it 'only returns searched tags' do
        get api("#{route}", user), params: { search: 'v1.1.0' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)
        expect(json_response[0]['name']).to eq('v1.1.0')
      end
    end

    shared_examples_for 'repository tags' do
      it 'returns the repository tags' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/tags')
        expect(response).to include_pagination_headers
        expect(json_response.map { |r| r['name'] }).to include(tag_name)
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user) }
        end
      end

      context 'when repository does not exist' do
        it_behaves_like '404 response' do
          let(:project) { create(:project, creator: user) }
          let(:request) { get api(route, current_user) }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like 'repository tags'
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a maintainer' do
      let(:current_user) { user }

      it_behaves_like 'repository tags'

      context 'requesting with the escaped project full path' do
        let(:project_id) { CGI.escape(project.full_path) }

        it_behaves_like 'repository tags'
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end

    context 'with releases' do
      let(:description) { 'Awesome release!' }

      let!(:release) do
        create(:release,
               :legacy,
               project: project,
               tag: tag_name,
               description: description)
      end

      it 'returns an array of project tags with release info' do
        get api(route, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/tags')
        expect(response).to include_pagination_headers

        expected_tag = json_response.find { |r| r['name'] == tag_name }
        expect(expected_tag['message']).to eq(tag_message)
        expect(expected_tag['release']['description']).to eq(description)
      end
    end

    context 'with keyset pagination on', :aggregate_errors do
      before do
        stub_feature_flags(tag_list_keyset_pagination: true)
      end

      context 'with keyset pagination option' do
        let(:base_params) { { pagination: 'keyset' } }

        context 'with gitaly pagination params' do
          context 'with high limit' do
            let(:params) { base_params.merge(per_page: 100) }

            it 'returns all repository tags' do
              get api(route, user), params: params

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to match_response_schema('public_api/v4/tags')
              expect(response.headers).not_to include('Link')
              tag_names = json_response.map { |x| x['name'] }
              expect(tag_names).to match_array(project.repository.tag_names)
            end
          end

          context 'with low limit' do
            let(:params) { base_params.merge(per_page: 2) }

            it 'returns limited repository tags' do
              get api(route, user), params: params

              expect(response).to have_gitlab_http_status(:ok)
              expect(response).to match_response_schema('public_api/v4/tags')
              expect(response.headers).to include('Link')
              tag_names = json_response.map { |x| x['name'] }
              expect(tag_names).to match_array(%w(v1.1.0 v1.1.1))
            end
          end

          context 'with missing page token' do
            let(:params) { base_params.merge(page_token: 'unknown') }

            it_behaves_like '422 response' do
              let(:request) { get api(route, user), params: params }
              let(:message) { 'Invalid page token: refs/tags/unknown' }
            end
          end
        end
      end
    end

    describe "cache expiry" do
      let(:route) { "/projects/#{project_id}/repository/tags" }
      let(:current_user) { user }

      before do
        # Set the cache
        get api(route, current_user)
      end

      it "is cached" do
        expect(API::Entities::Tag).not_to receive(:represent)

        get api(route, current_user)
      end

      shared_examples "cache expired" do
        it "isn't cached" do
          expect(API::Entities::Tag).to receive(:represent).exactly(3).times

          get api(route, current_user)
        end
      end

      context "when protected tag is changed" do
        before do
          create(:protected_tag, name: tag_name, project: project)
        end

        it_behaves_like "cache expired"
      end

      context "when release is changed" do
        before do
          create(:release, :legacy, project: project, tag: tag_name)
        end

        it_behaves_like "cache expired"
      end

      context "when project is changed" do
        before do
          project.touch
        end

        it_behaves_like "cache expired"
      end
    end

    context 'when gitaly is unavailable' do
      let(:route) { "/projects/#{project_id}/repository/tags" }

      before do
        expect_next_instance_of(TagsFinder) do |finder|
          allow(finder).to receive(:execute).and_raise(Gitlab::Git::CommandError)
        end
      end

      it_behaves_like '503 response' do
        let(:request) { get api(route, user) }
      end
    end
  end

  describe 'GET /projects/:id/repository/tags/:tag_name' do
    let(:route) { "/projects/#{project_id}/repository/tags/#{tag_name}" }

    shared_examples_for 'repository tag' do
      it 'returns the repository branch' do
        get api(route, current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('public_api/v4/tag')
        expect(json_response['name']).to eq(tag_name)
      end

      context 'when tag does not exist' do
        let(:tag_name) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { get api(route, current_user) }
          let(:message) { '404 Tag Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { get api(route, current_user) }
        end
      end
    end

    context 'when unauthenticated', 'and project is public' do
      let(:project) { create(:project, :public, :repository) }

      it_behaves_like 'repository tag'
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { get api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a maintainer' do
      let(:current_user) { user }

      it_behaves_like 'repository tag'

      context 'requesting with the escaped project full path' do
        let(:project_id) { CGI.escape(project.full_path) }

        it_behaves_like 'repository tag'
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { get api(route, guest) }
      end
    end
  end

  describe 'POST /projects/:id/repository/tags' do
    let(:tag_name) { 'new_tag' }
    let(:route) { "/projects/#{project_id}/repository/tags" }

    shared_examples_for 'repository new tag' do
      it 'creates a new tag' do
        post api(route, current_user), params: { tag_name: tag_name, ref: 'master' }

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/tag')
        expect(json_response['name']).to eq(tag_name)
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { post api(route, current_user) }
        end
      end
    end

    context 'when unauthenticated', 'and project is private' do
      it_behaves_like '404 response' do
        let(:request) { post api(route) }
        let(:message) { '404 Project Not Found' }
      end
    end

    context 'when authenticated', 'as a guest' do
      it_behaves_like '403 response' do
        let(:request) { post api(route, guest) }
      end
    end

    context 'when authenticated', 'as a maintainer' do
      let(:current_user) { user }

      context "when a protected branch doesn't already exist" do
        it_behaves_like 'repository new tag'

        context 'when tag contains a dot' do
          let(:tag_name) { 'v7.0.1' }

          it_behaves_like 'repository new tag'
        end

        context 'requesting with the escaped project full path' do
          let(:project_id) { CGI.escape(project.full_path) }

          it_behaves_like 'repository new tag'

          context 'when tag contains a dot' do
            let(:tag_name) { 'v7.0.1' }

            it_behaves_like 'repository new tag'
          end
        end
      end

      it 'returns 400 if tag name is invalid' do
        post api(route, current_user), params: { tag_name: 'new design', ref: 'master' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Tag name invalid')
      end

      it 'returns 400 if tag already exists' do
        post api(route, current_user), params: { tag_name: 'new_design1', ref: 'master' }

        expect(response).to have_gitlab_http_status(:created)
        expect(response).to match_response_schema('public_api/v4/tag')

        post api(route, current_user), params: { tag_name: 'new_design1', ref: 'master' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Tag new_design1 already exists')
      end

      it 'returns 400 if ref name is invalid' do
        post api(route, current_user), params: { tag_name: 'new_design3', ref: 'foo' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq('Target foo is invalid')
      end

      context 'annotated tag' do
        it 'creates a new annotated tag' do
          # Identity must be set in .gitconfig to create annotated tag.
          repo_path = Gitlab::GitalyClient::StorageSettings.allow_disk_access do
            project.repository.path_to_repo
          end

          system(*%W(#{Gitlab.config.git.bin_path} --git-dir=#{repo_path} config user.name #{user.name}))
          system(*%W(#{Gitlab.config.git.bin_path} --git-dir=#{repo_path} config user.email #{user.email}))

          post api(route, current_user), params: { tag_name: 'v7.1.0', ref: 'master', message: 'Release 7.1.0' }

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/tag')
          expect(json_response['name']).to eq('v7.1.0')
          expect(json_response['message']).to eq('Release 7.1.0')
        end
      end
    end
  end

  describe 'DELETE /projects/:id/repository/tags/:tag_name' do
    let(:route) { "/projects/#{project_id}/repository/tags/#{tag_name}" }

    before do
      allow_next_instance_of(Repository) do |instance|
        allow(instance).to receive(:rm_tag).and_return(true)
      end
    end

    shared_examples_for 'repository delete tag' do
      it 'deletes a tag' do
        delete api(route, current_user)

        expect(response).to have_gitlab_http_status(:no_content)
      end

      it_behaves_like '412 response' do
        let(:request) { api(route, current_user) }
      end

      context 'when tag does not exist' do
        let(:tag_name) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { delete api(route, current_user) }
          let(:message) { '404 Tag Not Found' }
        end
      end

      context 'when repository is disabled' do
        include_context 'disabled repository'

        it_behaves_like '403 response' do
          let(:request) { delete api(route, current_user) }
        end
      end
    end

    context 'when authenticated', 'as a maintainer' do
      let(:current_user) { user }

      it_behaves_like 'repository delete tag'

      context 'requesting with the escaped project full path' do
        let(:project_id) { CGI.escape(project.full_path) }

        it_behaves_like 'repository delete tag'
      end
    end
  end
end
