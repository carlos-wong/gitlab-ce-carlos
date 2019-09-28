import Vuex from 'vuex';
import * as actions from './actions';
import * as getters from './getters';
import mutations from './mutations';
import state from './state';

const createStore = () =>
  new Vuex.Store({
    actions,
    getters,
    mutations,
    state,
  });

export default createStore;
