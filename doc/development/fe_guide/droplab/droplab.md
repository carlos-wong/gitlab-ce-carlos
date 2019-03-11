# DropLab

A generic dropdown for all of your custom dropdown needs.

## Usage

DropLab can be used by simply adding a `data-dropdown-trigger` HTML attribute.
This attribute allows us to find the "trigger" _(toggle)_ for the dropdown,
whether that is a button, link or input.

The value of the `data-dropdown-trigger` should be a CSS selector that
DropLab can use to find the trigger's dropdown list.

You should also add the `data-dropdown` attribute to declare the dropdown list.
The value is irrelevant.

The DropLab class has no side effects, so you must always call `.init` when
the DOM is ready. `DropLab.prototype.init` takes the same arguments as `DropLab.prototype.addHook`.
If you do not provide any arguments, it will globally query and instantiate all droplab compatible dropdowns.

```html
<a href="#" data-dropdown-trigger="#list">Toggle</a>

<ul id="list" data-dropdown>
  <!-- ... -->
<ul>
```
```js
const droplab = new DropLab();
droplab.init();
```

As you can see, we have a "Toggle" link, that is declared as a trigger.
It provides a selector to find the dropdown list it should control.

### Static data

You can add static list items.

```html
<a href="#" data-dropdown-trigger="#list">Toggle</a>

<ul id="list" data-dropdown>
  <li>Static value 1</li>
  <li>Static value 2</li>
<ul>
```
```js
const droplab = new DropLab();
droplab.init();
```

### Explicit instantiation

You can pass the trigger and list elements as constructor arguments to return
a non-global instance of DropLab using the `DropLab.prototype.init` method.

```html
<a href="#" id="trigger" data-dropdown-trigger="#list">Toggle</a>

<ul id="list" data-dropdown>
  <!-- ... -->
<ul>
```
```js
const trigger = document.getElementById('trigger');
const list = document.getElementById('list');

const droplab = new DropLab();
droplab.init(trigger, list);
```

You can also add hooks to an existing DropLab instance using `DropLab.prototype.addHook`.

```html
<a href="#" data-dropdown-trigger="#auto-dropdown">Toggle</a>
<ul id="auto-dropdown" data-dropdown><!-- ... --><ul>

<a href="#" id="trigger" data-dropdown-trigger="#list">Toggle</a>
<ul id="list" data-dropdown><!-- ... --><ul>
```
```js
const droplab = new DropLab();

droplab.init();

const trigger = document.getElementById('trigger');
const list = document.getElementById('list');

droplab.addHook(trigger, list);
```

### Dynamic data

Adding `data-dynamic` to your dropdown element will enable dynamic list rendering.

You can template a list item using the keys of the data object provided.
Use the handlebars syntax `{{ value }}` to HTML escape the value.
Use the `<%= value %>` syntax to simply interpolate the value.
Use the `<%= value %>` syntax to evaluate the value.

Passing an array of objects to `DropLab.prototype.addData` will render that data
for all `data-dynamic` dropdown lists tracked by that DropLab instance.

```html
<a href="#" data-dropdown-trigger="#list">Toggle</a>

<ul id="list" data-dropdown data-dynamic>
  <li><a href="#" data-id="{{id}}">{{text}}</a></li>
</ul>
```
```js
const droplab = new DropLab();

droplab.init().addData([{
  id: 0,
  text: 'Jacob',
}, {
  id: 1,
  text: 'Jeff',
}]);
```

Alternatively, you can specify a specific dropdown to add this data to but passing
the data as the second argument and the `id` of the trigger element as the first argument.

```html
<a href="#" data-dropdown-trigger="#list" id="trigger">Toggle</a>

<ul id="list" data-dropdown data-dynamic>
  <li><a href="#" data-id="{{id}}">{{text}}</a></li>
</ul>
```
```js
const droplab = new DropLab();

droplab.init().addData('trigger', [{
  id: 0,
  text: 'Jacob',
}, {
  id: 1,
  text: 'Jeff',
}]);
```

This allows you to mix static and dynamic content with ease, even with one trigger.

Note the use of scoping regarding the `data-dropdown` attribute to capture both
dropdown lists, one of which is dynamic.

```html
<input id="trigger" data-dropdown-trigger="#list">
<div id="list" data-dropdown>
  <ul>
    <li><a href="#">Static item 1</a></li>
    <li><a href="#">Static item 2</a></li>
  </ul>
  <ul data-dynamic>
    <li><a href="#" data-id="{{id}}">{{text}}</a></li>
  </ul>
</div>
```
```js
const droplab = new DropLab();

droplab.init().addData('trigger', [{
  id: 0,
  text: 'Jacob',
}, {
  id: 1,
  text: 'Jeff',
}]);
```

## Internal selectors

DropLab adds some CSS classes to help lower the barrier to integration.

For example:

- The `droplab-item-selected` css class is added to items that have been selected
  either by a mouse click or by enter key selection.
- The `droplab-item-active` css class is added to items that have been selected
  using arrow key navigation.
- You can add the `droplab-item-ignore` css class to any item that you do not want to be selectable. For example,
  an `<li class="divider"></li>` list divider element that should not be interactive.

## Internal events

DropLab uses some custom events to help lower the barrier to integration.

For example:

- The `click.dl` event is fired when an `li` list item has been clicked. It is also
  fired when a list item has been selected with the keyboard. It is also fired when a
  `HookButton` button is clicked (a registered `button` tag or `a` tag trigger).
- The `input.dl` event is fired when a `HookInput` (a registered `input` tag trigger) triggers an `input` event.
- The `mousedown.dl` event is fired when a `HookInput` triggers a `mousedown` event.
- The `keyup.dl` event is fired when a `HookInput` triggers a `keyup` event.
- The `keydown.dl` event is fired when a `HookInput` triggers a `keydown` event.

These custom events add a `detail` object to the vanilla `Event` object that provides some potentially useful data.

## Plugins

Plugins are objects that are registered to be executed when a hook is added (when a droplab trigger and dropdown are instantiated).

If no modules API is detected, the library will fall back as it does with `window.DropLab` and will add `window.DropLab.plugins.PluginName`.

### Usage

To use plugins, you can pass them in an array as the third argument of `DropLab.prototype.init` or `DropLab.prototype.addHook`.
Some plugins require configuration values, the config object can be passed as the fourth argument.

```html
<a href="#" id="trigger" data-dropdown-trigger="#list">Toggle</a>
<ul id="list" data-dropdown><!-- ... --><ul>
```
```js
const droplab = new DropLab();

const trigger = document.getElementById('trigger');
const list = document.getElementById('list');

droplab.init(trigger, list, [droplabAjax], {
  droplabAjax: {
    endpoint: '/some-endpoint',
    method: 'setData',
  },
});
```

### Documentation

- [Ajax plugin](plugins/ajax.md)
- [Filter plugin](plugins/filter.md)
- [InputSetter plugin](plugins/input_setter.md)

### Development

When plugins are initialised for a droplab trigger+dropdown, DropLab will
call the plugins `init` function, so this must be implemented in the plugin.

```js
class MyPlugin {
  static init() {
    this.someProp = 'someProp';
    this.someMethod();
  }

  static someMethod() {
    this.otherProp = 'otherProp';
  }
}

export default MyPlugin;
```
