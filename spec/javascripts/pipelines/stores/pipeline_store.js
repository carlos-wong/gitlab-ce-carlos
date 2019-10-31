import PipelineStore from '~/pipelines/stores/pipeline_store';
import LinkedPipelines from '../linked_pipelines_mock.json';

describe('EE Pipeline store', () => {
  let store;
  let data;

  beforeEach(() => {
    store = new PipelineStore();
    data = Object.assign({}, LinkedPipelines);
  });

  describe('storePipeline', () => {
    beforeAll(() => {
      store.storePipeline(data);
    });

    describe('triggered_by', () => {
      it('sets triggered_by as an array', () => {
        expect(store.state.pipeline.triggered_by.length).toEqual(1);
      });

      it('adds isExpanding & isLoading keys set to false', () => {
        expect(store.state.pipeline.triggered_by[0].isExpanded).toEqual(false);
        expect(store.state.pipeline.triggered_by[0].isLoading).toEqual(false);
      });

      it('parses nested triggered_by', () => {
        expect(store.state.pipeline.triggered_by[0].triggered_by.length).toEqual(1);
        expect(store.state.pipeline.triggered_by[0].triggered_by[0].isExpanded).toEqual(false);
        expect(store.state.pipeline.triggered_by[0].triggered_by[0].isLoading).toEqual(false);
      });
    });

    describe('triggered', () => {
      it('adds isExpanding & isLoading keys set to false for each triggered pipeline', () => {
        store.state.pipeline.triggered.forEach(pipeline => {
          expect(pipeline.isExpanded).toEqual(false);
          expect(pipeline.isLoading).toEqual(false);
        });
      });

      it('parses nested triggered pipelines', () => {
        store.state.pipeline.triggered[1].triggered.forEach(pipeline => {
          expect(pipeline.isExpanded).toEqual(false);
          expect(pipeline.isLoading).toEqual(false);
        });
      });
    });
  });

  describe('resetTriggeredByPipeline', () => {
    beforeEach(() => {
      store.storePipeline(data);
    });

    it('closes the pipeline & nested ones', () => {
      store.state.pipeline.triggered_by[0].isExpanded = true;
      store.state.pipeline.triggered_by[0].triggered_by[0].isExpanded = true;

      store.resetTriggeredByPipeline(store.state.pipeline, store.state.pipeline.triggered_by[0]);

      expect(store.state.pipeline.triggered_by[0].isExpanded).toEqual(false);
      expect(store.state.pipeline.triggered_by[0].triggered_by[0].isExpanded).toEqual(false);
    });
  });

  describe('openTriggeredByPipeline', () => {
    beforeEach(() => {
      store.storePipeline(data);
    });

    it('opens the given pipeline', () => {
      store.openTriggeredByPipeline(store.state.pipeline, store.state.pipeline.triggered_by[0]);

      expect(store.state.pipeline.triggered_by[0].isExpanded).toEqual(true);
    });
  });

  describe('closeTriggeredByPipeline', () => {
    beforeEach(() => {
      store.storePipeline(data);
    });

    it('closes the given pipeline', () => {
      // open it first
      store.openTriggeredByPipeline(store.state.pipeline, store.state.pipeline.triggered_by[0]);

      store.closeTriggeredByPipeline(store.state.pipeline, store.state.pipeline.triggered_by[0]);

      expect(store.state.pipeline.triggered_by[0].isExpanded).toEqual(false);
    });
  });

  describe('resetTriggeredPipelines', () => {
    beforeEach(() => {
      store.storePipeline(data);
    });

    it('closes the pipeline & nested ones', () => {
      store.state.pipeline.triggered[0].isExpanded = true;
      store.state.pipeline.triggered[0].triggered[0].isExpanded = true;

      store.resetTriggeredPipeline(store.state.pipeline, store.state.pipeline.triggered[0]);

      expect(store.state.pipeline.triggered[0].isExpanded).toEqual(false);
      expect(store.state.pipeline.triggered[0].triggered[0].isExpanded).toEqual(false);
    });
  });

  describe('openTriggeredPipeline', () => {
    beforeEach(() => {
      store.storePipeline(data);
    });

    it('opens the given pipeline', () => {
      store.openTriggeredPipeline(store.state.pipeline, store.state.pipeline.triggered[0]);

      expect(store.state.pipeline.triggered[0].isExpanded).toEqual(true);
    });
  });

  describe('closeTriggeredPipeline', () => {
    beforeEach(() => {
      store.storePipeline(data);
    });

    it('closes the given pipeline', () => {
      // open it first
      store.openTriggeredPipeline(store.state.pipeline, store.state.pipeline.triggered[0]);

      store.closeTriggeredPipeline(store.state.pipeline, store.state.pipeline.triggered[0]);

      expect(store.state.pipeline.triggered[0].isExpanded).toEqual(false);
    });
  });

  describe('toggleLoading', () => {
    beforeEach(() => {
      store.storePipeline(data);
    });

    it('toggles the isLoading property for the given pipeline', () => {
      store.togglePipeline(store.state.pipeline.triggered[0]);

      expect(store.state.pipeline.triggered[0].isLoading).toEqual(true);
    });
  });

  describe('addExpandedPipelineToRequestData', () => {
    it('pushes the given id to expandedPipelines array', () => {
      store.addExpandedPipelineToRequestData('213231');

      expect(store.state.expandedPipelines).toEqual(['213231']);
    });
  });

  describe('removeExpandedPipelineToRequestData', () => {
    it('pushes the given id to expandedPipelines array', () => {
      store.removeExpandedPipelineToRequestData('213231');

      expect(store.state.expandedPipelines).toEqual([]);
    });
  });
});
