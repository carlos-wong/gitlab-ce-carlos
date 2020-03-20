export default class FilteredSearchSpecHelper {
  static createFilterVisualTokenHTML(name, operator, value, isSelected) {
    return FilteredSearchSpecHelper.createFilterVisualToken(name, operator, value, isSelected)
      .outerHTML;
  }

  static createFilterVisualToken(name, operator, value, isSelected = false) {
    const li = document.createElement('li');
    li.classList.add('js-visual-token', 'filtered-search-token', `search-token-${name}`);

    li.innerHTML = `
      <div class="selectable ${isSelected ? 'selected' : ''}" role="button">
        <div class="name">${name}</div>
        <div class="operator">${operator}</div>
        <div class="value-container">
          <div class="value">${value}</div>
          <div class="remove-token" role="button">
            <i class="fa fa-close"></i>
          </div>
        </div>
      </div>
    `;

    return li;
  }

  static createNameFilterVisualTokenHTML(name) {
    return `
      <li class="js-visual-token filtered-search-token">
        <div class="name">${name}</div>
      </li>
    `;
  }

  static createNameOperatorFilterVisualTokenHTML(name, operator) {
    return `
      <li class="js-visual-token filtered-search-token">
        <div class="name">${name}</div>
        <div class="operator">${operator}</div>
      </li>
    `;
  }

  static createSearchVisualToken(name) {
    const li = document.createElement('li');
    li.classList.add('js-visual-token', 'filtered-search-term');
    li.innerHTML = `<div class="name">${name}</div>`;
    return li;
  }

  static createSearchVisualTokenHTML(name) {
    return FilteredSearchSpecHelper.createSearchVisualToken(name).outerHTML;
  }

  static createInputHTML(placeholder = '', value = '') {
    return `
      <li class="input-token">
        <input type='text' class='filtered-search' placeholder='${placeholder}' value='${value}'/>
      </li>
    `;
  }

  static createTokensContainerHTML(html, inputPlaceholder) {
    return `
      ${html}
      ${FilteredSearchSpecHelper.createInputHTML(inputPlaceholder)}
    `;
  }
}
