# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchController do
  include ExternalAuthorizationServiceHelpers

  context 'authorized user' do
    let(:user) { create(:user) }

    before do
      sign_in(user)
    end

    shared_examples_for 'when the user cannot read cross project' do |action, params|
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
                            .with(user, :read_cross_project, :global) { false }
      end

      it 'blocks access without a project_id' do
        get action, params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'allows access with a project_id' do
        get action, params: params.merge(project_id: create(:project, :public).id)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    shared_examples_for 'with external authorization service enabled' do |action, params|
      let(:project) { create(:project, namespace: user.namespace) }
      let(:note) { create(:note_on_issue, project: project) }

      before do
        enable_external_authorization_service_check
      end

      it 'renders a 403 when no project is given' do
        get action, params: params

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'renders a 200 when a project was set' do
        get action, params: params.merge(project_id: project.id)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    shared_examples_for 'support for active record query timeouts' do |action, params, method_to_stub, format|
      before do
        allow_next_instance_of(SearchService) do |service|
          allow(service).to receive(method_to_stub).and_raise(ActiveRecord::QueryCanceled)
        end
      end

      it 'renders a 408 when a timeout occurs' do
        get action, params: params, format: format

        expect(response).to have_gitlab_http_status(:request_timeout)
      end
    end

    describe 'GET #show', :snowplow do
      it_behaves_like 'when the user cannot read cross project', :show, { search: 'hello' } do
        it 'still allows accessing the search page' do
          get :show

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      it_behaves_like 'with external authorization service enabled', :show, { search: 'hello' }
      it_behaves_like 'support for active record query timeouts', :show, { search: 'hello' }, :search_objects, :html

      context 'uses the right partials depending on scope' do
        using RSpec::Parameterized::TableSyntax
        render_views

        let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }

        before do
          expect(::Gitlab::GitalyClient).to receive(:allow_ref_name_caching).and_call_original
        end

        subject { get(:show, params: { project_id: project.id, scope: scope, search: 'merge' }) }

        where(:partial, :scope) do
          '_blob'        | :blobs
          '_wiki_blob'   | :wiki_blobs
          '_commit'      | :commits
        end

        with_them do
          it do
            project_wiki = create(:project_wiki, project: project, user: user)
            create(:wiki_page, wiki: project_wiki, title: 'merge', content: 'merge')

            expect(subject).to render_template("search/results/#{partial}")
          end
        end
      end

      context 'global search' do
        using RSpec::Parameterized::TableSyntax
        render_views

        context 'when block_anonymous_global_searches is disabled' do
          before do
            stub_feature_flags(block_anonymous_global_searches: false)
          end

          it 'omits pipeline status from load' do
            project = create(:project, :public)
            expect(Gitlab::Cache::Ci::ProjectPipelineStatus).not_to receive(:load_in_batch_for_projects)

            get :show, params: { scope: 'projects', search: project.name }

            expect(assigns[:search_objects].first).to eq project
          end

          context 'check search term length' do
            let(:search_queries) do
              char_limit = Gitlab::Search::Params::SEARCH_CHAR_LIMIT
              term_limit = Gitlab::Search::Params::SEARCH_TERM_LIMIT
              term_char_limit = Gitlab::Search::AbuseDetection::ABUSIVE_TERM_SIZE
              {
                chars_under_limit: (('a' * (term_char_limit - 1) + ' ') * (term_limit - 1))[0, char_limit],
                chars_over_limit: (('a' * (term_char_limit - 1) + ' ') * (term_limit - 1))[0, char_limit + 1],
                 terms_under_limit: ('abc ' * (term_limit - 1)),
                terms_over_limit: ('abc ' * (term_limit + 1)),
                term_length_over_limit: ('a' * (term_char_limit + 1)),
                term_length_under_limit: ('a' * (term_char_limit - 1))
              }
            end

            where(:string_name, :expectation) do
              :chars_under_limit       | :not_to_set_flash
              :chars_over_limit        | :set_chars_flash
              :terms_under_limit       | :not_to_set_flash
              :terms_over_limit        | :set_terms_flash
              :term_length_under_limit | :not_to_set_flash
              :term_length_over_limit  | :not_to_set_flash # abuse, so do nothing.
            end

            with_them do
              it do
                get :show, params: { scope: 'projects', search: search_queries[string_name] }

                case expectation
                when :not_to_set_flash
                  expect(controller).not_to set_flash[:alert]
                when :set_chars_flash
                  expect(controller).to set_flash[:alert].to(/characters/)
                when :set_terms_flash
                  expect(controller).to set_flash[:alert].to(/terms/)
                end
              end
            end
          end
        end

        context 'when block_anonymous_global_searches is enabled' do
          context 'for unauthenticated user' do
            before do
              sign_out(user)
            end

            it 'redirects to login page' do
              get :show, params: { scope: 'projects', search: '*' }

              expect(response).to redirect_to new_user_session_path
            end

            it 'redirects to login page when trying to circumvent the restriction' do
              get :show, params: { scope: 'projects', project_id: non_existing_record_id, search: '*' }

              expect(response).to redirect_to new_user_session_path
            end
          end

          context 'for authenticated user' do
            it 'succeeds' do
              get :show, params: { scope: 'projects', search: '*' }

              expect(response).to have_gitlab_http_status(:ok)
            end
          end

          context 'handling abusive search_terms' do
            it 'succeeds but does NOT do anything' do
              get :show, params: { scope: 'projects', search: '*', repository_ref: '-1%20OR%203%2B640-640-1=0%2B0%2B0%2B1' }
              expect(response).to have_gitlab_http_status(:ok)
              expect(assigns(:search_results)).to be_a Gitlab::EmptySearchResults
            end
          end
        end

        context 'tab feature flags' do
          subject { get :show, params: { scope: scope, search: 'term' }, format: :html }

          where(:feature_flag, :scope) do
            :global_search_code_tab           | 'blobs'
            :global_search_issues_tab         | 'issues'
            :global_search_merge_requests_tab | 'merge_requests'
            :global_search_wiki_tab           | 'wiki_blobs'
            :global_search_commits_tab        | 'commits'
            :global_search_users_tab          | 'users'
          end

          with_them do
            it 'returns 200 if flag is enabled' do
              stub_feature_flags(feature_flag => true)

              subject

              expect(response).to have_gitlab_http_status(:ok)
            end

            it 'redirects with alert if flag is disabled' do
              stub_feature_flags(feature_flag => false)

              subject

              expect(response).to redirect_to search_path
              expect(controller).to set_flash[:alert].to(/Global Search is disabled for this scope/)
            end
          end
        end
      end

      it 'finds issue comments' do
        project = create(:project, :public)
        note = create(:note_on_issue, project: project)

        get :show, params: { project_id: project.id, scope: 'notes', search: note.note }

        expect(assigns[:search_objects].first).to eq note
      end

      context 'unique users tracking' do
        before do
          allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
        end

        it_behaves_like 'tracking unique hll events' do
          subject(:request) { get :show, params: { scope: 'projects', search: 'term' } }

          let(:target_event) { 'i_search_total' }
          let(:expected_value) { instance_of(String) }
        end
      end

      it_behaves_like 'Snowplow event tracking' do
        subject { get :show, params: { group_id: namespace.id, scope: 'blobs', search: 'term' } }

        let(:project) { nil }
        let(:category) { described_class.to_s }
        let(:action) { 'i_search_total' }
        let(:namespace) { create(:group) }
        let(:feature_flag_name) { :route_hll_to_snowplow_phase2 }
      end

      context 'on restricted projects' do
        context 'when signed out' do
          before do
            sign_out(user)
          end

          it "doesn't expose comments on issues" do
            project = create(:project, :public, :issues_private)
            note = create(:note_on_issue, project: project)

            get :show, params: { project_id: project.id, scope: 'notes', search: note.note }

            expect(assigns[:search_objects].count).to eq(0)
          end
        end

        it "doesn't expose comments on merge_requests" do
          project = create(:project, :public, :merge_requests_private)
          note = create(:note_on_merge_request, project: project)

          get :show, params: { project_id: project.id, scope: 'notes', search: note.note }

          expect(assigns[:search_objects].count).to eq(0)
        end

        it "doesn't expose comments on snippets" do
          project = create(:project, :public, :snippets_private)
          note = create(:note_on_project_snippet, project: project)

          get :show, params: { project_id: project.id, scope: 'notes', search: note.note }

          expect(assigns[:search_objects].count).to eq(0)
        end
      end

      it_behaves_like 'rate limited endpoint', rate_limit_key: :search_rate_limit do
        let(:current_user) { user }

        def request
          get(:show, params: { search: 'foo@bar.com', scope: 'users' })
        end
      end
    end

    describe 'GET #count', :aggregate_failures do
      it_behaves_like 'when the user cannot read cross project', :count, { search: 'hello', scope: 'projects' }
      it_behaves_like 'with external authorization service enabled', :count, { search: 'hello', scope: 'projects' }
      it_behaves_like 'support for active record query timeouts', :count, { search: 'hello', scope: 'projects' }, :search_results, :json

      it 'returns the result count for the given term and scope' do
        create(:project, :public, name: 'hello world')
        create(:project, :public, name: 'foo bar')

        get :count, params: { search: 'hello', scope: 'projects' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'count' => '1' })
      end

      it 'raises an error if search term is missing' do
        expect do
          get :count, params: { scope: 'projects' }
        end.to raise_error(ActionController::ParameterMissing)
      end

      it 'raises an error if search scope is missing' do
        expect do
          get :count, params: { search: 'hello' }
        end.to raise_error(ActionController::ParameterMissing)
      end

      it 'sets private cache control headers' do
        get :count, params: { search: 'hello', scope: 'projects' }

        expect(response).to have_gitlab_http_status(:ok)

        expect(response.headers['Cache-Control']).to eq('max-age=60, private')
      end

      it 'does NOT blow up if search param is NOT a string' do
        get :count, params: { search: ['hello'], scope: 'projects' }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'count' => '0' })

        get :count, params: { search: { nested: 'hello' }, scope: 'projects' }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'count' => '0' })
      end

      it 'does NOT blow up if repository_ref contains abusive characters' do
        get :count, params: {
          search: 'hello',
          repository_ref: "(nslookup%20hitqlwv501f.somewhere.bad%7C%7Cperl%20-e%20%22gethostbyname('hitqlwv501f.somewhere.bad')%22)",
          scope: 'projects'
        }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'count' => '0' })
      end

      it_behaves_like 'rate limited endpoint', rate_limit_key: :search_rate_limit do
        let(:current_user) { user }

        def request
          get(:count, params: { search: 'foo@bar.com', scope: 'users' })
        end
      end
    end

    describe 'GET #autocomplete' do
      it_behaves_like 'when the user cannot read cross project', :autocomplete, { term: 'hello' }
      it_behaves_like 'with external authorization service enabled', :autocomplete, { term: 'hello' }
      it_behaves_like 'support for active record query timeouts', :autocomplete, { term: 'hello' }, :project, :json

      it 'returns an empty array when given abusive search term' do
        get :autocomplete, params: { term: ('hal' * 9000), scope: 'projects' }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to match_array([])
      end

      it_behaves_like 'rate limited endpoint', rate_limit_key: :search_rate_limit do
        let(:current_user) { user }

        def request
          get(:autocomplete, params: { term: 'foo@bar.com', scope: 'users' })
        end
      end
    end

    describe '#append_info_to_payload' do
      it 'appends search metadata for logging' do
        expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
          method.call(payload)

          expect(payload[:metadata]['meta.search.group_id']).to eq('123')
          expect(payload[:metadata]['meta.search.project_id']).to eq('456')
          expect(payload[:metadata]).not_to have_key('meta.search.search')
          expect(payload[:metadata]['meta.search.scope']).to eq('issues')
          expect(payload[:metadata]['meta.search.force_search_results']).to eq('true')
          expect(payload[:metadata]['meta.search.filters.confidential']).to eq('true')
          expect(payload[:metadata]['meta.search.filters.state']).to eq('true')
          expect(payload[:metadata]['meta.search.project_ids']).to eq(%w(456 789))
          expect(payload[:metadata]['meta.search.type']).to eq('basic')
          expect(payload[:metadata]['meta.search.level']).to eq('global')
        end

        get :show, params: { scope: 'issues', search: 'hello world', group_id: '123', project_id: '456', project_ids: %w(456 789), confidential: true, state: true, force_search_results: true }
      end

      it 'appends the default scope in meta.search.scope' do
        expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
          method.call(payload)

          expect(payload[:metadata]['meta.search.scope']).to eq('projects')
        end

        get :show, params: { search: 'hello world', group_id: '123', project_id: '456' }
      end

      it 'appends the search time based on the search' do
        expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
          method.call(payload)

          expect(payload[:metadata][:global_search_duration_s]).to be_a_kind_of(Numeric)
        end

        get :show, params: { search: 'hello world', group_id: '123', project_id: '456' }
      end
    end

    context 'abusive searches', :aggregate_failures do
      let(:project) { create(:project, :public, name: 'hello world') }
      let(:make_abusive_request) do
        get :show, params: { scope: '1;drop%20tables;boom', search: 'hello world', project_id: project.id }
      end

      before do
        enable_external_authorization_service_check
      end

      it 'returns EmptySearchResults' do
        expect(Gitlab::EmptySearchResults).to receive(:new).and_call_original
        make_abusive_request
        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  context 'unauthorized user' do
    describe 'search rate limits' do
      using RSpec::Parameterized::TableSyntax

      let(:project) { create(:project, :public) }

      where(:endpoint, :params) do
        :show         | { search: 'hello', scope: 'projects' }
        :count        | { search: 'hello', scope: 'projects' }
        :autocomplete | { term: 'hello', scope: 'projects' }
      end

      with_them do
        it_behaves_like 'rate limited endpoint', rate_limit_key: :search_rate_limit_unauthenticated do
          def request
            get endpoint, params: params.merge(project_id: project.id)
          end
        end
      end
    end

    describe 'GET #opensearch' do
      render_views

      it 'renders xml' do
        get :opensearch, format: :xml

        doc = Nokogiri::XML.parse(response.body)

        expect(response).to have_gitlab_http_status(:ok)
        expect(doc.css('OpenSearchDescription ShortName').text).to eq('GitLab')
        expect(doc.css('OpenSearchDescription *').map(&:name)).to eq(%w[ShortName Description InputEncoding Image Url SearchForm])
      end
    end
  end
end
