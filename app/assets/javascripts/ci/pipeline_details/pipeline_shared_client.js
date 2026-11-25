import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import cacheConfig from './jobs/graphql/cache_config';

export const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient({}, { cacheConfig }),
});
