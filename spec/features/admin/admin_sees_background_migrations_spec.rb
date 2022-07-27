# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Admin > Admin sees background migrations" do
  let_it_be(:admin) { create(:admin) }
  let(:job_class) { Gitlab::BackgroundMigration::CopyColumnUsingBackgroundMigrationJob }

  let_it_be(:active_migration) { create(:batched_background_migration, :active, table_name: 'active') }
  let_it_be(:failed_migration) { create(:batched_background_migration, :failed, table_name: 'failed', total_tuple_count: 100) }
  let_it_be(:finished_migration) { create(:batched_background_migration, :finished, table_name: 'finished') }

  before_all do
    create(:batched_background_migration_job, :failed, batched_migration: failed_migration, batch_size: 10, min_value: 6, max_value: 15, attempts: 3)
  end

  before do
    sign_in(admin)
    gitlab_enable_admin_mode_sign_in(admin)
  end

  it 'can navigate to background migrations' do
    visit admin_root_path

    within '.nav-sidebar' do
      link = find_link 'Background Migrations'

      link.click

      expect(page).to have_current_path(admin_background_migrations_path)
      expect(link).to have_ancestor(:css, 'li.active')
    end
  end

  it 'can click on a specific migration' do
    visit admin_background_migrations_path

    within '#content-body' do
      tab = find_link active_migration.job_class_name
      tab.click

      expect(page).to have_current_path admin_background_migration_path(active_migration)
    end
  end

  it 'can view failed jobs' do
    visit admin_background_migration_path(failed_migration)

    within '#content-body' do
      expect(page).to have_content('Failed jobs')
      expect(page).to have_content('Id')
      expect(page).to have_content('Started at')
      expect(page).to have_content('Finished at')
      expect(page).to have_content('Batch size')
    end
  end

  it 'can click on a specific job' do
    job = create(:batched_background_migration_job, :failed, batched_migration: failed_migration)

    visit admin_background_migration_path(failed_migration)

    within '#content-body' do
      tab = find_link job.id
      tab.click

      expect(page).to have_current_path admin_background_migration_batched_job_path(id: job.id, background_migration_id: failed_migration.id)
    end
  end

  context 'when there are no failed jobs' do
    it 'dos not display failed jobs' do
      visit admin_background_migration_path(active_migration)

      within '#content-body' do
        expect(page).not_to have_content('Failed jobs')
      end
    end
  end

  it 'can view queued migrations and pause and resume them' do
    visit admin_background_migrations_path

    within '#content-body' do
      expect(page).to have_selector('tbody tr', count: 1)

      expect(page).to have_content(active_migration.job_class_name)
      expect(page).to have_content(active_migration.table_name)
      expect(page).to have_content('0.00%')
      expect(page).not_to have_content('Paused')
      expect(page).to have_content('Active')

      click_button('Pause')
      expect(page).not_to have_content('Active')
      expect(page).to have_content('Paused')

      click_button('Resume')
      expect(page).not_to have_content('Paused')
      expect(page).to have_content('Active')
    end
  end

  context 'when there are failed migrations' do
    before do
      allow_next_instance_of(Gitlab::BackgroundMigration::BatchingStrategies::PrimaryKeyBatchingStrategy) do |batch_class|
        allow(batch_class).to receive(:next_batch).with(
          anything,
          anything,
          batch_min_value: 6,
          batch_size: 5,
          job_arguments: failed_migration.job_arguments,
          job_class: job_class
        ).and_return([6, 10])
      end
    end

    it 'can fire an action with a database param' do
      visit admin_background_migrations_path(database: 'main')

      within '#content-body' do
        tab = find_link 'Failed'
        tab.click

        expect(page).to have_selector("[method='post'][action='/admin/background_migrations/#{failed_migration.id}/retry?database=main']")
      end
    end

    it 'can view and retry them' do
      visit admin_background_migrations_path

      within '#content-body' do
        tab = find_link 'Failed'
        tab.click

        expect(page).to have_current_path(admin_background_migrations_path(tab: 'failed'))
        expect(tab[:class]).to include('gl-tab-nav-item-active')

        expect(page).to have_selector('tbody tr', count: 1)

        expect(page).to have_content(failed_migration.job_class_name)
        expect(page).to have_content(failed_migration.table_name)
        expect(page).to have_content('0.00%')
        expect(page).to have_content(failed_migration.status_name.to_s)

        click_button('Retry')
        expect(page).not_to have_content(failed_migration.job_class_name)
        expect(page).not_to have_content(failed_migration.table_name)
        expect(page).not_to have_content('0.00%')
      end
    end
  end

  it 'can view finished migrations' do
    visit admin_background_migrations_path

    within '#content-body' do
      tab = find_link 'Finished'
      tab.click

      expect(page).to have_current_path(admin_background_migrations_path(tab: 'finished'))
      expect(tab[:class]).to include('gl-tab-nav-item-active')

      expect(page).to have_selector('tbody tr', count: 1)

      expect(page).to have_content(finished_migration.job_class_name)
      expect(page).to have_content(finished_migration.table_name)
      expect(page).to have_content('100.00%')
      expect(page).to have_content(finished_migration.status_name.to_s)
    end
  end

  it 'can change tabs and retain database param' do
    skip_if_multiple_databases_not_setup

    visit admin_background_migrations_path(database: 'ci')

    within '#content-body' do
      tab = find_link 'Finished'
      expect(tab[:class]).not_to include('gl-tab-nav-item-active')

      tab.click

      expect(page).to have_current_path(admin_background_migrations_path(tab: 'finished', database: 'ci'))
      expect(tab[:class]).to include('gl-tab-nav-item-active')
    end
  end

  it 'can view documentation from Learn more link' do
    visit admin_background_migrations_path

    within '#content-body' do
      expect(page).to have_link('Learn more', href: help_page_path('development/database/batched_background_migrations'))
    end
  end

  describe 'selected database toggle', :js do
    context 'when multi database is not enabled' do
      before do
        skip_if_multiple_databases_are_setup

        allow(Gitlab::Database).to receive(:db_config_names).and_return(['main'])
      end

      it 'does not render the database listbox' do
        visit admin_background_migrations_path

        expect(page).not_to have_selector('[data-testid="database-listbox"]')
      end
    end

    context 'when multi database is enabled' do
      before do
        skip_if_multiple_databases_not_setup

        allow(Gitlab::Database).to receive(:db_config_names).and_return(%w[main ci])
      end

      it 'does render the database listbox' do
        visit admin_background_migrations_path

        expect(page).to have_selector('[data-testid="database-listbox"]')
      end

      it 'defaults to main when no parameter is passed' do
        visit admin_background_migrations_path

        listbox = page.find('[data-testid="database-listbox"]')

        expect(listbox).to have_text('main')
      end

      it 'shows correct database when a parameter is passed' do
        visit admin_background_migrations_path(database: 'ci')

        listbox = page.find('[data-testid="database-listbox"]')

        expect(listbox).to have_text('ci')
      end

      it 'updates the path to correct database when clicking on listbox option' do
        visit admin_background_migrations_path

        listbox = page.find('[data-testid="database-listbox"]')
        expect(listbox).to have_text('main')

        listbox.find('button').click
        listbox.find('li', text: 'ci').click
        wait_for_requests

        expect(page).to have_current_path(admin_background_migrations_path(database: 'ci'))
        listbox = page.find('[data-testid="database-listbox"]')
        expect(listbox).to have_text('ci')
      end
    end
  end
end
