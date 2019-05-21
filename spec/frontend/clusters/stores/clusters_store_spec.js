import ClustersStore from '~/clusters/stores/clusters_store';
import { APPLICATION_INSTALLED_STATUSES, APPLICATION_STATUS, RUNNER } from '~/clusters/constants';
import { CLUSTERS_MOCK_DATA } from '../services/mock_data';

describe('Clusters Store', () => {
  let store;

  beforeEach(() => {
    store = new ClustersStore();
  });

  describe('updateStatus', () => {
    it('should store new status', () => {
      expect(store.state.status).toEqual(null);

      const newStatus = 'errored';
      store.updateStatus(newStatus);

      expect(store.state.status).toEqual(newStatus);
    });
  });

  describe('updateStatusReason', () => {
    it('should store new reason', () => {
      expect(store.state.statusReason).toEqual(null);

      const newReason = 'Something went wrong!';
      store.updateStatusReason(newReason);

      expect(store.state.statusReason).toEqual(newReason);
    });
  });

  describe('updateAppProperty', () => {
    it('should store new request reason', () => {
      expect(store.state.applications.helm.requestReason).toEqual(null);

      const newReason = 'We broke it.';
      store.updateAppProperty('helm', 'requestReason', newReason);

      expect(store.state.applications.helm.requestReason).toEqual(newReason);
    });
  });

  describe('updateStateFromServer', () => {
    it('should store new polling data from server', () => {
      const mockResponseData =
        CLUSTERS_MOCK_DATA.GET['/gitlab-org/gitlab-shell/clusters/1/status.json'].data;
      store.updateStateFromServer(mockResponseData);

      expect(store.state).toEqual({
        helpPath: null,
        ingressHelpPath: null,
        status: mockResponseData.status,
        statusReason: mockResponseData.status_reason,
        rbac: false,
        applications: {
          helm: {
            title: 'Helm Tiller',
            status: mockResponseData.applications[0].status,
            statusReason: mockResponseData.applications[0].status_reason,
            requestReason: null,
            installed: false,
            installFailed: false,
            uninstallable: false,
            uninstallSuccessful: false,
            uninstallFailed: false,
          },
          ingress: {
            title: 'Ingress',
            status: APPLICATION_STATUS.INSTALLABLE,
            statusReason: mockResponseData.applications[1].status_reason,
            requestReason: null,
            externalIp: null,
            externalHostname: null,
            installed: false,
            installFailed: true,
            uninstallable: false,
            uninstallSuccessful: false,
            uninstallFailed: false,
          },
          runner: {
            title: 'GitLab Runner',
            status: mockResponseData.applications[2].status,
            statusReason: mockResponseData.applications[2].status_reason,
            requestReason: null,
            version: mockResponseData.applications[2].version,
            upgradeAvailable: mockResponseData.applications[2].update_available,
            chartRepo: 'https://gitlab.com/charts/gitlab-runner',
            installed: false,
            installFailed: false,
            updateAcknowledged: true,
            updateFailed: false,
            updateSuccessful: false,
            uninstallable: false,
            uninstallSuccessful: false,
            uninstallFailed: false,
          },
          prometheus: {
            title: 'Prometheus',
            status: APPLICATION_STATUS.INSTALLABLE,
            statusReason: mockResponseData.applications[3].status_reason,
            requestReason: null,
            installed: false,
            installFailed: true,
            uninstallable: false,
            uninstallSuccessful: false,
            uninstallFailed: false,
          },
          jupyter: {
            title: 'JupyterHub',
            status: mockResponseData.applications[4].status,
            statusReason: mockResponseData.applications[4].status_reason,
            requestReason: null,
            hostname: '',
            installed: false,
            installFailed: false,
            uninstallable: false,
            uninstallSuccessful: false,
            uninstallFailed: false,
          },
          knative: {
            title: 'Knative',
            status: mockResponseData.applications[5].status,
            statusReason: mockResponseData.applications[5].status_reason,
            requestReason: null,
            hostname: null,
            isEditingHostName: false,
            externalIp: null,
            externalHostname: null,
            installed: false,
            installFailed: false,
            uninstallable: false,
            uninstallSuccessful: false,
            uninstallFailed: false,
          },
          cert_manager: {
            title: 'Cert-Manager',
            status: APPLICATION_STATUS.INSTALLABLE,
            installFailed: true,
            statusReason: mockResponseData.applications[6].status_reason,
            requestReason: null,
            email: mockResponseData.applications[6].email,
            installed: false,
            uninstallable: false,
            uninstallSuccessful: false,
            uninstallFailed: false,
          },
        },
      });
    });

    describe.each(APPLICATION_INSTALLED_STATUSES)('given the current app status is %s', status => {
      it('marks application as installed', () => {
        const mockResponseData =
          CLUSTERS_MOCK_DATA.GET['/gitlab-org/gitlab-shell/clusters/2/status.json'].data;
        const runnerAppIndex = 2;

        mockResponseData.applications[runnerAppIndex].status = status;

        store.updateStateFromServer(mockResponseData);

        expect(store.state.applications[RUNNER].installed).toBe(true);
      });
    });

    it('sets default hostname for jupyter when ingress has a ip address', () => {
      const mockResponseData =
        CLUSTERS_MOCK_DATA.GET['/gitlab-org/gitlab-shell/clusters/2/status.json'].data;

      store.updateStateFromServer(mockResponseData);

      expect(store.state.applications.jupyter.hostname).toEqual(
        `jupyter.${store.state.applications.ingress.externalIp}.nip.io`,
      );
    });
  });
});
