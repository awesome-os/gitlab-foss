import {
  readWorkItemConnectionFromColumn,
  readWorkItemFromColumn,
  readWorkItemsFromColumn,
  removeWorkItemFromColumn,
  addWorkItemToColumn,
  adjustWorkItemCountInColumn,
} from '~/work_items/board/graphql/cache_updates';

describe('board cache_updates', () => {
  const query = { fake: 'query' };
  const variables = { fake: 'variables' };
  const workItemA = { id: 'gid://gitlab/WorkItem/1', title: 'A' };
  const workItemB = { id: 'gid://gitlab/WorkItem/2', title: 'B' };
  const workItemC = { id: 'gid://gitlab/WorkItem/3', title: 'C' };

  const buildRestData = (nodes, pageInfo) => ({
    restWorkItems: { nodes, ...(pageInfo ? { pageInfo } : {}) },
  });

  const buildCountData = (count) => ({
    namespace: {
      workItems: {
        ...(typeof count === 'number' ? { timeLimitedCount: count } : {}),
      },
    },
  });

  // Minimal cache stub that just holds a single "row" of data and lets the
  // helpers exercise both read and updateQuery flows.
  const createCache = (initialData) => {
    let stored = initialData;
    return {
      readQuery: jest.fn(() => stored),
      updateQuery: jest.fn((_options, updater) => {
        const result = updater(stored);
        if (result !== undefined) {
          stored = result;
        }
      }),
      getStored: () => stored,
    };
  };

  describe('column helpers', () => {
    describe('readWorkItemFromColumn', () => {
      it('returns a deep clone of the matching node', () => {
        const cache = createCache(buildRestData([workItemA, workItemB]));

        const result = readWorkItemFromColumn({
          cache,
          query,
          variables,
          workItemId: workItemA.id,
        });

        expect(result).toEqual(workItemA);
        expect(result).not.toBe(workItemA);
      });

      it('returns null when the item is not present', () => {
        const cache = createCache(buildRestData([workItemA]));

        const result = readWorkItemFromColumn({
          cache,
          query,
          variables,
          workItemId: workItemB.id,
        });

        expect(result).toBeNull();
      });

      it('returns null when the connection is missing', () => {
        const cache = createCache({});

        const result = readWorkItemFromColumn({
          cache,
          query,
          variables,
          workItemId: workItemA.id,
        });

        expect(result).toBeNull();
      });
    });

    describe('readWorkItemConnectionFromColumn', () => {
      it('returns the connection, including pageInfo', () => {
        const pageInfo = { hasNextPage: true };
        const cache = createCache(buildRestData([workItemA, workItemB], pageInfo));

        const result = readWorkItemConnectionFromColumn({ cache, query, variables });

        expect(result).toEqual({ nodes: [workItemA, workItemB], pageInfo });
      });

      it('returns null when the connection is missing', () => {
        const cache = createCache({});

        const result = readWorkItemConnectionFromColumn({ cache, query, variables });

        expect(result).toBeNull();
      });
    });

    describe('readWorkItemsFromColumn', () => {
      it('returns the connection nodes', () => {
        const cache = createCache(buildRestData([workItemA, workItemB]));

        const result = readWorkItemsFromColumn({ cache, query, variables });

        expect(result).toEqual([workItemA, workItemB]);
      });

      it('returns an empty array when the connection is missing', () => {
        const cache = createCache({});

        const result = readWorkItemsFromColumn({ cache, query, variables });

        expect(result).toEqual([]);
      });
    });

    describe('removeWorkItemFromColumn', () => {
      it('removes the matching node from the connection', () => {
        const cache = createCache(buildRestData([workItemA, workItemB]));

        removeWorkItemFromColumn({
          cache,
          query,
          variables,
          workItemId: workItemA.id,
        });

        expect(cache.getStored().restWorkItems.nodes).toEqual([workItemB]);
      });

      it('is a no-op when the connection is missing', () => {
        const cache = createCache({});

        removeWorkItemFromColumn({
          cache,
          query,
          variables,
          workItemId: workItemA.id,
        });

        expect(cache.getStored()).toEqual({});
      });
    });

    describe('addWorkItemToColumn', () => {
      it('inserts the work item at the given index', () => {
        const cache = createCache(buildRestData([workItemA, workItemC]));

        addWorkItemToColumn({
          cache,
          query,
          variables,
          workItem: workItemB,
          index: 1,
        });

        expect(cache.getStored().restWorkItems.nodes).toEqual([workItemA, workItemB, workItemC]);
      });

      it('does not insert duplicates', () => {
        const cache = createCache(buildRestData([workItemA, workItemB]));

        addWorkItemToColumn({
          cache,
          query,
          variables,
          workItem: workItemA,
          index: 0,
        });

        expect(cache.getStored().restWorkItems.nodes).toEqual([workItemA, workItemB]);
      });

      it('runs patchCard on the cloned inserted node', () => {
        const cache = createCache(buildRestData([workItemA]));
        const patchCard = jest.fn((node) => {
          // eslint-disable-next-line no-param-reassign
          node.title = 'patched';
        });

        addWorkItemToColumn({
          cache,
          query,
          variables,
          workItem: workItemB,
          index: 1,
          patchCard,
        });

        expect(patchCard).toHaveBeenCalledTimes(1);
        expect(cache.getStored().restWorkItems.nodes[1]).toEqual({
          ...workItemB,
          title: 'patched',
        });
        // The original object is not mutated.
        expect(workItemB.title).toBe('B');
      });

      it('is a no-op when the connection is missing', () => {
        const cache = createCache({});

        addWorkItemToColumn({
          cache,
          query,
          variables,
          workItem: workItemA,
          index: 0,
        });

        expect(cache.getStored()).toEqual({});
      });
    });
  });

  // The count-only query is a regular GraphQL query, so its cache entry always
  // lives at namespace.workItems.timeLimitedCount regardless of the REST API flag.
  describe('adjustWorkItemCountInColumn', () => {
    it('increments the count by delta', () => {
      const cache = createCache(buildCountData(5));

      adjustWorkItemCountInColumn({ cache, query, variables, delta: 2 });

      expect(cache.getStored().namespace.workItems.timeLimitedCount).toBe(7);
    });

    it('clamps the count to zero when delta would drop it below zero', () => {
      const cache = createCache(buildCountData(1));

      adjustWorkItemCountInColumn({ cache, query, variables, delta: -5 });

      expect(cache.getStored().namespace.workItems.timeLimitedCount).toBe(0);
    });

    it('is a no-op when count is not a number', () => {
      const cache = createCache(buildCountData());

      adjustWorkItemCountInColumn({ cache, query, variables, delta: 1 });

      expect(cache.getStored().namespace.workItems.timeLimitedCount).toBeUndefined();
    });

    it('leaves a count that exceeded the time limit unknown', () => {
      const cache = createCache({ namespace: { workItems: { timeLimitedCount: null } } });

      adjustWorkItemCountInColumn({ cache, query, variables, delta: 1 });

      expect(cache.getStored().namespace.workItems.timeLimitedCount).toBeNull();
    });

    it('leaves a capped count alone', () => {
      const cache = createCache(buildCountData(1001));
      const cappedVariables = { ...variables, countLimit: 1000 };

      adjustWorkItemCountInColumn({ cache, query, variables: cappedVariables, delta: -1 });

      expect(cache.getStored().namespace.workItems.timeLimitedCount).toBe(1001);
    });

    it('adjusts a count at the limit, so the header can tip over to the capped label', () => {
      const cache = createCache(buildCountData(1000));
      const cappedVariables = { ...variables, countLimit: 1000 };

      adjustWorkItemCountInColumn({ cache, query, variables: cappedVariables, delta: 1 });

      expect(cache.getStored().namespace.workItems.timeLimitedCount).toBe(1001);
    });
  });
});
