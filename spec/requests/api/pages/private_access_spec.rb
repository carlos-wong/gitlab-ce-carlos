require 'spec_helper'

describe "Private Project Pages Access" do
  using RSpec::Parameterized::TableSyntax
  include AccessMatchers

  set(:group) { create(:group) }
  set(:project) { create(:project, :private, pages_access_level: ProjectFeature::ENABLED, namespace: group) }

  set(:admin) { create(:admin) }
  set(:owner) { create(:user) }
  set(:master) { create(:user) }
  set(:developer) { create(:user) }
  set(:reporter) { create(:user) }
  set(:guest) { create(:user) }
  set(:user) { create(:user) }

  before do
    allow(Gitlab.config.pages).to receive(:access_control).and_return(true)
    group.add_owner(owner)
    project.add_master(master)
    project.add_developer(developer)
    project.add_reporter(reporter)
    project.add_guest(guest)
  end

  describe "Project should be private" do
    describe '#private?' do
      subject { project.private? }

      it { is_expected.to be_truthy }
    end
  end

  describe "GET /projects/:id/pages_access" do
    context 'access depends on the level' do
      where(:pages_access_level, :with_user, :expected_result) do
        ProjectFeature::DISABLED   |   "admin"     |  403
        ProjectFeature::DISABLED   |   "owner"     |  403
        ProjectFeature::DISABLED   |   "master"    |  403
        ProjectFeature::DISABLED   |   "developer" |  403
        ProjectFeature::DISABLED   |   "reporter"  |  403
        ProjectFeature::DISABLED   |   "guest"     |  403
        ProjectFeature::DISABLED   |   "user"      |  404
        ProjectFeature::DISABLED   |   nil         |  404
        ProjectFeature::PUBLIC     |   "admin"     |  200
        ProjectFeature::PUBLIC     |   "owner"     |  200
        ProjectFeature::PUBLIC     |   "master"    |  200
        ProjectFeature::PUBLIC     |   "developer" |  200
        ProjectFeature::PUBLIC     |   "reporter"  |  200
        ProjectFeature::PUBLIC     |   "guest"     |  200
        ProjectFeature::PUBLIC     |   "user"      |  404
        ProjectFeature::PUBLIC     |   nil         |  404
        ProjectFeature::ENABLED    |   "admin"     |  200
        ProjectFeature::ENABLED    |   "owner"     |  200
        ProjectFeature::ENABLED    |   "master"    |  200
        ProjectFeature::ENABLED    |   "developer" |  200
        ProjectFeature::ENABLED    |   "reporter"  |  200
        ProjectFeature::ENABLED    |   "guest"     |  200
        ProjectFeature::ENABLED    |   "user"      |  404
        ProjectFeature::ENABLED    |   nil         |  404
        ProjectFeature::PRIVATE    |   "admin"     |  200
        ProjectFeature::PRIVATE    |   "owner"     |  200
        ProjectFeature::PRIVATE    |   "master"    |  200
        ProjectFeature::PRIVATE    |   "developer" |  200
        ProjectFeature::PRIVATE    |   "reporter"  |  200
        ProjectFeature::PRIVATE    |   "guest"     |  200
        ProjectFeature::PRIVATE    |   "user"      |  404
        ProjectFeature::PRIVATE    |   nil         |  404
      end

      with_them do
        before do
          project.project_feature.update(pages_access_level: pages_access_level)
        end
        it "correct return value" do
          if !with_user.nil?
            user = public_send(with_user)
            get api("/projects/#{project.id}/pages_access", user)
          else
            get api("/projects/#{project.id}/pages_access")
          end

          expect(response).to have_gitlab_http_status(expected_result)
        end
      end
    end
  end
end
