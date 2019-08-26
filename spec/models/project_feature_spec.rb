# frozen_string_literal: true

require 'spec_helper'

describe ProjectFeature do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  describe '.quoted_access_level_column' do
    it 'returns the table name and quoted column name for a feature' do
      expected = '"project_features"."issues_access_level"'

      expect(described_class.quoted_access_level_column(:issues)).to eq(expected)
    end
  end

  describe '#feature_available?' do
    let(:features) { %w(issues wiki builds merge_requests snippets repository pages) }

    context 'when features are disabled' do
      it "returns false" do
        features.each do |feature|
          project.project_feature.update_attribute("#{feature}_access_level".to_sym, ProjectFeature::DISABLED)
          expect(project.feature_available?(:issues, user)).to eq(false)
        end
      end
    end

    context 'when features are enabled only for team members' do
      it "returns false when user is not a team member" do
        features.each do |feature|
          project.project_feature.update_attribute("#{feature}_access_level".to_sym, ProjectFeature::PRIVATE)
          expect(project.feature_available?(:issues, user)).to eq(false)
        end
      end

      it "returns true when user is a team member" do
        project.add_developer(user)

        features.each do |feature|
          project.project_feature.update_attribute("#{feature}_access_level".to_sym, ProjectFeature::PRIVATE)
          expect(project.feature_available?(:issues, user)).to eq(true)
        end
      end

      it "returns true when user is a member of project group" do
        group = create(:group)
        project = create(:project, namespace: group)
        group.add_developer(user)

        features.each do |feature|
          project.project_feature.update_attribute("#{feature}_access_level".to_sym, ProjectFeature::PRIVATE)
          expect(project.feature_available?(:issues, user)).to eq(true)
        end
      end

      it "returns true if user is an admin" do
        user.update_attribute(:admin, true)

        features.each do |feature|
          project.project_feature.update_attribute("#{feature}_access_level".to_sym, ProjectFeature::PRIVATE)
          expect(project.feature_available?(:issues, user)).to eq(true)
        end
      end
    end

    context 'when feature is enabled for everyone' do
      it "returns true" do
        features.each do |feature|
          expect(project.feature_available?(:issues, user)).to eq(true)
        end
      end
    end

    context 'when feature is disabled by a feature flag' do
      it 'returns false' do
        stub_feature_flags(issues: false)

        expect(project.feature_available?(:issues, user)).to eq(false)
      end
    end

    context 'when feature is enabled by a feature flag' do
      it 'returns true' do
        stub_feature_flags(issues: true)

        expect(project.feature_available?(:issues, user)).to eq(true)
      end
    end
  end

  context 'repository related features' do
    before do
      project.project_feature.update(
        merge_requests_access_level: ProjectFeature::DISABLED,
        builds_access_level: ProjectFeature::DISABLED,
        repository_access_level: ProjectFeature::PRIVATE
      )
    end

    it "does not allow repository related features have higher level" do
      features = %w(builds merge_requests)
      project_feature = project.project_feature

      features.each do |feature|
        field = "#{feature}_access_level".to_sym
        project_feature.update_attribute(field, ProjectFeature::ENABLED)
        expect(project_feature.valid?).to be_falsy
      end
    end
  end

  context 'public features' do
    it "does not allow public for other than pages" do
      features = %w(issues wiki builds merge_requests snippets repository)
      project_feature = project.project_feature

      features.each do |feature|
        field = "#{feature}_access_level".to_sym
        project_feature.update_attribute(field, ProjectFeature::PUBLIC)
        expect(project_feature.valid?).to be_falsy
      end
    end
  end

  describe '#*_enabled?' do
    let(:features) { %w(wiki builds merge_requests) }

    it "returns false when feature is disabled" do
      features.each do |feature|
        project.project_feature.update_attribute("#{feature}_access_level".to_sym, ProjectFeature::DISABLED)
        expect(project.public_send("#{feature}_enabled?")).to eq(false)
      end
    end

    it "returns true when feature is enabled only for team members" do
      features.each do |feature|
        project.project_feature.update_attribute("#{feature}_access_level".to_sym, ProjectFeature::PRIVATE)
        expect(project.public_send("#{feature}_enabled?")).to eq(true)
      end
    end

    it "returns true when feature is enabled for everyone" do
      features.each do |feature|
        expect(project.public_send("#{feature}_enabled?")).to eq(true)
      end
    end
  end

  describe 'default pages access level' do
    subject { project.project_feature.pages_access_level }

    before do
      # project factory overrides all values in project_feature after creation
      project.project_feature.destroy!
      project.build_project_feature.save!
    end

    context 'when new project is private' do
      let(:project) { create(:project, :private) }

      it { is_expected.to eq(ProjectFeature::PRIVATE) }
    end

    context 'when new project is internal' do
      let(:project) { create(:project, :internal) }

      it { is_expected.to eq(ProjectFeature::PRIVATE) }
    end

    context 'when new project is public' do
      let(:project) { create(:project, :public) }

      it { is_expected.to eq(ProjectFeature::ENABLED) }
    end
  end
end
