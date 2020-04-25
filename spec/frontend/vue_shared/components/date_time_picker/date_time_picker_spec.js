import { mount } from '@vue/test-utils';
import DateTimePicker from '~/vue_shared/components/date_time_picker/date_time_picker.vue';
import {
  defaultTimeRanges,
  defaultTimeRange,
} from '~/vue_shared/components/date_time_picker/date_time_picker_lib';

const optionsCount = defaultTimeRanges.length;

describe('DateTimePicker', () => {
  let dateTimePicker;

  const dropdownToggle = () => dateTimePicker.find('.dropdown-toggle');
  const dropdownMenu = () => dateTimePicker.find('.dropdown-menu');
  const applyButtonElement = () => dateTimePicker.find('button.btn-success').element;
  const findQuickRangeItems = () => dateTimePicker.findAll('.dropdown-item');
  const cancelButtonElement = () => dateTimePicker.find('button.btn-secondary').element;

  const createComponent = props => {
    dateTimePicker = mount(DateTimePicker, {
      propsData: {
        ...props,
      },
    });
  };

  afterEach(() => {
    dateTimePicker.destroy();
  });

  it('renders dropdown toggle button with selected text', done => {
    createComponent();
    dateTimePicker.vm.$nextTick(() => {
      expect(dropdownToggle().text()).toBe(defaultTimeRange.label);
      done();
    });
  });

  it('renders dropdown with 2 custom time range inputs', () => {
    createComponent();
    dateTimePicker.vm.$nextTick(() => {
      expect(dateTimePicker.findAll('input').length).toBe(2);
    });
  });

  it('renders inputs with h/m/s truncated if its all 0s', done => {
    createComponent({
      value: {
        start: '2019-10-10T00:00:00.000Z',
        end: '2019-10-14T00:10:00.000Z',
      },
    });
    dateTimePicker.vm.$nextTick(() => {
      expect(dateTimePicker.find('#custom-time-from').element.value).toBe('2019-10-10');
      expect(dateTimePicker.find('#custom-time-to').element.value).toBe('2019-10-14 00:10:00');
      done();
    });
  });

  it(`renders dropdown with ${optionsCount} (default) items in quick range`, done => {
    createComponent();
    dropdownToggle().trigger('click');
    dateTimePicker.vm.$nextTick(() => {
      expect(findQuickRangeItems().length).toBe(optionsCount);
      done();
    });
  });

  it('renders dropdown with a default quick range item selected', done => {
    createComponent();
    dropdownToggle().trigger('click');
    dateTimePicker.vm.$nextTick(() => {
      expect(dateTimePicker.find('.dropdown-item.active').exists()).toBe(true);
      expect(dateTimePicker.find('.dropdown-item.active').text()).toBe(defaultTimeRange.label);
      done();
    });
  });

  it('renders a disabled apply button on wrong input', () => {
    createComponent({
      start: 'invalid-input-date',
    });

    expect(applyButtonElement().getAttribute('disabled')).toBe('disabled');
  });

  describe('user input', () => {
    const fillInputAndBlur = (input, val) => {
      dateTimePicker.find(input).setValue(val);
      return dateTimePicker.vm.$nextTick().then(() => {
        dateTimePicker.find(input).trigger('blur');
        return dateTimePicker.vm.$nextTick();
      });
    };

    beforeEach(done => {
      createComponent();
      dateTimePicker.vm.$nextTick(done);
    });

    it('displays inline error message if custom time range inputs are invalid', done => {
      fillInputAndBlur('#custom-time-from', '2019-10-01abc')
        .then(() => fillInputAndBlur('#custom-time-to', '2019-10-10abc'))
        .then(() => {
          expect(dateTimePicker.findAll('.invalid-feedback').length).toBe(2);
          done();
        })
        .catch(done);
    });

    it('keeps apply button disabled with invalid custom time range inputs', done => {
      fillInputAndBlur('#custom-time-from', '2019-10-01abc')
        .then(() => fillInputAndBlur('#custom-time-to', '2019-09-19'))
        .then(() => {
          expect(applyButtonElement().getAttribute('disabled')).toBe('disabled');
          done();
        })
        .catch(done);
    });

    it('enables apply button with valid custom time range inputs', done => {
      fillInputAndBlur('#custom-time-from', '2019-10-01')
        .then(() => fillInputAndBlur('#custom-time-to', '2019-10-19'))
        .then(() => {
          expect(applyButtonElement().getAttribute('disabled')).toBeNull();
          done();
        })
        .catch(done.fail);
    });

    it('emits dates in an object when apply is clicked', done => {
      fillInputAndBlur('#custom-time-from', '2019-10-01')
        .then(() => fillInputAndBlur('#custom-time-to', '2019-10-19'))
        .then(() => {
          applyButtonElement().click();

          expect(dateTimePicker.emitted().input).toHaveLength(1);
          expect(dateTimePicker.emitted().input[0]).toEqual([
            {
              end: '2019-10-19T00:00:00Z',
              start: '2019-10-01T00:00:00Z',
            },
          ]);
          done();
        })
        .catch(done.fail);
    });

    it('unchecks quick range when text is input is clicked', done => {
      const findActiveItems = () => findQuickRangeItems().filter(w => w.is('.active'));

      expect(findActiveItems().length).toBe(1);

      fillInputAndBlur('#custom-time-from', '2019-10-01')
        .then(() => {
          expect(findActiveItems().length).toBe(0);

          done();
        })
        .catch(done.fail);
    });

    it('emits dates in an object when a  is clicked', () => {
      findQuickRangeItems()
        .at(3) // any item
        .trigger('click');

      expect(dateTimePicker.emitted().input).toHaveLength(1);
      expect(dateTimePicker.emitted().input[0][0]).toMatchObject({
        duration: {
          seconds: expect.any(Number),
        },
      });
    });

    it('hides the popover with cancel button', done => {
      dropdownToggle().trigger('click');

      dateTimePicker.vm.$nextTick(() => {
        cancelButtonElement().click();

        dateTimePicker.vm.$nextTick(() => {
          expect(dropdownMenu().classes('show')).toBe(false);
          done();
        });
      });
    });
  });

  describe('when using non-default time windows', () => {
    const MOCK_NOW = Date.UTC(2020, 0, 23, 20);

    const otherTimeRanges = [
      {
        label: '1 minute',
        duration: { seconds: 60 },
      },
      {
        label: '2 minutes',
        duration: { seconds: 60 * 2 },
        default: true,
      },
      {
        label: '5 minutes',
        duration: { seconds: 60 * 5 },
      },
    ];

    beforeEach(() => {
      jest.spyOn(Date, 'now').mockImplementation(() => MOCK_NOW);
    });

    it('renders dropdown with a label in the quick range', done => {
      createComponent({
        value: {
          duration: { seconds: 60 * 5 },
        },
        options: otherTimeRanges,
      });
      dropdownToggle().trigger('click');
      dateTimePicker.vm.$nextTick(() => {
        expect(dropdownToggle().text()).toBe('5 minutes');

        done();
      });
    });

    it('renders dropdown with quick range items', done => {
      createComponent({
        value: {
          duration: { seconds: 60 * 2 },
        },
        options: otherTimeRanges,
      });
      dropdownToggle().trigger('click');
      dateTimePicker.vm.$nextTick(() => {
        const items = findQuickRangeItems();

        expect(items.length).toBe(Object.keys(otherTimeRanges).length);
        expect(items.at(0).text()).toBe('1 minute');
        expect(items.at(0).is('.active')).toBe(false);

        expect(items.at(1).text()).toBe('2 minutes');
        expect(items.at(1).is('.active')).toBe(true);

        expect(items.at(2).text()).toBe('5 minutes');
        expect(items.at(2).is('.active')).toBe(false);

        done();
      });
    });

    it('renders dropdown with a label not in the quick range', done => {
      createComponent({
        value: {
          duration: { seconds: 60 * 4 },
        },
      });
      dropdownToggle().trigger('click');
      dateTimePicker.vm.$nextTick(() => {
        expect(dropdownToggle().text()).toBe('2020-01-23 19:56:00 to 2020-01-23 20:00:00');

        done();
      });
    });
  });
});
