import _ from 'underscore';
import AjaxCache from '~/lib/utils/ajax_cache';
import { objectToQueryString } from '~/lib/utils/common_utils';
import Flash from '../flash';
import FilteredSearchContainer from './container';
import UsersCache from '../lib/utils/users_cache';
import DropdownUtils from './dropdown_utils';

export default class FilteredSearchVisualTokens {
  static getLastVisualTokenBeforeInput() {
    const inputLi = FilteredSearchContainer.container.querySelector('.input-token');
    const lastVisualToken = inputLi && inputLi.previousElementSibling;

    return {
      lastVisualToken,
      isLastVisualTokenValid:
        lastVisualToken === null ||
        lastVisualToken.className.indexOf('filtered-search-term') !== -1 ||
        (lastVisualToken && lastVisualToken.querySelector('.value') !== null),
    };
  }

  /**
   * Returns a computed API endpoint
   * and query string composed of values from endpointQueryParams
   * @param {String} endpoint
   * @param {String} endpointQueryParams
   */
  static getEndpointWithQueryParams(endpoint, endpointQueryParams) {
    if (!endpointQueryParams) {
      return endpoint;
    }

    const queryString = objectToQueryString(JSON.parse(endpointQueryParams));
    return `${endpoint}?${queryString}`;
  }

  static unselectTokens() {
    const otherTokens = FilteredSearchContainer.container.querySelectorAll(
      '.js-visual-token .selectable.selected',
    );
    [].forEach.call(otherTokens, t => t.classList.remove('selected'));
  }

  static selectToken(tokenButton, forceSelection = false) {
    const selected = tokenButton.classList.contains('selected');
    FilteredSearchVisualTokens.unselectTokens();

    if (!selected || forceSelection) {
      tokenButton.classList.add('selected');
    }
  }

  static removeSelectedToken() {
    const selected = FilteredSearchContainer.container.querySelector('.js-visual-token .selected');

    if (selected) {
      const li = selected.closest('.js-visual-token');
      li.parentElement.removeChild(li);
    }
  }

  static createVisualTokenElementHTML(options = {}) {
    const { canEdit = true, uppercaseTokenName = false, capitalizeTokenValue = false } = options;

    return `
      <div class="${canEdit ? 'selectable' : 'hidden'}" role="button">
        <div class="${uppercaseTokenName ? 'text-uppercase' : ''} name"></div>
        <div class="value-container">
          <div class="${capitalizeTokenValue ? 'text-capitalize' : ''} value"></div>
          <div class="remove-token" role="button">
            <i class="fa fa-close"></i>
          </div>
        </div>
      </div>
    `;
  }

  static setTokenStyle(tokenContainer, backgroundColor, textColor) {
    const token = tokenContainer;

    token.style.backgroundColor = backgroundColor;
    token.style.color = textColor;

    if (textColor === '#FFFFFF') {
      const removeToken = token.querySelector('.remove-token');
      removeToken.classList.add('inverted');
    }

    return token;
  }

  static updateLabelTokenColor(tokenValueContainer, tokenValue) {
    const filteredSearchInput = FilteredSearchContainer.container.querySelector('.filtered-search');
    const { baseEndpoint } = filteredSearchInput.dataset;
    const labelsEndpoint = FilteredSearchVisualTokens.getEndpointWithQueryParams(
      `${baseEndpoint}/labels.json`,
      filteredSearchInput.dataset.endpointQueryParams,
    );

    return AjaxCache.retrieve(labelsEndpoint)
      .then(labels => {
        const matchingLabel = (labels || []).find(
          label => `~${DropdownUtils.getEscapedText(label.title)}` === tokenValue,
        );

        if (!matchingLabel) {
          return;
        }

        FilteredSearchVisualTokens.setTokenStyle(
          tokenValueContainer,
          matchingLabel.color,
          matchingLabel.text_color,
        );
      })
      .catch(() => new Flash('An error occurred while fetching label colors.'));
  }

  static updateUserTokenAppearance(tokenValueContainer, tokenValueElement, tokenValue) {
    const username = tokenValue.replace(/^@/, '');
    return (
      UsersCache.retrieve(username)
        .then(user => {
          if (!user) {
            return;
          }

          /* eslint-disable no-param-reassign */
          tokenValueContainer.dataset.originalValue = tokenValue;
          tokenValueElement.innerHTML = `
          <img class="avatar s20" src="${user.avatar_url}" alt="">
          ${_.escape(user.name)}
        `;
          /* eslint-enable no-param-reassign */
        })
        // ignore error and leave username in the search bar
        .catch(() => {})
    );
  }

