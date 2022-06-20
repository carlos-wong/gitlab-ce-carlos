/* eslint-disable @gitlab/require-i18n-strings */

import { Node } from '@tiptap/core';
import { VueNodeViewRenderer } from '@tiptap/vue-2';
import MediaWrapper from '../components/wrappers/media.vue';

const queryPlayableElement = (element, mediaType) => element.querySelector(mediaType);

export default Node.create({
  group: 'inline',
  inline: true,
  draggable: true,

  addAttributes() {
    return {
      uploading: {
        default: false,
      },
      src: {
        default: null,
        parseHTML: (element) => {
          const playable = queryPlayableElement(element, this.options.mediaType);

          return playable.src;
        },
      },
      canonicalSrc: {
        default: null,
        parseHTML: (element) => {
          const playable = queryPlayableElement(element, this.options.mediaType);

          return playable.dataset.canonicalSrc;
        },
      },
      alt: {
        default: null,
        parseHTML: (element) => {
          const playable = queryPlayableElement(element, this.options.mediaType);

          return playable.dataset.title;
        },
      },
    };
  },

  parseHTML() {
    return [
      {
        tag: `.${this.options.mediaType}-container`,
      },
    ];
  },

  renderHTML({ node }) {
    return [
      'span',
      { class: `media-container ${this.options.mediaType}-container` },
      [
        this.options.mediaType,
        {
          src: node.attrs.src,
          controls: true,
          'data-setup': '{}',
          'data-title': node.attrs.alt,
          ...this.extraElementAttrs,
        },
      ],
      ['a', { href: node.attrs.src }, node.attrs.title || node.attrs.alt || ''],
    ];
  },

  addNodeView() {
    return VueNodeViewRenderer(MediaWrapper);
  },
});
