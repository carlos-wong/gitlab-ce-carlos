require 'spec_helper'

describe Gitlab::Sentry do
  describe '.context' do
    it 'adds the expected tags' do
      expect(described_class).to receive(:enabled?).and_return(true)
      allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return('cid')

      described_class.context(nil)

      expect(Raven.tags_context[:locale].to_s).to eq(I18n.locale.to_s)
      expect(Raven.tags_context[Labkit::Correlation::CorrelationId::LOG_KEY.to_sym].to_s)
        .to eq('cid')
    end
  end

  describe '.track_exception' do
    let(:exception) { RuntimeError.new('boom') }

    before do
      allow(described_class).to receive(:enabled?).and_return(true)
    end

    it 'raises the exception if it should' do
      expect(described_class).to receive(:should_raise_for_dev?).and_return(true)
      expect { described_class.track_exception(exception) }
        .to raise_error(RuntimeError)
    end

    context 'when exceptions should not be raised' do
      before do
        allow(described_class).to receive(:should_raise_for_dev?).and_return(false)
        allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return('cid')
      end

      it 'logs the exception with all attributes passed' do
        expected_extras = {
          some_other_info: 'info',
          issue_url: 'http://gitlab.com/gitlab-org/gitlab-ce/issues/1'
        }

        expected_tags = {
          correlation_id: 'cid'
        }

        expect(Raven).to receive(:capture_exception)
                           .with(exception,
                            tags: a_hash_including(expected_tags),
                            extra: a_hash_including(expected_extras))

        described_class.track_exception(
          exception,
          issue_url: 'http://gitlab.com/gitlab-org/gitlab-ce/issues/1',
          extra: { some_other_info: 'info' }
        )
      end

      it 'sets the context' do
        expect(described_class).to receive(:context)

        described_class.track_exception(exception)
      end
    end
  end

  context '.track_acceptable_exception' do
    let(:exception) { RuntimeError.new('boom') }

    before do
      allow(described_class).to receive(:enabled?).and_return(true)
      allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return('cid')
    end

    it 'calls Raven.capture_exception' do
      expected_extras = {
        some_other_info: 'info',
        issue_url: 'http://gitlab.com/gitlab-org/gitlab-ce/issues/1'
      }

      expected_tags = {
        correlation_id: 'cid'
      }

      expect(Raven).to receive(:capture_exception)
                         .with(exception,
                          tags: a_hash_including(expected_tags),
                          extra: a_hash_including(expected_extras))

      described_class.track_acceptable_exception(
        exception,
        issue_url: 'http://gitlab.com/gitlab-org/gitlab-ce/issues/1',
        extra: { some_other_info: 'info' }
      )
    end
  end
end
