# frozen_string_literal: true

require 'fast_spec_helper'

describe Gitlab::MarkdownCache::FieldData do
  subject(:field_data) { described_class.new }

  before do
    field_data[:description] = { project: double('project in context') }
  end

  it 'translates a markdown field name into a html field name' do
    expect(field_data.html_field(:description)).to eq("description_html")
  end
end
