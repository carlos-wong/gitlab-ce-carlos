# frozen_string_literal: true

require 'spec_helper'

describe Snippet do
  describe 'modules' do
    subject { described_class }

    it { is_expected.to include_module(Gitlab::VisibilityLevel) }
    it { is_expected.to include_module(Participable) }
    it { is_expected.to include_module(Referable) }
    it { is_expected.to include_module(Sortable) }
    it { is_expected.to include_module(Awardable) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:author).class_name('User') }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:notes).dependent(:destroy) }
    it { is_expected.to have_many(:award_emoji).dependent(:destroy) }
    it { is_expected.to have_many(:user_mentions).class_name("SnippetUserMention") }
    it { is_expected.to have_one(:snippet_repository) }
  end

  describe 'validation' do
    it { is_expected.to validate_presence_of(:author) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }

    it { is_expected.to validate_length_of(:file_name).is_at_most(255) }

    it { is_expected.to validate_presence_of(:content) }

    it { is_expected.to validate_inclusion_of(:visibility_level).in_array(Gitlab::VisibilityLevel.values) }

    it do
      allow(Gitlab::CurrentSettings).to receive(:snippet_size_limit).and_return(1)

      is_expected
        .to validate_length_of(:content)
              .is_at_most(Gitlab::CurrentSettings.snippet_size_limit)
              .with_message("is too long (2 Bytes). The maximum size is 1 Byte.")
    end

    context 'content validations' do
      context 'with existing snippets' do
        let(:snippet) { create(:personal_snippet, content: 'This is a valid content at the time of creation') }

        before do
          expect(snippet).to be_valid

          stub_application_setting(snippet_size_limit: 2)
        end

        it 'does not raise a validation error if the content is not changed' do
          snippet.title = 'new title'

          expect(snippet).to be_valid
        end

        it 'raises and error if the content is changed and the size is bigger than limit' do
          snippet.content = snippet.content + "test"

          expect(snippet).not_to be_valid
        end
      end

      context 'with new snippets' do
        let(:limit) { 15 }

        before do
          stub_application_setting(snippet_size_limit: limit)
        end

        it 'is valid when content is smaller than the limit' do
          snippet = build(:personal_snippet, content: 'Valid Content')

          expect(snippet).to be_valid
        end

        it 'raises error when content is bigger than setting limit' do
          snippet = build(:personal_snippet, content: 'This is an invalid content')

          aggregate_failures do
            expect(snippet).not_to be_valid
            expect(snippet.errors[:content]).to include("is too long (#{snippet.content.size} Bytes). The maximum size is #{limit} Bytes.")
          end
        end
      end
    end
  end

  describe '#to_reference' do
    context 'when snippet belongs to a project' do
      let(:project) { build(:project, name: 'sample-project') }
      let(:snippet) { build(:snippet, id: 1, project: project) }

      it 'returns a String reference to the object' do
        expect(snippet.to_reference).to eq "$1"
      end

      it 'supports a cross-project reference' do
        another_project = build(:project, name: 'another-project', namespace: project.namespace)
        expect(snippet.to_reference(another_project)).to eq "sample-project$1"
      end
    end

    context 'when snippet does not belong to a project' do
      let(:snippet) { build(:snippet, id: 1, project: nil) }

      it 'returns a String reference to the object' do
        expect(snippet.to_reference).to eq "$1"
      end

      it 'still returns shortest reference when project arg present' do
        another_project = build(:project, name: 'another-project')
        expect(snippet.to_reference(another_project)).to eq "$1"
      end
    end
  end

  describe '#file_name' do
    let(:project) { create(:project) }

    context 'file_name is nil' do
      let(:snippet) { create(:snippet, project: project, file_name: nil) }

      it 'returns an empty string' do
        expect(snippet.file_name).to eq ''
      end
    end

    context 'file_name is not nil' do
      let(:snippet) { create(:snippet, project: project, file_name: 'foo.txt') }

      it 'returns the file_name' do
        expect(snippet.file_name).to eq 'foo.txt'
      end
    end
  end

  describe "#content_html_invalidated?" do
    let(:snippet) { create(:snippet, content: "md", content_html: "html", file_name: "foo.md") }

    it "invalidates the HTML cache of content when the filename changes" do
      expect { snippet.file_name = "foo.rb" }.to change { snippet.content_html_invalidated? }.from(false).to(true)
    end
  end

  describe '.search' do
    let(:snippet) { create(:snippet, title: 'test snippet') }

    it 'returns snippets with a matching title' do
      expect(described_class.search(snippet.title)).to eq([snippet])
    end

    it 'returns snippets with a partially matching title' do
      expect(described_class.search(snippet.title[0..2])).to eq([snippet])
    end

    it 'returns snippets with a matching title regardless of the casing' do
      expect(described_class.search(snippet.title.upcase)).to eq([snippet])
    end

    it 'returns snippets with a matching file name' do
      expect(described_class.search(snippet.file_name)).to eq([snippet])
    end

    it 'returns snippets with a partially matching file name' do
      expect(described_class.search(snippet.file_name[0..2])).to eq([snippet])
    end

    it 'returns snippets with a matching file name regardless of the casing' do
      expect(described_class.search(snippet.file_name.upcase)).to eq([snippet])
    end
  end

  describe '.search_code' do
    let(:snippet) { create(:snippet, content: 'class Foo; end') }

    it 'returns snippets with matching content' do
      expect(described_class.search_code(snippet.content)).to eq([snippet])
    end

    it 'returns snippets with partially matching content' do
      expect(described_class.search_code('class')).to eq([snippet])
    end

    it 'returns snippets with matching content regardless of the casing' do
      expect(described_class.search_code('FOO')).to eq([snippet])
    end
  end

  describe 'when default snippet visibility set to internal' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_application_setting(default_snippet_visibility: Gitlab::VisibilityLevel::INTERNAL)
    end

    where(:attribute_name, :value) do
      :visibility | 'private'
      :visibility_level | Gitlab::VisibilityLevel::PRIVATE
      'visibility' | 'private'
      'visibility_level' | Gitlab::VisibilityLevel::PRIVATE
    end

    with_them do
      it 'sets the visibility level' do
        snippet = described_class.new(attribute_name => value, title: 'test', file_name: 'test.rb', content: 'test data')

        expect(snippet.visibility_level).to eq(Gitlab::VisibilityLevel::PRIVATE)
        expect(snippet.title).to eq('test')
        expect(snippet.file_name).to eq('test.rb')
        expect(snippet.content).to eq('test data')
      end
    end
  end

  describe '.with_optional_visibility' do
    context 'when a visibility level is provided' do
      it 'returns snippets with the given visibility' do
        create(:snippet, :private)

        snippet = create(:snippet, :public)
        snippets = described_class
          .with_optional_visibility(Gitlab::VisibilityLevel::PUBLIC)

        expect(snippets).to eq([snippet])
      end
    end

    context 'when a visibility level is not provided' do
      it 'returns all snippets' do
        snippet1 = create(:snippet, :public)
        snippet2 = create(:snippet, :private)
        snippets = described_class.with_optional_visibility

        expect(snippets).to include(snippet1, snippet2)
      end
    end
  end

  describe '.only_personal_snippets' do
    it 'returns snippets not associated with any projects' do
      create(:project_snippet)

      snippet = create(:snippet)
      snippets = described_class.only_personal_snippets

      expect(snippets).to eq([snippet])
    end
  end

  describe '.only_include_projects_visible_to' do
    let!(:project1) { create(:project, :public) }
    let!(:project2) { create(:project, :internal) }
    let!(:project3) { create(:project, :private) }
    let!(:snippet1) { create(:project_snippet, project: project1) }
    let!(:snippet2) { create(:project_snippet, project: project2) }
    let!(:snippet3) { create(:project_snippet, project: project3) }

    context 'when a user is provided' do
      it 'returns snippets visible to the user' do
        user = create(:user)

        snippets = described_class.only_include_projects_visible_to(user)

        expect(snippets).to include(snippet1, snippet2)
        expect(snippets).not_to include(snippet3)
      end
    end

    context 'when a user is not provided' do
      it 'returns snippets visible to anonymous users' do
        snippets = described_class.only_include_projects_visible_to

        expect(snippets).to include(snippet1)
        expect(snippets).not_to include(snippet2, snippet3)
      end
    end
  end

  describe 'only_include_projects_with_snippets_enabled' do
    context 'when the include_private option is enabled' do
      it 'includes snippets for projects with snippets set to private' do
        project = create(:project)

        project.project_feature
          .update(snippets_access_level: ProjectFeature::PRIVATE)

        snippet = create(:project_snippet, project: project)

        snippets = described_class
          .only_include_projects_with_snippets_enabled(include_private: true)

        expect(snippets).to eq([snippet])
      end
    end

    context 'when the include_private option is not enabled' do
      it 'does not include snippets for projects that have snippets set to private' do
        project = create(:project)

        project.project_feature
          .update(snippets_access_level: ProjectFeature::PRIVATE)

        create(:project_snippet, project: project)

        snippets = described_class.only_include_projects_with_snippets_enabled

        expect(snippets).to be_empty
      end
    end

    it 'includes snippets for projects with snippets enabled' do
      project = create(:project)

      project.project_feature
        .update(snippets_access_level: ProjectFeature::ENABLED)

      snippet = create(:project_snippet, project: project)
      snippets = described_class.only_include_projects_with_snippets_enabled

      expect(snippets).to eq([snippet])
    end
  end

  describe '.only_include_authorized_projects' do
    it 'only includes snippets for projects the user is authorized to see' do
      user = create(:user)
      project1 = create(:project, :private)
      project2 = create(:project, :private)

      project1.team.add_developer(user)

      create(:project_snippet, project: project2)

      snippet = create(:project_snippet, project: project1)
      snippets = described_class.only_include_authorized_projects(user)

      expect(snippets).to eq([snippet])
    end
  end

  describe '.for_project_with_user' do
    context 'when a user is provided' do
      it 'returns an empty collection if the user can not view the snippets' do
        project = create(:project, :private)
        user = create(:user)

        project.project_feature
          .update(snippets_access_level: ProjectFeature::ENABLED)

        create(:project_snippet, :public, project: project)

        expect(described_class.for_project_with_user(project, user)).to be_empty
      end

      it 'returns the snippets if the user is a member of the project' do
        project = create(:project, :private)
        user = create(:user)
        snippet = create(:project_snippet, project: project)

        project.team.add_developer(user)

        snippets = described_class.for_project_with_user(project, user)

        expect(snippets).to eq([snippet])
      end

      it 'returns public snippets for a public project the user is not a member of' do
        project = create(:project, :public)

        project.project_feature
          .update(snippets_access_level: ProjectFeature::ENABLED)

        user = create(:user)
        snippet = create(:project_snippet, :public, project: project)

        create(:project_snippet, :private, project: project)

        snippets = described_class.for_project_with_user(project, user)

        expect(snippets).to eq([snippet])
      end
    end

    context 'when a user is not provided' do
      it 'returns an empty collection for a private project' do
        project = create(:project, :private)

        project.project_feature
          .update(snippets_access_level: ProjectFeature::ENABLED)

        create(:project_snippet, :public, project: project)

        expect(described_class.for_project_with_user(project)).to be_empty
      end

      it 'returns public snippets for a public project' do
        project = create(:project, :public)
        snippet = create(:project_snippet, :public, project: project)

        project.project_feature
          .update(snippets_access_level: ProjectFeature::PUBLIC)

        create(:project_snippet, :private, project: project)

        snippets = described_class.for_project_with_user(project)

        expect(snippets).to eq([snippet])
      end
    end
  end

  describe '.visible_to_or_authored_by' do
    it 'returns snippets visible to the user' do
      user = create(:user)
      snippet1 = create(:snippet, :public)
      snippet2 = create(:snippet, :private, author: user)
      snippet3 = create(:snippet, :private)

      snippets = described_class.visible_to_or_authored_by(user)

      expect(snippets).to include(snippet1, snippet2)
      expect(snippets).not_to include(snippet3)
    end
  end

  describe '#participants' do
    let(:project) { create(:project, :public) }
    let(:snippet) { create(:snippet, content: 'foo', project: project) }

    let!(:note1) do
      create(:note_on_project_snippet,
             noteable: snippet,
             project: project,
             note: 'a')
    end

    let!(:note2) do
      create(:note_on_project_snippet,
             noteable: snippet,
             project: project,
             note: 'b')
    end

    it 'includes the snippet author' do
      expect(snippet.participants).to include(snippet.author)
    end

    it 'includes the note authors' do
      expect(snippet.participants).to include(note1.author, note2.author)
    end
  end

  describe '#check_for_spam' do
    let(:snippet) { create :snippet, visibility_level: visibility_level }

    subject do
      snippet.assign_attributes(title: title)
      snippet.check_for_spam?
    end

    context 'when public and spammable attributes changed' do
      let(:visibility_level) { Snippet::PUBLIC }
      let(:title) { 'woo' }

      it 'returns true' do
        is_expected.to be_truthy
      end
    end

    context 'when private' do
      let(:visibility_level) { Snippet::PRIVATE }
      let(:title) { snippet.title }

      it 'returns false' do
        is_expected.to be_falsey
      end

      it 'returns true when switching to public' do
        snippet.save!
        snippet.visibility_level = Snippet::PUBLIC

        expect(snippet.check_for_spam?).to be_truthy
      end
    end

    context 'when spammable attributes have not changed' do
      let(:visibility_level) { Snippet::PUBLIC }
      let(:title) { snippet.title }

      it 'returns false' do
        is_expected.to be_falsey
      end
    end
  end

  describe '#blob' do
    let(:snippet) { create(:snippet) }

    it 'returns a blob representing the snippet data' do
      blob = snippet.blob

      expect(blob).to be_a(Blob)
      expect(blob.path).to eq(snippet.file_name)
      expect(blob.data).to eq(snippet.content)
    end
  end

  describe '#to_json' do
    let(:snippet) { build(:snippet) }

    it 'excludes secret_token from generated json' do
      expect(JSON.parse(to_json).keys).not_to include("secret_token")
    end

    it 'does not override existing exclude option value' do
      expect(JSON.parse(to_json(except: [:id])).keys).not_to include("secret_token", "id")
    end

    def to_json(params = {})
      snippet.to_json(params)
    end
  end

  describe '#storage' do
    let(:snippet) { create(:snippet) }

    it "stores snippet in #{Storage::Hashed::SNIPPET_REPOSITORY_PATH_PREFIX} dir" do
      expect(snippet.storage.disk_path).to start_with Storage::Hashed::SNIPPET_REPOSITORY_PATH_PREFIX
    end
  end

  describe '#track_snippet_repository' do
    let(:snippet) { create(:snippet, :repository) }

    context 'when a snippet repository entry does not exist' do
      it 'creates a new entry' do
        expect { snippet.track_snippet_repository }.to change(snippet, :snippet_repository)
      end

      it 'tracks the snippet storage location' do
        snippet.track_snippet_repository

        expect(snippet.snippet_repository).to have_attributes(
          disk_path: snippet.disk_path,
          shard_name: snippet.repository_storage
        )
      end
    end

    context 'when a tracking entry exists' do
      let!(:snippet_repository) { create(:snippet_repository, snippet: snippet) }
      let!(:shard) { create(:shard, name: 'foo') }

      it 'does not create a new entry in the database' do
        expect { snippet.track_snippet_repository }.not_to change(snippet, :snippet_repository)
      end

      it 'updates the snippet storage location' do
        allow(snippet).to receive(:disk_path).and_return('fancy/new/path')
        allow(snippet).to receive(:repository_storage).and_return('foo')

        snippet.track_snippet_repository

        expect(snippet.snippet_repository).to have_attributes(
          disk_path: 'fancy/new/path',
          shard_name: 'foo'
        )
      end
    end
  end

  describe '#create_repository' do
    let(:snippet) { create(:snippet) }

    it 'creates the repository' do
      expect(snippet.repository).to receive(:after_create).and_call_original

      expect(snippet.create_repository).to be_truthy
      expect(snippet.repository.exists?).to be_truthy
    end

    it 'tracks snippet repository' do
      expect do
        snippet.create_repository
      end.to change(SnippetRepository, :count).by(1)
    end

    context 'when repository exists' do
      let(:snippet) { create(:snippet, :repository) }

      it 'does not try to create repository' do
        expect(snippet.repository).not_to receive(:after_create)

        expect(snippet.create_repository).to be_nil
      end

      it 'does not track snippet repository' do
        expect do
          snippet.create_repository
        end.not_to change(SnippetRepository, :count)
      end
    end
  end

  describe '#repository_storage' do
    let(:snippet) { create(:snippet) }

    it 'returns default repository storage' do
      expect(Gitlab::CurrentSettings).to receive(:pick_repository_storage)

      snippet.repository_storage
    end

    context 'when snippet_project is already created' do
      let!(:snippet_repository) { create(:snippet_repository, snippet: snippet) }

      before do
        allow(snippet_repository).to receive(:shard_name).and_return('foo')
      end

      it 'returns repository_storage from snippet_project' do
        expect(Gitlab::CurrentSettings).not_to receive(:pick_repository_storage)

        expect(snippet.repository_storage).to eq 'foo'
      end
    end
  end
end
