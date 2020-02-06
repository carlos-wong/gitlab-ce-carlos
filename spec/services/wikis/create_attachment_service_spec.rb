# frozen_string_literal: true
require 'spec_helper'

describe Wikis::CreateAttachmentService do
  let(:project) { create(:project, :wiki_repo) }
  let(:user) { create(:user) }
  let(:file_name) { 'filename.txt' }
  let(:file_path_regex) { %r{#{described_class::ATTACHMENT_PATH}/\h{32}/#{file_name}} }

  let(:file_opts) do
    {
      file_name: file_name,
      file_content: 'Content of attachment'
    }
  end
  let(:opts) { file_opts }

  subject(:service) { described_class.new(project, user, opts) }

  before do
    project.add_developer(user)
  end

  describe 'initialization' do
    context 'author commit info' do
      it 'does not raise error if user is nil' do
        service = described_class.new(project, nil, opts)

        expect(service.instance_variable_get(:@author_email)).to be_nil
        expect(service.instance_variable_get(:@author_name)).to be_nil
      end

      it 'fills file_path from the repository uploads folder' do
        expect(service.instance_variable_get(:@file_path)).to match(file_path_regex)
      end

      context 'when no author info provided' do
        it 'fills author_email and author_name from current_user info' do
          expect(service.instance_variable_get(:@author_email)).to eq user.email
          expect(service.instance_variable_get(:@author_name)).to eq user.name
        end
      end

      context 'when author info provided' do
        let(:author_email) { 'author_email' }
        let(:author_name) { 'author_name' }
        let(:opts) { file_opts.merge(author_email: author_email, author_name: author_name) }

        it 'fills author_email and author_name from params' do
          expect(service.instance_variable_get(:@author_email)).to eq author_email
          expect(service.instance_variable_get(:@author_name)).to eq author_name
        end
      end
    end

    context 'commit message' do
      context 'when no commit message provided' do
        it 'sets a default commit message' do
          expect(service.instance_variable_get(:@commit_message)).to eq "Upload attachment #{opts[:file_name]}"
        end
      end

      context 'when commit message provided' do
        let(:commit_message) { 'whatever' }
        let(:opts) { file_opts.merge(commit_message: commit_message) }

        it 'use the commit message from params' do
          expect(service.instance_variable_get(:@commit_message)).to eq commit_message
        end
      end
    end

    context 'branch name' do
      context 'when no branch provided' do
        it 'sets the branch from the wiki default_branch' do
          expect(service.instance_variable_get(:@branch_name)).to eq project.wiki.default_branch
        end
      end

      context 'when branch provided' do
        let(:branch_name) { 'whatever' }
        let(:opts) { file_opts.merge(branch_name: branch_name) }

        it 'use the commit message from params' do
          expect(service.instance_variable_get(:@branch_name)).to eq branch_name
        end
      end
    end
  end

  describe '#parse_file_name' do
    context 'when file_name' do
      context 'has white spaces' do
        let(:file_name) { 'file with spaces' }

        it "replaces all of them with '_'" do
          result = service.execute

          expect(result[:status]).to eq :success
          expect(result[:result][:file_name]).to eq 'file_with_spaces'
        end
      end

      context 'has other invalid characters' do
        let(:file_name) { "file\twith\tinvalid chars" }

        it "replaces all of them with '_'" do
          result = service.execute

          expect(result[:status]).to eq :success
          expect(result[:result][:file_name]).to eq 'file_with_invalid_chars'
        end
      end

      context 'is not present' do
        let(:file_name) { nil }

        it 'returns error' do
          result = service.execute

          expect(result[:status]).to eq :error
          expect(result[:message]).to eq 'The file name cannot be empty'
        end
      end

      context 'length' do
        context 'is bigger than 255' do
          let(:file_name) { "#{'0' * 256}.jpg" }

          it 'truncates file name' do
            result = service.execute

            expect(result[:status]).to eq :success
            expect(result[:result][:file_name].length).to eq 255
            expect(result[:result][:file_name]).to match(/0{251}\.jpg/)
          end
        end

        context 'is less or equal to 255 does not return error' do
          let(:file_name) { '0' * 255 }

          it 'does not return error' do
            result = service.execute

            expect(result[:status]).to eq :success
          end
        end
      end
    end

    context 'when user' do
      shared_examples 'wiki attachment user validations' do
        it 'returns error' do
          result = described_class.new(project, user2, opts).execute

          expect(result[:status]).to eq :error
          expect(result[:message]).to eq 'You are not allowed to push to the wiki'
        end
      end

      context 'does not have permission' do
        let(:user2) { create(:user) }

        it_behaves_like 'wiki attachment user validations'
      end

      context 'is nil' do
        let(:user2) { nil }

        it_behaves_like 'wiki attachment user validations'
      end
    end
  end

  describe '#execute' do
    let(:wiki) { project.wiki }

    subject(:service_execute) { service.execute[:result] }

    context 'creates branch if it does not exists' do
      let(:branch_name) { 'new_branch' }
      let(:opts) { file_opts.merge(branch_name: branch_name) }

      it do
        expect(wiki.repository.branches).to be_empty
        expect { service.execute }.to change { wiki.repository.branches.count }.by(1)
        expect(wiki.repository.branches.first.name).to eq branch_name
      end
    end

    it 'adds file to the repository' do
      expect(wiki.repository.ls_files('HEAD')).to be_empty

      service.execute

      files = wiki.repository.ls_files('HEAD')
      expect(files.count).to eq 1
      expect(files.first).to match(file_path_regex)
    end

    context 'returns' do
      before do
        allow(SecureRandom).to receive(:hex).and_return('fixed_hex')

        service_execute
      end

      it 'returns the file name' do
        expect(service_execute[:file_name]).to eq file_name
      end

      it 'returns the path where file was stored' do
        expect(service_execute[:file_path]).to eq 'uploads/fixed_hex/filename.txt'
      end

      it 'returns the branch where the file was pushed' do
        expect(service_execute[:branch]).to eq wiki.default_branch
      end

      it 'returns the commit id' do
        expect(service_execute[:commit]).not_to be_empty
      end
    end
  end
end
