# frozen_string_literal: true

require 'spec_helper'

describe 'Admin Appearance' do
  let!(:appearance) { create(:appearance) }

  it 'Create new appearance' do
    sign_in(create(:admin))
    visit admin_appearances_path

    fill_in 'appearance_title', with: 'MyCompany'
    fill_in 'appearance_description', with: 'dev server'
    fill_in 'appearance_new_project_guidelines', with: 'Custom project guidelines'
    click_button 'Update appearance settings'

    expect(current_path).to eq admin_appearances_path
    expect(page).to have_content 'Appearance'

    expect(page).to have_field('appearance_title', with: 'MyCompany')
    expect(page).to have_field('appearance_description', with: 'dev server')
    expect(page).to have_field('appearance_new_project_guidelines', with: 'Custom project guidelines')
    expect(page).to have_content 'Last edit'
  end

  it 'Preview sign-in page appearance' do
    sign_in(create(:admin))

    visit admin_appearances_path
    click_link "Sign-in page"

    expect_custom_sign_in_appearance(appearance)
  end

  it 'Preview new project page appearance' do
    sign_in(create(:admin))

    visit admin_appearances_path
    click_link "New project page"

    expect_custom_new_project_appearance(appearance)
  end

  context 'Custom system header and footer' do
    before do
      sign_in(create(:admin))
    end

    context 'when system header and footer messages are empty' do
      it 'shows custom system header and footer fields' do
        visit admin_appearances_path

        expect(page).to have_field('appearance_header_message', with: '')
        expect(page).to have_field('appearance_footer_message', with: '')
        expect(page).to have_field('appearance_message_background_color')
        expect(page).to have_field('appearance_message_font_color')
      end
    end

    context 'when system header and footer messages are not empty' do
      before do
        appearance.update(header_message: 'Foo', footer_message: 'Bar')
      end

      it 'shows custom system header and footer fields' do
        visit admin_appearances_path

        expect(page).to have_field('appearance_header_message', with: appearance.header_message)
        expect(page).to have_field('appearance_footer_message', with: appearance.footer_message)
        expect(page).to have_field('appearance_message_background_color')
        expect(page).to have_field('appearance_message_font_color')
      end
    end
  end

  it 'Custom sign-in page' do
    visit new_user_session_path

    expect_custom_sign_in_appearance(appearance)
  end

  it 'Custom new project page' do
    sign_in create(:user)
    visit new_project_path

    expect_custom_new_project_appearance(appearance)
  end

  it 'Appearance logo' do
    sign_in(create(:admin))
    visit admin_appearances_path

    attach_file(:appearance_logo, logo_fixture)
    click_button 'Update appearance settings'
    expect(page).to have_css(logo_selector)

    click_link 'Remove logo'
    expect(page).not_to have_css(logo_selector)
  end

  it 'Header logos' do
    sign_in(create(:admin))
    visit admin_appearances_path

    attach_file(:appearance_header_logo, logo_fixture)
    click_button 'Update appearance settings'
    expect(page).to have_css(header_logo_selector)

    click_link 'Remove header logo'
    expect(page).not_to have_css(header_logo_selector)
  end

  it 'Favicon' do
    sign_in(create(:admin))
    visit admin_appearances_path

    attach_file(:appearance_favicon, logo_fixture)
    click_button 'Update appearance settings'

    expect(page).to have_css('.appearance-light-logo-preview')

    click_link 'Remove favicon'

    expect(page).not_to have_css('.appearance-light-logo-preview')

    # allowed file types
    attach_file(:appearance_favicon, Rails.root.join('spec', 'fixtures', 'sanitized.svg'))
    click_button 'Update appearance settings'

    expect(page).to have_content 'Favicon You are not allowed to upload "svg" files, allowed types: png, ico'
  end

  def expect_custom_sign_in_appearance(appearance)
    expect(page).to have_content appearance.title
    expect(page).to have_content appearance.description
  end

  def expect_custom_new_project_appearance(appearance)
    expect(page).to have_content appearance.new_project_guidelines
  end

  def logo_selector
    '//img[data-src^="/uploads/-/system/appearance/logo"]'
  end

  def header_logo_selector
    '//img[data-src^="/uploads/-/system/appearance/header_logo"]'
  end

  def logo_fixture
    Rails.root.join('spec', 'fixtures', 'dk.png')
  end
end
