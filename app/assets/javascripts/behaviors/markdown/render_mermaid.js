import flash from '~/flash';
import { sprintf, __ } from '../../locale';

// Renders diagrams and flowcharts from text using Mermaid in any element with the
// `js-render-mermaid` class.
//
// Example markup:
//
// <pre class="js-render-mermaid">
//  graph TD;
//    A-- > B;
//    A-- > C;
//    B-- > D;
//    C-- > D;
// </pre>
//

// This is an arbitary number; Can be iterated upon when suitable.
const MAX_CHAR_LIMIT = 5000;

export default function renderMermaid($els) {
  if (!$els.length) return;

  import(/* webpackChunkName: 'mermaid' */ 'mermaid')
    .then(mermaid => {
      mermaid.initialize({
        // mermaid core options
        mermaid: {
          startOnLoad: false,
        },
        // mermaidAPI options
        theme: 'neutral',
        flowchart: {
          htmlLabels: false,
        },
      });

      $els.each((i, el) => {
        const source = el.textContent;

        /**
         * Restrict the rendering to a certain amount of character to
         * prevent mermaidjs from hanging up the entire thread and
         * causing a DoS.
         */
        if (source && source.length > MAX_CHAR_LIMIT) {
          el.textContent = sprintf(
            __(
              'Cannot render the image. Maximum character count (%{charLimit}) has been exceeded.',
            ),
            { charLimit: MAX_CHAR_LIMIT },
          );
          return;
        }

        // Remove any extra spans added by the backend syntax highlighting.
        Object.assign(el, { textContent: source });

        mermaid.init(undefined, el, id => {
          const svg = document.getElementById(id);

          svg.classList.add('mermaid');

          // pre > code > svg
          svg.closest('pre').replaceWith(svg);

          // We need to add the original source into the DOM to allow Copy-as-GFM
          // to access it.
          const sourceEl = document.createElement('text');
          sourceEl.classList.add('source');
          sourceEl.setAttribute('display', 'none');
          sourceEl.textContent = source;

          svg.appendChild(sourceEl);
        });
      });
    })
    .catch(err => {
      flash(`Can't load mermaid module: ${err}`);
    });
}
