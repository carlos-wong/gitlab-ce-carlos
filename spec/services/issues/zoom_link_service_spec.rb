# frozen_string_literal: true

require 'spec_helper'

describe Issues::ZoomLinkService do
  set(:user) { create(:user) }
  set(:issue) { create(:issue) }

  let(:project) { issue.project }
  let(:service) { described_class.new(issue, user) }
  let(:zoom_link) { 'https://zoom.us/j/123456789' }

  before do
    project.add_reporter(user)
  end

  shared_context 'with Zoom link' do
    before do
      issue.update!(description: "Description\n\n#{zoom_link}")
    end
  end

  shared_context 'with Zoom link not at the end' do
    before do
      issue.update!(description: "Description with #{zoom_link} some where")
    end
  end

  shared_context 'without Zoom link' do
    before do
      issue.update!(description: "Description\n\nhttp://example.com")
    end
  end

  shared_context 'without issue description' do
    before do
      issue.update!(description: nil)
    end
  end

  shared_context 'feature flag disabled' do
    before do
      stub_feature_flags(issue_zoom_integration: false)
    end
  end

  shared_context 'insufficient permissions' do
    before do
      project.add_guest(user)
    end
  end

  describe '#add_link' do
    shared_examples 'can add link' do
      it 'appends the link to issue description' do
        expect(result).to be_success
        expect(result.payload[:description])
          .to eq("#{issue.description}\n\n#{zoom_link}")
      end
    end

    shared_examples 'cannot add link' do
      it 'cannot add the link' do
        expect(result).to be_error
        expect(result.message).to eq('Failed to add a Zoom meeting')
      end
    end

    subject(:result) { service.add_link(zoom_link) }

    context 'without Zoom link in the issue description' do
      include_context 'without Zoom link'
      include_examples 'can add link'

      context 'with invalid Zoom link' do
        let(:zoom_link) { 'https://not-zoom.link' }

        include_examples 'cannot add link'
      end

      context 'when feature flag is disabled' do
        include_context 'feature flag disabled'
        include_examples 'cannot add link'
      end

      context 'with insufficient permissions' do
        include_context 'insufficient permissions'
        include_examples 'cannot add link'
      end
    end

    context 'with Zoom link in the issue description' do
      include_context 'with Zoom link'
      include_examples 'cannot add link'

      context 'but not at the end' do
        include_context 'with Zoom link not at the end'
        include_examples 'can add link'
      end
    end

    context 'without issue description' do
      include_context 'without issue description'
      include_examples 'can add link'
    end
  end

  describe '#can_add_link?' do
    subject { service.can_add_link? }

    context 'without Zoom link in the issue description' do
      include_context 'without Zoom link'

      it { is_expected.to eq(true) }

      context 'when feature flag is disabled' do
        include_context 'feature flag disabled'

        it { is_expected.to eq(false) }
      end

      context 'with insufficient permissions' do
        include_context 'insufficient permissions'

        it { is_expected.to eq(false) }
      end
    end

    context 'with Zoom link in the issue description' do
      include_context 'with Zoom link'

      it { is_expected.to eq(false) }
    end
  end

  describe '#remove_link' do
    shared_examples 'cannot remove link' do
      it 'cannot remove the link' do
        expect(result).to be_error
        expect(result.message).to eq('Failed to remove a Zoom meeting')
      end
    end

    subject(:result) { service.remove_link }

    context 'with Zoom link in the issue description' do
      include_context 'with Zoom link'

      it 'removes the link from the issue description' do
        expect(result).to be_success
        expect(result.payload[:description])
          .to eq(issue.description.delete_suffix("\n\n#{zoom_link}"))
      end

      context 'when feature flag is disabled' do
        include_context 'feature flag disabled'
        include_examples 'cannot remove link'
      end

      context 'with insufficient permissions' do
        include_context 'insufficient permissions'
        include_examples 'cannot remove link'
      end

      context 'but not at the end' do
        include_context 'with Zoom link not at the end'
        include_examples 'cannot remove link'
      end
    end

    context 'without Zoom link in the issue description' do
      include_context 'without Zoom link'
      include_examples 'cannot remove link'
    end

    context 'without issue description' do
      include_context 'without issue description'
      include_examples 'cannot remove link'
    end
  end

  describe '#can_remove_link?' do
    subject { service.can_remove_link? }

    context 'with Zoom link in the issue description' do
      include_context 'with Zoom link'

      it { is_expected.to eq(true) }

      context 'when feature flag is disabled' do
        include_context 'feature flag disabled'

        it { is_expected.to eq(false) }
      end

      context 'with insufficient permissions' do
        include_context 'insufficient permissions'

        it { is_expected.to eq(false) }
      end
    end

    context 'without Zoom link in the issue description' do
      include_context 'without Zoom link'

      it { is_expected.to eq(false) }
    end
  end

  describe '#parse_link' do
    subject { service.parse_link(description) }

    context 'with valid Zoom links' do
      where(:description) do
        [
          'Some text https://zoom.us/j/123456789 more text',
          'Mixed https://zoom.us/j/123456789 http://example.com',
          'Multiple link https://zoom.us/my/name https://zoom.us/j/123456789'
        ]
      end

      with_them do
        it { is_expected.to eq('https://zoom.us/j/123456789') }
      end
    end

    context 'with invalid Zoom links' do
      where(:description) do
        [
          nil,
          '',
          'Text only',
          'Non-Zoom http://example.com',
          'Almost Zoom http://zoom.us'
        ]
      end

      with_them do
        it { is_expected.to eq(nil) }
      end
    end
  end
end
