import Members from 'ee_else_ce/members';
import memberExpirationDate from '../../../member_expiration_date';
import UsersSelect from '../../../users_select';
import groupsSelect from '../../../groups_select';

document.addEventListener('DOMContentLoaded', () => {
  memberExpirationDate('.js-access-expiration-date-groups');
  groupsSelect();
  memberExpirationDate();
  new Members(); // eslint-disable-line no-new
  new UsersSelect(); // eslint-disable-line no-new
});
