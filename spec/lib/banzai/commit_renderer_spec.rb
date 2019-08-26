# frozen_string_literal: true

require 'spec_helper'

describe Banzai::CommitRenderer do
  describe '.render', :clean_gitlab_redis_cache do
    it 'renders a commit description and title' do
      user = build(:user)
      project = create(:project, :repository)

      expect(Banzai::ObjectRenderer)
        .to receive(:new)
        .with(user: user, default_project: project)
        .and_call_original

      described_class::ATTRIBUTES.each do |attr|
        expect_any_instance_of(Banzai::ObjectRenderer).to receive(:render).with([project.commit], attr).once.and_call_original
        expect(Banzai::Renderer).to receive(:cacheless_render_field).with(project.commit, attr, { skip_project_check: false }).and_call_original
      end

      described_class.render([project.commit], project, user)
    end
  end
end
