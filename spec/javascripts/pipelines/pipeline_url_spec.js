import Vue from 'vue';
import pipelineUrlComp from '~/pipelines/components/pipeline_url.vue';

describe('Pipeline Url Component', () => {
  let PipelineUrlComponent;

  beforeEach(() => {
    PipelineUrlComponent = Vue.extend(pipelineUrlComp);
  });

  it('should render a table cell', () => {
    const component = new PipelineUrlComponent({
      propsData: {
        pipeline: {
          id: 1,
          path: 'foo',
          flags: {},
        },
        autoDevopsHelpPath: 'foo',
      },
    }).$mount();

    expect(component.$el.getAttribute('class')).toContain('table-section');
  });

  it('should render a link the provided path and id', () => {
    const component = new PipelineUrlComponent({
      propsData: {
        pipeline: {
          id: 1,
          path: 'foo',
          flags: {},
        },
        autoDevopsHelpPath: 'foo',
      },
    }).$mount();

    expect(component.$el.querySelector('.js-pipeline-url-link').getAttribute('href')).toEqual(
      'foo',
    );

    expect(component.$el.querySelector('.js-pipeline-url-link span').textContent).toEqual('#1');
  });

  it('should render user information when a user is provided', () => {
    const mockData = {
      pipeline: {
        id: 1,
        path: 'foo',
        flags: {},
        user: {
          web_url: '/',
          name: 'foo',
          avatar_url: '/',
          path: '/',
        },
      },
      autoDevopsHelpPath: 'foo',
    };

    const component = new PipelineUrlComponent({
      propsData: mockData,
    }).$mount();

    const image = component.$el.querySelector('.js-pipeline-url-user img');
    const tooltip = component.$el.querySelector(
      '.js-pipeline-url-user .js-user-avatar-image-toolip',
    );

    expect(component.$el.querySelector('.js-pipeline-url-user').getAttribute('href')).toEqual(
      mockData.pipeline.user.web_url,
    );

    expect(tooltip.textContent.trim()).toEqual(mockData.pipeline.user.name);
    expect(image.getAttribute('src')).toEqual(`${mockData.pipeline.user.avatar_url}?width=20`);
  });

  it('should render "API" when no user is provided', () => {
    const component = new PipelineUrlComponent({
      propsData: {
        pipeline: {
          id: 1,
          path: 'foo',
          flags: {},
        },
        autoDevopsHelpPath: 'foo',
      },
    }).$mount();

    expect(component.$el.querySelector('.js-pipeline-url-api').textContent).toContain('API');
  });

  it('should render latest, yaml invalid, merge request, and stuck flags when provided', () => {
    const component = new PipelineUrlComponent({
      propsData: {
        pipeline: {
          id: 1,
          path: 'foo',
          flags: {
            latest: true,
            yaml_errors: true,
            stuck: true,
            merge_request_pipeline: true,
            detached_merge_request_pipeline: true,
          },
        },
        autoDevopsHelpPath: 'foo',
      },
    }).$mount();

    expect(component.$el.querySelector('.js-pipeline-url-latest').textContent).toContain('latest');

    expect(component.$el.querySelector('.js-pipeline-url-yaml').textContent).toContain(
      'yaml invalid',
    );

    expect(component.$el.querySelector('.js-pipeline-url-stuck').textContent).toContain('stuck');

    expect(component.$el.querySelector('.js-pipeline-url-detached').textContent).toContain(
      'detached',
    );
  });

  it('should render a badge for autodevops', () => {
    const component = new PipelineUrlComponent({
      propsData: {
        pipeline: {
          id: 1,
          path: 'foo',
          flags: {
            latest: true,
            yaml_errors: true,
            stuck: true,
            auto_devops: true,
          },
        },
        autoDevopsHelpPath: 'foo',
      },
    }).$mount();

    expect(component.$el.querySelector('.js-pipeline-url-autodevops').textContent.trim()).toEqual(
      'Auto DevOps',
    );
  });

  it('should render error badge when pipeline has a failure reason set', () => {
    const component = new PipelineUrlComponent({
      propsData: {
        pipeline: {
          id: 1,
          path: 'foo',
          flags: {
            failure_reason: true,
          },
          failure_reason: 'some reason',
        },
        autoDevopsHelpPath: 'foo',
      },
    }).$mount();

    expect(component.$el.querySelector('.js-pipeline-url-failure').textContent).toContain('error');
    expect(
      component.$el.querySelector('.js-pipeline-url-failure').getAttribute('data-original-title'),
    ).toContain('some reason');
  });
});
