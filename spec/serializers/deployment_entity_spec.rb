require 'spec_helper'

describe DeploymentEntity do
  let(:user) { developer }
  let(:developer) { create(:user) }
  let(:reporter) { create(:user) }
  let(:project) { create(:project) }
  let(:request) { double('request') }
  let(:deployment) { create(:deployment, deployable: build, project: project) }
  let(:build) { create(:ci_build, :manual, pipeline: pipeline) }
  let(:pipeline) { create(:ci_pipeline, project: project, user: user) }
  let(:entity) { described_class.new(deployment, request: request) }
  subject { entity.as_json }

  before do
    project.add_developer(developer)
    project.add_reporter(reporter)
    allow(request).to receive(:current_user).and_return(user)
    allow(request).to receive(:project).and_return(project)
  end

  it 'exposes internal deployment id' do
    expect(subject).to include(:iid)
  end

  it 'exposes nested information about branch' do
    expect(subject[:ref][:name]).to eq 'master'
  end

  it 'exposes creation date' do
    expect(subject).to include(:created_at)
  end

  context 'when the pipeline has another manual action' do
    let(:other_build) { create(:ci_build, :manual, name: 'another deploy', pipeline: pipeline) }
    let!(:other_deployment) { create(:deployment, deployable: other_build) }

    it 'returns another manual action' do
      expect(subject[:manual_actions].count).to eq(1)
      expect(subject[:manual_actions].first[:name]).to eq('another deploy')
    end

    context 'when user is a reporter' do
      let(:user) { reporter }

      it 'returns another manual action' do
        expect(subject[:manual_actions]).not_to be_present
      end
    end
  end

  describe 'scheduled_actions' do
    let(:project) { create(:project, :repository) }
    let(:pipeline) { create(:ci_pipeline, project: project, user: user) }
    let(:build) { create(:ci_build, :success, pipeline: pipeline) }
    let(:deployment) { create(:deployment, deployable: build) }

    context 'when the same pipeline has a scheduled action' do
      let(:other_build) { create(:ci_build, :schedulable, :success, pipeline: pipeline, name: 'other build') }
      let!(:other_deployment) { create(:deployment, deployable: other_build) }

      it 'returns other scheduled actions' do
        expect(subject[:scheduled_actions][0][:name]).to eq 'other build'
      end
    end

    context 'when the same pipeline does not have a scheduled action' do
      it 'does not return other actions' do
        expect(subject[:scheduled_actions]).to be_empty
      end
    end
  end
end
