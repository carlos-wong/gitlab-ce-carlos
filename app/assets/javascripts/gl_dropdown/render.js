const renderersByType = {
  divider(element) {
    element.classList.add('divider');

    return element;
  },
  separator(element) {
    element.classList.add('separator');

    return element;
  },
  header(element, data) {
    element.classList.add('dropdown-header');
    element.innerHTML = data.content;

    return element;
  },
};

function getPropertyWithDefault(data, options, property, defaultValue = '') {
  let result;

  if (options[property] != null) {
    result = options[property](data);
  } else {
    result = data[property] != null ? data[property] : defaultValue;
  }

  return result;
}

function getHighlightTextBuilder(text, data, options) {
  if (options.highlight) {
    return data.template
      ? options.highlightTemplate(text, data.template)
      : options.highlightText(text);
  }

  return text;
}

function getIconTextBuilder(text, data, options) {
  if (options.icon) {
    const wrappedText = `<span>${text}</span>`;
    return data.icon ? `${data.icon}${wrappedText}` : wrappedText;
  }

  return text;
}

function getLinkText(data, options) {
  const text = getPropertyWithDefault(data, options, 'text');

  return [getHighlightTextBuilder, getIconTextBuilder].reduce(
    (acc, fn) => fn(acc, data, options),
    text,
  );
}

function escape(text) {
  return text ? String(text).replace(/'/g, "\\'") : text;
}

function getOptionValue(data, options) {
  if (options.renderRow) {
    return undefined;
  }

  return escape(options.id ? options.id(data) : data.id);
}

function shouldHide(data, { options }) {
  const value = getOptionValue(data, options);

  return options.hideRow && options.hideRow(value);
}

function hideElement(element) {
  element.style.display = 'none';

  return element;
}

function checkSelected(data, options) {
  const value = getOptionValue(data, options);

  if (!options.parent) {
    return !data.id;
  } else if (value) {
    return (
      options.parent.querySelector(`input[name='${options.fieldName}'][value='${value}']`) != null
    );
  }

  return options.parent.querySelector(`input[name='${options.fieldName}']`) == null;
}

function createLink(url, selected, options) {
  const link = document.createElement('a');

  link.href = url;

  if (options.icon) {
    link.classList.add('d-flex', 'align-items-center');
  }

  link.classList.toggle('is-active', selected);

  return link;
}

function assignTextToLink(el, data, options) {
  const text = getLinkText(data, options);

  if (options.icon || options.highlight) {
    el.innerHTML = text;
  } else {
    el.textContent = text;
  }

  return el;
}

function renderLink(row, data, { options, group, index }) {
  const selected = checkSelected(data, options);
  const url = getPropertyWithDefault(data, options, 'url', '#');
  const link = createLink(url, selected, options);

  assignTextToLink(link, data, options);

  if (group) {
    link.dataset.group = group;
    link.dataset.index = index;
  }

  row.appendChild(link);

  return row;
}

function getOptionRenderer({ options, instance }) {
  return options.renderRow && ((li, data) => options.renderRow(data, instance));
}

function getRenderer(data, params) {
  return renderersByType[data.type] || getOptionRenderer(params) || renderLink;
}

export default function item({ data, ...params }) {
  const renderer = getRenderer(data, params);
  const li = document.createElement('li');

  if (shouldHide(data, params)) {
    hideElement(li);
  }

  return renderer(li, data, params);
}
