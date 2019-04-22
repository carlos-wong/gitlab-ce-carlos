import LinkedTabs from '~/lib/utils/bootstrap_linked_tabs';

describe('Linked Tabs', () => {
  preloadFixtures('static/linked_tabs.html');

  beforeEach(() => {
    loadFixtures('static/linked_tabs.html');
  });

  describe('when is initialized', () => {
    beforeEach(() => {
      spyOn(window.history, 'replaceState').and.callFake(function() {});
    });

    it('should activate the tab correspondent to the given action', () => {
      // eslint-disable-next-line no-new
      new LinkedTabs({
        action: 'tab1',
        defaultAction: 'tab1',
        parentEl: '.linked-tabs',
      });

      expect(document.querySelector('#tab1').classList).toContain('active');
    });

    it('should active the default tab action when the action is show', () => {
      // eslint-disable-next-line no-new
      new LinkedTabs({
        action: 'show',
        defaultAction: 'tab1',
        parentEl: '.linked-tabs',
      });

      expect(document.querySelector('#tab1').classList).toContain('active');
    });
  });

  describe('on click', () => {
    it('should change the url according to the clicked tab', () => {
      const historySpy = spyOn(window.history, 'replaceState').and.callFake(() => {});

      const linkedTabs = new LinkedTabs({
        action: 'show',
        defaultAction: 'tab1',
        parentEl: '.linked-tabs',
      });

      const secondTab = document.querySelector('.linked-tabs li:nth-child(2) a');
      const newState =
        secondTab.getAttribute('href') +
        linkedTabs.currentLocation.search +
        linkedTabs.currentLocation.hash;

      secondTab.click();

      if (historySpy) {
        expect(historySpy).toHaveBeenCalledWith(
          {
            url: newState,
          },
          document.title,
          newState,
        );
      }
    });
  });
});
