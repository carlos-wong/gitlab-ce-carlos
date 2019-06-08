# frozen_string_literal: true

require 'spec_helper'

describe ImportUrlParams do
  let(:import_url_params) do
    controller = OpenStruct.new(params: params).extend(described_class)
    controller.import_url_params
  end

  context 'empty URL' do
    let(:params) do
      ActionController::Parameters.new(project: {
        title: 'Test'
      })
    end

    it 'returns empty hash' do
      expect(import_url_params).to eq({})
    end
  end

  context 'url and password separately provided' do
    let(:params) do
      ActionController::Parameters.new(project: {
        import_url: 'https://url.com',
        import_url_user: 'user', import_url_password: 'password'
      })
    end

    describe '#import_url_params' do
      it 'returns hash with import_url' do
        expect(import_url_params).to eq(
          import_url: "https://user:password@url.com"
        )
      end
    end
  end

  context 'url with provided empty credentials' do
    let(:params) do
      ActionController::Parameters.new(project: {
        import_url: 'https://user:password@url.com',
        import_url_user: '', import_url_password: ''
      })
    end

    describe '#import_url_params' do
      it 'does not change the url' do
        expect(import_url_params).to eq(
          import_url: "https://user:password@url.com"
        )
      end
    end
  end
end
