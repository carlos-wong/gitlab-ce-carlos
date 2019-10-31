# frozen_string_literal: true

require 'spec_helper'

describe Banzai::Filter::UserReferenceFilter do
  include FilterSpecHelper

  def get_reference(user)
    user.to_reference
  end

  let(:project)   { create(:project, :public) }
  let(:user)      { create(:user) }
  subject { user }

  let(:subject_name) { "user" }
  let(:reference) { get_reference(user) }

  it_behaves_like 'user reference or project reference'

  it 'requires project context' do
    expect { described_class.call('') }.to raise_error(ArgumentError, /:project/)
  end

  it 'ignores invalid users' do
    exp = act = "Hey #{invalidate_reference(reference)}"
    expect(reference_filter(act).to_html).to eq(exp)
  end

  it 'ignores references with text before the @ sign' do
    exp = act = "Hey foo#{reference}"
    expect(reference_filter(act).to_html).to eq(exp)
  end

  %w(pre code a style).each do |elem|
    it "ignores valid references contained inside '#{elem}' element" do
      exp = act = "<#{elem}>Hey #{reference}</#{elem}>"
      expect(reference_filter(act).to_html).to eq exp
    end
  end

  context 'mentioning @all' do
    it_behaves_like 'a reference containing an element node'

    let(:reference) { User.reference_prefix + 'all' }

    before do
      project.add_developer(project.creator)
    end

    it 'supports a special @all mention' do
      project.add_developer(user)
      doc = reference_filter("Hey #{reference}", author: user)

      expect(doc.css('a').length).to eq 1
      expect(doc.css('a').first.attr('href'))
        .to eq urls.project_url(project)
    end

    it 'includes a data-author attribute when there is an author' do
      project.add_developer(user)
      doc = reference_filter(reference, author: user)

      expect(doc.css('a').first.attr('data-author')).to eq(user.id.to_s)
    end

    it 'does not include a data-author attribute when there is no author' do
      doc = reference_filter(reference)

      expect(doc.css('a').first.has_attribute?('data-author')).to eq(false)
    end

    it 'ignores reference to all when the user is not a project member' do
      doc = reference_filter("Hey #{reference}", author: user)

      expect(doc.css('a').length).to eq 0
    end
  end

  context 'mentioning a group' do
    it_behaves_like 'a reference containing an element node'

    let(:group)     { create(:group) }
    let(:reference) { group.to_reference }

    it 'links to the Group' do
      doc = reference_filter("Hey #{reference}")
      expect(doc.css('a').first.attr('href')).to eq urls.group_url(group)
    end

    it 'includes a data-group attribute' do
      doc = reference_filter("Hey #{reference}")
      link = doc.css('a').first

      expect(link).to have_attribute('data-group')
      expect(link.attr('data-group')).to eq group.id.to_s
    end
  end

  context 'mentioning a nested group' do
    it_behaves_like 'a reference containing an element node'

    let(:group)     { create(:group, :nested) }
    let(:reference) { group.to_reference }

    it 'links to the nested group' do
      doc = reference_filter("Hey #{reference}")

      expect(doc.css('a').first.attr('href')).to eq urls.group_url(group)
    end

    it 'has the full group name as a title' do
      doc = reference_filter("Hey #{reference}")

      expect(doc.css('a').first.attr('title')).to eq group.full_name
    end
  end

  it 'links with adjacent text' do
    doc = reference_filter("Mention me (#{reference}.)")
    expect(doc.to_html).to match(%r{\(<a.+>#{reference}</a>\.\)})
  end

  it 'includes default classes' do
    doc = reference_filter("Hey #{reference}")
    expect(doc.css('a').first.attr('class')).to eq 'gfm gfm-project_member'
  end

  context 'when a project is not specified' do
    let(:project) { nil }

    it 'does not link a User' do
      doc = reference_filter("Hey #{reference}")

      expect(doc).not_to include('a')
    end

    context 'when skip_project_check set to true' do
      it 'links to a User' do
        doc = reference_filter("Hey #{reference}", skip_project_check: true)

        expect(doc.css('a').first.attr('href')).to eq urls.user_url(user)
      end

      it 'does not link users using @all reference' do
        doc = reference_filter("Hey #{User.reference_prefix}all", skip_project_check: true)

        expect(doc).not_to include('a')
      end
    end
  end

  context 'in group context' do
    let(:group) { create(:group) }
    let(:group_member) { create(:user) }

    before do
      group.add_developer(group_member)
    end

    let(:context) { { author: group_member, project: nil, group: group } }

    it 'supports a special @all mention' do
      reference = User.reference_prefix + 'all'
      doc = reference_filter("Hey #{reference}", context)

      expect(doc.css('a').length).to eq(1)
      expect(doc.css('a').first.attr('href')).to eq urls.group_url(group)
    end

    it 'supports mentioning a single user' do
      reference = get_reference(group_member)
      doc = reference_filter("Hey #{reference}", context)

      expect(doc.css('a').first.attr('href')).to eq urls.user_url(group_member)
    end

    it 'supports mentioning a group' do
      reference = group.to_reference
      doc = reference_filter("Hey #{reference}", context)

      expect(doc.css('a').first.attr('href')).to eq urls.user_url(group)
    end
  end

  describe '#namespaces' do
    it 'returns a Hash containing all Namespaces' do
      document = Nokogiri::HTML.fragment("<p>#{get_reference(user)}</p>")
      filter = described_class.new(document, project: project)
      ns = user.namespace

      expect(filter.namespaces).to eq({ ns.path => ns })
    end
  end

  describe '#usernames' do
    it 'returns the usernames mentioned in a document' do
      document = Nokogiri::HTML.fragment("<p>#{get_reference(user)}</p>")
      filter = described_class.new(document, project: project)

      expect(filter.usernames).to eq([user.username])
    end
  end
end
