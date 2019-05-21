import Clusters from '~/clusters/clusters_bundle';
import { APPLICATION_STATUS, INGRESS_DOMAIN_SUFFIX, APPLICATIONS } from '~/clusters/constants';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { loadHTMLFixture } from 'helpers/fixtures';
import { setTestTimeout } from 'helpers/timeout';
import $ from 'jquery';

const { INSTALLING, INSTALLABLE, INSTALLED, UNINSTALLING } = APPLICATION_STATUS;

describe('Clusters', () => {
  setTestTimeout(1000);

  let cluster;
  let mock;

  const mockGetClusterStatusRequest = () => {
    const { statusPath } = document.querySelector('.js-edit-cluster-form').dataset;

    mock = new MockAdapter(axios);

    mock.onGet(statusPath).reply(200);
  };

  beforeEach(() => {
    loadHTMLFixture('clusters/show_cluster.html');
  });

  beforeEach(() => {
    mockGetClusterStatusRequest();
  });

  beforeEach(() => {
    cluster = new Clusters();
  });

  afterEach(() => {
    cluster.destroy();
    mock.restore();
  });

  describe('toggle', () => {
    it('should update the button and the input field on click', done => {
      const toggleButton = document.querySelector(
        '.js-cluster-enable-toggle-area .js-project-feature-toggle',
      );
      const toggleInput = document.querySelector(
        '.js-cluster-enable-toggle-area .js-project-feature-toggle-input',
      );

      $(toggleInput).one('trigger-change', () => {
        expect(toggleButton.classList).not.toContain('is-checked');
        expect(toggleInput.getAttribute('value')).toEqual('false');
        done();
      });

      toggleButton.click();
    });
  });

  describe('showToken', () => {
    it('should update token field type', () => {
      cluster.showTokenButton.click();

      expect(cluster.tokenField.getAttribute('type')).toEqual('text');

      cluster.showTokenButton.click();

      expect(cluster.tokenField.getAttribute('type')).toEqual('password');
    });

    it('should update show token button text', () => {
      cluster.showTokenButton.click();

      expect(cluster.showTokenButton.textContent).toEqual('Hide');

      cluster.showTokenButton.click();

      expect(cluster.showTokenButton.textContent).toEqual('Show');
    });
  });

  describe('checkForNewInstalls', () => {
    const INITIAL_APP_MAP = {
      helm: { status: null, title: 'Helm Tiller' },
      ingress: { status: null, title: 'Ingress' },
      runner: { status: null, title: 'GitLab Runner' },
    };

    it('does not show alert when things transition from initial null state to something', () => {
      cluster.checkForNewInstalls(INITIAL_APP_MAP, {
        ...INITIAL_APP_MAP,
        helm: { status: INSTALLABLE, title: 'Helm Tiller' },
      });

      const flashMessage = document.querySelector('.js-cluster-application-notice .flash-text');

      expect(flashMessage).toBeNull();
    });

    it('shows an alert when something gets newly installed', () => {
      cluster.checkForNewInstalls(
        {
          ...INITIAL_APP_MAP,
          helm: { status: INSTALLING, title: 'Helm Tiller' },
        },
        {
          ...INITIAL_APP_MAP,
          helm: { status: INSTALLED, title: 'Helm Tiller' },
        },
      );

      const flashMessage = document.querySelector('.js-cluster-application-notice .flash-text');

      expect(flashMessage).not.toBeNull();
      expect(flashMessage.textContent.trim()).toEqual(
        'Helm Tiller was successfully installed on your Kubernetes cluster',
      );
    });

    it('shows an alert when multiple things gets newly installed', () => {
      cluster.checkForNewInstalls(
        {
          ...INITIAL_APP_MAP,
          helm: { status: INSTALLING, title: 'Helm Tiller' },
          ingress: { status: INSTALLABLE, title: 'Ingress' },
        },
        {
          ...INITIAL_APP_MAP,
          helm: { status: INSTALLED, title: 'Helm Tiller' },
          ingress: { status: INSTALLED, title: 'Ingress' },
        },
      );

      const flashMessage = document.querySelector('.js-cluster-application-notice .flash-text');

      expect(flashMessage).not.toBeNull();
      expect(flashMessage.textContent.trim()).toEqual(
        'Helm Tiller, Ingress was successfully installed on your Kubernetes cluster',
      );
    });
  });

  describe('updateContainer', () => {
    describe('when creating cluster', () => {
      it('should show the creating container', () => {
        cluster.updateContainer(null, 'creating');

        expect(cluster.creatingContainer.classList.contains('hidden')).toBeFalsy();

        expect(cluster.successContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.errorContainer.classList.contains('hidden')).toBeTruthy();
      });

      it('should continue to show `creating` banner with subsequent updates of the same status', () => {
        cluster.updateContainer('creating', 'creating');

        expect(cluster.creatingContainer.classList.contains('hidden')).toBeFalsy();

        expect(cluster.successContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.errorContainer.classList.contains('hidden')).toBeTruthy();
      });
    });

    describe('when cluster is created', () => {
      it('should show the success container and fresh the page', () => {
        cluster.updateContainer(null, 'created');

        expect(cluster.creatingContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.successContainer.classList.contains('hidden')).toBeFalsy();

        expect(cluster.errorContainer.classList.contains('hidden')).toBeTruthy();
      });

      it('should not show a banner when status is already `created`', () => {
        cluster.updateContainer('created', 'created');

        expect(cluster.creatingContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.successContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.errorContainer.classList.contains('hidden')).toBeTruthy();
      });
    });

    describe('when cluster has error', () => {
      it('should show the error container', () => {
        cluster.updateContainer(null, 'errored', 'this is an error');

        expect(cluster.creatingContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.successContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.errorContainer.classList.contains('hidden')).toBeFalsy();

        expect(cluster.errorReasonContainer.textContent).toContain('this is an error');
      });

      it('should show `error` banner when previously `creating`', () => {
        cluster.updateContainer('creating', 'errored');

        expect(cluster.creatingContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.successContainer.classList.contains('hidden')).toBeTruthy();

        expect(cluster.errorContainer.classList.contains('hidden')).toBeFalsy();
      });
    });
  });

  describe('installApplication', () => {
    it.each(APPLICATIONS)('tries to install %s', applicationId => {
      jest.spyOn(cluster.service, 'installApplication').mockResolvedValueOnce();

      cluster.store.state.applications[applicationId].status = INSTALLABLE;

      cluster.installApplication({ id: applicationId });

      expect(cluster.store.state.applications[applicationId].status).toEqual(INSTALLING);
      expect(cluster.store.state.applications[applicationId].requestReason).toEqual(null);
      expect(cluster.service.installApplication).toHaveBeenCalledWith(applicationId, undefined);
    });

    it('sets error request status when the request fails', () => {
      jest
        .spyOn(cluster.service, 'installApplication')
        .mockRejectedValueOnce(new Error('STUBBED ERROR'));

      cluster.store.state.applications.helm.status = INSTALLABLE;

      const promise = cluster.installApplication({ id: 'helm' });

      return promise.then(() => {
        expect(cluster.store.state.applications.helm.status).toEqual(INSTALLABLE);
        expect(cluster.store.state.applications.helm.installFailed).toBe(true);

        expect(cluster.store.state.applications.helm.requestReason).toBeDefined();
      });
    });
  });

  describe('uninstallApplication', () => {
    it.each(APPLICATIONS)('tries to uninstall %s', applicationId => {
      jest.spyOn(cluster.service, 'uninstallApplication').mockResolvedValueOnce();

      cluster.store.state.applications[applicationId].status = INSTALLED;

      cluster.uninstallApplication({ id: applicationId });

      expect(cluster.store.state.applications[applicationId].status).toEqual(UNINSTALLING);
      expect(cluster.store.state.applications[applicationId].requestReason).toEqual(null);
      expect(cluster.service.uninstallApplication).toHaveBeenCalledWith(applicationId);
    });

    it('sets error request status when the uninstall request fails', () => {
      jest
        .spyOn(cluster.service, 'uninstallApplication')
        .mockRejectedValueOnce(new Error('STUBBED ERROR'));

      cluster.store.state.applications.helm.status = INSTALLED;

      const promise = cluster.uninstallApplication({ id: 'helm' });

      return promise.then(() => {
        expect(cluster.store.state.applications.helm.status).toEqual(INSTALLED);
        expect(cluster.store.state.applications.helm.uninstallFailed).toBe(true);

        expect(cluster.store.state.applications.helm.requestReason).toBeDefined();
      });
    });
  });

  describe('handleSuccess', () => {
    beforeEach(() => {
      jest.spyOn(cluster.store, 'updateStateFromServer').mockReturnThis();
      jest.spyOn(cluster, 'toggleIngressDomainHelpText').mockReturnThis();
      jest.spyOn(cluster, 'checkForNewInstalls').mockReturnThis();
      jest.spyOn(cluster, 'updateContainer').mockReturnThis();

      cluster.handleSuccess({ data: {} });
    });

    it('updates clusters store', () => {
      expect(cluster.store.updateStateFromServer).toHaveBeenCalled();
    });

    it('checks for new installable apps', () => {
      expect(cluster.checkForNewInstalls).toHaveBeenCalled();
    });

    it('toggles ingress domain help text', () => {
      expect(cluster.toggleIngressDomainHelpText).toHaveBeenCalled();
    });

    it('updates message containers', () => {
      expect(cluster.updateContainer).toHaveBeenCalled();
    });
  });

  describe('toggleIngressDomainHelpText', () => {
    let ingressPreviousState;
    let ingressNewState;

    beforeEach(() => {
      ingressPreviousState = { externalIp: null };
      ingressNewState = { externalIp: '127.0.0.1' };
    });

    describe(`when ingress have an external ip assigned`, () => {
      beforeEach(() => {
        cluster.toggleIngressDomainHelpText(ingressPreviousState, ingressNewState);
      });

      it('displays custom domain help text', () => {
        expect(cluster.ingressDomainHelpText.classList.contains('hide')).toEqual(false);
      });

      it('updates ingress external ip address', () => {
        expect(cluster.ingressDomainSnippet.textContent).toEqual(
          `${ingressNewState.externalIp}${INGRESS_DOMAIN_SUFFIX}`,
        );
      });
    });

    describe(`when ingress does not have an external ip assigned`, () => {
      it('hides custom domain help text', () => {
        ingressPreviousState.externalIp = '127.0.0.1';
        ingressNewState.externalIp = null;
        cluster.ingressDomainHelpText.classList.remove('hide');

        cluster.toggleIngressDomainHelpText(ingressPreviousState, ingressNewState);

        expect(cluster.ingressDomainHelpText.classList.contains('hide')).toEqual(true);
      });
    });
  });
});
