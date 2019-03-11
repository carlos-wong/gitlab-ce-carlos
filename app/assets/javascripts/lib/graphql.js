import ApolloClient from 'apollo-boost';
import csrf from '~/lib/utils/csrf';

export default (clientState = {}) =>
  new ApolloClient({
    uri: `${gon.relative_url_root}/api/graphql`,
    headers: {
      [csrf.headerKey]: csrf.token,
    },
    clientState,
  });
