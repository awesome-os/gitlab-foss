import * as Sentry from '~/sentry/sentry_browser_wrapper';

export const reportToSentry = (component, error) => {
  Sentry.captureException(error, {
    tags: {
      component,
    },
  });
};

export const buildFixPipelineContext = ({ sourceBranch, source, mergeRequestPath } = {}) => {
  return [
    {
      Category: 'merge_request',
      Content: JSON.stringify({
        url: mergeRequestPath || '',
      }),
    },
    {
      Category: 'pipeline',
      Content: JSON.stringify({
        source_branch: sourceBranch || '',
        source: source || '',
      }),
    },
  ];
};

export const createSubscriptionsCollection = () => {
  const subscriptions = new Map();

  return {
    syncSubscriptions(ids, factory) {
      const desiredSet = new Set(ids);
      for (const [id, unsubscribe] of subscriptions) {
        if (!desiredSet.has(id)) {
          unsubscribe();
          subscriptions.delete(id);
        }
      }
      for (const id of ids) {
        if (!subscriptions.has(id)) {
          const unsubscribe = factory(id);
          subscriptions.set(id, unsubscribe);
        }
      }
    },
    unsubscribeAll() {
      for (const unsubscribe of subscriptions.values()) {
        unsubscribe();
      }
      subscriptions.clear();
    },
  };
};
