# frozen_string_literal: true

require 'spec_helper'

describe ProtectedBranch::PushAccessLevel do
  it { is_expected.to validate_inclusion_of(:access_level).in_array([Gitlab::Access::MAINTAINER, Gitlab::Access::DEVELOPER, Gitlab::Access::NO_ACCESS]) }
end
