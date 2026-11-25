import { buildFixPipelineContext, createSubscriptionsCollection } from '~/ci/utils';

describe('buildFixPipelineContext util', () => {
  it('returns correct context structure', () => {
    const context = buildFixPipelineContext({
      source: 'push',
      sourceBranch: 'duo/fix/2954-fix-check-math-expression',
      mergeRequestPath: 'http://example.com/gitlab-duo/fix-pipeline-flow/-/merge_requests/13',
    });

    expect(context).toEqual([
      {
        Category: 'merge_request',
        Content: JSON.stringify({
          url: 'http://example.com/gitlab-duo/fix-pipeline-flow/-/merge_requests/13',
        }),
      },
      {
        Category: 'pipeline',
        Content: JSON.stringify({
          source_branch: 'duo/fix/2954-fix-check-math-expression',
          source: 'push',
        }),
      },
    ]);
  });

  it('returns empty-string content when called without arguments', () => {
    expect(buildFixPipelineContext()).toEqual([
      {
        Category: 'merge_request',
        Content: JSON.stringify({ url: '' }),
      },
      {
        Category: 'pipeline',
        Content: JSON.stringify({ source_branch: '', source: '' }),
      },
    ]);
  });

  it('coerces null values to empty strings', () => {
    const context = buildFixPipelineContext({
      source: null,
      sourceBranch: null,
      mergeRequestPath: null,
    });

    expect(context).toEqual([
      {
        Category: 'merge_request',
        Content: JSON.stringify({ url: '' }),
      },
      {
        Category: 'pipeline',
        Content: JSON.stringify({ source_branch: '', source: '' }),
      },
    ]);
  });
});

describe('createSubscriptionsCollection', () => {
  let collection;
  let unsubscribeMocks;
  let factory;

  beforeEach(() => {
    unsubscribeMocks = new Map();
    factory = jest.fn((id) => {
      const unsubscribe = jest.fn();
      unsubscribeMocks.set(id, unsubscribe);
      return unsubscribe;
    });
    collection = createSubscriptionsCollection();
  });

  describe('syncSubscriptions', () => {
    it('subscribes to every id when there are no existing subscriptions', () => {
      collection.syncSubscriptions(['1', '2'], factory);

      expect(factory).toHaveBeenCalledTimes(2);
      expect(factory).toHaveBeenCalledWith('1');
      expect(factory).toHaveBeenCalledWith('2');
    });

    it('does not resubscribe to ids that are already subscribed', () => {
      collection.syncSubscriptions(['1', '2'], factory);
      factory.mockClear();

      collection.syncSubscriptions(['1', '2'], factory);

      expect(factory).not.toHaveBeenCalled();
    });

    it('subscribes only to newly added ids', () => {
      collection.syncSubscriptions(['1'], factory);
      factory.mockClear();

      collection.syncSubscriptions(['1', '2'], factory);

      expect(factory).toHaveBeenCalledTimes(1);
      expect(factory).toHaveBeenCalledWith('2');
    });

    it('unsubscribes from ids that are no longer desired', () => {
      collection.syncSubscriptions(['1', '2'], factory);

      collection.syncSubscriptions(['1'], factory);

      expect(unsubscribeMocks.get('2')).toHaveBeenCalledTimes(1);
      expect(unsubscribeMocks.get('1')).not.toHaveBeenCalled();
    });

    it('resubscribes to an id that was removed and then desired again', () => {
      collection.syncSubscriptions(['1'], factory);

      collection.syncSubscriptions([], factory);
      factory.mockClear();

      collection.syncSubscriptions(['1'], factory);

      expect(factory).toHaveBeenCalledTimes(1);
      expect(factory).toHaveBeenCalledWith('1');
    });

    it('unsubscribes from all ids when synced with an empty list', () => {
      collection.syncSubscriptions(['1', '2'], factory);

      collection.syncSubscriptions([], factory);

      expect(unsubscribeMocks.get('1')).toHaveBeenCalledTimes(1);
      expect(unsubscribeMocks.get('2')).toHaveBeenCalledTimes(1);
    });
  });

  describe('unsubscribeAll', () => {
    it('unsubscribes from every current subscription', () => {
      collection.syncSubscriptions(['1', '2'], factory);

      collection.unsubscribeAll();

      expect(unsubscribeMocks.get('1')).toHaveBeenCalledTimes(1);
      expect(unsubscribeMocks.get('2')).toHaveBeenCalledTimes(1);
    });

    it('clears the collection so a subsequent sync resubscribes', () => {
      collection.syncSubscriptions(['1'], factory);
      collection.unsubscribeAll();
      factory.mockClear();

      collection.syncSubscriptions(['1'], factory);

      expect(factory).toHaveBeenCalledTimes(1);
      expect(factory).toHaveBeenCalledWith('1');
    });

    it('does not throw when there are no subscriptions', () => {
      expect(() => collection.unsubscribeAll()).not.toThrow();
    });
  });
});
