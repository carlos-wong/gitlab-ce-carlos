import initImportAProjectModal from '~/invite_members/init_import_a_project_modal';
import initInviteGroupTrigger from '~/invite_members/init_invite_group_trigger';
import initInviteMembersModal from '~/invite_members/init_invite_members_modal';
import initInviteGroupsModal from '~/invite_members/init_invite_groups_modal';
import initInviteMembersTrigger from '~/invite_members/init_invite_members_trigger';
import { s__ } from '~/locale';
import { initMembersApp } from '~/members';
import { MEMBER_TYPES } from '~/members/constants';
import { groupLinkRequestFormatter } from '~/members/utils';
import { projectMemberRequestFormatter } from '~/projects/members/utils';

initImportAProjectModal();
initInviteMembersModal();
initInviteGroupsModal();
initInviteMembersTrigger();
initInviteGroupTrigger();

const SHARED_FIELDS = ['account', 'maxRole', 'expiration', 'actions'];
initMembersApp(document.querySelector('.js-project-members-list-app'), {
  [MEMBER_TYPES.user]: {
    tableFields: SHARED_FIELDS.concat(['source', 'granted', 'userCreatedAt', 'lastActivityOn']),
    tableAttrs: { tr: { 'data-qa-selector': 'member_row' } },
    tableSortableFields: [
      'account',
      'granted',
      'maxRole',
      'lastSignIn',
      'userCreatedAt',
      'lastActivityOn',
    ],
    requestFormatter: projectMemberRequestFormatter,
    filteredSearchBar: {
      show: true,
      tokens: ['with_inherited_permissions'],
      searchParam: 'search',
      placeholder: s__('Members|Filter members'),
      recentSearchesStorageKey: 'project_members',
    },
  },
  [MEMBER_TYPES.group]: {
    tableFields: SHARED_FIELDS.concat('granted'),
    tableAttrs: {
      table: { 'data-qa-selector': 'groups_list' },
      tr: { 'data-qa-selector': 'group_row' },
    },
    requestFormatter: groupLinkRequestFormatter,
    filteredSearchBar: {
      show: true,
      tokens: [],
      searchParam: 'search_groups',
      placeholder: s__('Members|Search groups'),
      recentSearchesStorageKey: 'project_group_links',
    },
  },
  [MEMBER_TYPES.invite]: {
    tableFields: SHARED_FIELDS.concat('invited'),
    requestFormatter: projectMemberRequestFormatter,
  },
  [MEMBER_TYPES.accessRequest]: {
    tableFields: SHARED_FIELDS.concat('requested'),
    requestFormatter: projectMemberRequestFormatter,
  },
});
