import axios from '../../lib/utils/axios_utils';
import Api from '~/api';

export default class PipelinesService {
  /**
   * Commits and merge request endpoints need to be requested with `.json`.
   *
   * The url provided to request the pipelines in the new merge request
   * page already has `.json`.
   *
   * @param  {String} root
   */
  constructor(root) {
    if (root.indexOf('.json') === -1) {
      this.endpoint = `${root}.json`;
    } else {
      this.endpoint = root;
    }
  }

  getPipelines(data = {}) {
    const { scope, page } = data;
    const { CancelToken } = axios;

    this.cancelationSource = CancelToken.source();

    return axios.get(this.endpoint, {
      params: { scope, page },
      cancelToken: this.cancelationSource.token,
    });
  }

  /**
   * Post request for all pipelines actions.
   *
   * @param  {String} endpoint
   * @return {Promise}
   */
  // eslint-disable-next-line class-methods-use-this
  postAction(endpoint) {
    return axios.post(`${endpoint}.json`);
  }

  // eslint-disable-next-line class-methods-use-this
  runMRPipeline({ projectId, mergeRequestId }) {
    return Api.postMergeRequestPipeline(projectId, { mergeRequestId });
  }
}
