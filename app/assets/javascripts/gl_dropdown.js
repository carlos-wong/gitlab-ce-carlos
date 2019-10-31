/* eslint-disable func-names, no-underscore-dangle, no-var, one-var, vars-on-top, no-shadow, no-cond-assign, no-return-assign, no-else-return, camelcase, no-lonely-if, guard-for-in, no-restricted-syntax, consistent-return, no-param-reassign, no-loop-func */

import $ from 'jquery';
import _ from 'underscore';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import axios from './lib/utils/axios_utils';
import { visitUrl } from './lib/utils/url_utility';
import { isObject } from './lib/utils/type_utility';
import renderItem from './gl_dropdown/render';

var GitLabDropdown, GitLabDropdownFilter, GitLabDropdownRemote, GitLabDropdownInput;

GitLabDropdownInput = (function() {
  function GitLabDropdownInput(input, options) {
    var $inputContainer, $clearButton;
    var _this = this;
    this.input = input;
    this.options = options;
    this.fieldName = this.options.fieldName || 'field-name';
    $inputContainer = this.input.parent();
    $clearButton = $inputContainer.find('.js-dropdown-input-clear');
    $clearButton.on(
      'click',
      (function(_this) {
        // Clear click
        return function(e) {
          e.preventDefault();
          e.stopPropagation();
          return _this.input
            .val('')
            .trigger('input')
            .focus();
        };
      })(this),
    );

    this.input
      .on('keydown', e => {
        var keyCode = e.which;
        if (keyCode === 13 && !options.elIsInput) {
          e.preventDefault();
        }
      })
      .on('input', e => {
        var val = e.currentTarget.value || _this.options.inputFieldName;
        val = val
          .split(' ')
          .join('-') // replaces space with dash
          .replace(/[^a-zA-Z0-9 -]/g, '')
          .toLowerCase() // replace non alphanumeric
          .replace(/(-)\1+/g, '-'); // replace repeated dashes
        _this.cb(_this.options.fieldName, val, {}, true);
        _this.input
          .closest('.dropdown')
          .find('.dropdown-toggle-text')
          .text(val);
      });
  }

  GitLabDropdownInput.prototype.onInput = function(cb) {
    this.cb = cb;
  };

  return GitLabDropdownInput;
})();

GitLabDropdownFilter = (function() {
  var BLUR_KEYCODES, HAS_VALUE_CLASS;

  BLUR_KEYCODES = [27, 40];

  HAS_VALUE_CLASS = 'has-value';

  function GitLabDropdownFilter(input, options) {
    var $clearButton, $inputContainer, ref, timeout;
    this.input = input;
    this.options = options;
    this.filterInputBlur = (ref = this.options.filterInputBlur) != null ? ref : true;
    $inputContainer = this.input.parent();
    $clearButton = $inputContainer.find('.js-dropdown-input-clear');
    $clearButton.on(
      'click',
      (function(_this) {
        // Clear click
        return function(e) {
          e.preventDefault();
          e.stopPropagation();
          return _this.input
            .val('')
            .trigger('input')
            .focus();
        };
      })(this),
    );
    // Key events
    timeout = '';
    this.input
      .on('keydown', e => {
        var keyCode = e.which;
        if (keyCode === 13 && !options.elIsInput) {
          e.preventDefault();
        }
      })
      .on('input', () => {
        if (this.input.val() !== '' && !$inputContainer.hasClass(HAS_VALUE_CLASS)) {
          $inputContainer.addClass(HAS_VALUE_CLASS);
        } else if (this.input.val() === '' && $inputContainer.hasClass(HAS_VALUE_CLASS)) {
          $inputContainer.removeClass(HAS_VALUE_CLASS);
        }
        // Only filter asynchronously only if option remote is set
        if (this.options.remote) {
          clearTimeout(timeout);
          return (timeout = setTimeout(() => {
            $inputContainer.parent().addClass('is-loading');

            return this.options.query(this.input.val(), data => {
              $inputContainer.parent().removeClass('is-loading');
              return this.options.callback(data);
            });
          }, 250));
        } else {
          return this.filter(this.input.val());
        }
      });
  }

  GitLabDropdownFilter.prototype.shouldBlur = function(keyCode) {
    return BLUR_KEYCODES.indexOf(keyCode) !== -1;
  };

  GitLabDropdownFilter.prototype.filter = function(search_text) {
    var data, elements, group, key, results, tmp;
    if (this.options.onFilter) {
      this.options.onFilter(search_text);
    }
    data = this.options.data();
    if (data != null && !this.options.filterByText) {
      results = data;
      if (search_text !== '') {
        // When data is an array of objects therefore [object Array] e.g.
        // [
        //   { prop: 'foo' },
        //   { prop: 'baz' }
        // ]
        if (_.isArray(data)) {
          results = fuzzaldrinPlus.filter(data, search_text, {
            key: this.options.keys,
          });
        } else {
          // If data is grouped therefore an [object Object]. e.g.
          // {
          //   groupName1: [
          //     { prop: 'foo' },
          //     { prop: 'baz' }
          //   ],
          //   groupName2: [
          //     { prop: 'abc' },
          //     { prop: 'def' }
          //   ]
          // }
          if (isObject(data)) {
            results = {};
            for (key in data) {
              group = data[key];
              tmp = fuzzaldrinPlus.filter(group, search_text, {
                key: this.options.keys,
              });
              if (tmp.length) {
                results[key] = tmp.map(item => item);
              }
            }
          }
        }
      }
      return this.options.callback(results);
    } else {
      elements = this.options.elements();
      if (search_text) {
        elements.each(function() {
          var $el, matches;
          $el = $(this);
          matches = fuzzaldrinPlus.match($el.text().trim(), search_text);
          if (!$el.is('.dropdown-header')) {
            if (matches.length) {
              return $el.show().removeClass('option-hidden');
            } else {
              return $el.hide().addClass('option-hidden');
            }
          }
        });
      } else {
        elements.show().removeClass('option-hidden');
      }

      elements
        .parent()
        .find('.dropdown-menu-empty-item')
        .toggleClass('hidden', elements.is(':visible'));
    }
  };

  return GitLabDropdownFilter;
})();

