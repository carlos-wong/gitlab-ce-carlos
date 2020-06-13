import { shallowMount } from '@vue/test-utils';
import { GlLoadingIcon } from '@gitlab/ui';
import { mockTracking, triggerEvent } from 'helpers/tracking_helper';
import Component from '~/sidebar/components/assignees/assignee_title.vue';

describe('AssigneeTitle component', () => {
  let wrapper;

  const createComponent = props => {
    return shallowMount(Component, {
      propsData: {
        numberOfAssignees: 0,
        editable: false,
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('assignee title', () => {
    it('renders assignee', () => {
      wrapper = createComponent({
        numberOfAssignees: 1,
        editable: false,
      });

      expect(wrapper.vm.$el.innerText.trim()).toEqual('Assignee');
    });

    it('renders 2 assignees', () => {
      wrapper = createComponent({
        numberOfAssignees: 2,
        editable: false,
      });

      expect(wrapper.vm.$el.innerText.trim()).toEqual('2 Assignees');
    });
  });

  describe('gutter toggle', () => {
    it('does not show toggle by default', () => {
      wrapper = createComponent({
        numberOfAssignees: 2,
        editable: false,
      });

      expect(wrapper.vm.$el.querySelector('.gutter-toggle')).toBeNull();
    });

    it('shows toggle when showToggle is true', () => {
      wrapper = createComponent({
        numberOfAssignees: 2,
        editable: false,
        showToggle: true,
      });

      expect(wrapper.vm.$el.querySelector('.gutter-toggle')).toEqual(expect.any(Object));
    });
  });

  it('does not render spinner by default', () => {
    wrapper = createComponent({
      numberOfAssignees: 0,
      editable: false,
    });

    expect(wrapper.find(GlLoadingIcon).exists()).toBeFalsy();
  });

  it('renders spinner when loading', () => {
    wrapper = createComponent({
      loading: true,
      numberOfAssignees: 0,
      editable: false,
    });

    expect(wrapper.find(GlLoadingIcon).exists()).toBeTruthy();
  });

  it('does not render edit link when not editable', () => {
    wrapper = createComponent({
      numberOfAssignees: 0,
      editable: false,
    });

    expect(wrapper.vm.$el.querySelector('.edit-link')).toBeNull();
  });

  it('renders edit link when editable', () => {
    wrapper = createComponent({
      numberOfAssignees: 0,
      editable: true,
    });

    expect(wrapper.vm.$el.querySelector('.edit-link')).not.toBeNull();
  });

  it('tracks the event when edit is clicked', () => {
    wrapper = createComponent({
      numberOfAssignees: 0,
      editable: true,
    });

    const spy = mockTracking('_category_', wrapper.element, jest.spyOn);
    triggerEvent('.js-sidebar-dropdown-toggle');

    expect(spy).toHaveBeenCalledWith('_category_', 'click_edit_button', {
      label: 'right_sidebar',
      property: 'assignee',
    });
  });
});
