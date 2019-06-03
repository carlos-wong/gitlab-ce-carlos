# frozen_string_literal: true

require 'spec_helper'

describe CampfireService do
  include StubRequests

  describe 'Associations' do
    it { is_expected.to belong_to :project }
    it { is_expected.to have_one :service_hook }
  end

  describe 'Validations' do
    context 'when service is active' do
      before do
        subject.active = true
      end

      it { is_expected.to validate_presence_of(:token) }
    end

    context 'when service is inactive' do
      before do
        subject.active = false
      end

      it { is_expected.not_to validate_presence_of(:token) }
    end
  end

  describe "#execute" do
    let(:user)    { create(:user) }
    let(:project) { create(:project, :repository) }

    before do
      @campfire_service = described_class.new
      allow(@campfire_service).to receive_messages(
        project_id: project.id,
        project: project,
        service_hook: true,
        token: 'verySecret',
        subdomain: 'project-name',
        room: 'test-room'
      )
      @sample_data = Gitlab::DataBuilder::Push.build_sample(project, user)
      @rooms_url = 'https://project-name.campfirenow.com/rooms.json'
      @auth = %w(verySecret X)
      @headers = { 'Content-Type' => 'application/json; charset=utf-8' }
    end

    it "calls Campfire API to get a list of rooms and speak in a room" do
      # make sure a valid list of rooms is returned
      body = File.read(Rails.root + 'spec/fixtures/project_services/campfire/rooms.json')

      stub_full_request(@rooms_url).with(basic_auth: @auth).to_return(
        body: body,
        status: 200,
        headers: @headers
      )

      # stub the speak request with the room id found in the previous request's response
      speak_url = 'https://project-name.campfirenow.com/room/123/speak.json'
      stub_full_request(speak_url, method: :post).with(basic_auth: @auth)

      @campfire_service.execute(@sample_data)

      expect(WebMock).to have_requested(:get, stubbed_hostname(@rooms_url)).once
      expect(WebMock).to have_requested(:post, stubbed_hostname(speak_url))
                           .with(body: /#{project.path}.*#{@sample_data[:before]}.*#{@sample_data[:after]}/).once
    end

    it "calls Campfire API to get a list of rooms but shouldn't speak in a room" do
      # return a list of rooms that do not contain a room named 'test-room'
      body = File.read(Rails.root + 'spec/fixtures/project_services/campfire/rooms2.json')
      stub_full_request(@rooms_url).with(basic_auth: @auth).to_return(
        body: body,
        status: 200,
        headers: @headers
      )

      @campfire_service.execute(@sample_data)

      expect(WebMock).to have_requested(:get, 'https://8.8.8.9/rooms.json').once
      expect(WebMock).not_to have_requested(:post, '*/room/.*/speak.json')
    end
  end
end