GitLabDropdownRemote = (function() {
  function GitLabDropdownRemote(dataEndpoint, options) {
    this.dataEndpoint = dataEndpoint;
    this.options = options;
  }

  GitLabDropdownRemote.prototype.execute = function() {
    if (typeof this.dataEndpoint === 'string') {
      return this.fetchData();
    } else if (typeof this.dataEndpoint === 'function') {
      if (this.options.beforeSend) {
        this.options.beforeSend();
      }
      return this.dataEndpoint(
        '',
        (function(_this) {
          // Fetch the data by calling the data funcfion
          return function(data) {
            if (_this.options.success) {
              _this.options.success(data);
            }
            if (_this.options.beforeSend) {
              return _this.options.beforeSend();
            }
          };
        })(this),
      );
    }
  };

  GitLabDropdownRemote.prototype.fetchData = function() {
    if (this.options.beforeSend) {
      this.options.beforeSend();
    }

    // Fetch the data through ajax if the data is a string
    return axios.get(this.dataEndpoint).then(({ data }) => {
      if (this.options.success) {
        return this.options.success(data);
      }
    });
  };

  return GitLabDropdownRemote;
})();

GitLabDropdown = (function() {
  var ACTIVE_CLASS,
    FILTER_INPUT,
    NO_FILTER_INPUT,
    INDETERMINATE_CLASS,
    LOADING_CLASS,
    PAGE_TWO_CLASS,
    NON_SELECTABLE_CLASSES,
    SELECTABLE_CLASSES,
    CURSOR_SELECT_SCROLL_PADDING,
    currentIndex;

  LOADING_CLASS = 'is-loading';

  PAGE_TWO_CLASS = 'is-page-two';

  ACTIVE_CLASS = 'is-active';

  INDETERMINATE_CLASS = 'is-indeterminate';

  currentIndex = -1;

  NON_SELECTABLE_CLASSES = '.divider, .separator, .dropdown-header, .dropdown-menu-empty-item';

  SELECTABLE_CLASSES = `.dropdown-content li:not(${NON_SELECTABLE_CLASSES}, .option-hidden)`;

  CURSOR_SELECT_SCROLL_PADDING = 5;

  FILTER_INPUT = '.dropdown-input .dropdown-input-field:not(.dropdown-no-filter)';

  NO_FILTER_INPUT = '.dropdown-input .dropdown-input-field.dropdown-no-filter';

  function GitLabDropdown(el1, options) {
    var searchFields, selector, self;
    this.el = el1;
    this.options = options;
    this.updateLabel = this.updateLabel.bind(this);
    this.hidden = this.hidden.bind(this);
    this.opened = this.opened.bind(this);
    this.shouldPropagate = this.shouldPropagate.bind(this);
    self = this;
    selector = $(this.el).data('target');
    this.dropdown = selector != null ? $(selector) : $(this.el).parent();
    // Set Defaults
    this.filterInput = this.options.filterInput || this.getElement(FILTER_INPUT);
    this.noFilterInput = this.options.noFilterInput || this.getElement(NO_FILTER_INPUT);
    this.highlight = Boolean(this.options.highlight);
    this.icon = Boolean(this.options.icon);
    this.filterInputBlur =
      this.options.filterInputBlur != null ? this.options.filterInputBlur : true;
    // If no input is passed create a default one
    self = this;
    // If selector was passed
    if (_.isString(this.filterInput)) {
      this.filterInput = this.getElement(this.filterInput);
    }
    searchFields = this.options.search ? this.options.search.fields : [];
    if (this.options.data) {
      // If we provided data
      // data could be an array of objects or a group of arrays
      if (_.isObject(this.options.data) && !_.isFunction(this.options.data)) {
        this.fullData = this.options.data;
        currentIndex = -1;
        this.parseData(this.options.data);
        this.focusTextInput();
      } else {
        this.remote = new GitLabDropdownRemote(this.options.data, {
          dataType: this.options.dataType,
          beforeSend: this.toggleLoading.bind(this),
          success: (function(_this) {
            return function(data) {
              _this.fullData = data;
              _this.parseData(_this.fullData);
              _this.focusTextInput();

              // Update dropdown position since remote data may have changed dropdown size
              _this.dropdown.find('.dropdown-menu-toggle').dropdown('update');

              if (
                _this.options.filterable &&
                _this.filter &&
                _this.filter.input &&
                _this.filter.input.val() &&
                _this.filter.input.val().trim() !== ''
              ) {
                return _this.filter.input.trigger('input');
              }
            };
            // Remote data
          })(this),
          instance: this,
        });
      }
    }
    if (this.noFilterInput.length) {
      this.plainInput = new GitLabDropdownInput(this.noFilterInput, this.options);
      this.plainInput.onInput(this.addInput.bind(this));
    }
    // Init filterable
    if (this.options.filterable) {
      this.filter = new GitLabDropdownFilter(this.filterInput, {
        elIsInput: $(this.el).is('input'),
        filterInputBlur: this.filterInputBlur,
        filterByText: this.options.filterByText,
        onFilter: this.options.onFilter,
        remote: this.options.filterRemote,
        query: this.options.data,
        keys: searchFields,
        instance: this,
        elements: (function(_this) {
          return function() {
            selector = `.dropdown-content li:not(${NON_SELECTABLE_CLASSES})`;
            if (_this.dropdown.find('.dropdown-toggle-page').length) {
              selector = `.dropdown-page-one ${selector}`;
            }
            return $(selector, this.instance.dropdown);
          };
        })(this),
        data: (function(_this) {
          return function() {
            return _this.fullData;
          };
        })(this),
        callback: (function(_this) {
          return function(data) {
            _this.parseData(data);
            if (_this.filterInput.val() !== '') {
              selector = SELECTABLE_CLASSES;
              if (_this.dropdown.find('.dropdown-toggle-page').length) {
                selector = `.dropdown-page-one ${selector}`;
              }
              if ($(_this.el).is('input')) {
                currentIndex = -1;
              } else {
                $(selector, _this.dropdown)
                  .first()
                  .find('a')
                  .addClass('is-focused');
                currentIndex = 0;
              }
            }
          };
        })(this),
      });
    }
    // Event listeners
    this.dropdown.on('shown.bs.dropdown', this.opened);
    this.dropdown.on('hidden.bs.dropdown', this.hidden);
    $(this.el).on('update.label', this.updateLabel);
    this.dropdown.on('click', '.dropdown-menu, .dropdown-menu-close', this.shouldPropagate);
    this.dropdown.on(
      'keyup',
      (function(_this) {
        return function(e) {
          // Escape key
          if (e.which === 27) {
            return $('.dropdown-menu-close', _this.dropdown).trigger('click');
          }
        };
      })(this),
    );
    this.dropdown.on(
      'blur',
      'a',
      (function(_this) {
        return function(e) {
          var $dropdownMenu, $relatedTarget;
          if (e.relatedTarget != null) {
            $relatedTarget = $(e.relatedTarget);
            $dropdownMenu = $relatedTarget.closest('.dropdown-menu');
            if ($dropdownMenu.length === 0) {
              return _this.dropdown.removeClass('show');
            }
          }
        };
      })(this),
    );
    if (this.dropdown.find('.dropdown-toggle-page').length) {
      this.dropdown.find('.dropdown-toggle-page, .dropdown-menu-back').on(
        'click',
        (function(_this) {
          return function(e) {
            e.preventDefault();
            e.stopPropagation();
            return _this.togglePage();
          };
        })(this),
      );
    }
    if (this.options.selectable) {
      selector = '.dropdown-content a';
      if (this.dropdown.find('.dropdown-toggle-page').length) {
        selector = '.dropdown-page-one .dropdown-content a';
      }
      this.dropdown.on('click', selector, e => {
        var $el, selected, selectedObj, isMarking;
        $el = $(e.currentTarget);
        selected = self.rowClicked($el);
        selectedObj = selected ? selected[0] : null;
        isMarking = selected ? selected[1] : null;
        if (this.options.clicked) {
          this.options.clicked.call(this, {
            selectedObj,
            $el,
            e,
            isMarking,
          });
        }

        // Update label right after all modifications in dropdown has been done
        if (this.options.toggleLabel) {
          this.updateLabel(selectedObj, $el, this);
        }

        $el.trigger('blur');
      });
    }
  }

  // Finds an element inside wrapper element
  GitLabDropdown.prototype.getElement = function(selector) {
    return this.dropdown.find(selector);
  };

  GitLabDropdown.prototype.toggleLoading = function() {
    return $('.dropdown-menu', this.dropdown).toggleClass(LOADING_CLASS);
  };

  GitLabDropdown.prototype.togglePage = function() {
    var menu;
    menu = $('.dropdown-menu', this.dropdown);
    if (menu.hasClass(PAGE_TWO_CLASS)) {
      if (this.remote) {
        this.remote.execute();
      }
    }
    menu.toggleClass(PAGE_TWO_CLASS);
    // Focus first visible input on active page
    return this.dropdown.find('[class^="dropdown-page-"]:visible :text:visible:first').focus();
  };

  GitLabDropdown.prototype.parseData = function(data) {
    var full_html, groupData, html, name;
    this.renderedData = data;
    if (this.options.filterable && data.length === 0) {
      // render no matching results
      html = [this.noResults()];
    } else {
      // Handle array groups
      if (isObject(data)) {
        html = [];
        for (name in data) {
          groupData = data[name];
          html.push(
            this.renderItem(
              {
                content: name,
                type: 'header',
              },
              name,
            ),
          );
          this.renderData(groupData, name).map(item => html.push(item));
        }
      } else {
        // Render each row
        html = this.renderData(data);
      }
    }
    // Render the full menu
    full_html = this.renderMenu(html);
    return this.appendMenu(full_html);
  };

  GitLabDropdown.prototype.renderData = function(data, group) {
    return data.map((obj, index) => this.renderItem(obj, group || false, index));
  };

  GitLabDropdown.prototype.shouldPropagate = function(e) {
    var $target;
    if (this.options.multiSelect || this.options.shouldPropagate === false) {
      $target = $(e.target);
      if (
        $target &&
        !$target.hasClass('dropdown-menu-close') &&
        !$target.hasClass('dropdown-menu-close-icon') &&
        !$target.data('isLink')
      ) {
        e.stopPropagation();

        // This prevents automatic scrolling to the top
        if ($target.closest('a').length) {
          return false;
        }
      }

      return true;
    }
  };

  GitLabDropdown.prototype.filteredFullData = function() {
    return this.fullData.filter(
      r =>
        typeof r === 'object' &&
        !Object.prototype.hasOwnProperty.call(r, 'beforeDivider') &&
        !Object.prototype.hasOwnProperty.call(r, 'header'),
    );
  };

  GitLabDropdown.prototype.opened = function(e) {
    var contentHtml;
    this.resetRows();
    this.addArrowKeyEvent();

    const dropdownToggle = this.dropdown.find('.dropdown-menu-toggle');
    const hasFilterBulkUpdate = dropdownToggle.hasClass('js-filter-bulk-update');
    const shouldRefreshOnOpen = dropdownToggle.hasClass('js-gl-dropdown-refresh-on-open');
    const hasMultiSelect = dropdownToggle.hasClass('js-multiselect');

    // Makes indeterminate items effective
    if (this.fullData && (shouldRefreshOnOpen || hasFilterBulkUpdate)) {
      this.parseData(this.fullData);
    }

    // Process the data to make sure rendered data
    // matches the correct layout
    const inputValue = this.filterInput.val();
    if (this.fullData && hasMultiSelect && this.options.processData && inputValue.length === 0) {
      this.options.processData.call(
        this.options,
        inputValue,
        this.filteredFullData(),
        this.parseData.bind(this),
      );
    }

    contentHtml = $('.dropdown-content', this.dropdown).html();
    if (this.remote && contentHtml === '') {
      this.remote.execute();
    } else {
      this.focusTextInput();
    }

    if (this.options.showMenuAbove) {
      this.positionMenuAbove();
    }

    if (this.options.opened) {
      if (this.options.preserveContext) {
        this.options.opened(e);
      } else {
        this.options.opened.call(this, e);
      }
    }

    return this.dropdown.trigger('shown.gl.dropdown');
  };

  GitLabDropdown.prototype.positionMenuAbove = function() {
    var $menu = this.dropdown.find('.dropdown-menu');

    $menu.addClass('dropdown-open-top');
    $menu.css('top', 'initial');
    $menu.css('bottom', '100%');
  };

  GitLabDropdown.prototype.hidden = function(e) {
    var $input;
    this.resetRows();
    this.removeArrayKeyEvent();
    $input = this.dropdown.find('.dropdown-input-field');
    if (this.options.filterable) {
      $input.blur();
    }
    if (this.dropdown.find('.dropdown-toggle-page').length) {
      $('.dropdown-menu', this.dropdown).removeClass(PAGE_TWO_CLASS);
    }
    if (this.options.hidden) {
      this.options.hidden.call(this, e);
    }
    return this.dropdown.trigger('hidden.gl.dropdown');
  };

  // Render the full menu
  GitLabDropdown.prototype.renderMenu = function(html) {
    if (this.options.renderMenu) {
      return this.options.renderMenu(html);
    } else {
      return $('<ul>').append(html);
    }
  };

  // Append the menu into the dropdown
  GitLabDropdown.prototype.appendMenu = function(html) {
    return this.clearMenu().append(html);
  };

  GitLabDropdown.prototype.clearMenu = function() {
    var selector;
    selector = '.dropdown-content';
    if (this.dropdown.find('.dropdown-toggle-page').length) {
      if (this.options.containerSelector) {
        selector = this.options.containerSelector;
      } else {
        selector = '.dropdown-page-one .dropdown-content';
      }
    }

    return $(selector, this.dropdown).empty();
  };

  GitLabDropdown.prototype.renderItem = function(data, group, index) {
    let parent;

    if (this.dropdown && this.dropdown[0]) {
      parent = this.dropdown[0].parentNode;
    }

    return renderItem({
      instance: this,
      options: Object.assign({}, this.options, {
        icon: this.icon,
        highlight: this.highlight,
        highlightText: text => this.highlightTextMatches(text, this.filterInput.val()),
        highlightTemplate: this.highlightTemplate.bind(this),
        parent,
      }),
      data,
      group,
      index,
    });
  };

  GitLabDropdown.prototype.highlightTemplate = function(text, template) {
    return `"<b>${_.escape(text)}</b>" ${template}`;
  };

  GitLabDropdown.prototype.highlightTextMatches = function(text, term) {
    const occurrences = fuzzaldrinPlus.match(text, term);
    const { indexOf } = [];

    return text
      .split('')
      .map((character, i) => {
        if (indexOf.call(occurrences, i) !== -1) {
          return `<b>${character}</b>`;
        } else {
          return character;
        }
      })
      .join('');
  };

  GitLabDropdown.prototype.noResults = function() {
    return '<li class="dropdown-menu-empty-item"><a>No matching results</a></li>';
  };

  GitLabDropdown.prototype.rowClicked = function(el) {
    var field, groupName, isInput, selectedIndex, selectedObject, value, isMarking;

    const { fieldName } = this.options;
    isInput = $(this.el).is('input');
    if (this.renderedData) {
      groupName = el.data('group');
      if (groupName) {
        selectedIndex = el.data('index');
        selectedObject = this.renderedData[groupName][selectedIndex];
      } else {
        selectedIndex = el.closest('li').index();
        this.selectedIndex = selectedIndex;
        selectedObject = this.renderedData[selectedIndex];
      }
    }

    if (this.options.vue) {
      if (el.hasClass(ACTIVE_CLASS)) {
        el.removeClass(ACTIVE_CLASS);
      } else {
        el.addClass(ACTIVE_CLASS);
      }

      return [selectedObject];
    }

    field = [];
    value = this.options.id ? this.options.id(selectedObject, el) : selectedObject.id;
    if (isInput) {
      field = $(this.el);
    } else if (value != null) {
      field = this.dropdown
        .parent()
        .find(`input[name='${fieldName}'][value='${value.toString().replace(/'/g, "\\'")}']`);
    }

    if (this.options.isSelectable && !this.options.isSelectable(selectedObject, el)) {
      return [selectedObject];
    }

    if (el.hasClass(ACTIVE_CLASS) && value !== 0) {
      isMarking = false;
      el.removeClass(ACTIVE_CLASS);
      if (field && field.length) {
        this.clearField(field, isInput);
      }
    } else if (el.hasClass(INDETERMINATE_CLASS)) {
      isMarking = true;
      el.addClass(ACTIVE_CLASS);
      el.removeClass(INDETERMINATE_CLASS);
      if (field && field.length && value == null) {
        this.clearField(field, isInput);
      }
      if ((!field || !field.length) && fieldName) {
        this.addInput(fieldName, value, selectedObject);
      }
    } else {
      isMarking = true;
      if (!this.options.multiSelect || el.hasClass('dropdown-clear-active')) {
        this.dropdown.find(`.${ACTIVE_CLASS}`).removeClass(ACTIVE_CLASS);
        if (!isInput) {
          this.dropdown
            .parent()
            .find(`input[name='${fieldName}']`)
            .remove();
        }
      }
      if (field && field.length && value == null) {
        this.clearField(field, isInput);
      }
      // Toggle active class for the tick mark
      el.addClass(ACTIVE_CLASS);
      if (value != null) {
        if ((!field || !field.length) && fieldName) {
          this.addInput(fieldName, value, selectedObject);
        } else if (field && field.length) {
          field.val(value).trigger('change');
        }
      }
    }

    return [selectedObject, isMarking];
  };

  GitLabDropdown.prototype.focusTextInput = function() {
    if (this.options.filterable) {
      const initialScrollTop = $(window).scrollTop();

      if (this.dropdown.is('.show') && !this.filterInput.is(':focus')) {
        this.filterInput.focus();
      }

      if ($(window).scrollTop() < initialScrollTop) {
        $(window).scrollTop(initialScrollTop);
      }
    }
  };

  GitLabDropdown.prototype.addInput = function(fieldName, value, selectedObject, single) {
    var $input;
    // Create hidden input for form
    if (single) {
      $(`input[name="${fieldName}"]`).remove();
    }

    $input = $('<input>')
      .attr('type', 'hidden')
      .attr('name', fieldName)
      .val(value);
    if (this.options.inputId != null) {
      $input.attr('id', this.options.inputId);
    }

    if (this.options.multiSelect) {
      Object.keys(selectedObject).forEach(attribute => {
        $input.attr(`data-${attribute}`, selectedObject[attribute]);
      });
    }

    if (this.options.inputMeta) {
      $input.attr('data-meta', selectedObject[this.options.inputMeta]);
    }

    this.dropdown.before($input).trigger('change');
  };

  GitLabDropdown.prototype.selectRowAtIndex = function(index) {
    var $el, selector;
    // If we pass an option index
    if (typeof index !== 'undefined') {
      selector = `${SELECTABLE_CLASSES}:eq(${index}) a`;
    } else {
      selector = '.dropdown-content .is-focused';
    }
    if (this.dropdown.find('.dropdown-toggle-page').length) {
      selector = `.dropdown-page-one ${selector}`;
    }
    // simulate a click on the first link
    $el = $(selector, this.dropdown);
    if ($el.length) {
      var href = $el.attr('href');
      if (href && href !== '#') {
        visitUrl(href);
      } else {
        $el.trigger('click');
      }
    }
  };

  GitLabDropdown.prototype.addArrowKeyEvent = function() {
    var ARROW_KEY_CODES, selector;
    ARROW_KEY_CODES = [38, 40];
    selector = SELECTABLE_CLASSES;
    if (this.dropdown.find('.dropdown-toggle-page').length) {
      selector = `.dropdown-page-one ${selector}`;
    }
    return $('body').on(
      'keydown',
      (function(_this) {
        return function(e) {
          var $listItems, PREV_INDEX, currentKeyCode;
          currentKeyCode = e.which;
          if (ARROW_KEY_CODES.indexOf(currentKeyCode) !== -1) {
            e.preventDefault();
            e.stopImmediatePropagation();
            PREV_INDEX = currentIndex;
            $listItems = $(selector, _this.dropdown);
            // if @options.filterable
            //   $input.blur()
            if (currentKeyCode === 40) {
              // Move down
              if (currentIndex < $listItems.length - 1) {
                currentIndex += 1;
              }
            } else if (currentKeyCode === 38) {
              // Move up
              if (currentIndex > 0) {
                currentIndex -= 1;
              }
            }
            if (currentIndex !== PREV_INDEX) {
              _this.highlightRowAtIndex($listItems, currentIndex);
            }
            return false;
          }
          if (currentKeyCode === 13 && currentIndex !== -1) {
            e.preventDefault();
            _this.selectRowAtIndex();
          }
        };
      })(this),
    );
  };

  GitLabDropdown.prototype.removeArrayKeyEvent = function() {
    return $('body').off('keydown');
  };

  GitLabDropdown.prototype.resetRows = function resetRows() {
    currentIndex = -1;
    $('.is-focused', this.dropdown).removeClass('is-focused');
  };

  GitLabDropdown.prototype.highlightRowAtIndex = function($listItems, index) {
    var $dropdownContent,
      $listItem,
      dropdownContentBottom,
      dropdownContentHeight,
      dropdownContentTop,
      dropdownScrollTop,
      listItemBottom,
      listItemHeight,
      listItemTop;

    if (!$listItems) {
      $listItems = $(SELECTABLE_CLASSES, this.dropdown);
    }

    // Remove the class for the previously focused row
    $('.is-focused', this.dropdown).removeClass('is-focused');
    // Update the class for the row at the specific index
    $listItem = $listItems.eq(index);
    $listItem.find('a:first-child').addClass('is-focused');
    // Dropdown content scroll area
    $dropdownContent = $listItem.closest('.dropdown-content');
    dropdownScrollTop = $dropdownContent.scrollTop();
    dropdownContentHeight = $dropdownContent.outerHeight();
    dropdownContentTop = $dropdownContent.prop('offsetTop');
    dropdownContentBottom = dropdownContentTop + dropdownContentHeight;
    // Get the offset bottom of the list item
    listItemHeight = $listItem.outerHeight();
    listItemTop = $listItem.prop('offsetTop');
    listItemBottom = listItemTop + listItemHeight;
    if (!index) {
      // Scroll the dropdown content to the top
      $dropdownContent.scrollTop(0);
    } else if (index === $listItems.length - 1) {
      // Scroll the dropdown content to the bottom
      $dropdownContent.scrollTop($dropdownContent.prop('scrollHeight'));
    } else if (listItemBottom > dropdownContentBottom + dropdownScrollTop) {
      // Scroll the dropdown content down
      $dropdownContent.scrollTop(
        listItemBottom - dropdownContentBottom + CURSOR_SELECT_SCROLL_PADDING,
      );
    } else if (listItemTop < dropdownContentTop + dropdownScrollTop) {
      // Scroll the dropdown content up
      return $dropdownContent.scrollTop(
        listItemTop - dropdownContentTop - CURSOR_SELECT_SCROLL_PADDING,
      );
    }
  };

  GitLabDropdown.prototype.updateLabel = function(selected, el, instance) {
    if (selected == null) {
      selected = null;
    }
    if (el == null) {
      el = null;
    }
    if (instance == null) {
      instance = null;
    }

    let toggleText = this.options.toggleLabel(selected, el, instance);
    if (this.options.updateLabel) {
      // Option to override the dropdown label text
      toggleText = this.options.updateLabel;
    }

    return $(this.el)
      .find('.dropdown-toggle-text')
      .text(toggleText);
  };

  GitLabDropdown.prototype.clearField = function(field, isInput) {
    return isInput ? field.val('') : field.remove();
  };

  return GitLabDropdown;
})();

$.fn.glDropdown = function(opts) {
  return this.each(function() {
    if (!$.data(this, 'glDropdown')) {
      return $.data(this, 'glDropdown', new GitLabDropdown(this, opts));
    }
  });
};
