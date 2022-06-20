import { GROUP_BADGE } from '~/badges/constants';
import dirtySubmitFactory from '~/dirty_submit/dirty_submit_factory';
import initFilePickers from '~/file_pickers';
import initTransferGroupForm from '~/groups/init_transfer_group_form';
import groupsSelect from '~/groups_select';
import { initCascadingSettingsLockPopovers } from '~/namespaces/cascading_settings';
import mountBadgeSettings from '~/pages/shared/mount_badge_settings';
import projectSelect from '~/project_select';
import initSearchSettings from '~/search_settings';
import initSettingsPanels from '~/settings_panels';
import initConfirmDanger from '~/init_confirm_danger';

initFilePickers();
initConfirmDanger();
initSettingsPanels();
initTransferGroupForm();
dirtySubmitFactory(
  document.querySelectorAll('.js-general-settings-form, .js-general-permissions-form'),
);
mountBadgeSettings(GROUP_BADGE);

// Initialize Subgroups selector
groupsSelect();

projectSelect();

initSearchSettings();
initCascadingSettingsLockPopovers();
