import $ from 'jquery';
import Pikaday from 'pikaday';
import dateFormat from 'dateformat';
import { __ } from '~/locale';
import axios from './lib/utils/axios_utils';
import { timeFor, parsePikadayDate, pikadayToString } from './lib/utils/datetime_utility';
import boardsStore from './boards/stores/boards_store';

class DueDateSelect {
  constructor({ $dropdown, $loading } = {}) {
    const $dropdownParent = $dropdown.closest('.dropdown');
    const $block = $dropdown.closest('.block');
    this.$loading = $loading;
    this.$dropdown = $dropdown;
    this.$dropdownParent = $dropdownParent;
    this.$datePicker = $dropdownParent.find('.js-due-date-calendar');
    this.$block = $block;
    this.$sidebarCollapsedValue = $block.find('.sidebar-collapsed-icon');
    this.$selectbox = $dropdown.closest('.selectbox');
    this.$value = $block.find('.value');
    this.$valueContent = $block.find('.value-content');
    this.$sidebarValue = $('.js-due-date-sidebar-value', $block);
    this.fieldName = $dropdown.data('fieldName');
    this.abilityName = $dropdown.data('abilityName');
    this.issueUpdateURL = $dropdown.data('issueUpdate');

    this.rawSelectedDate = null;
    this.displayedDate = null;
    this.datePayload = null;

    this.initGlDropdown();
    this.initRemoveDueDate();
    this.initDatePicker();
  }

  initGlDropdown() {
    this.$dropdown.glDropdown({
      opened: () => {
        const calendar = this.$datePicker.data('pikaday');
        calendar.show();
      },
      hidden: () => {
        this.$selectbox.hide();
        this.$value.css('display', '');
      },
    });
  }

  initDatePicker() {
    const $dueDateInput = $(`input[name='${this.fieldName}']`);
    const calendar = new Pikaday({
      field: $dueDateInput.get(0),
      theme: 'gitlab-theme',
      format: 'yyyy-mm-dd',
      parse: dateString => parsePikadayDate(dateString),
      toString: date => pikadayToString(date),
      onSelect: dateText => {
        $dueDateInput.val(calendar.toString(dateText));

        if (this.$dropdown.hasClass('js-issue-boards-due-date')) {
          boardsStore.detail.issue.dueDate = $dueDateInput.val();
          this.updateIssueBoardIssue();
        } else {
          this.saveDueDate(true);
        }
      },
      firstDay: gon.first_day_of_week,
    });

    calendar.setDate(parsePikadayDate($dueDateInput.val()));
    this.$datePicker.append(calendar.el);
    this.$datePicker.data('pikaday', calendar);
  }

  initRemoveDueDate() {
    this.$block.on('click', '.js-remove-due-date', e => {
      const calendar = this.$datePicker.data('pikaday');
      e.preventDefault();

      calendar.setDate(null);

      if (this.$dropdown.hasClass('js-issue-boards-due-date')) {
        boardsStore.detail.issue.dueDate = '';
        this.updateIssueBoardIssue();
      } else {
        $(`input[name='${this.fieldName}']`).val('');
        this.saveDueDate(false);
      }
    });
  }

  saveDueDate(isDropdown) {
    this.parseSelectedDate();
    this.prepSelectedDate();
    this.submitSelectedDate(isDropdown);
  }

  parseSelectedDate() {
    this.rawSelectedDate = $(`input[name='${this.fieldName}']`).val();

    if (this.rawSelectedDate.length) {
      // Construct Date object manually to avoid buggy dateString support within Date constructor
      const dateArray = this.rawSelectedDate.split('-').map(v => parseInt(v, 10));
      const dateObj = new Date(dateArray[0], dateArray[1] - 1, dateArray[2]);
      this.displayedDate = dateFormat(dateObj, 'mmm d, yyyy');
    } else {
      this.displayedDate = __('None');
    }
  }

  prepSelectedDate() {
    const datePayload = {};
    datePayload[this.abilityName] = {};
    datePayload[this.abilityName].due_date = this.rawSelectedDate;
    this.datePayload = datePayload;
  }

  updateIssueBoardIssue() {
    this.$loading.fadeIn();
    this.$dropdown.trigger('loading.gl.dropdown');
    this.$selectbox.hide();
    this.$value.css('display', '');
    const fadeOutLoader = () => {
      this.$loading.fadeOut();
    };

    boardsStore.detail.issue
      .update(this.$dropdown.attr('data-issue-update'))
      .then(fadeOutLoader)
      .catch(fadeOutLoader);
  }

  submitSelectedDate(isDropdown) {
    const selectedDateValue = this.datePayload[this.abilityName].due_date;
    const hasDueDate = this.displayedDate !== __('None');
    const displayedDateStyle = hasDueDate ? 'bold' : 'no-value';

    this.$loading.removeClass('hidden').fadeIn();

    if (isDropdown) {
      this.$dropdown.trigger('loading.gl.dropdown');
      this.$selectbox.hide();
    }

    this.$value.css('display', '');
    this.$valueContent.html(`<span class='${displayedDateStyle}'>${this.displayedDate}</span>`);
    this.$sidebarValue.html(this.displayedDate);

    $('.js-remove-due-date-holder').toggleClass('hidden', selectedDateValue.length);

    return axios.put(this.issueUpdateURL, this.datePayload).then(() => {
      const tooltipText = hasDueDate
        ? `${__('Due date')}<br />${selectedDateValue} (${timeFor(selectedDateValue)})`
        : __('Due date');
      if (isDropdown) {
        this.$dropdown.trigger('loaded.gl.dropdown');
        this.$dropdown.dropdown('toggle');
      }
      this.$sidebarCollapsedValue.attr('data-original-title', tooltipText);

      return this.$loading.fadeOut();
    });
  }
}

export default class DueDateSelectors {
  constructor() {
    this.initMilestoneDatePicker();
    this.initIssuableSelect();
  }
  // eslint-disable-next-line class-methods-use-this
  initMilestoneDatePicker() {
    $('.datepicker').each(function initPikadayMilestone() {
      const $datePicker = $(this);
      const datePickerVal = $datePicker.val();

      const calendar = new Pikaday({
        field: $datePicker.get(0),
        theme: 'gitlab-theme animate-picker',
        format: 'yyyy-mm-dd',
        container: $datePicker.parent().get(0),
        parse: dateString => parsePikadayDate(dateString),
        toString: date => pikadayToString(date),
        onSelect(dateText) {
          $datePicker.val(calendar.toString(dateText));
        },
        firstDay: gon.first_day_of_week,
      });

      calendar.setDate(parsePikadayDate(datePickerVal));

      $datePicker.data('pikaday', calendar);
    });

    $('.js-clear-due-date,.js-clear-start-date').on('click', e => {
      e.preventDefault();
      const calendar = $(e.target)
        .siblings('.datepicker')
        .data('pikaday');
      calendar.setDate(null);
    });
  }
  // eslint-disable-next-line class-methods-use-this
  initIssuableSelect() {
    const $loading = $('.js-issuable-update .due_date')
      .find('.block-loading')
      .hide();

    $('.js-due-date-select').each((i, dropdown) => {
      const $dropdown = $(dropdown);
      // eslint-disable-next-line no-new
      new DueDateSelect({
        $dropdown,
        $loading,
      });
    });
  }
}
