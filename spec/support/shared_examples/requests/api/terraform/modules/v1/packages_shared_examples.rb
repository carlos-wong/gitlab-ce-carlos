# frozen_string_literal: true

RSpec.shared_examples 'when package feature is disabled' do
  before do
    stub_config(packages: { enabled: false })
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'without authentication' do
  it_behaves_like 'returning response status', :unauthorized
end

RSpec.shared_examples 'with authentication' do
  where(:user_role, :token_header, :token_type, :valid_token, :status) do
    :guest     | 'PRIVATE-TOKEN' | :personal_access_token   | true  | :not_found
    :guest     | 'PRIVATE-TOKEN' | :personal_access_token   | false | :unauthorized
    :guest     | 'DEPLOY-TOKEN'  | :deploy_token            | true  | :not_found
    :guest     | 'DEPLOY-TOKEN'  | :deploy_token            | false | :unauthorized
    :guest     | 'JOB-TOKEN'     | :job_token               | true  | :not_found
    :guest     | 'JOB-TOKEN'     | :job_token               | false | :unauthorized
    :reporter  | 'PRIVATE-TOKEN' | :personal_access_token   | true  | :not_found
    :reporter  | 'PRIVATE-TOKEN' | :personal_access_token   | false | :unauthorized
    :reporter  | 'DEPLOY-TOKEN'  | :deploy_token            | true  | :not_found
    :reporter  | 'DEPLOY-TOKEN'  | :deploy_token            | false | :unauthorized
    :reporter  | 'JOB-TOKEN'     | :job_token               | true  | :not_found
    :reporter  | 'JOB-TOKEN'     | :job_token               | false | :unauthorized
    :developer | 'PRIVATE-TOKEN' | :personal_access_token   | true  | :not_found
    :developer | 'PRIVATE-TOKEN' | :personal_access_token   | false | :unauthorized
    :developer | 'DEPLOY-TOKEN'  | :deploy_token            | true  | :not_found
    :developer | 'DEPLOY-TOKEN'  | :deploy_token            | false | :unauthorized
    :developer | 'JOB-TOKEN'     | :job_token               | true  | :not_found
    :developer | 'JOB-TOKEN'     | :job_token               | false | :unauthorized
  end

  with_them do
    before do
      project.send("add_#{user_role}", user) unless user_role == :anonymous
    end

    let(:token) { valid_token ? tokens[token_type] : 'invalid-token123' }
    let(:headers) { { token_header => token } }

    it_behaves_like 'returning response status', params[:status]
  end
end

RSpec.shared_examples 'an unimplemented route' do
  it_behaves_like 'without authentication'
  it_behaves_like 'with authentication'
  it_behaves_like 'when package feature is disabled'
end

RSpec.shared_examples 'redirects to version download' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      group.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status

    it 'returns a valid response' do
      subject

      expect(request.url).to include 'module-1/system/download'
      expect(response.headers).to include 'Location'
      expect(response.headers['Location']).to include 'module-1/system/1.0.1/download'
    end
  end
end

RSpec.shared_examples 'grants terraform module download' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      group.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status

    it 'returns a valid response' do
      subject

      expect(response.headers).to include 'X-Terraform-Get'
    end
  end
end

RSpec.shared_examples 'returns terraform module packages' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      group.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status

    it 'returning a valid response' do
      subject

      expect(json_response).to match_schema('public_api/v4/packages/terraform/modules/v1/versions')
    end
  end
end

RSpec.shared_examples 'returns terraform module version' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      group.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status

    it 'returning a valid response' do
      subject

      expect(json_response).to match_schema('public_api/v4/packages/terraform/modules/v1/single_version')
    end
  end
end

RSpec.shared_examples 'returns no terraform module packages' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      group.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status

    it 'returns a response with no versions' do
      subject

      expect(json_response['modules'][0]['versions'].size).to eq(0)
    end
  end
end

RSpec.shared_examples 'grants terraform module packages access' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      project.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status
  end
end

RSpec.shared_examples 'grants terraform module package file access' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      project.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status
    it_behaves_like 'a package tracking event', described_class.name, 'pull_package'
  end
end

RSpec.shared_examples 'rejects terraform module packages access' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      project.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status
  end
end

RSpec.shared_examples 'process terraform module workhorse authorization' do |user_type, status, add_member = true|
  context "for user type #{user_type}" do
    before do
      project.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    it_behaves_like 'returning response status', status

    it 'has the proper content type' do
      subject

      expect(response.media_type).to eq(Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE)
    end

    context 'with a request that bypassed gitlab-workhorse' do
      let(:headers) do
        { 'HTTP_PRIVATE_TOKEN' => personal_access_token.token }
          .merge(workhorse_headers)
          .tap { |h| h.delete(Gitlab::Workhorse::INTERNAL_API_REQUEST_HEADER) }
      end

      before do
        project.add_maintainer(user)
      end

      it_behaves_like 'returning response status', :forbidden
    end
  end
end

RSpec.shared_examples 'process terraform module upload' do |user_type, status, add_member = true|
  RSpec.shared_examples 'creates terraform module package files' do
    it 'creates package files', :aggregate_failures do
      expect { subject }
          .to change { project.packages.count }.by(1)
          .and change { Packages::PackageFile.count }.by(1)
      expect(response).to have_gitlab_http_status(status)

      package_file = project.packages.last.package_files.reload.last
      expect(package_file.file_name).to eq('mymodule-mysystem-1.0.0.tgz')
    end
  end

  context "for user type #{user_type}" do
    before do
      project.send("add_#{user_type}", user) if add_member && user_type != :anonymous
    end

    context 'with object storage disabled' do
      before do
        stub_package_file_object_storage(enabled: false)
      end

      context 'without a file from workhorse' do
        let(:send_rewritten_field) { false }

        it_behaves_like 'returning response status', :bad_request
      end

      context 'with correct params' do
        it_behaves_like 'package workhorse uploads'
        it_behaves_like 'creates terraform module package files'
        it_behaves_like 'a package tracking event', described_class.name, 'push_package'
      end
    end

    context 'with object storage enabled' do
      let(:tmp_object) do
        fog_connection.directories.new(key: 'packages').files.create( # rubocop:disable Rails/SaveBang
          key: "tmp/uploads/#{file_name}",
          body: 'content'
        )
      end

      let(:fog_file) { fog_to_uploaded_file(tmp_object) }
      let(:params) { { file: fog_file, 'file.remote_id' => file_name } }

      context 'and direct upload enabled' do
        let(:fog_connection) do
          stub_package_file_object_storage(direct_upload: true)
        end

        it_behaves_like 'creates terraform module package files'

        ['123123', '../../123123'].each do |remote_id|
          context "with invalid remote_id: #{remote_id}" do
            let(:params) do
              {
                file: fog_file,
                'file.remote_id' => remote_id
              }
            end

            it_behaves_like 'returning response status', :forbidden
          end
        end
      end

      context 'and direct upload disabled' do
        context 'and background upload disabled' do
          let(:fog_connection) do
            stub_package_file_object_storage(direct_upload: false, background_upload: false)
          end

          it_behaves_like 'creates terraform module package files'
        end

        context 'and background upload enabled' do
          let(:fog_connection) do
            stub_package_file_object_storage(direct_upload: false, background_upload: true)
          end

          it_behaves_like 'creates terraform module package files'
        end
      end
    end
  end
end
