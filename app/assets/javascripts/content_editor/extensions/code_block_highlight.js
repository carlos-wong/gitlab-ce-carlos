import { CodeBlockLowlight } from '@tiptap/extension-code-block-lowlight';
import { textblockTypeInputRule } from '@tiptap/core';
import { VueNodeViewRenderer } from '@tiptap/vue-2';
import languageLoader from '../services/code_block_language_loader';
import CodeBlockWrapper from '../components/wrappers/code_block.vue';

const extractLanguage = (element) => element.dataset.canonicalLang ?? element.getAttribute('lang');

export const backtickInputRegex = /^```([a-z]+)?[\s\n]$/;
export const tildeInputRegex = /^~~~([a-z]+)?[\s\n]$/;

export default CodeBlockLowlight.extend({
  isolating: true,
  exitOnArrowDown: false,
  addAttributes() {
    return {
      language: {
        default: null,
        parseHTML: (element) => extractLanguage(element),
      },
      class: {
        // eslint-disable-next-line @gitlab/require-i18n-strings
        default: 'code highlight',
      },
    };
  },
  addInputRules() {
    const getAttributes = (match) => languageLoader?.loadLanguageFromInputRule(match) || {};

    return [
      textblockTypeInputRule({
        find: backtickInputRegex,
        type: this.type,
        getAttributes,
      }),
      textblockTypeInputRule({
        find: tildeInputRegex,
        type: this.type,
        getAttributes,
      }),
    ];
  },
  parseHTML() {
    return [
      {
        tag: 'div.markdown-code-block',
        skip: true,
      },
      {
        tag: 'pre.js-syntax-highlight',
        preserveWhitespace: 'full',
      },
    ];
  },
  renderHTML({ HTMLAttributes }) {
    return [
      'pre',
      {
        ...HTMLAttributes,
        class: `content-editor-code-block ${gon.user_color_scheme} ${HTMLAttributes.class}`,
      },
      ['code', {}, 0],
    ];
  },

  addNodeView() {
    return new VueNodeViewRenderer(CodeBlockWrapper);
  },
});
