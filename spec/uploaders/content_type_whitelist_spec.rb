# frozen_string_literal: true

require 'spec_helper'

describe ContentTypeWhitelist do
  class DummyUploader < CarrierWave::Uploader::Base
    include ContentTypeWhitelist::Concern

    def content_type_whitelist
      %w[image/png image/jpeg]
    end
  end

  let_it_be(:model) { build_stubbed(:user) }
  let_it_be(:uploader) { DummyUploader.new(model, :dummy) }

  context 'upload whitelisted file content type' do
    let(:path) { File.join('spec', 'fixtures', 'rails_sample.jpg') }

    it_behaves_like 'accepted carrierwave upload'
    it_behaves_like 'upload with content type', 'image/jpeg'
  end

  context 'upload non-whitelisted file content type' do
    let(:path) { File.join('spec', 'fixtures', 'sanitized.svg') }

    it_behaves_like 'denied carrierwave upload'
  end

  context 'upload misnamed non-whitelisted file content type' do
    let(:path) { File.join('spec', 'fixtures', 'not_a_png.png') }

    it_behaves_like 'denied carrierwave upload'
  end
end