  static updateEmojiTokenAppearance(tokenValueContainer, tokenValueElement, tokenValue) {
    const container = tokenValueContainer;
    const element = tokenValueElement;

    return (
      import(/* webpackChunkName: 'emoji' */ '../emoji')
        .then(Emoji => {
          if (!Emoji.isEmojiNameValid(tokenValue)) {
            return;
          }

          container.dataset.originalValue = tokenValue;
          element.innerHTML = Emoji.glEmojiTag(tokenValue);
        })
        // ignore error and leave emoji name in the search bar
        .catch(() => {})
    );
  }

  static renderVisualTokenValue(parentElement, tokenName, tokenValue) {
    const tokenValueContainer = parentElement.querySelector('.value-container');
    const tokenValueElement = tokenValueContainer.querySelector('.value');
    tokenValueElement.innerText = tokenValue;

    if (['none', 'any'].includes(tokenValue.toLowerCase())) {
      return;
    }

    const tokenType = tokenName.toLowerCase();

    if (tokenType === 'label') {
      FilteredSearchVisualTokens.updateLabelTokenColor(tokenValueContainer, tokenValue);
    } else if (tokenType === 'author' || tokenType === 'assignee') {
      FilteredSearchVisualTokens.updateUserTokenAppearance(
        tokenValueContainer,
        tokenValueElement,
        tokenValue,
      );
    } else if (tokenType === 'my-reaction') {
      FilteredSearchVisualTokens.updateEmojiTokenAppearance(
        tokenValueContainer,
        tokenValueElement,
        tokenValue,
      );
    }
  }

  static addVisualTokenElement(name, value, options = {}) {
    const { isSearchTerm = false, canEdit, uppercaseTokenName, capitalizeTokenValue } = options;
    const li = document.createElement('li');
    li.classList.add('js-visual-token');
    li.classList.add(isSearchTerm ? 'filtered-search-term' : 'filtered-search-token');

    if (value) {
      li.innerHTML = FilteredSearchVisualTokens.createVisualTokenElementHTML({
        canEdit,
        uppercaseTokenName,
        capitalizeTokenValue,
      });
      FilteredSearchVisualTokens.renderVisualTokenValue(li, name, value);
    } else {
      li.innerHTML = `<div class="${uppercaseTokenName ? 'text-uppercase' : ''} name"></div>`;
    }
    li.querySelector('.name').innerText = name;

    const tokensContainer = FilteredSearchContainer.container.querySelector('.tokens-container');
    const input = FilteredSearchContainer.container.querySelector('.filtered-search');
    tokensContainer.insertBefore(li, input.parentElement);
  }

  static addValueToPreviousVisualTokenElement(value) {
    const {
      lastVisualToken,
      isLastVisualTokenValid,
    } = FilteredSearchVisualTokens.getLastVisualTokenBeforeInput();

    if (!isLastVisualTokenValid && lastVisualToken.classList.contains('filtered-search-token')) {
      const name = FilteredSearchVisualTokens.getLastTokenPartial();
      lastVisualToken.innerHTML = FilteredSearchVisualTokens.createVisualTokenElementHTML();
      lastVisualToken.querySelector('.name').innerText = name;
      FilteredSearchVisualTokens.renderVisualTokenValue(lastVisualToken, name, value);
    }
  }

  static addFilterVisualToken(
    tokenName,
    tokenValue,
    { canEdit, uppercaseTokenName = false, capitalizeTokenValue = false } = {},
  ) {
    const {
      lastVisualToken,
      isLastVisualTokenValid,
    } = FilteredSearchVisualTokens.getLastVisualTokenBeforeInput();
    const { addVisualTokenElement } = FilteredSearchVisualTokens;

    if (isLastVisualTokenValid) {
      addVisualTokenElement(tokenName, tokenValue, {
        canEdit,
        uppercaseTokenName,
        capitalizeTokenValue,
      });
    } else {
      const previousTokenName = lastVisualToken.querySelector('.name').innerText;
      const tokensContainer = FilteredSearchContainer.container.querySelector('.tokens-container');
      tokensContainer.removeChild(lastVisualToken);

      const value = tokenValue || tokenName;
      addVisualTokenElement(previousTokenName, value, {
        canEdit,
        uppercaseTokenName,
        capitalizeTokenValue,
      });
    }
  }

