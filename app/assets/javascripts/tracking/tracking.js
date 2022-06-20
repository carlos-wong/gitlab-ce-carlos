import { LOAD_ACTION_ATTR_SELECTOR } from './constants';
import { dispatchSnowplowEvent } from './dispatch_snowplow_event';
import getStandardContext from './get_standard_context';
import {
  getEventHandlers,
  createEventPayload,
  renameKey,
  addExperimentContext,
  getReferrersCache,
  addReferrersCacheEntry,
} from './utils';

const ALLOWED_URL_HASHES = ['#diff', '#note'];

export default class Tracking {
  static nonInitializedQueue = [];
  static initialized = false;
  static definitionsLoaded = false;
  static definitionsManifest = {};
  static definitionsEventsQueue = [];
  static definitions = [];

  /**
   * (Legacy) Determines if tracking is enabled at the user level.
   * https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/DNT.
   *
   * @returns {Boolean}
   */
  static trackable() {
    return !['1', 'yes'].includes(
      window.doNotTrack || navigator.doNotTrack || navigator.msDoNotTrack,
    );
  }

  /**
   * Determines if Snowplow is available/enabled.
   *
   * @returns {Boolean}
   */
  static enabled() {
    return typeof window.snowplow === 'function' && this.trackable();
  }

  /**
   * Dispatches a structured event per our taxonomy:
   * https://docs.gitlab.com/ee/development/snowplow/index.html#structured-event-taxonomy.
   *
   * If the library is not initialized and events are trying to be
   * dispatched (data-attributes, load-events), they will be added
   * to a queue to be flushed afterwards.
   *
   * @param  {...any} eventData defined event taxonomy
   * @returns {undefined|Boolean}
   */
  static event(...eventData) {
    if (!this.enabled()) {
      return false;
    }

    if (!this.initialized) {
      this.nonInitializedQueue.push(eventData);
      return false;
    }

    return dispatchSnowplowEvent(...eventData);
  }

  /**
   * Preloads event definitions.
   *
   * @returns {undefined}
   */
  static loadDefinitions() {
    // TODO: fetch definitions from the server and flush the queue
    // See https://gitlab.com/gitlab-org/gitlab/-/issues/358256
    this.definitionsLoaded = true;

    while (this.definitionsEventsQueue.length) {
      this.dispatchFromDefinition(...this.definitionsEventsQueue.shift());
    }
  }

  /**
   * Dispatches a structured event with data from its event definition.
   *
   * @param {String} basename
   * @param {Object} eventData
   * @returns {undefined|Boolean}
   */
  static definition(basename, eventData = {}) {
    if (!this.enabled()) {
      return false;
    }

    if (!(basename in this.definitionsManifest)) {
      throw new Error(`Missing Snowplow event definition "${basename}"`);
    }

    return this.dispatchFromDefinition(basename, eventData);
  }

  /**
   * Builds an event with data from a valid definition and sends it to
   * Snowplow. If the definitions are not loaded, it pushes the data to a queue.
   *
   * @param {String} basename
   * @param {Object} eventData
   * @returns {undefined|Boolean}
   */
  static dispatchFromDefinition(basename, eventData) {
    if (!this.definitionsLoaded) {
      this.definitionsEventsQueue.push([basename, eventData]);

      return false;
    }

    const eventDefinition = this.definitions.find((definition) => definition.key === basename);

    return this.event(
      eventData.category ?? eventDefinition.category,
      eventData.action ?? eventDefinition.action,
      eventData,
    );
  }

  /**
   * Dispatches any event emitted before initialization.
   *
   * @returns {undefined}
   */
  static flushPendingEvents() {
    this.initialized = true;

    while (this.nonInitializedQueue.length) {
      dispatchSnowplowEvent(...this.nonInitializedQueue.shift());
    }
  }

