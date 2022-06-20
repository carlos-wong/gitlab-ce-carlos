import { __, s__ } from '~/locale';
import { OPERATOR_IS_ONLY } from '~/vue_shared/components/filtered_search_bar/constants';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { PARAM_KEY_PAUSED } from '../../constants';

const options = [
  { value: 'true', title: __('Yes') },
  { value: 'false', title: __('No') },
];

export const pausedTokenConfig = {
  icon: 'pause',
  title: s__('Runners|Paused'),
  type: PARAM_KEY_PAUSED,
  token: BaseToken,
  unique: true,
  options: options.map(({ value, title }) => ({
    value,
    // Replace whitespace with a special character to avoid
    // splitting this value.
    // Replacing in each option, as translations may also
    // contain spaces!
    // see: https://gitlab.com/gitlab-org/gitlab/-/issues/344142
    // see: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/1438
    title: title.replace(' ', '\u00a0'),
  })),
  operators: OPERATOR_IS_ONLY,
};
