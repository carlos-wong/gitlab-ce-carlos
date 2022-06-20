# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::PlantumlFilter do
  include FilterSpecHelper

  it 'replaces plantuml pre tag with img tag' do
    stub_application_setting(plantuml_enabled: true, plantuml_url: "http://localhost:8080")

    input = '<pre lang="plantuml"><code>Bob -> Sara : Hello</code></pre>'
    output = '<img class="plantuml" src="http://localhost:8080/png/U9npoazIqBLJ24uiIbImKl18pSd91m0rkGMq" data-diagram="plantuml" data-diagram-src="data:text/plain;base64,Qm9iIC0+IFNhcmEgOiBIZWxsbw==">'
    doc = filter(input)

    expect(doc.to_s).to eq output
  end

  it 'does not replace plantuml pre tag with img tag if disabled' do
    stub_application_setting(plantuml_enabled: false)

    input = '<pre lang="plantuml"><code>Bob -> Sara : Hello</code></pre>'
    output = '<pre lang="plantuml"><code>Bob -&gt; Sara : Hello</code></pre>'
    doc = filter(input)

    expect(doc.to_s).to eq output
  end

  it 'does not replace plantuml pre tag with img tag if url is invalid' do
    stub_application_setting(plantuml_enabled: true, plantuml_url: "invalid")

    input = '<pre lang="plantuml"><code>Bob -> Sara : Hello</code></pre>'
    output = '<pre lang="plantuml"><code>Bob -&gt; Sara : Hello</code></pre>'
    doc = filter(input)

    expect(doc.to_s).to eq output
  end
end