  /**
   * Attaches event handlers for data-attributes powered events.
   *
   * @param {String} category - the default category for all events
   * @param {HTMLElement} parent - element containing data-attributes
   * @returns {Array}
   */
  static bindDocument(category = document.body.dataset.page, parent = document) {
    if (!this.enabled() || parent.trackingBound) {
      return [];
    }

    // eslint-disable-next-line no-param-reassign
    parent.trackingBound = true;

    const handlers = getEventHandlers(category, (...args) => this.event(...args));
    handlers.forEach((event) => parent.addEventListener(event.name, event.func));

    return handlers;
  }

  /**
   * Attaches event handlers for load-events (on render).
   *
   * @param {String} category - the default category for all events
   * @param {HTMLElement} parent - element containing event targets
   * @returns {Array}
   */
  static trackLoadEvents(category = document.body.dataset.page, parent = document) {
    if (!this.enabled()) {
      return [];
    }

    const loadEvents = parent.querySelectorAll(LOAD_ACTION_ATTR_SELECTOR);

    loadEvents.forEach((element) => {
      const { action, data } = createEventPayload(element);
      this.event(category, action, data);
    });

    return loadEvents;
  }

  /**
   * Enable Snowplow automatic form tracking.
   * The config param requires at least one array of either forms
   * class names, or field name attributes.
   * https://docs.gitlab.com/ee/development/snowplow/index.html#form-tracking.
   *
   * @param {Object} config
   * @param {Array} contexts
   * @returns {undefined}
   */
  static enableFormTracking(config, contexts = []) {
    if (!this.enabled()) {
      return;
    }

    if (!Array.isArray(config?.forms?.allow) && !Array.isArray(config?.fields?.allow)) {
      // eslint-disable-next-line @gitlab/require-i18n-strings
      throw new Error('Unable to enable form event tracking without allow rules.');
    }

    // Ignore default/standard schema
    const standardContext = getStandardContext();
    const userProvidedContexts = contexts.filter(
      (context) => context.schema !== standardContext.schema,
    );

    const mappedConfig = {};
    if (config.forms) {
      mappedConfig.forms = renameKey(config.forms, 'allow', 'whitelist');
    }

    if (config.fields) {
      mappedConfig.fields = renameKey(config.fields, 'allow', 'whitelist');
    }

    const enabler = () => window.snowplow('enableFormTracking', mappedConfig, userProvidedContexts);

    if (document.readyState === 'complete') {
      enabler();
    } else {
      document.addEventListener('readystatechange', () => {
        if (document.readyState === 'complete') {
          enabler();
        }
      });
    }
  }

  /**
   * Replaces the URL and referrer for the default web context
   * if the replacements are available.
   *
   * @returns {undefined}
   */
  static setAnonymousUrls() {
    const { snowplowPseudonymizedPageUrl: pageUrl } = window.gl;

    if (!pageUrl) {
      return;
    }

    const referrers = getReferrersCache();
    const pageLinks = Object.seal({
      url: pageUrl,
      referrer: '',
      originalUrl: window.location.href,
    });

    const appendHash = ALLOWED_URL_HASHES.some((prefix) => window.location.hash.startsWith(prefix));
    const customUrl = `${pageUrl}${appendHash ? window.location.hash : ''}`;
    window.snowplow('setCustomUrl', customUrl);

    if (document.referrer) {
      const node = referrers.find((links) => links.originalUrl === document.referrer);

      if (node) {
        pageLinks.referrer = node.url;
        window.snowplow('setReferrerUrl', pageLinks.referrer);
      }
    }

    addReferrersCacheEntry(referrers, pageLinks);
  }

  /**
   * Returns an implementation of this class in the form of
   * a Vue mixin.
   *
   * @param {Object} opts - default options for all events
   * @returns {Object}
   */
  static mixin(opts = {}) {
    return {
      computed: {
        trackingCategory() {
          const localCategory = this.tracking ? this.tracking.category : null;
          return localCategory || opts.category;
        },
        trackingOptions() {
          const options = addExperimentContext(opts);
          return { ...options, ...this.tracking };
        },
      },
      methods: {
        track(action, data = {}) {
          const category = data.category || this.trackingCategory;
          const options = {
            ...this.trackingOptions,
            ...data,
          };

          Tracking.event(category, action, options);
        },
      },
    };
  }
}
