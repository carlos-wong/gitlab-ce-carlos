import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { spriteIcon } from '~/lib/utils/common_utils';
import { __, s__ } from '~/locale';

export default class Star {
  constructor(containerSelector = '.project-home-panel') {
    const container = document.querySelector(containerSelector);
    const starToggle = container.querySelector('.toggle-star');
    starToggle.addEventListener('click', function toggleStarClickCallback() {
      const starSpan = starToggle.querySelector('span');
      const starIcon = starToggle.querySelector('svg');
      const iconClasses = Array.from(starIcon.classList.values());

      axios
        .post(starToggle.dataset.endpoint)
        .then(({ data }) => {
          const isStarred = starSpan.classList.contains('starred');
          starToggle.parentNode.querySelector('.count').textContent = data.star_count;

          if (isStarred) {
            starSpan.classList.remove('starred');
            starSpan.textContent = s__('StarProject|Star');
            starIcon.remove();
            starSpan.insertAdjacentHTML('beforebegin', spriteIcon('star-o', iconClasses));
          } else {
            starSpan.classList.add('starred');
            starSpan.textContent = __('Unstar');
            starIcon.remove();
            starSpan.insertAdjacentHTML('beforebegin', spriteIcon('star', iconClasses));
          }
        })
        .catch(() =>
          createFlash({
            message: __('Star toggle failed. Try again later.'),
          }),
        );
    });
  }
}
