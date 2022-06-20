import $ from 'jquery';
import syntaxHighlight from '~/syntax_highlight';
import initUserPopovers from '../../user_popovers';
import highlightCurrentUser from './highlight_current_user';
import { renderKroki } from './render_kroki';
import renderMath from './render_math';
import renderMermaid from './render_mermaid';
import renderSandboxedMermaid from './render_sandboxed_mermaid';
import renderMetrics from './render_metrics';

// Render GitLab flavoured Markdown
//
// Delegates to syntax highlight and render math & mermaid diagrams.
//
$.fn.renderGFM = function renderGFM() {
  syntaxHighlight(this.find('.js-syntax-highlight').get());
  renderKroki(this.find('.js-render-kroki[hidden]').get());
  renderMath(this.find('.js-render-math'));
  if (gon.features?.sandboxedMermaid) {
    renderSandboxedMermaid(this.find('.js-render-mermaid'));
  } else {
    renderMermaid(this.find('.js-render-mermaid'));
  }
  highlightCurrentUser(this.find('.gfm-project_member').get());
  initUserPopovers(this.find('.js-user-link').get());

  const mrPopoverElements = this.find('.gfm-merge_request').get();
  if (mrPopoverElements.length) {
    import(/* webpackChunkName: 'MrPopoverBundle' */ '~/mr_popover')
      .then(({ default: initMRPopovers }) => {
        initMRPopovers(mrPopoverElements);
      })
      .catch(() => {});
  }

  renderMetrics(this.find('.js-render-metrics').get());
  return this;
};

$(() => {
  window.requestIdleCallback(
    () => {
      $('body').renderGFM();
    },
    { timeout: 500 },
  );
});
