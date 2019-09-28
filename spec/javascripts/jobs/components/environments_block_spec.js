import Vue from 'vue';
import component from '~/jobs/components/environments_block.vue';
import mountComponent from '../../helpers/vue_mount_component_helper';

describe('Environments block', () => {
  const Component = Vue.extend(component);
  let vm;
  const status = {
    group: 'success',
    icon: 'status_success',
    label: 'passed',
    text: 'passed',
    tooltip: 'passed',
  };

  const environment = {
    environment_path: '/environment',
    name: 'environment',
  };

  const lastDeployment = { iid: 'deployment', deployable: { build_path: 'bar' } };

  afterEach(() => {
    vm.$destroy();
  });

  describe('with last deployment', () => {
    it('renders info for most recent deployment', () => {
      vm = mountComponent(Component, {
        deploymentStatus: {
          status: 'last',
          environment,
        },
        iconStatus: status,
      });

      expect(vm.$el.textContent.trim()).toEqual(
        'This job is the most recent deployment to environment.',
      );
    });
  });

  describe('with out of date deployment', () => {
    describe('with last deployment', () => {
      it('renders info for out date and most recent', () => {
        vm = mountComponent(Component, {
          deploymentStatus: {
            status: 'out_of_date',
            environment: Object.assign({}, environment, {
              last_deployment: lastDeployment,
            }),
          },
          iconStatus: status,
        });

        expect(vm.$el.textContent.trim()).toEqual(
          'This job is an out-of-date deployment to environment. View the most recent deployment #deployment.',
        );

        expect(vm.$el.querySelector('.js-job-deployment-link').getAttribute('href')).toEqual('bar');
      });
    });

    describe('without last deployment', () => {
      it('renders info about out of date deployment', () => {
        vm = mountComponent(Component, {
          deploymentStatus: {
            status: 'out_of_date',
            environment,
          },
          iconStatus: status,
        });

        expect(vm.$el.textContent.trim()).toEqual(
          'This job is an out-of-date deployment to environment.',
        );
      });
    });
  });

  describe('with failed deployment', () => {
    it('renders info about failed deployment', () => {
      vm = mountComponent(Component, {
        deploymentStatus: {
          status: 'failed',
          environment,
        },
        iconStatus: status,
      });

      expect(vm.$el.textContent.trim()).toEqual(
        'The deployment of this job to environment did not succeed.',
      );
    });
  });

  describe('creating deployment', () => {
    describe('with last deployment', () => {
      it('renders info about creating deployment and overriding latest deployment', () => {
        vm = mountComponent(Component, {
          deploymentStatus: {
            status: 'creating',
            environment: Object.assign({}, environment, {
              last_deployment: lastDeployment,
            }),
          },
          iconStatus: status,
        });

        expect(vm.$el.textContent.trim()).toEqual(
          'This job is creating a deployment to environment and will overwrite the latest deployment.',
        );

        expect(vm.$el.querySelector('.js-job-deployment-link').getAttribute('href')).toEqual('bar');
      });
    });

    describe('without last deployment', () => {
      it('renders info about failed deployment', () => {
        vm = mountComponent(Component, {
          deploymentStatus: {
            status: 'creating',
            environment,
          },
          iconStatus: status,
        });

        expect(vm.$el.textContent.trim()).toEqual(
          'This job is creating a deployment to environment.',
        );
      });
    });

    describe('without environment', () => {
      it('does not render environment link', () => {
        vm = mountComponent(Component, {
          deploymentStatus: {
            status: 'creating',
            environment: null,
          },
          iconStatus: status,
        });

        expect(vm.$el.querySelector('.js-environment-link')).toBeNull();
      });
    });
  });

  describe('with a cluster', () => {
    it('renders the cluster link', () => {
      const cluster = {
        name: 'the-cluster',
        path: '/the-cluster-path',
      };
      vm = mountComponent(Component, {
        deploymentStatus: {
          status: 'last',
          environment: Object.assign({}, environment, {
            last_deployment: {
              ...lastDeployment,
              cluster,
            },
          }),
        },
        iconStatus: status,
      });

      expect(vm.$el.textContent.trim()).toContain('Cluster the-cluster was used.');

      expect(vm.$el.querySelector('.js-job-cluster-link').getAttribute('href')).toEqual(
        '/the-cluster-path',
      );
    });

    describe('when the cluster is missing the path', () => {
      it('renders the name without a link', () => {
        const cluster = {
          name: 'the-cluster',
        };
        vm = mountComponent(Component, {
          deploymentStatus: {
            status: 'last',
            environment: Object.assign({}, environment, {
              last_deployment: {
                ...lastDeployment,
                cluster,
              },
            }),
          },
          iconStatus: status,
        });

        expect(vm.$el.textContent.trim()).toContain('Cluster the-cluster was used.');

        expect(vm.$el.querySelector('.js-job-cluster-link')).toBeNull();
      });
    });
  });

  describe('without a cluster', () => {
    it('does not render a cluster link', () => {
      vm = mountComponent(Component, {
        deploymentStatus: {
          status: 'last',
          environment: Object.assign({}, environment, {
            last_deployment: lastDeployment,
          }),
        },
        iconStatus: status,
      });

      expect(vm.$el.querySelector('.js-job-cluster-link')).toBeNull();
    });
  });
});
