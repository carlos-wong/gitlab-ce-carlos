# frozen_string_literal: true

require "spec_helper"

describe WikiPage do
  let(:project) { create(:project, :wiki_repo) }
  let(:user) { project.owner }
  let(:wiki) { ProjectWiki.new(project, user) }

  let(:new_page) do
    described_class.new(wiki).tap do |page|
      page.attributes = { title: 'test page', content: 'test content' }
    end
  end

  let(:existing_page) do
    create_page('test page', 'test content')
    wiki.find_page('test page')
  end

  subject { new_page }

  describe '.group_by_directory' do
    context 'when there are no pages' do
      it 'returns an empty array' do
        expect(described_class.group_by_directory(nil)).to eq([])
        expect(described_class.group_by_directory([])).to eq([])
      end
    end

    context 'when there are pages' do
      before do
        create_page('dir_1/dir_1_1/page_3', 'content')
        create_page('page_1', 'content')
        create_page('dir_1/page_2', 'content')
        create_page('dir_2', 'page with dir name')
        create_page('dir_2/page_5', 'content')
        create_page('page_6', 'content')
        create_page('dir_2/page_4', 'content')
      end

      let(:page_1) { wiki.find_page('page_1') }
      let(:page_6) { wiki.find_page('page_6') }
      let(:page_dir_2) { wiki.find_page('dir_2') }

      let(:dir_1) do
        WikiDirectory.new('dir_1', [wiki.find_page('dir_1/page_2')])
      end
      let(:dir_1_1) do
        WikiDirectory.new('dir_1/dir_1_1', [wiki.find_page('dir_1/dir_1_1/page_3')])
      end
      let(:dir_2) do
        pages = [wiki.find_page('dir_2/page_5'),
                 wiki.find_page('dir_2/page_4')]
        WikiDirectory.new('dir_2', pages)
      end

      describe "#list_pages" do
        context 'sort by title' do
          let(:grouped_entries) { described_class.group_by_directory(wiki.list_pages) }
          let(:expected_grouped_entries) { [dir_1_1, dir_1, page_dir_2, dir_2, page_1, page_6] }

          it 'returns an array with pages and directories' do
            grouped_entries.each_with_index do |page_or_dir, i|
              expected_page_or_dir = expected_grouped_entries[i]
              expected_slugs = get_slugs(expected_page_or_dir)
              slugs = get_slugs(page_or_dir)

              expect(slugs).to match_array(expected_slugs)
            end
          end
        end

        context 'sort by created_at' do
          let(:grouped_entries) { described_class.group_by_directory(wiki.list_pages(sort: 'created_at')) }
          let(:expected_grouped_entries) { [dir_1_1, page_1, dir_1, page_dir_2, dir_2, page_6] }

          it 'returns an array with pages and directories' do
            grouped_entries.each_with_index do |page_or_dir, i|
              expected_page_or_dir = expected_grouped_entries[i]
              expected_slugs = get_slugs(expected_page_or_dir)
              slugs = get_slugs(page_or_dir)

              expect(slugs).to match_array(expected_slugs)
            end
          end
        end

        it 'returns an array with retained order with directories at the top' do
          expected_order = ['dir_1/dir_1_1/page_3', 'dir_1/page_2', 'dir_2', 'dir_2/page_4', 'dir_2/page_5', 'page_1', 'page_6']

          grouped_entries = described_class.group_by_directory(wiki.list_pages)

          actual_order =
            grouped_entries.flat_map do |page_or_dir|
              get_slugs(page_or_dir)
            end
          expect(actual_order).to eq(expected_order)
        end
      end
    end
  end

  describe '.unhyphenize' do
    it 'removes hyphens from a name' do
      name = 'a-name--with-hyphens'

      expect(described_class.unhyphenize(name)).to eq('a name with hyphens')
    end
  end

  describe "#initialize" do
    context "when initialized with an existing page" do
      subject { existing_page }

      it "sets the slug attribute" do
        expect(subject.slug).to eq("test-page")
      end

      it "sets the title attribute" do
        expect(subject.title).to eq("test page")
      end

      it "sets the formatted content attribute" do
        expect(subject.content).to eq("test content")
      end

      it "sets the format attribute" do
        expect(subject.format).to eq(:markdown)
      end

      it "sets the message attribute" do
        expect(subject.message).to eq("test commit")
      end

      it "sets the version attribute" do
        expect(subject.version).to be_a Gitlab::Git::WikiPageVersion
      end
    end
  end

  describe "validations" do
    it "validates presence of title" do
      subject.attributes.delete(:title)

      expect(subject).not_to be_valid
      expect(subject.errors.keys).to contain_exactly(:title)
    end

    it "validates presence of content" do
      subject.attributes.delete(:content)

      expect(subject).not_to be_valid
      expect(subject.errors.keys).to contain_exactly(:content)
    end

    describe '#validate_path_limits' do
      let(:max_title) { described_class::MAX_TITLE_BYTES }
      let(:max_directory) { described_class::MAX_DIRECTORY_BYTES }

      where(:character) do
        ['a', 'ä', '🙈']
      end

      with_them do
        let(:size) { character.bytesize.to_f }
        let(:valid_title) { character * (max_title / size).floor }
        let(:valid_directory) { character * (max_directory / size).floor }
        let(:invalid_title) { character * ((max_title + 1) / size).ceil }
        let(:invalid_directory) { character * ((max_directory + 1) / size).ceil }

        it 'accepts page titles below the limit' do
          subject.title = valid_title

          expect(subject).to be_valid
        end

        it 'accepts directories below the limit' do
          subject.title = valid_directory + '/foo'

          expect(subject).to be_valid
        end

        it 'accepts a path with page title and directory below the limit' do
          subject.title = "#{valid_directory}/#{valid_title}"

          expect(subject).to be_valid
        end

        it 'rejects page titles exceeding the limit' do
          subject.title = invalid_title

          expect(subject).not_to be_valid
          expect(subject.errors[:title]).to contain_exactly(
            "exceeds the limit of #{max_title} bytes for page titles"
          )
        end

        it 'rejects directories exceeding the limit' do
          subject.title = invalid_directory + '/foo'

          expect(subject).not_to be_valid
          expect(subject.errors[:title]).to contain_exactly(
            "exceeds the limit of #{max_directory} bytes for directory names"
          )
        end

        it 'rejects a page with both title and directory exceeding the limit' do
          subject.title = "#{invalid_directory}/#{invalid_title}"

          expect(subject).not_to be_valid
          expect(subject.errors[:title]).to contain_exactly(
            "exceeds the limit of #{max_title} bytes for page titles",
            "exceeds the limit of #{max_directory} bytes for directory names"
          )
        end
      end

      context 'with an existing page title exceeding the limit' do
        subject do
          title = 'a' * (max_title + 1)
          create_page(title, 'content')
          wiki.find_page(title)
        end

        it 'accepts the exceeding title length when unchanged' do
          expect(subject).to be_valid
        end

        it 'rejects the exceeding title length when changed' do
          subject.title = 'b' * (max_title + 1)

          expect(subject).not_to be_valid
          expect(subject.errors).to include(:title)
        end
      end
    end
  end

  describe "#create" do
    let(:attributes) do
      {
        title: "Index",
        content: "Home Page",
        format: "markdown",
        message: 'Custom Commit Message'
      }
    end

    context "with valid attributes" do
      it "saves the wiki page" do
        subject.create(attributes)

        expect(wiki.find_page("Index")).not_to be_nil
      end

      it "returns true" do
        expect(subject.create(attributes)).to eq(true)
      end

      it 'saves the wiki page with message' do
        subject.create(attributes)

        expect(wiki.find_page("Index").message).to eq 'Custom Commit Message'
      end
    end
  end

  describe "dot in the title" do
    let(:title) { 'Index v1.2.3' }

    describe "#create" do
      let(:attributes) { { title: title, content: "Home Page", format: "markdown" } }

      context "with valid attributes" do
        it "saves the wiki page" do
          subject.create(attributes)

          expect(wiki.find_page(title)).not_to be_nil
        end

        it "returns true" do
          expect(subject.create(attributes)).to eq(true)
        end
      end
    end

    describe "#update" do
      subject do
        create_page(title, "content")
        wiki.find_page(title)
      end

      it "updates the content of the page" do
        subject.update(content: "new content")
        page = wiki.find_page(title)

        expect(page.content).to eq('new content')
      end

      it "returns true" do
        expect(subject.update(content: "more content")).to be_truthy
      end
    end
  end

  describe '#create' do
    context 'with valid attributes' do
      it 'raises an error if a page with the same path already exists' do
        create_page('New Page', 'content')
        create_page('foo/bar', 'content')

        expect { create_page('New Page', 'other content') }.to raise_error Gitlab::Git::Wiki::DuplicatePageError
        expect { create_page('foo/bar', 'other content') }.to raise_error Gitlab::Git::Wiki::DuplicatePageError
      end

      it 'if the title is preceded by a / it is removed' do
        create_page('/New Page', 'content')

        expect(wiki.find_page('New Page')).not_to be_nil
      end
    end
  end

  describe "#update" do
    subject { existing_page }

    context "with valid attributes" do
      it "updates the content of the page" do
        new_content = "new content"

        subject.update(content: new_content)
        page = wiki.find_page('test page')

        expect(page.content).to eq("new content")
      end

      it "updates the title of the page" do
        new_title = "Index v.1.2.4"

        subject.update(title: new_title)
        page = wiki.find_page(new_title)

        expect(page.title).to eq(new_title)
      end

      it "returns true" do
        expect(subject.update(content: "more content")).to be_truthy
      end
    end

    context 'with same last commit sha' do
      it 'returns true' do
        expect(subject.update(content: 'more content', last_commit_sha: subject.last_commit_sha)).to be_truthy
      end
    end

    context 'with different last commit sha' do
      it 'raises exception' do
        expect { subject.update(content: 'more content', last_commit_sha: 'xxx') }.to raise_error(WikiPage::PageChangedError)
      end
    end

    context 'when renaming a page' do
      it 'raises an error if the page already exists' do
        create_page('Existing Page', 'content')

        expect { subject.update(title: 'Existing Page', content: 'new_content') }.to raise_error(WikiPage::PageRenameError)
        expect(subject.title).to eq 'test page'
        expect(subject.content).to eq 'new_content'
      end

      it 'updates the content and rename the file' do
        new_title = 'Renamed Page'
        new_content = 'updated content'

        expect(subject.update(title: new_title, content: new_content)).to be_truthy

        page = wiki.find_page(new_title)

        expect(page).not_to be_nil
        expect(page.content).to eq new_content
      end
    end

    context 'when moving a page' do
      it 'raises an error if the page already exists' do
        create_page('foo/Existing Page', 'content')

        expect { subject.update(title: 'foo/Existing Page', content: 'new_content') }.to raise_error(WikiPage::PageRenameError)
        expect(subject.title).to eq 'test page'
        expect(subject.content).to eq 'new_content'
      end

      it 'updates the content and moves the file' do
        new_title = 'foo/Other Page'
        new_content = 'new_content'

        expect(subject.update(title: new_title, content: new_content)).to be_truthy

        page = wiki.find_page(new_title)

        expect(page).not_to be_nil
        expect(page.content).to eq new_content
      end

      context 'in subdir' do
        subject do
          create_page('foo/Existing Page', 'content')
          wiki.find_page('foo/Existing Page')
        end

        it 'moves the page to the root folder if the title is preceded by /' do
          expect(subject.slug).to eq 'foo/Existing-Page'
          expect(subject.update(title: '/Existing Page', content: 'new_content')).to be_truthy
          expect(subject.slug).to eq 'Existing-Page'
        end

        it 'does nothing if it has the same title' do
          original_path = subject.slug

          expect(subject.update(title: 'Existing Page', content: 'new_content')).to be_truthy
          expect(subject.slug).to eq original_path
        end
      end

      context 'in root dir' do
        it 'does nothing if the title is preceded by /' do
          original_path = subject.slug

          expect(subject.update(title: '/test page', content: 'new_content')).to be_truthy
          expect(subject.slug).to eq original_path
        end
      end
    end

    context "with invalid attributes" do
      it 'aborts update if title blank' do
        expect(subject.update(title: '', content: 'new_content')).to be_falsey
        expect(subject.content).to eq 'new_content'

        page = wiki.find_page('test page')

        expect(page.content).to eq 'test content'
      end
    end
  end

  describe "#destroy" do
    subject { existing_page }

    it "deletes the page" do
      subject.delete

      expect(wiki.list_pages).to be_empty
    end

    it "returns true" do
      expect(subject.delete).to eq(true)
    end
  end

  describe "#versions" do
    subject { existing_page }

    it "returns an array of all commits for the page" do
      3.times { |i| subject.update(content: "content #{i}") }

      expect(subject.versions.count).to eq(4)
    end

    it 'returns instances of WikiPageVersion' do
      expect(subject.versions).to all( be_a(Gitlab::Git::WikiPageVersion) )
    end
  end

  describe "#title" do
    it "replaces a hyphen to a space" do
      subject.title = "Import-existing-repositories-into-GitLab"

      expect(subject.title).to eq("Import existing repositories into GitLab")
    end

    it 'unescapes html' do
      subject.title = 'foo &amp; bar'

      expect(subject.title).to eq('foo & bar')
    end
  end

  describe '#path' do
    let(:path) { 'mypath.md' }
    let(:git_page) { instance_double('Gitlab::Git::WikiPage', path: path).as_null_object }

    it 'returns the path when persisted' do
      page = described_class.new(wiki, git_page, true)

      expect(page.path).to eq(path)
    end

    it 'returns nil when not persisted' do
      page = described_class.new(wiki, git_page, false)

      expect(page.path).to be_nil
    end
  end

  describe '#directory' do
    context 'when the page is at the root directory' do
      subject do
        create_page('file', 'content')
        wiki.find_page('file')
      end

      it 'returns an empty string' do
        expect(subject.directory).to eq('')
      end
    end

    context 'when the page is inside an actual directory' do
      subject do
        create_page('dir_1/dir_1_1/file', 'content')
        wiki.find_page('dir_1/dir_1_1/file')
      end

      it 'returns the full directory hierarchy' do
        expect(subject.directory).to eq('dir_1/dir_1_1')
      end
    end
  end

  describe '#historical?' do
    subject { existing_page }

    let(:old_version) { subject.versions.last.id }
    let(:old_page) { wiki.find_page(subject.title, old_version) }
    let(:latest_version) { subject.versions.first.id }
    let(:latest_page) { wiki.find_page(subject.title, latest_version) }

    before do
      3.times { |i| subject.update(content: "content #{i}") }
    end

    it 'returns true when requesting an old version' do
      expect(old_page.historical?).to be_truthy
    end

    it 'returns false when requesting latest version' do
      expect(latest_page.historical?).to be_falsy
    end

    it 'returns false when version is nil' do
      expect(latest_page.historical?).to be_falsy
    end

    it 'returns false when the last version is nil' do
      expect(old_page).to receive(:last_version) { nil }

      expect(old_page.historical?).to be_falsy
    end

    it 'returns false when the version is nil' do
      expect(old_page).to receive(:version) { nil }

      expect(old_page.historical?).to be_falsy
    end
  end

  describe '#to_partial_path' do
    it 'returns the relative path to the partial to be used' do
      expect(subject.to_partial_path).to eq('projects/wikis/wiki_page')
    end
  end

  describe '#==' do
    subject { existing_page }

    it 'returns true for identical wiki page' do
      expect(subject).to eq(subject)
    end

    it 'returns false for updated wiki page' do
      subject.update(content: "Updated content")
      updated_page = wiki.find_page('test page')

      expect(updated_page).not_to be_nil
      expect(updated_page).not_to eq(subject)
    end
  end

  describe '#last_commit_sha' do
    subject { existing_page }

    it 'returns commit sha' do
      expect(subject.last_commit_sha).to eq subject.last_version.sha
    end

    it 'is changed after page updated' do
      last_commit_sha_before_update = subject.last_commit_sha

      subject.update(content: "new content")
      page = wiki.find_page('test page')

      expect(page.last_commit_sha).not_to eq last_commit_sha_before_update
    end
  end

  describe '#hook_attrs' do
    it 'adds absolute urls for images in the content' do
      subject.attributes[:content] = 'test![WikiPage_Image](/uploads/abc/WikiPage_Image.png)'

      expect(subject.hook_attrs['content']).to eq("test![WikiPage_Image](#{Settings.gitlab.url}/uploads/abc/WikiPage_Image.png)")
    end
  end

  private

  def remove_temp_repo(path)
    FileUtils.rm_rf path
  end

  def commit_details
    Gitlab::Git::Wiki::CommitDetails.new(user.id, user.username, user.name, user.email, "test commit")
  end

  def create_page(name, content)
    wiki.wiki.write_page(name, :markdown, content, commit_details)
  end

  def get_slugs(page_or_dir)
    if page_or_dir.is_a? WikiPage
      [page_or_dir.slug]
    else
      page_or_dir.pages.present? ? page_or_dir.pages.map(&:slug) : []
    end
  end
end
