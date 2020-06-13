# frozen_string_literal: true

require 'spec_helper'

shared_examples_for 'snippet editor' do
  before do
    stub_feature_flags(snippets_vue: false)
    stub_feature_flags(monaco_snippets: flag)
    sign_in(user)
    visit new_snippet_path
  end

  def description_field
    find('.js-description-input').find('input,textarea')
  end

  def fill_form
    fill_in 'personal_snippet_title', with: 'My Snippet Title'

    # Click placeholder first to expand full description field
    description_field.click
    fill_in 'personal_snippet_description', with: 'My Snippet **Description**'

    page.within('.file-editor') do
      el = flag == true ? find('.inputarea') : find('.ace_text-input', visible: false)
      el.send_keys 'Hello World!'
    end
  end

  it 'Authenticated user creates a snippet' do
    fill_form

    click_button('Create snippet')
    wait_for_requests

    expect(page).to have_content('My Snippet Title')
    page.within('.snippet-header .description') do
      expect(page).to have_content('My Snippet Description')
      expect(page).to have_selector('strong')
    end
    expect(page).to have_content('Hello World!')
  end

  it 'previews a snippet with file' do
    # Click placeholder first to expand full description field
    description_field.click
    fill_in 'personal_snippet_description', with: 'My Snippet'
    dropzone_file Rails.root.join('spec', 'fixtures', 'banana_sample.gif')
    find('.js-md-preview-button').click

    page.within('#new_personal_snippet .md-preview-holder') do
      expect(page).to have_content('My Snippet')

      link = find('a.no-attachment-icon img.js-lazy-loaded[alt="banana_sample"]')['src']
      expect(link).to match(%r{/uploads/-/system/user/#{user.id}/\h{32}/banana_sample\.gif\z})

      # Adds a cache buster for checking if the image exists as Selenium is now handling the cached regquests
      # not anymore as requests when they come straight from memory cache.
      reqs = inspect_requests { visit("#{link}?ran=#{SecureRandom.base64(20)}") }
      expect(reqs.first.status_code).to eq(200)
    end
  end

  it 'uploads a file when dragging into textarea' do
    fill_form

    dropzone_file Rails.root.join('spec', 'fixtures', 'banana_sample.gif')

    expect(page.find_field("personal_snippet_description").value).to have_content('banana_sample')

    click_button('Create snippet')
    wait_for_requests

    link = find('a.no-attachment-icon img.js-lazy-loaded[alt="banana_sample"]')['src']
    expect(link).to match(%r{/uploads/-/system/personal_snippet/#{Snippet.last.id}/\h{32}/banana_sample\.gif\z})

    reqs = inspect_requests { visit("#{link}?ran=#{SecureRandom.base64(20)}") }
    expect(reqs.first.status_code).to eq(200)
  end

  context 'when the git operation fails' do
    let(:error) { 'This is a git error' }

    before do
      allow_next_instance_of(Snippets::CreateService) do |instance|
        allow(instance).to receive(:create_commit).and_raise(StandardError, error)
      end

      fill_form

      click_button('Create snippet')
      wait_for_requests
    end

    it 'displays the error' do
      expect(page).to have_content(error)
    end

    it 'renders new page' do
      expect(page).to have_content('New Snippet')
    end
  end

  it 'validation fails for the first time' do
    fill_in 'personal_snippet_title', with: 'My Snippet Title'
    click_button('Create snippet')

    expect(page).to have_selector('#error_explanation')

    fill_form
    dropzone_file Rails.root.join('spec', 'fixtures', 'banana_sample.gif')

    click_button('Create snippet')
    wait_for_requests

    expect(page).to have_content('My Snippet Title')
    page.within('.snippet-header .description') do
      expect(page).to have_content('My Snippet Description')
      expect(page).to have_selector('strong')
    end
    expect(page).to have_content('Hello World!')
    link = find('a.no-attachment-icon img.js-lazy-loaded[alt="banana_sample"]')['src']
    expect(link).to match(%r{/uploads/-/system/personal_snippet/#{Snippet.last.id}/\h{32}/banana_sample\.gif\z})

    reqs = inspect_requests { visit("#{link}?ran=#{SecureRandom.base64(20)}") }
    expect(reqs.first.status_code).to eq(200)
  end

  it 'Authenticated user creates a snippet with + in filename' do
    fill_in 'personal_snippet_title', with: 'My Snippet Title'
    page.within('.file-editor') do
      find(:xpath, "//input[@id='personal_snippet_file_name']").set 'snippet+file+name'
      el = flag == true ? find('.inputarea') : find('.ace_text-input', visible: false)
      el.send_keys 'Hello World!'
    end

    click_button 'Create snippet'
    wait_for_requests

    expect(page).to have_content('My Snippet Title')
    expect(page).to have_content('snippet+file+name')
    expect(page).to have_content('Hello World!')
  end
end

describe 'User creates snippet', :js do
  include DropzoneHelper

  let_it_be(:user) { create(:user) }

  context 'when using Monaco' do
    it_behaves_like "snippet editor" do
      let(:flag) { true }
    end
  end

  context 'when using ACE' do
    it_behaves_like "snippet editor" do
      let(:flag) { false }
    end
  end
end
