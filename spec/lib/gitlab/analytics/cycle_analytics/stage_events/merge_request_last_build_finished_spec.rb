# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Analytics::CycleAnalytics::StageEvents::MergeRequestLastBuildFinished do
  it_behaves_like 'cycle analytics event'
end
