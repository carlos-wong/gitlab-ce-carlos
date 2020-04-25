# frozen_string_literal: true

require 'spec_helper'

describe Snippets::CreateService do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:admin) { create(:user, :admin) }
    let(:opts) { base_opts.merge(extra_opts) }
    let(:base_opts) do
      {
        title: 'Test snippet',
        file_name: 'snippet.rb',
        content: 'puts "hello world"',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE
      }
    end
    let(:extra_opts) { {} }
    let(:creator) { admin }

    subject { Snippets::CreateService.new(project, creator, opts).execute }

    let(:snippet) { subject.payload[:snippet] }

    shared_examples 'a service that creates a snippet' do
      it 'creates a snippet with the provided attributes' do
        expect(snippet.title).to eq(opts[:title])
        expect(snippet.file_name).to eq(opts[:file_name])
        expect(snippet.content).to eq(opts[:content])
        expect(snippet.visibility_level).to eq(opts[:visibility_level])
      end
    end

    shared_examples 'public visibility level restrictions apply' do
      let(:extra_opts) { { visibility_level: Gitlab::VisibilityLevel::PUBLIC } }

      before do
        stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::PUBLIC])
      end

      context 'when user is not an admin' do
        let(:creator) { user }

        it 'responds with an error' do
          expect(subject).to be_error
        end

        it 'does not create a public snippet' do
          expect(subject.message).to match('has been restricted')
        end
      end

      context 'when user is an admin' do
        it 'responds with success' do
          expect(subject).to be_success
        end

        it 'creates a public snippet' do
          expect(snippet.visibility_level).to eq(Gitlab::VisibilityLevel::PUBLIC)
        end
      end

      describe 'when visibility level is passed as a string' do
        let(:extra_opts) { { visibility: 'internal' } }

        before do
          base_opts.delete(:visibility_level)
        end

        it 'assigns the correct visibility level' do
          expect(subject).to be_success
          expect(snippet.visibility_level).to eq(Gitlab::VisibilityLevel::INTERNAL)
        end
      end
    end

    shared_examples 'spam check is performed' do
      shared_examples 'marked as spam' do
        it 'marks a snippet as spam ' do
          expect(snippet).to be_spam
        end

        it 'invalidates the snippet' do
          expect(snippet).to be_invalid
        end

        it 'creates a new spam_log' do
          expect { snippet }
            .to have_spam_log(title: snippet.title, noteable_type: snippet.class.name)
        end

        it 'assigns a spam_log to an issue' do
          expect(snippet.spam_log).to eq(SpamLog.last)
        end
      end

      let(:extra_opts) do
        { visibility_level: Gitlab::VisibilityLevel::PUBLIC, request: double(:request, env: {}) }
      end

      before do
        expect_next_instance_of(Spam::AkismetService) do |akismet_service|
          expect(akismet_service).to receive_messages(spam?: true)
        end
      end

      [true, false, nil].each do |allow_possible_spam|
        context "when recaptcha_disabled flag is #{allow_possible_spam.inspect}" do
          before do
            stub_feature_flags(allow_possible_spam: allow_possible_spam) unless allow_possible_spam.nil?
          end

          it_behaves_like 'marked as spam'
        end
      end
    end

    shared_examples 'snippet create data is tracked' do
      let(:counter) { Gitlab::UsageDataCounters::SnippetCounter }

      it 'increments count when create succeeds' do
        expect { subject }.to change { counter.read(:create) }.by 1
      end

      context 'when create fails' do
        let(:opts) { {} }

        it 'does not increment count' do
          expect { subject }.not_to change { counter.read(:create) }
        end
      end
    end

    shared_examples 'an error service response when save fails' do
      let(:extra_opts) { { content: nil } }

      it 'responds with an error' do
        expect(subject).to be_error
      end

      it 'does not create the snippet' do
        expect { subject }.not_to change { Snippet.count }
      end
    end

    shared_examples 'creates repository' do
      it do
        subject

        expect(snippet.repository_exists?).to be_truthy
      end

      context 'when snippet creation fails' do
        let(:extra_opts) { { content: nil } }

        it 'does not create repository' do
          subject

          expect(snippet.repository_exists?).to be_falsey
        end
      end

      context 'when feature flag :version_snippets is disabled' do
        it 'does not create snippet repository' do
          stub_feature_flags(version_snippets: false)

          expect do
            subject
          end.to change(Snippet, :count).by(1)

          expect(snippet.repository_exists?).to be_falsey
        end
      end
    end

    context 'when Project Snippet' do
      let_it_be(:project) { create(:project) }

      before do
        project.add_developer(user)
      end

      it_behaves_like 'a service that creates a snippet'
      it_behaves_like 'public visibility level restrictions apply'
      it_behaves_like 'spam check is performed'
      it_behaves_like 'snippet create data is tracked'
      it_behaves_like 'an error service response when save fails'
      it_behaves_like 'creates repository'
    end

    context 'when PersonalSnippet' do
      let(:project) { nil }

      it_behaves_like 'a service that creates a snippet'
      it_behaves_like 'public visibility level restrictions apply'
      it_behaves_like 'spam check is performed'
      it_behaves_like 'snippet create data is tracked'
      it_behaves_like 'an error service response when save fails'
      it_behaves_like 'creates repository'
    end
  end
end
