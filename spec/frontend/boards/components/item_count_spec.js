import { shallowMount } from '@vue/test-utils';
import IssueCount from '~/boards/components/item_count.vue';

describe('IssueCount', () => {
  let vm;
  let maxIssueCount;
  let itemsSize;

  const createComponent = (props) => {
    vm = shallowMount(IssueCount, { propsData: props });
  };

  afterEach(() => {
    maxIssueCount = 0;
    itemsSize = 0;

    if (vm) vm.destroy();
  });

  describe('when maxIssueCount is zero', () => {
    beforeEach(() => {
      itemsSize = 3;

      createComponent({ maxIssueCount: 0, itemsSize });
    });

    it('contains issueSize in the template', () => {
      expect(vm.find('[data-testid="board-items-count"]').text()).toEqual(String(itemsSize));
    });

    it('does not contains maxIssueCount in the template', () => {
      expect(vm.find('.max-issue-size').exists()).toBe(false);
    });
  });

  describe('when maxIssueCount is greater than zero', () => {
    beforeEach(() => {
      maxIssueCount = 2;
      itemsSize = 1;

      createComponent({ maxIssueCount, itemsSize });
    });

    afterEach(() => {
      vm.destroy();
    });

    it('contains issueSize in the template', () => {
      expect(vm.find('[data-testid="board-items-count"]').text()).toEqual(String(itemsSize));
    });

    it('contains maxIssueCount in the template', () => {
      expect(vm.find('.max-issue-size').text()).toEqual(String(maxIssueCount));
    });

    it('does not have text-danger class when issueSize is less than maxIssueCount', () => {
      expect(vm.classes('.text-danger')).toBe(false);
    });
  });

  describe('when issueSize is greater than maxIssueCount', () => {
    beforeEach(() => {
      itemsSize = 3;
      maxIssueCount = 2;

      createComponent({ maxIssueCount, itemsSize });
    });

    afterEach(() => {
      vm.destroy();
    });

    it('contains issueSize in the template', () => {
      expect(vm.find('[data-testid="board-items-count"]').text()).toEqual(String(itemsSize));
    });

    it('contains maxIssueCount in the template', () => {
      expect(vm.find('.max-issue-size').text()).toEqual(String(maxIssueCount));
    });

    it('has text-danger class', () => {
      expect(vm.find('.text-danger').text()).toEqual(String(itemsSize));
    });
  });
});
