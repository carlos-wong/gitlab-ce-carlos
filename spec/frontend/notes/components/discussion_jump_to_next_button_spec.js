import JumpToNextDiscussionButton from '~/notes/components/discussion_jump_to_next_button.vue';
import { shallowMount } from '@vue/test-utils';

describe('JumpToNextDiscussionButton', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMount(JumpToNextDiscussionButton, {
      sync: false,
    });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('matches the snapshot', () => {
    expect(wrapper.vm.$el).toMatchSnapshot();
  });

  it('emits onClick event on button click', () => {
    const button = wrapper.find({ ref: 'button' });

    button.trigger('click');

    expect(wrapper.emitted()).toEqual({
      onClick: [[]],
    });
  });
});
