import CodeBlockHighlight from '~/content_editor/extensions/code_block_highlight';
import { createTestEditor, createDocBuilder, triggerNodeInputRule } from '../test_utils';

const CODE_BLOCK_HTML = `<pre class="code highlight js-syntax-highlight language-javascript" lang="javascript" v-pre="true">
  <code>
    <span id="LC1" class="line" lang="javascript">
      <span class="nx">console</span><span class="p">.</span><span class="nx">log</span><span class="p">(</span><span class="dl">'</span><span class="s1">hello world</span><span class="dl">'</span><span class="p">)</span>
    </span>
  </code>
</pre>`;

describe('content_editor/extensions/code_block_highlight', () => {
  let parsedCodeBlockHtmlFixture;
  let tiptapEditor;
  let doc;
  let codeBlock;
  let languageLoader;

  const parseHTML = (html) => new DOMParser().parseFromString(html, 'text/html');
  const preElement = () => parsedCodeBlockHtmlFixture.querySelector('pre');

  beforeEach(() => {
    languageLoader = { loadLanguages: jest.fn() };
    tiptapEditor = createTestEditor({
      extensions: [CodeBlockHighlight.configure({ languageLoader })],
    });

    ({
      builders: { doc, codeBlock },
    } = createDocBuilder({
      tiptapEditor,
      names: {
        codeBlock: { nodeType: CodeBlockHighlight.name },
      },
    }));
  });

  describe('when parsing HTML', () => {
    beforeEach(() => {
      parsedCodeBlockHtmlFixture = parseHTML(CODE_BLOCK_HTML);

      tiptapEditor.commands.setContent(CODE_BLOCK_HTML);
    });
    it('extracts language and params attributes from Markdown API output', () => {
      const language = preElement().getAttribute('lang');

      expect(tiptapEditor.getJSON().content[0].attrs).toMatchObject({
        language,
      });
    });

    it('adds code, highlight, and js-syntax-highlight to code block element', () => {
      const editorHtmlOutput = parseHTML(tiptapEditor.getHTML()).querySelector('pre');

      expect(editorHtmlOutput.classList.toString()).toContain('code highlight js-syntax-highlight');
    });

    it('adds content-editor-code-block class to the pre element', () => {
      const editorHtmlOutput = parseHTML(tiptapEditor.getHTML()).querySelector('pre');

      expect(editorHtmlOutput.classList.toString()).toContain('content-editor-code-block');
    });
  });

  describe.each`
    inputRule
    ${'```'}
    ${'~~~'}
  `('when typing $inputRule input rule', ({ inputRule }) => {
    const language = 'javascript';

    beforeEach(() => {
      triggerNodeInputRule({
        tiptapEditor,
        inputRuleText: `${inputRule}${language} `,
      });
    });

    it('creates a new code block and loads related language', () => {
      const expectedDoc = doc(codeBlock({ language }));

      expect(tiptapEditor.getJSON()).toEqual(expectedDoc.toJSON());
    });

    it('loads language when language loader is available', () => {
      expect(languageLoader.loadLanguages).toHaveBeenCalledWith([language]);
    });
  });
});
