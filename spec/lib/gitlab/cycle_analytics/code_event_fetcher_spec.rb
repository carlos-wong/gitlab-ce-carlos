# frozen_string_literal: true

require 'spec_helper'
require 'lib/gitlab/cycle_analytics/shared_event_spec'

describe Gitlab::CycleAnalytics::CodeEventFetcher do
  let(:stage_name) { :code }

  it_behaves_like 'default query config' do
    it 'has a default order' do
      expect(event.order).not_to be_nil
    end
  end
end
