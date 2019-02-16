import $ from 'jquery';
import { getSelector, inserted } from './feature_highlight_helper';
import { togglePopover, mouseenter, debouncedMouseleave } from '../shared/popover';

export function setupFeatureHighlightPopover(id, debounceTimeout = 300) {
  const $selector = $(getSelector(id));
  const $parent = $selector.parent();
  const $popoverContent = $parent.siblings('.feature-highlight-popover-content');
  const hideOnScroll = togglePopover.bind($selector, false);

  $selector
    // Set up popover
    .data('content', $popoverContent.prop('outerHTML'))
    .popover({
      html: true,
      // Override the existing template to add custom CSS classes
      template: `
        <div class="popover feature-highlight-popover" role="tooltip">
          <div class="arrow"></div>
          <div class="popover-body"></div>
        </div>
      `,
    })
    .on('mouseenter', mouseenter)
    .on('mouseleave', debouncedMouseleave(debounceTimeout))
    .on('inserted.bs.popover', inserted)
    .on('show.bs.popover', () => {
      window.addEventListener('scroll', hideOnScroll, { once: true });
    })
    // Display feature highlight
    .removeAttr('disabled');
}

const getPriority = e => parseInt(e.dataset.highlightPriority, 10) || 0;

export function findHighestPriorityFeature() {
  let priorityFeature;

  const sortedFeatureEls = [].slice
    .call(document.querySelectorAll('.js-feature-highlight'))
    .sort((a, b) => getPriority(b) - getPriority(a));

  const [priorityFeatureEl] = sortedFeatureEls;
  if (priorityFeatureEl) {
    priorityFeature = priorityFeatureEl.dataset.highlight;
  }

  return priorityFeature;
}

export function highlightFeatures() {
  const priorityFeature = findHighestPriorityFeature();

  if (priorityFeature) {
    setupFeatureHighlightPopover(priorityFeature);
  }

  return priorityFeature;
}
