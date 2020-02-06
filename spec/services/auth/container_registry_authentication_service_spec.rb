# frozen_string_literal: true

require 'spec_helper'

describe Auth::ContainerRegistryAuthenticationService do
  let(:current_project) { nil }
  let(:current_user) { nil }
  let(:current_params) { {} }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(512) }
  let(:payload) { JWT.decode(subject[:token], rsa_key, true, { algorithm: 'RS256' }).first }

  let(:authentication_abilities) do
    [:read_container_image, :create_container_image, :admin_container_image]
  end

  subject do
    described_class.new(current_project, current_user, current_params)
      .execute(authentication_abilities: authentication_abilities)
  end

  before do
    allow(Gitlab.config.registry).to receive_messages(enabled: true, issuer: 'rspec', key: nil)
    allow_next_instance_of(JSONWebToken::RSAToken) do |instance|
      allow(instance).to receive(:key).and_return(rsa_key)
    end
  end

  shared_examples 'an authenticated' do
    it { is_expected.to include(:token) }
    it { expect(payload).to include('access') }
  end

  shared_examples 'a valid token' do
    it { is_expected.to include(:token) }
    it { expect(payload).to include('access') }

    context 'a expirable' do
      let(:expires_at) { Time.at(payload['exp']) }
      let(:expire_delay) { 10 }

      context 'for default configuration' do
        it { expect(expires_at).not_to be_within(2.seconds).of(Time.now + expire_delay.minutes) }
      end

      context 'for changed configuration' do
        before do
          stub_application_setting(container_registry_token_expire_delay: expire_delay)
        end

        it { expect(expires_at).to be_within(2.seconds).of(Time.now + expire_delay.minutes) }
      end
    end
  end

  shared_examples 'a browsable' do
    let(:access) do
      [{ 'type' => 'registry',
         'name' => 'catalog',
         'actions' => ['*'] }]
    end

    it_behaves_like 'a valid token'
    it_behaves_like 'not a container repository factory'

    it 'has the correct scope' do
      expect(payload).to include('access' => access)
    end
  end

  shared_examples 'an accessible' do
    let(:access) do
      [{ 'type' => 'repository',
         'name' => project.full_path,
         'actions' => actions }]
    end

    it_behaves_like 'a valid token'

    it 'has the correct scope' do
      expect(payload).to include('access' => access)
    end
  end

  shared_examples 'an inaccessible' do
    it_behaves_like 'a valid token'
    it { expect(payload).to include('access' => []) }
  end

  shared_examples 'a deletable' do
    it_behaves_like 'an accessible' do
      let(:actions) { ['*'] }
    end
  end

  shared_examples 'a deletable since registry 2.7' do
    it_behaves_like 'an accessible' do
      let(:actions) { ['delete'] }
    end
  end

  shared_examples 'a pullable' do
    it_behaves_like 'an accessible' do
      let(:actions) { ['pull'] }
    end
  end

  shared_examples 'a pushable' do
    it_behaves_like 'an accessible' do
      let(:actions) { ['push'] }
    end
  end

  shared_examples 'a pullable and pushable' do
    it_behaves_like 'an accessible' do
      let(:actions) { %w(pull push) }
    end
  end

  shared_examples 'a forbidden' do
    it { is_expected.to include(http_status: 403) }
    it { is_expected.not_to include(:token) }
  end

  shared_examples 'container repository factory' do
    it 'creates a new container repository resource' do
      expect { subject }
        .to change { project.container_repositories.count }.by(1)
    end
  end

  shared_examples 'not a container repository factory' do
    it 'does not create a new container repository resource' do
      expect { subject }.not_to change { ContainerRepository.count }
    end
  end

  describe '#full_access_token' do
    let(:project) { create(:project) }
    let(:token) { described_class.full_access_token(project.full_path) }

    subject { { token: token } }

    it_behaves_like 'an accessible' do
      let(:actions) { ['*'] }
    end

    it_behaves_like 'not a container repository factory'
  end

  describe '#pull_access_token' do
    let(:project) { create(:project) }
    let(:token) { described_class.pull_access_token(project.full_path) }

    subject { { token: token } }

    it_behaves_like 'an accessible' do
      let(:actions) { ['pull'] }
    end

    it_behaves_like 'not a container repository factory'
  end

  context 'user authorization' do
    let(:current_user) { create(:user) }

    context 'for registry catalog' do
      let(:current_params) do
        { scopes: ["registry:catalog:*"] }
      end

      context 'disallow browsing for users without GitLab admin rights' do
        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end
    end

    context 'for private project' do
      let(:project) { create(:project) }

      context 'allow to use scope-less authentication' do
        it_behaves_like 'a valid token'
      end

      context 'allow developer to push images' do
        before do
          project.add_developer(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:push"] }
        end

        it_behaves_like 'a pushable'
        it_behaves_like 'container repository factory'
      end

      context 'disallow developer to delete images' do
        before do
          project.add_developer(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:*"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'disallow developer to delete images since registry 2.7' do
        before do
          project.add_developer(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:delete"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'allow reporter to pull images' do
        before do
          project.add_reporter(current_user)
        end

        context 'when pulling from root level repository' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:pull"] }
          end

          it_behaves_like 'a pullable'
          it_behaves_like 'not a container repository factory'
        end
      end

      context 'disallow reporter to delete images' do
        before do
          project.add_reporter(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:*"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'disallow reporter to delete images since registry 2.7' do
        before do
          project.add_reporter(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:delete"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'return a least of privileges' do
        before do
          project.add_reporter(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:push,pull"] }
        end

        it_behaves_like 'a pullable'
        it_behaves_like 'not a container repository factory'
      end

      context 'disallow guest to pull or push images' do
        before do
          project.add_guest(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:pull,push"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'disallow guest to delete images' do
        before do
          project.add_guest(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:*"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'disallow guest to delete images since registry 2.7' do
        before do
          project.add_guest(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:delete"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end
    end

    context 'for public project' do
      let(:project) { create(:project, :public) }

      context 'allow anyone to pull images' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:pull"] }
        end

        it_behaves_like 'a pullable'
        it_behaves_like 'not a container repository factory'
      end

      context 'disallow anyone to push images' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:push"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'disallow anyone to delete images' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:*"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'disallow anyone to delete images since registry 2.7' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:delete"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end

      context 'when repository name is invalid' do
        let(:current_params) do
          { scopes: ['repository:invalid:push'] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end
    end

    context 'for internal project' do
      let(:project) { create(:project, :internal) }

      context 'for internal user' do
        context 'allow anyone to pull images' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:pull"] }
          end

          it_behaves_like 'a pullable'
          it_behaves_like 'not a container repository factory'
        end

        context 'disallow anyone to push images' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:push"] }
          end

          it_behaves_like 'an inaccessible'
          it_behaves_like 'not a container repository factory'
        end

        context 'disallow anyone to delete images' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:*"] }
          end

          it_behaves_like 'an inaccessible'
          it_behaves_like 'not a container repository factory'
        end

        context 'disallow anyone to delete images since registry 2.7' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:delete"] }
          end

          it_behaves_like 'an inaccessible'
          it_behaves_like 'not a container repository factory'
        end
      end

      context 'for external user' do
        context 'disallow anyone to pull or push images' do
          let(:current_user) { create(:user, external: true) }
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:pull,push"] }
          end

          it_behaves_like 'an inaccessible'
          it_behaves_like 'not a container repository factory'
        end

        context 'disallow anyone to delete images' do
          let(:current_user) { create(:user, external: true) }
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:*"] }
          end

          it_behaves_like 'an inaccessible'
          it_behaves_like 'not a container repository factory'
        end

        context 'disallow anyone to delete images since registry 2.7' do
          let(:current_user) { create(:user, external: true) }
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:delete"] }
          end

          it_behaves_like 'an inaccessible'
          it_behaves_like 'not a container repository factory'
        end
      end
    end
  end

  context 'delete authorized as maintainer' do
    let(:current_project) { create(:project) }
    let(:current_user) { create(:user) }

    let(:authentication_abilities) do
      [:admin_container_image]
    end

    before do
      current_project.add_maintainer(current_user)
    end

    it_behaves_like 'a valid token'

    context 'allow to delete images' do
      let(:current_params) do
        { scopes: ["repository:#{current_project.full_path}:*"] }
      end

      it_behaves_like 'a deletable' do
        let(:project) { current_project }
      end
    end

    context 'allow to delete images since registry 2.7' do
      let(:current_params) do
        { scopes: ["repository:#{current_project.full_path}:delete"] }
      end

      it_behaves_like 'a deletable since registry 2.7' do
        let(:project) { current_project }
      end
    end
  end

  context 'build authorized as user' do
    let(:current_project) { create(:project) }
    let(:current_user) { create(:user) }

    let(:authentication_abilities) do
      [:build_read_container_image, :build_create_container_image, :build_destroy_container_image]
    end

    before do
      current_project.add_developer(current_user)
    end

    context 'allow to use offline_token' do
      let(:current_params) do
        { offline_token: true }
      end

      it_behaves_like 'an authenticated'
    end

    it_behaves_like 'a valid token'

    context 'allow to pull and push images' do
      let(:current_params) do
        { scopes: ["repository:#{current_project.full_path}:pull,push"] }
      end

      it_behaves_like 'a pullable and pushable' do
        let(:project) { current_project }
      end

      it_behaves_like 'container repository factory' do
        let(:project) { current_project }
      end
    end

    context 'allow to delete images since registry 2.7' do
      let(:current_params) do
        { scopes: ["repository:#{current_project.full_path}:delete"] }
      end

      it_behaves_like 'a deletable since registry 2.7' do
        let(:project) { current_project }
      end
    end

    context 'disallow to delete images' do
      let(:current_params) do
        { scopes: ["repository:#{current_project.full_path}:*"] }
      end

      it_behaves_like 'an inaccessible' do
        let(:project) { current_project }
      end
    end

    context 'for other projects' do
      context 'when pulling' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:pull"] }
        end

        context 'allow for public' do
          let(:project) { create(:project, :public) }

          it_behaves_like 'a pullable'
          it_behaves_like 'not a container repository factory'
        end

        shared_examples 'pullable for being team member' do
          context 'when you are not member' do
            it_behaves_like 'an inaccessible'
            it_behaves_like 'not a container repository factory'
          end

          context 'when you are member' do
            before do
              project.add_developer(current_user)
            end

            it_behaves_like 'a pullable'
            it_behaves_like 'not a container repository factory'
          end

          context 'when you are owner' do
            let(:project) { create(:project, namespace: current_user.namespace) }

            it_behaves_like 'a pullable'
            it_behaves_like 'not a container repository factory'
          end
        end

        context 'for private' do
          let(:project) { create(:project, :private) }

          it_behaves_like 'pullable for being team member'

          context 'when you are admin' do
            let(:current_user) { create(:admin) }

            context 'when you are not member' do
              it_behaves_like 'an inaccessible'
              it_behaves_like 'not a container repository factory'
            end

            context 'when you are member' do
              before do
                project.add_developer(current_user)
              end

              it_behaves_like 'a pullable'
              it_behaves_like 'not a container repository factory'
            end

            context 'when you are owner' do
              let(:project) { create(:project, namespace: current_user.namespace) }

              it_behaves_like 'a pullable'
              it_behaves_like 'not a container repository factory'
            end
          end
        end
      end

      context 'when pushing' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:push"] }
        end

        context 'disallow for all' do
          context 'when you are member' do
            let(:project) { create(:project, :public) }

            before do
              project.add_developer(current_user)
            end

            it_behaves_like 'an inaccessible'
            it_behaves_like 'not a container repository factory'
          end

          context 'when you are owner' do
            let(:project) { create(:project, :public, namespace: current_user.namespace) }

            it_behaves_like 'an inaccessible'
            it_behaves_like 'not a container repository factory'
          end
        end
      end
    end

    context 'for project without container registry' do
      let(:project) { create(:project, :public, container_registry_enabled: false) }

      before do
        project.update(container_registry_enabled: false)
      end

      context 'disallow when pulling' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:pull"] }
        end

        it_behaves_like 'an inaccessible'
        it_behaves_like 'not a container repository factory'
      end
    end
  end

  context 'registry catalog browsing authorized as admin' do
    let(:current_user) { create(:user, :admin) }
    let(:project) { create(:project, :public) }

    let(:current_params) do
      { scopes: ["registry:catalog:*"] }
    end

    it_behaves_like 'a browsable'
  end

  context 'support for multiple scopes' do
    let(:internal_project) { create(:project, :internal) }
    let(:private_project) { create(:project, :private) }

    let(:current_params) do
      {
        scopes: [
          "repository:#{internal_project.full_path}:pull",
          "repository:#{private_project.full_path}:pull"
        ]
      }
    end

    context 'user has access to all projects' do
      let(:current_user) { create(:user, :admin) }

      it_behaves_like 'a browsable' do
        let(:access) do
          [
            { 'type' => 'repository',
              'name' => internal_project.full_path,
              'actions' => ['pull'] },
            { 'type' => 'repository',
              'name' => private_project.full_path,
              'actions' => ['pull'] }
          ]
        end
      end
    end

    context 'user only has access to internal project' do
      let(:current_user) { create(:user) }

      it_behaves_like 'a browsable' do
        let(:access) do
          [
            { 'type' => 'repository',
              'name' => internal_project.full_path,
              'actions' => ['pull'] }
          ]
        end
      end
    end

    context 'anonymous access is rejected' do
      let(:current_user) { nil }

      it_behaves_like 'a forbidden'
    end
  end

  context 'unauthorized' do
    context 'disallow to use scope-less authentication' do
      it_behaves_like 'a forbidden'
      it_behaves_like 'not a container repository factory'
    end

    context 'for invalid scope' do
      let(:current_params) do
        { scopes: ['invalid:aa:bb'] }
      end

      it_behaves_like 'a forbidden'
      it_behaves_like 'not a container repository factory'
    end

    context 'for private project' do
      let(:project) { create(:project, :private) }

      let(:current_params) do
        { scopes: ["repository:#{project.full_path}:pull"] }
      end

      it_behaves_like 'a forbidden'
    end

    context 'for public project' do
      let(:project) { create(:project, :public) }

      context 'when pulling and pushing' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:pull,push"] }
        end

        it_behaves_like 'a pullable'
        it_behaves_like 'not a container repository factory'
      end

      context 'when pushing' do
        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:push"] }
        end

        it_behaves_like 'a forbidden'
        it_behaves_like 'not a container repository factory'
      end
    end

    context 'for registry catalog' do
      let(:current_params) do
        { scopes: ["registry:catalog:*"] }
      end

      it_behaves_like 'a forbidden'
      it_behaves_like 'not a container repository factory'
    end
  end

  context 'for deploy tokens' do
    let(:current_params) do
      { scopes: ["repository:#{project.full_path}:pull"] }
    end

    context 'when deploy token has read_registry as a scope' do
      let(:current_user) { create(:deploy_token, projects: [project]) }

      context 'for public project' do
        let(:project) { create(:project, :public) }

        context 'when pulling' do
          it_behaves_like 'a pullable'
        end

        context 'when pushing' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:push"] }
          end

          it_behaves_like 'an inaccessible'
        end
      end

      context 'for internal project' do
        let(:project) { create(:project, :internal) }

        context 'when pulling' do
          it_behaves_like 'a pullable'
        end

        context 'when pushing' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:push"] }
          end

          it_behaves_like 'an inaccessible'
        end
      end

      context 'for private project' do
        let(:project) { create(:project, :private) }

        context 'when pulling' do
          it_behaves_like 'a pullable'
        end

        context 'when pushing' do
          let(:current_params) do
            { scopes: ["repository:#{project.full_path}:push"] }
          end

          it_behaves_like 'an inaccessible'
        end
      end
    end

    context 'when deploy token does not have read_registry scope' do
      let(:current_user) { create(:deploy_token, projects: [project], read_registry: false) }

      context 'for public project' do
        let(:project) { create(:project, :public) }

        context 'when pulling' do
          it_behaves_like 'a pullable'
        end
      end

      context 'for internal project' do
        let(:project) { create(:project, :internal) }

        context 'when pulling' do
          it_behaves_like 'an inaccessible'
        end
      end

      context 'for private project' do
        let(:project) { create(:project, :internal) }

        context 'when pulling' do
          it_behaves_like 'an inaccessible'
        end
      end
    end

    context 'when deploy token is not related to the project' do
      let(:current_user) { create(:deploy_token, read_registry: false) }

      context 'for public project' do
        let(:project) { create(:project, :public) }

        context 'when pulling' do
          it_behaves_like 'a pullable'
        end
      end

      context 'for internal project' do
        let(:project) { create(:project, :internal) }

        context 'when pulling' do
          it_behaves_like 'an inaccessible'
        end
      end

      context 'for private project' do
        let(:project) { create(:project, :internal) }

        context 'when pulling' do
          it_behaves_like 'an inaccessible'
        end
      end
    end

    context 'when deploy token has been revoked' do
      let(:current_user) { create(:deploy_token, :revoked, projects: [project]) }

      context 'for public project' do
        let(:project) { create(:project, :public) }

        it_behaves_like 'a pullable'
      end

      context 'for internal project' do
        let(:project) { create(:project, :internal) }

        it_behaves_like 'an inaccessible'
      end

      context 'for private project' do
        let(:project) { create(:project, :internal) }

        it_behaves_like 'an inaccessible'
      end
    end
  end

  context 'user authorization' do
    let(:current_user) { create(:user) }

    context 'with multiple scopes' do
      let(:project) { create(:project) }
      let(:project2) { create }

      context 'allow developer to push images' do
        before do
          project.add_developer(current_user)
        end

        let(:current_params) do
          { scopes: ["repository:#{project.full_path}:push"] }
        end

        it_behaves_like 'a pushable'
        it_behaves_like 'container repository factory'
      end
    end
  end
end