  static addSearchVisualToken(searchTerm) {
    const { lastVisualToken } = FilteredSearchVisualTokens.getLastVisualTokenBeforeInput();

    if (lastVisualToken && lastVisualToken.classList.contains('filtered-search-term')) {
      lastVisualToken.querySelector('.name').innerText += ` ${searchTerm}`;
    } else {
      FilteredSearchVisualTokens.addVisualTokenElement(searchTerm, null, {
        isSearchTerm: true,
      });
    }
  }

  static getLastTokenPartial() {
    const { lastVisualToken } = FilteredSearchVisualTokens.getLastVisualTokenBeforeInput();

    if (!lastVisualToken) return '';

    const valueContainer = lastVisualToken.querySelector('.value-container');
    const originalValue = valueContainer && valueContainer.dataset.originalValue;
    if (originalValue) {
      return originalValue;
    }

    const value = lastVisualToken.querySelector('.value');
    const name = lastVisualToken.querySelector('.name');

    const valueText = value ? value.innerText : '';
    const nameText = name ? name.innerText : '';

    return valueText || nameText;
  }

  static removeLastTokenPartial() {
    const { lastVisualToken } = FilteredSearchVisualTokens.getLastVisualTokenBeforeInput();

    if (lastVisualToken) {
      const value = lastVisualToken.querySelector('.value');

      if (value) {
        const button = lastVisualToken.querySelector('.selectable');
        const valueContainer = lastVisualToken.querySelector('.value-container');
        button.removeChild(valueContainer);
        lastVisualToken.innerHTML = button.innerHTML;
      } else {
        lastVisualToken.closest('.tokens-container').removeChild(lastVisualToken);
      }
    }
  }

  static tokenizeInput() {
    const input = FilteredSearchContainer.container.querySelector('.filtered-search');
    const { isLastVisualTokenValid } = FilteredSearchVisualTokens.getLastVisualTokenBeforeInput();

    if (input.value) {
      if (isLastVisualTokenValid) {
        FilteredSearchVisualTokens.addSearchVisualToken(input.value);
      } else {
        FilteredSearchVisualTokens.addValueToPreviousVisualTokenElement(input.value);
      }

      input.value = '';
    }
  }

  static editToken(token) {
    const input = FilteredSearchContainer.container.querySelector('.filtered-search');

    FilteredSearchVisualTokens.tokenizeInput();

    // Replace token with input field
    const tokenContainer = token.parentElement;
    const inputLi = input.parentElement;
    tokenContainer.replaceChild(inputLi, token);

    const nameElement = token.querySelector('.name');
    let value;

    if (token.classList.contains('filtered-search-token')) {
      FilteredSearchVisualTokens.addFilterVisualToken(nameElement.innerText, null, {
        uppercaseTokenName: nameElement.classList.contains('text-uppercase'),
      });

      const valueContainerElement = token.querySelector('.value-container');
      value = valueContainerElement.dataset.originalValue;

      if (!value) {
        const valueElement = valueContainerElement.querySelector('.value');
        value = valueElement.innerText;
      }
    }

    // token is a search term
    if (!value) {
      value = nameElement.innerText;
    }

    input.value = value;

    // Opens dropdown
    const inputEvent = new Event('input');
    input.dispatchEvent(inputEvent);

    // Adds cursor to input
    input.focus();
  }

  static moveInputToTheRight() {
    const input = FilteredSearchContainer.container.querySelector('.filtered-search');

    if (!input) return;

    const inputLi = input.parentElement;
    const tokenContainer = FilteredSearchContainer.container.querySelector('.tokens-container');

    FilteredSearchVisualTokens.tokenizeInput();

    if (!tokenContainer.lastElementChild.isEqualNode(inputLi)) {
      const { isLastVisualTokenValid } = FilteredSearchVisualTokens.getLastVisualTokenBeforeInput();

      if (!isLastVisualTokenValid) {
        const lastPartial = FilteredSearchVisualTokens.getLastTokenPartial();
        FilteredSearchVisualTokens.removeLastTokenPartial();
        FilteredSearchVisualTokens.addSearchVisualToken(lastPartial);
      }

      tokenContainer.removeChild(inputLi);
      tokenContainer.appendChild(inputLi);
    }
  }
}
