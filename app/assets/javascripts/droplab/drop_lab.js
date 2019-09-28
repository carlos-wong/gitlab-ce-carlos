import HookButton from './hook_button';
import HookInput from './hook_input';
import utils from './utils';
import Keyboard from './keyboard';
import { DATA_TRIGGER } from './constants';

class DropLab {
  constructor() {
    this.ready = false;
    this.hooks = [];
    this.queuedData = [];
    this.config = {};

    this.eventWrapper = {};
  }

  loadStatic() {
    const dropdownTriggers = [].slice.apply(document.querySelectorAll(`[${DATA_TRIGGER}]`));
    this.addHooks(dropdownTriggers);
  }

  addData(...args) {
    this.applyArgs(args, 'processAddData');
  }

  setData(...args) {
    this.applyArgs(args, 'processSetData');
  }

  destroy() {
    this.hooks.forEach(hook => hook.destroy());
    this.hooks = [];
    this.removeEvents();
  }

  applyArgs(args, methodName) {
    if (this.ready) return this[methodName](...args);

    this.queuedData = this.queuedData || [];
    this.queuedData.push(args);

    return this.ready;
  }

  processAddData(trigger, data) {
    this.processData(trigger, data, 'addData');
  }

  processSetData(trigger, data) {
    this.processData(trigger, data, 'setData');
  }

  processData(trigger, data, methodName) {
    this.hooks.forEach(hook => {
      if (Array.isArray(trigger)) hook.list[methodName](trigger);

      if (hook.trigger.id === trigger) hook.list[methodName](data);
    });
  }

  addEvents() {
    this.eventWrapper.documentClicked = this.documentClicked.bind(this);
    document.addEventListener('mousedown', this.eventWrapper.documentClicked);
  }

  documentClicked(e) {
    let thisTag = e.target;

    if (thisTag.tagName !== 'UL') thisTag = utils.closest(thisTag, 'UL');
    if (utils.isDropDownParts(thisTag, this.hooks)) return;
    if (utils.isDropDownParts(e.target, this.hooks)) return;

    this.hooks.forEach(hook => hook.list.hide());
  }

  removeEvents() {
    document.removeEventListener('mousedown', this.eventWrapper.documentClicked);
  }

  changeHookList(trigger, list, plugins, config) {
    const availableTrigger =
      typeof trigger === 'string' ? document.getElementById(trigger) : trigger;

    this.hooks.forEach((hook, i) => {
      const aHook = hook;

      aHook.list.list.dataset.dropdownActive = false;

      if (aHook.trigger !== availableTrigger) return;

      aHook.destroy();
      this.hooks.splice(i, 1);
      this.addHook(availableTrigger, list, plugins, config);
    });
  }

  addHook(hook, list, plugins, config) {
    const availableHook = typeof hook === 'string' ? document.querySelector(hook) : hook;
    let availableList;

    if (typeof list === 'string') {
      availableList = document.querySelector(list);
    } else if (list instanceof Element) {
      availableList = list;
    } else {
      availableList = document.querySelector(hook.dataset[utils.toCamelCase(DATA_TRIGGER)]);
    }

    availableList.dataset.dropdownActive = true;

    const HookObject = availableHook.tagName === 'INPUT' ? HookInput : HookButton;
    this.hooks.push(new HookObject(availableHook, availableList, plugins, config));

    return this;
  }

  addHooks(hooks, plugins, config) {
    hooks.forEach(hook => this.addHook(hook, null, plugins, config));
    return this;
  }

  setConfig(obj) {
    this.config = obj;
  }

  fireReady() {
    const readyEvent = new CustomEvent('ready.dl', {
      detail: {
        dropdown: this,
      },
    });
    document.dispatchEvent(readyEvent);

    this.ready = true;
  }

  init(hook, list, plugins, config) {
    if (hook) {
      this.addHook(hook, list, plugins, config);
    } else {
      this.loadStatic();
    }

    this.addEvents();

    Keyboard();

    this.fireReady();

    this.queuedData.forEach(data => this.addData(data));
    this.queuedData = [];

    return this;
  }
}

export default DropLab;
