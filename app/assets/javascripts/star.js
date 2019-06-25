import $ from 'jquery';
import Flash from './flash';
import { __, s__ } from './locale';
import { spriteIcon } from './lib/utils/common_utils';
import axios from './lib/utils/axios_utils';

export default class Star {
  constructor(container = '.project-home-panel') {
    $(`${container} .toggle-star`).on('click', function toggleStarClickCallback() {
      const $this = $(this);
      const $starSpan = $this.find('span');
      const $starIcon = $this.find('svg');
      const iconClasses = $starIcon.attr('class').split(' ');

      axios
        .post($this.data('endpoint'))
        .then(({ data }) => {
          const isStarred = $starSpan.hasClass('starred');
          $this
            .parent()
            .find('.star-count')
            .text(data.star_count);

          if (isStarred) {
            $starSpan.removeClass('starred').text(s__('StarProject|Star'));
            $starIcon.remove();
            $this.prepend(spriteIcon('star-o', iconClasses));
          } else {
            $starSpan.addClass('starred').text(__('Unstar'));
            $starIcon.remove();
            $this.prepend(spriteIcon('star', iconClasses));
          }
        })
        .catch(() => Flash(__('Star toggle failed. Try again later.')));
    });
  }
}
