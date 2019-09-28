# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::DependencyLinker::RequirementsTxtLinker do
  describe '.support?' do
    it 'supports requirements.txt' do
      expect(described_class.support?('requirements.txt')).to be_truthy
    end

    it 'supports doc-requirements.txt' do
      expect(described_class.support?('doc-requirements.txt')).to be_truthy
    end

    it 'does not support other files' do
      expect(described_class.support?('requirements')).to be_falsey
    end
  end

  describe '#link' do
    let(:file_name) { "requirements.txt" }

    let(:file_content) do
      <<-CONTENT.strip_heredoc
        #
        ####### example-requirements.txt #######
        #
        ###### Requirements without Version Specifiers ######
        nose
        nose-cov
        beautifulsoup4
        #
        ###### Requirements with Version Specifiers ######
        #   See https://www.python.org/dev/peps/pep-0440/#version-specifiers
        docopt == 0.6.1             # Version Matching. Must be version 0.6.1
        keyring >= 4.1.1            # Minimum version 4.1.1
        coverage != 3.5             # Version Exclusion. Anything except version 3.5
        Mopidy-Dirble ~= 1.1        # Compatible release. Same as >= 1.1, == 1.*
        #
        ###### Refer to other requirements files ######
        -r other-requirements.txt
        #
        #
        ###### A particular file ######
        ./downloads/numpy-1.9.2-cp34-none-win32.whl
        http://wxpython.org/Phoenix/snapshot-builds/wxPython_Phoenix-3.0.3.dev1820+49a8884-cp34-none-win_amd64.whl
        #
        ###### Additional Requirements without Version Specifiers ######
        #   Same as 1st section, just here to show that you can put things in any order.
        rejected
        green
        #

        Jinja2>=2.3
        Pygments>=1.2
        Sphinx>=1.3
        docutils>=0.7
        markupsafe
        pytest~=3.0
        foop!=3.0
      CONTENT
    end

    subject { Gitlab::Highlight.highlight(file_name, file_content) }

    def link(name, url)
      %{<a href="#{url}" rel="nofollow noreferrer noopener" target="_blank">#{name}</a>}
    end

    it 'links dependencies' do
      expect(subject).to include(link('nose', 'https://pypi.python.org/pypi/nose'))
      expect(subject).to include(link('nose-cov', 'https://pypi.python.org/pypi/nose-cov'))
      expect(subject).to include(link('beautifulsoup4', 'https://pypi.python.org/pypi/beautifulsoup4'))
      expect(subject).to include(link('docopt', 'https://pypi.python.org/pypi/docopt'))
      expect(subject).to include(link('keyring', 'https://pypi.python.org/pypi/keyring'))
      expect(subject).to include(link('coverage', 'https://pypi.python.org/pypi/coverage'))
      expect(subject).to include(link('Mopidy-Dirble', 'https://pypi.python.org/pypi/Mopidy-Dirble'))
      expect(subject).to include(link('rejected', 'https://pypi.python.org/pypi/rejected'))
      expect(subject).to include(link('green', 'https://pypi.python.org/pypi/green'))
      expect(subject).to include(link('Jinja2', 'https://pypi.python.org/pypi/Jinja2'))
      expect(subject).to include(link('Pygments', 'https://pypi.python.org/pypi/Pygments'))
      expect(subject).to include(link('Sphinx', 'https://pypi.python.org/pypi/Sphinx'))
      expect(subject).to include(link('docutils', 'https://pypi.python.org/pypi/docutils'))
      expect(subject).to include(link('markupsafe', 'https://pypi.python.org/pypi/markupsafe'))
      expect(subject).to include(link('pytest', 'https://pypi.python.org/pypi/pytest'))
      expect(subject).to include(link('foop', 'https://pypi.python.org/pypi/foop'))
    end

    it 'links URLs' do
      expect(subject).to include(link('http://wxpython.org/Phoenix/snapshot-builds/wxPython_Phoenix-3.0.3.dev1820+49a8884-cp34-none-win_amd64.whl', 'http://wxpython.org/Phoenix/snapshot-builds/wxPython_Phoenix-3.0.3.dev1820+49a8884-cp34-none-win_amd64.whl'))
    end

    it 'does not contain link with a newline as package name' do
      expect(subject).not_to include(link("\n", "https://pypi.python.org/pypi/\n"))
    end
  end
end
