import { DOMParser as ProseMirrorDOMParser } from 'prosemirror-model';

export default ({ render }) => {
  /**
   * Converts a Markdown string into a ProseMirror JSONDocument based
   * on a ProseMirror schema.
   *
   * @param {Object} options — The schema and content for deserialization
   * @param {ProseMirror.Schema} params.schema A ProseMirror schema that defines
   * the types of content supported in the document
   * @param {String} params.content An arbitrary markdown string
   *
   * @returns An object with the following properties:
   *  - document: A ProseMirror document object generated from the deserialized Markdown
   *  - dom: The Markdown Deserializer renders Markdown as HTML to generate the ProseMirror
   *    document. The dom property contains the HTML generated from the Markdown Source.
   */
  return {
    deserialize: async ({ schema, markdown }) => {
      const html = await render(markdown);

      if (!html) return {};

      const parser = new DOMParser();
      const { body } = parser.parseFromString(html, 'text/html');

      // append original source as a comment that nodes can access
      body.append(document.createComment(markdown));

      return { document: ProseMirrorDOMParser.fromSchema(schema).parse(body) };
    },
  };
};
