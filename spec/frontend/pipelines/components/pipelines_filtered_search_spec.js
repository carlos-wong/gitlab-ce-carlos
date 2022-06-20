import { GlFilteredSearch } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import Api from '~/api';
import axios from '~/lib/utils/axios_utils';
import PipelinesFilteredSearch from '~/pipelines/components/pipelines_list/pipelines_filtered_search.vue';
import { OPERATOR_IS_ONLY } from '~/vue_shared/components/filtered_search_bar/constants';
import { users, mockSearch, branches, tags } from '../mock_data';

describe('Pipelines filtered search', () => {
  let wrapper;
  let mock;

  const findFilteredSearch = () => wrapper.find(GlFilteredSearch);
  const getSearchToken = (type) =>
    findFilteredSearch()
      .props('availableTokens')
      .find((token) => token.type === type);
  const findBranchToken = () => getSearchToken('ref');
  const findTagToken = () => getSearchToken('tag');
  const findUserToken = () => getSearchToken('username');
  const findStatusToken = () => getSearchToken('status');
  const findSourceToken = () => getSearchToken('source');

  const createComponent = (params = {}) => {
    wrapper = mount(PipelinesFilteredSearch, {
      propsData: {
        projectId: '21',
        defaultBranchName: 'main',
        params,
      },
      attachTo: document.body,
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);

    jest.spyOn(Api, 'projectUsers').mockResolvedValue(users);
    jest.spyOn(Api, 'branches').mockResolvedValue({ data: branches });
    jest.spyOn(Api, 'tags').mockResolvedValue({ data: tags });

    createComponent();
  });

  afterEach(() => {
    mock.restore();
    wrapper.destroy();
    wrapper = null;
  });

  it('displays UI elements', () => {
    expect(findFilteredSearch().exists()).toBe(true);
  });

  it('displays search tokens', () => {
    expect(findUserToken()).toMatchObject({
      type: 'username',
      icon: 'user',
      title: 'Trigger author',
      unique: true,
      projectId: '21',
      operators: OPERATOR_IS_ONLY,
    });

    expect(findBranchToken()).toMatchObject({
      type: 'ref',
      icon: 'branch',
      title: 'Branch name',
      unique: true,
      projectId: '21',
      defaultBranchName: 'main',
      operators: OPERATOR_IS_ONLY,
    });

    expect(findSourceToken()).toMatchObject({
      type: 'source',
      icon: 'trigger-source',
      title: 'Source',
      unique: true,
      operators: OPERATOR_IS_ONLY,
    });

    expect(findStatusToken()).toMatchObject({
      type: 'status',
      icon: 'status',
      title: 'Status',
      unique: true,
      operators: OPERATOR_IS_ONLY,
    });

    expect(findTagToken()).toMatchObject({
      type: 'tag',
      icon: 'tag',
      title: 'Tag name',
      unique: true,
      operators: OPERATOR_IS_ONLY,
    });
  });

  it('emits filterPipelines on submit with correct filter', () => {
    findFilteredSearch().vm.$emit('submit', mockSearch);

    expect(wrapper.emitted('filterPipelines')).toBeTruthy();
    expect(wrapper.emitted('filterPipelines')[0]).toEqual([mockSearch]);
  });

  it('disables tag name token when branch name token is active', async () => {
    findFilteredSearch().vm.$emit('input', [
      { type: 'ref', value: { data: 'branch-1', operator: '=' } },
      { type: 'filtered-search-term', value: { data: '' } },
    ]);

    await nextTick();
    expect(findBranchToken().disabled).toBe(false);
    expect(findTagToken().disabled).toBe(true);
  });

  it('disables branch name token when tag name token is active', async () => {
    findFilteredSearch().vm.$emit('input', [
      { type: 'tag', value: { data: 'tag-1', operator: '=' } },
      { type: 'filtered-search-term', value: { data: '' } },
    ]);

    await nextTick();
    expect(findBranchToken().disabled).toBe(true);
    expect(findTagToken().disabled).toBe(false);
  });

  it('resets tokens disabled state on clear', async () => {
    findFilteredSearch().vm.$emit('clearInput');

    await nextTick();
    expect(findBranchToken().disabled).toBe(false);
    expect(findTagToken().disabled).toBe(false);
  });

  it('resets tokens disabled state when clearing tokens by backspace', async () => {
    findFilteredSearch().vm.$emit('input', [{ type: 'filtered-search-term', value: { data: '' } }]);

    await nextTick();
    expect(findBranchToken().disabled).toBe(false);
    expect(findTagToken().disabled).toBe(false);
  });

  describe('Url query params', () => {
    const params = {
      username: 'deja.green',
      ref: 'main',
    };

    beforeEach(() => {
      createComponent(params);
    });

    it('sets default value if url query params', () => {
      const expectedValueProp = [
        {
          type: 'username',
          value: {
            data: params.username,
            operator: '=',
          },
        },
        {
          type: 'ref',
          value: {
            data: params.ref,
            operator: '=',
          },
        },
        { type: 'filtered-search-term', value: { data: '' } },
      ];

      expect(findFilteredSearch().props('value')).toMatchObject(expectedValueProp);
      expect(findFilteredSearch().props('value')).toHaveLength(expectedValueProp.length);
    });
  });
});
