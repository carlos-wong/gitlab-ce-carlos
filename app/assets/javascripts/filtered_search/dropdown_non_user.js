import Flash from '../flash';
import Ajax from '../droplab/plugins/ajax';
import Filter from '../droplab/plugins/filter';
import FilteredSearchDropdown from './filtered_search_dropdown';
import DropdownUtils from './dropdown_utils';
import { __ } from '~/locale';

export default class DropdownNonUser extends FilteredSearchDropdown {
  constructor(options = {}) {
    const { input, endpoint, symbol, preprocessing } = options;
    super(options);
    this.symbol = symbol;
    this.config = {
      Ajax: {
        endpoint,
        method: 'setData',
        loadingTemplate: this.loadingTemplate,
        preprocessing,
        onError() {
          /* eslint-disable no-new */
          new Flash(__('An error occurred fetching the dropdown data.'));
          /* eslint-enable no-new */
        },
      },
      Filter: {
        filterFunction: DropdownUtils.filterWithSymbol.bind(null, this.symbol, input),
        template: 'title',
      },
    };
  }

  itemClicked(e) {
    super.itemClicked(e, selected => {
      const title = selected.querySelector('.js-data-value').innerText.trim();
      return `${this.symbol}${DropdownUtils.getEscapedText(title)}`;
    });
  }

  renderContent(forceShowList = false) {
    this.droplab.changeHookList(this.hookId, this.dropdown, [Ajax, Filter], this.config);
    super.renderContent(forceShowList);
  }

  init() {
    this.droplab.addHook(this.input, this.dropdown, [Ajax, Filter], this.config).init();
  }
}
