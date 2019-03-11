import createFlash from '../flash';
import AjaxFilter from '../droplab/plugins/ajax_filter';
import FilteredSearchDropdown from './filtered_search_dropdown';
import DropdownUtils from './dropdown_utils';
import FilteredSearchTokenizer from './filtered_search_tokenizer';
import { __ } from '~/locale';

export default class DropdownAjaxFilter extends FilteredSearchDropdown {
  constructor(options = {}) {
    const { tokenKeys, endpoint, symbol } = options;

    super(options);

    this.tokenKeys = tokenKeys;
    this.endpoint = endpoint;
    this.symbol = symbol;

    this.config = {
      AjaxFilter: this.ajaxFilterConfig(),
    };
  }

  ajaxFilterConfig() {
    return {
      endpoint: `${gon.relative_url_root || ''}${this.endpoint}`,
      searchKey: 'search',
      searchValueFunction: this.getSearchInput.bind(this),
      loadingTemplate: this.loadingTemplate,
      onError() {
        createFlash(__('An error occurred fetching the dropdown data.'));
      },
    };
  }

  itemClicked(e) {
    super.itemClicked(e, selected =>
      selected.querySelector('.dropdown-light-content').innerText.trim(),
    );
  }

  renderContent(forceShowList = false) {
    this.droplab.changeHookList(this.hookId, this.dropdown, [AjaxFilter], this.config);
    super.renderContent(forceShowList);
  }

  getSearchInput() {
    const query = DropdownUtils.getSearchInput(this.input);
    const { lastToken } = FilteredSearchTokenizer.processTokens(query, this.tokenKeys.get());

    let value = lastToken || '';

    if (value[0] === this.symbol) {
      value = value.slice(1);
    }

    // Removes the first character if it is a quotation so that we can search
    // with multiple words
    if (value[0] === '"' || value[0] === "'") {
      value = value.slice(1);
    }

    return value;
  }

  init() {
    this.droplab.addHook(this.input, this.dropdown, [AjaxFilter], this.config).init();
  }
}
