import { groupMemberRequestFormatter } from '~/groups/members/utils';
import initInviteGroupTrigger from '~/invite_members/init_invite_group_trigger';
import initInviteGroupsModal from '~/invite_members/init_invite_groups_modal';
import initInviteMembersModal from '~/invite_members/init_invite_members_modal';
import initInviteMembersTrigger from '~/invite_members/init_invite_members_trigger';
import { s__ } from '~/locale';
import { initMembersApp } from '~/members';
import { MEMBER_TYPES, EE_APP_OPTIONS } from 'ee_else_ce/members/constants';
import { groupLinkRequestFormatter } from '~/members/utils';

const SHARED_FIELDS = ['account', 'maxRole', 'expiration', 'actions'];
const APP_OPTIONS = {
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
    requestFormatter: groupMemberRequestFormatter,
    filteredSearchBar: {
      show: true,
      tokens: ['two_factor', 'with_inherited_permissions', 'enterprise'],
      searchParam: 'search',
      placeholder: s__('Members|Filter members'),
      recentSearchesStorageKey: 'group_members',
    },
  },
  [MEMBER_TYPES.group]: {
    tableFields: SHARED_FIELDS.concat(['source', 'granted']),
    tableAttrs: {
      table: { 'data-qa-selector': 'groups_list' },
      tr: { 'data-qa-selector': 'group_row' },
    },
    requestFormatter: groupLinkRequestFormatter,
    filteredSearchBar: {
      show: true,
      tokens: ['groups_with_inherited_permissions'],
      searchParam: 'search_groups',
      placeholder: s__('Members|Filter groups'),
      recentSearchesStorageKey: 'group_links_members',
    },
  },
  [MEMBER_TYPES.invite]: {
    tableFields: SHARED_FIELDS.concat('invited'),
    requestFormatter: groupMemberRequestFormatter,
    filteredSearchBar: {
      show: true,
      tokens: [],
      searchParam: 'search_invited',
      placeholder: s__('Members|Search invited'),
      recentSearchesStorageKey: 'group_invited_members',
    },
  },
  [MEMBER_TYPES.accessRequest]: {
    tableFields: SHARED_FIELDS.concat('requested'),
    requestFormatter: groupMemberRequestFormatter,
  },
  ...EE_APP_OPTIONS,
};

initMembersApp(document.querySelector('.js-group-members-list-app'), APP_OPTIONS);

initInviteMembersModal();
initInviteGroupsModal();
initInviteMembersTrigger();
initInviteGroupTrigger();
