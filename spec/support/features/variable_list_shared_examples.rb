shared_examples 'variable list' do
  it 'shows list of variables' do
    page.within('.js-ci-variable-list-section') do
      expect(first('.js-ci-variable-input-key').value).to eq(variable.key)
    end
  end

  it 'adds new CI variable' do
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('key')
      find('.js-ci-variable-input-value').set('key_value')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    # We check the first row because it re-sorts to alphabetical order on refresh
    page.within('.js-ci-variable-list-section .js-row:nth-child(2)') do
      expect(find('.js-ci-variable-input-key').value).to eq('key')
      expect(find('.js-ci-variable-input-value', visible: false).value).to eq('key_value')
    end
  end

  it 'adds a new protected variable' do
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('key')
      find('.js-ci-variable-input-value').set('key_value')
      find('.ci-variable-protected-item .js-project-feature-toggle').click

      expect(find('.js-ci-variable-input-protected', visible: false).value).to eq('true')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    # We check the first row because it re-sorts to alphabetical order on refresh
    page.within('.js-ci-variable-list-section .js-row:nth-child(2)') do
      expect(find('.js-ci-variable-input-key').value).to eq('key')
      expect(find('.js-ci-variable-input-value', visible: false).value).to eq('key_value')
      expect(find('.js-ci-variable-input-protected', visible: false).value).to eq('true')
    end
  end

  it 'defaults to unmasked' do
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('key')
      find('.js-ci-variable-input-value').set('key_value')

      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('false')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    # We check the first row because it re-sorts to alphabetical order on refresh
    page.within('.js-ci-variable-list-section .js-row:nth-child(2)') do
      expect(find('.js-ci-variable-input-key').value).to eq('key')
      expect(find('.js-ci-variable-input-value', visible: false).value).to eq('key_value')
      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('false')
    end
  end

  context 'defaults to the application setting' do
    context 'application setting is true' do
      before do
        stub_application_setting(protected_ci_variables: true)

        visit page_path
      end

      it 'defaults to protected' do
        page.within('.js-ci-variable-list-section .js-row:last-child') do
          find('.js-ci-variable-input-key').set('key')
        end

        values = all('.js-ci-variable-input-protected', visible: false).map(&:value)

        expect(values).to eq %w(false true true)
      end

      it 'shows a message regarding the changed default' do
        expect(page).to have_content 'Environment variables are configured by your administrator to be protected by default'
      end
    end

    context 'application setting is false' do
      before do
        stub_application_setting(protected_ci_variables: false)

        visit page_path
      end

      it 'defaults to unprotected' do
        page.within('.js-ci-variable-list-section .js-row:last-child') do
          find('.js-ci-variable-input-key').set('key')
        end

        values = all('.js-ci-variable-input-protected', visible: false).map(&:value)

        expect(values).to eq %w(false false false)
      end

      it 'does not show a message regarding the default' do
        expect(page).not_to have_content 'Environment variables are configured by your administrator to be protected by default'
      end
    end
  end

  it 'reveals and hides variables' do
    page.within('.js-ci-variable-list-section') do
      expect(first('.js-ci-variable-input-key').value).to eq(variable.key)
      expect(first('.js-ci-variable-input-value', visible: false).value).to eq(variable.value)
      expect(page).to have_content('*' * 17)

      click_button('Reveal value')

      expect(first('.js-ci-variable-input-key').value).to eq(variable.key)
      expect(first('.js-ci-variable-input-value').value).to eq(variable.value)
      expect(page).not_to have_content('*' * 17)

      click_button('Hide value')

      expect(first('.js-ci-variable-input-key').value).to eq(variable.key)
      expect(first('.js-ci-variable-input-value', visible: false).value).to eq(variable.value)
      expect(page).to have_content('*' * 17)
    end
  end

  it 'deletes variable' do
    page.within('.js-ci-variable-list-section') do
      expect(page).to have_selector('.js-row', count: 2)

      first('.js-row-remove-button').click

      click_button('Save variables')
      wait_for_requests

      expect(page).to have_selector('.js-row', count: 1)
    end
  end

  it 'edits variable' do
    page.within('.js-ci-variable-list-section') do
      click_button('Reveal value')

      page.within('.js-row:nth-child(2)') do
        find('.js-ci-variable-input-key').set('new_key')
        find('.js-ci-variable-input-value').set('new_value')
      end

      click_button('Save variables')
      wait_for_requests

      visit page_path

      page.within('.js-row:nth-child(2)') do
        expect(find('.js-ci-variable-input-key').value).to eq('new_key')
        expect(find('.js-ci-variable-input-value', visible: false).value).to eq('new_value')
      end
    end
  end

  it 'edits variable to be protected' do
    # Create the unprotected variable
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('unprotected_key')
      find('.js-ci-variable-input-value').set('unprotected_value')

      expect(find('.js-ci-variable-input-protected', visible: false).value).to eq('false')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    # We check the first row because it re-sorts to alphabetical order on refresh
    page.within('.js-ci-variable-list-section .js-row:nth-child(3)') do
      find('.ci-variable-protected-item .js-project-feature-toggle').click

      expect(find('.js-ci-variable-input-protected', visible: false).value).to eq('true')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    # We check the first row because it re-sorts to alphabetical order on refresh
    page.within('.js-ci-variable-list-section .js-row:nth-child(3)') do
      expect(find('.js-ci-variable-input-key').value).to eq('unprotected_key')
      expect(find('.js-ci-variable-input-value', visible: false).value).to eq('unprotected_value')
      expect(find('.js-ci-variable-input-protected', visible: false).value).to eq('true')
    end
  end

  it 'edits variable to be unprotected' do
    # Create the protected variable
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('protected_key')
      find('.js-ci-variable-input-value').set('protected_value')
      find('.ci-variable-protected-item .js-project-feature-toggle').click

      expect(find('.js-ci-variable-input-protected', visible: false).value).to eq('true')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    page.within('.js-ci-variable-list-section .js-row:nth-child(2)') do
      find('.ci-variable-protected-item .js-project-feature-toggle').click

      expect(find('.js-ci-variable-input-protected', visible: false).value).to eq('false')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    page.within('.js-ci-variable-list-section .js-row:nth-child(2)') do
      expect(find('.js-ci-variable-input-key').value).to eq('protected_key')
      expect(find('.js-ci-variable-input-value', visible: false).value).to eq('protected_value')
      expect(find('.js-ci-variable-input-protected', visible: false).value).to eq('false')
    end
  end

  it 'edits variable to be unmasked' do
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('unmasked_key')
      find('.js-ci-variable-input-value').set('unmasked_value')
      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('false')

      find('.ci-variable-masked-item .js-project-feature-toggle').click

      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('true')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    page.within('.js-ci-variable-list-section .js-row:nth-child(2)') do
      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('true')

      find('.ci-variable-masked-item .js-project-feature-toggle').click

      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('false')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    page.within('.js-ci-variable-list-section .js-row:nth-child(2)') do
      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('false')
    end
  end

  it 'edits variable to be masked' do
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('masked_key')
      find('.js-ci-variable-input-value').set('masked_value')
      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('false')

      find('.ci-variable-masked-item .js-project-feature-toggle').click

      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('true')
    end

    click_button('Save variables')
    wait_for_requests

    visit page_path

    page.within('.js-ci-variable-list-section .js-row:nth-child(2)') do
      expect(find('.js-ci-variable-input-masked', visible: false).value).to eq('true')
    end
  end

  it 'handles multiple edits and deletion in the middle' do
    page.within('.js-ci-variable-list-section') do
      # Create 2 variables
      page.within('.js-row:last-child') do
        find('.js-ci-variable-input-key').set('akey')
        find('.js-ci-variable-input-value').set('akeyvalue')
      end
      page.within('.js-row:last-child') do
        find('.js-ci-variable-input-key').set('zkey')
        find('.js-ci-variable-input-value').set('zkeyvalue')
      end

      click_button('Save variables')
      wait_for_requests

      expect(page).to have_selector('.js-row', count: 4)

      # Remove the `akey` variable
      page.within('.js-row:nth-child(3)') do
        first('.js-row-remove-button').click
      end

      # Add another variable
      page.within('.js-row:last-child') do
        find('.js-ci-variable-input-key').set('ckey')
        find('.js-ci-variable-input-value').set('ckeyvalue')
      end

      click_button('Save variables')
      wait_for_requests

      visit page_path

      # Expect to find 3 variables(4 rows) in alphbetical order
      expect(page).to have_selector('.js-row', count: 4)
      row_keys = all('.js-ci-variable-input-key')
      expect(row_keys[0].value).to eq('ckey')
      expect(row_keys[1].value).to eq('test_key')
      expect(row_keys[2].value).to eq('zkey')
      expect(row_keys[3].value).to eq('')
    end
  end

  it 'shows validation error box about duplicate keys' do
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('samekey')
      find('.js-ci-variable-input-value').set('value123')
    end
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('samekey')
      find('.js-ci-variable-input-value').set('value456')
    end

    click_button('Save variables')
    wait_for_requests

    expect(all('.js-ci-variable-list-section .js-ci-variable-error-box ul li').count).to eq(1)

    # We check the first row because it re-sorts to alphabetical order on refresh
    page.within('.js-ci-variable-list-section') do
      expect(find('.js-ci-variable-error-box')).to have_content(/Validation failed Variables have duplicate values \(.+\)/)
    end
  end

  it 'shows validation error box about masking empty values' do
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('empty_value')
      find('.js-ci-variable-input-value').set('')
      find('.ci-variable-masked-item .js-project-feature-toggle').click
    end

    click_button('Save variables')
    wait_for_requests

    page.within('.js-ci-variable-list-section') do
      expect(all('.js-ci-variable-error-box ul li').count).to eq(1)
      expect(find('.js-ci-variable-error-box')).to have_content(/Validation failed Variables value is invalid/)
    end
  end

  it 'shows validation error box about unmaskable values' do
    page.within('.js-ci-variable-list-section .js-row:last-child') do
      find('.js-ci-variable-input-key').set('unmaskable_value')
      find('.js-ci-variable-input-value').set('???')
      find('.ci-variable-masked-item .js-project-feature-toggle').click
    end

    click_button('Save variables')
    wait_for_requests

    page.within('.js-ci-variable-list-section') do
      expect(all('.js-ci-variable-error-box ul li').count).to eq(1)
      expect(find('.js-ci-variable-error-box')).to have_content(/Validation failed Variables value is invalid/)
    end
  end
end
