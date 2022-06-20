import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import OrganizationFormWrapper from '~/crm/organizations/components/organization_form_wrapper.vue';
import OrganizationForm from '~/crm/components/form.vue';
import getGroupOrganizationsQuery from '~/crm/organizations/components/graphql/get_group_organizations.query.graphql';
import createOrganizationMutation from '~/crm/organizations/components/graphql/create_organization.mutation.graphql';
import updateOrganizationMutation from '~/crm/organizations/components/graphql/update_organization.mutation.graphql';

describe('Customer relations organization form wrapper', () => {
  let wrapper;

  const findOrganizationForm = () => wrapper.findComponent(OrganizationForm);

  const $apollo = {
    queries: {
      organizations: {
        loading: false,
      },
    },
  };
  const $route = {
    params: {
      id: 7,
    },
  };
  const organizations = [{ id: 'gid://gitlab/CustomerRelations::Organization/7' }];

  const mountComponent = ({ isEditMode = false } = {}) => {
    wrapper = shallowMountExtended(OrganizationFormWrapper, {
      propsData: {
        isEditMode,
      },
      provide: {
        groupFullPath: 'flightjs',
        groupId: 26,
      },
      mocks: {
        $apollo,
        $route,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('in edit mode', () => {
    it('should render organization form with correct props', () => {
      mountComponent({ isEditMode: true });

      const organizationForm = findOrganizationForm();
      expect(organizationForm.props('fields')).toHaveLength(3);
      expect(organizationForm.props('title')).toBe('Edit organization');
      expect(organizationForm.props('successMessage')).toBe('Organization has been updated.');
      expect(organizationForm.props('mutation')).toBe(updateOrganizationMutation);
      expect(organizationForm.props('getQuery')).toMatchObject({
        query: getGroupOrganizationsQuery,
        variables: { groupFullPath: 'flightjs' },
      });
      expect(organizationForm.props('getQueryNodePath')).toBe('group.organizations');
      expect(organizationForm.props('existingId')).toBe(organizations[0].id);
      expect(organizationForm.props('additionalCreateParams')).toMatchObject({
        groupId: 'gid://gitlab/Group/26',
      });
    });
  });

  describe('in create mode', () => {
    it('should render organization form with correct props', () => {
      mountComponent();

      const organizationForm = findOrganizationForm();
      expect(organizationForm.props('fields')).toHaveLength(3);
      expect(organizationForm.props('title')).toBe('New organization');
      expect(organizationForm.props('successMessage')).toBe('Organization has been added.');
      expect(organizationForm.props('mutation')).toBe(createOrganizationMutation);
      expect(organizationForm.props('getQuery')).toMatchObject({
        query: getGroupOrganizationsQuery,
        variables: { groupFullPath: 'flightjs' },
      });
      expect(organizationForm.props('getQueryNodePath')).toBe('group.organizations');
      expect(organizationForm.props('existingId')).toBeNull();
      expect(organizationForm.props('additionalCreateParams')).toMatchObject({
        groupId: 'gid://gitlab/Group/26',
      });
    });
  });
});
