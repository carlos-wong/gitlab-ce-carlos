# frozen_string_literal: true

RSpec.shared_context 'JSON response' do
  let(:json_response) { JSON.parse(response.body) }
end
