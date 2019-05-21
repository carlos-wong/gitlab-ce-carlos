import IssuableFilteredSearchTokenKeys from 'ee_else_ce/filtered_search/issuable_filtered_search_token_keys';
import FilteredSearchContainer from '../filtered_search/container';
import FilteredSearchManager from '../filtered_search/filtered_search_manager';
import boardsStore from './stores/boards_store';
import { isEE } from '~/lib/utils/common_utils';

export default class FilteredSearchBoards extends FilteredSearchManager {
  constructor(store, updateUrl = false, cantEdit = []) {
    super({
      page: 'boards',
      isGroupDecendent: true,
      stateFiltersSelector: '.issues-state-filters',
      isGroup: isEE(),
      filteredSearchTokenKeys: IssuableFilteredSearchTokenKeys,
    });

    this.store = store;
    this.updateUrl = updateUrl;

    // Issue boards is slightly different, we handle all the requests async
    // instead or reloading the page, we just re-fire the list ajax requests
    this.isHandledAsync = true;
    this.cantEdit = cantEdit.filter(i => typeof i === 'string');
    this.cantEditWithValue = cantEdit.filter(i => typeof i === 'object');
  }

  updateObject(path) {
    this.store.path = path.substr(1);

    if (this.updateUrl) {
      boardsStore.updateFiltersUrl();
    }
  }

  removeTokens() {
    const tokens = FilteredSearchContainer.container.querySelectorAll('.js-visual-token');

    // Remove all the tokens as they will be replaced by the search manager
    [].forEach.call(tokens, el => {
      el.parentNode.removeChild(el);
    });

    this.filteredSearchInput.value = '';
  }

  updateTokens() {
    this.removeTokens();

    this.loadSearchParamsFromURL();

    // Get the placeholder back if search is empty
    this.filteredSearchInput.dispatchEvent(new Event('input'));
  }

  canEdit(tokenName, tokenValue) {
    if (this.cantEdit.includes(tokenName)) return false;
    return (
      this.cantEditWithValue.findIndex(
        token => token.name === tokenName && token.value === tokenValue,
      ) === -1
    );
  }
}
