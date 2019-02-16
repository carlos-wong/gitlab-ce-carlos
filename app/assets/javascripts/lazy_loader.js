import _ from 'underscore';

export const placeholderImage =
  'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==';
const SCROLL_THRESHOLD = 500;

export default class LazyLoader {
  constructor(options = {}) {
    this.intersectionObserver = null;
    this.lazyImages = [];
    this.observerNode = options.observerNode || '#content-body';

    const scrollContainer = options.scrollContainer || window;
    scrollContainer.addEventListener('load', () => this.register());
  }

  static supportsIntersectionObserver() {
    return 'IntersectionObserver' in window;
  }

  searchLazyImages() {
    window.requestIdleCallback(
      () => {
        const lazyImages = [].slice.call(document.querySelectorAll('.lazy'));

        if (LazyLoader.supportsIntersectionObserver()) {
          if (this.intersectionObserver) {
            lazyImages.forEach(img => this.intersectionObserver.observe(img));
          }
        } else if (lazyImages.length) {
          this.lazyImages = lazyImages;
          this.checkElementsInView();
        }
      },
      { timeout: 500 },
    );
  }

  startContentObserver() {
    const contentNode = document.querySelector(this.observerNode) || document.querySelector('body');
    if (contentNode) {
      this.mutationObserver = new MutationObserver(() => this.searchLazyImages());

      this.mutationObserver.observe(contentNode, {
        childList: true,
        subtree: true,
      });
    }
  }

  stopContentObserver() {
    if (this.mutationObserver) {
      this.mutationObserver.takeRecords();
      this.mutationObserver.disconnect();
      this.mutationObserver = null;
    }
  }

  unregister() {
    this.stopContentObserver();
    if (this.intersectionObserver) {
      this.intersectionObserver.takeRecords();
      this.intersectionObserver.disconnect();
      this.intersectionObserver = null;
    }
    if (this.throttledScrollCheck) {
      window.removeEventListener('scroll', this.throttledScrollCheck);
    }
    if (this.debouncedElementsInView) {
      window.removeEventListener('resize', this.debouncedElementsInView);
    }
  }

  register() {
    if (LazyLoader.supportsIntersectionObserver()) {
      this.startIntersectionObserver();
    } else {
      this.startLegacyObserver();
    }
    this.startContentObserver();
    this.searchLazyImages();
  }

  startIntersectionObserver = () => {
    this.throttledElementsInView = _.throttle(() => this.checkElementsInView(), 300);
    this.intersectionObserver = new IntersectionObserver(this.onIntersection, {
      rootMargin: `${SCROLL_THRESHOLD}px 0px`,
      thresholds: 0.1,
    });
  };

  onIntersection = entries => {
    entries.forEach(entry => {
      // We are using `intersectionRatio > 0` over `isIntersecting`, as some browsers did not ship the latter
      // See: https://gitlab.com/gitlab-org/gitlab-ce/issues/54407
      if (entry.intersectionRatio > 0) {
        this.intersectionObserver.unobserve(entry.target);
        this.lazyImages.push(entry.target);
      }
    });
    this.throttledElementsInView();
  };

  startLegacyObserver() {
    this.throttledScrollCheck = _.throttle(() => this.scrollCheck(), 300);
    this.debouncedElementsInView = _.debounce(() => this.checkElementsInView(), 300);
    window.addEventListener('scroll', this.throttledScrollCheck);
    window.addEventListener('resize', this.debouncedElementsInView);
  }

  scrollCheck() {
    window.requestAnimationFrame(() => this.checkElementsInView());
  }

  checkElementsInView() {
    const scrollTop = window.pageYOffset;
    const visHeight = scrollTop + window.innerHeight + SCROLL_THRESHOLD;

    // Loading Images which are in the current viewport or close to them
    this.lazyImages = this.lazyImages.filter(selectedImage => {
      if (selectedImage.getAttribute('data-src')) {
        const imgBoundRect = selectedImage.getBoundingClientRect();
        const imgTop = scrollTop + imgBoundRect.top;
        const imgBound = imgTop + imgBoundRect.height;

        if (scrollTop <= imgBound && visHeight >= imgTop) {
          window.requestAnimationFrame(() => {
            LazyLoader.loadImage(selectedImage);
          });
          return false;
        }

        /*
        If we are scrolling fast, the img we watched intersecting could have left the view port.
        So we are going watch for new intersections.
        */
        if (LazyLoader.supportsIntersectionObserver()) {
          if (this.intersectionObserver) {
            this.intersectionObserver.observe(selectedImage);
          }
          return false;
        }
        return true;
      }
      return false;
    });
  }

  static loadImage(img) {
    if (img.getAttribute('data-src')) {
      let imgUrl = img.getAttribute('data-src');
      // Only adding width + height for avatars for now
      if (imgUrl.indexOf('/avatar/') > -1 && imgUrl.indexOf('?') === -1) {
        let targetWidth = null;
        if (img.getAttribute('width')) {
          targetWidth = img.getAttribute('width');
        } else {
          targetWidth = img.width;
        }
        if (targetWidth) imgUrl += `?width=${targetWidth}`;
      }
      img.setAttribute('src', imgUrl);
      img.removeAttribute('data-src');
      img.classList.remove('lazy');
      img.classList.add('js-lazy-loaded');
      img.classList.add('qa-js-lazy-loaded');
    }
  }
}
