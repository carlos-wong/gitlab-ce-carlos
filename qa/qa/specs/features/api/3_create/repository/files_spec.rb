# frozen_string_literal: true

require 'securerandom'

module QA
  describe 'API basics' do
    before(:context) do
      @api_client = Runtime::API::Client.new(:gitlab)
    end

    let(:project_name) { "api-basics-#{SecureRandom.hex(8)}" }
    let(:sanitized_project_path) { CGI.escape("#{Runtime::User.username}/#{project_name}") }

    it 'user creates a project with a file and deletes them afterwards' do
      create_project_request = Runtime::API::Request.new(@api_client, '/projects')
      post create_project_request.url, path: project_name, name: project_name

      expect_status(201)
      expect(json_body).to match(
        a_hash_including(name: project_name, path: project_name)
      )

      create_file_request = Runtime::API::Request.new(@api_client, "/projects/#{sanitized_project_path}/repository/files/README.md")
      post create_file_request.url, branch: 'master', content: 'Hello world', commit_message: 'Add README.md'

      expect_status(201)
      expect(json_body).to match(
        a_hash_including(branch: 'master', file_path: 'README.md')
      )

      get_file_request = Runtime::API::Request.new(@api_client, "/projects/#{sanitized_project_path}/repository/files/README.md", ref: 'master')
      get get_file_request.url

      expect_status(200)
      expect(json_body).to match(
        a_hash_including(
          ref: 'master',
          file_path: 'README.md', file_name: 'README.md',
          encoding: 'base64', content: 'SGVsbG8gd29ybGQ='
        )
      )

      delete_file_request = Runtime::API::Request.new(@api_client, "/projects/#{sanitized_project_path}/repository/files/README.md", branch: 'master', commit_message: 'Remove README.md')
      delete delete_file_request.url

      expect_status(204)

      get_tree_request = Runtime::API::Request.new(@api_client, "/projects/#{sanitized_project_path}/repository/tree")
      get get_tree_request.url

      expect_status(200)
      expect(json_body).to eq([])

      delete_project_request = Runtime::API::Request.new(@api_client, "/projects/#{sanitized_project_path}")
      delete delete_project_request.url

      expect_status(202)
      expect(json_body).to match(
        a_hash_including(message: '202 Accepted')
      )
    end
  end
end
