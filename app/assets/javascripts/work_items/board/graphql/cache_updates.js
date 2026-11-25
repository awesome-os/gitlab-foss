import produce from 'immer';
import { cloneDeep } from 'lodash-es';

// Clones the card so we have our own copy to reinsert into the target column,
// instead of a reference into the cache we're about to remove it from.
export const readWorkItemFromColumn = ({ cache, query, variables, workItemId }) => {
  const data = cache.readQuery({ query, variables });
  const node = data?.restWorkItems?.nodes?.find((item) => item.id === workItemId);
  return node ? cloneDeep(node) : null;
};

// Full connection (nodes + pageInfo), for callers that need to know whether the
// column has more pages left to load, not just its currently-cached nodes.
export const readWorkItemConnectionFromColumn = ({ cache, query, variables }) => {
  const data = cache.readQuery({ query, variables });
  return data?.restWorkItems ?? null;
};

// Snapshot of a column's order before a move, used to work out the
// moveBeforeId/moveAfterId for the card landing there.
export const readWorkItemsFromColumn = (params) =>
  readWorkItemConnectionFromColumn(params)?.nodes ?? [];

// A column can be missing from the cache if it's collapsed or hasn't loaded
// yet. When that happens we just do nothing, so the move still succeeds.
export const removeWorkItemFromColumn = ({ cache, query, variables, workItemId }) => {
  cache.updateQuery({ query, variables }, (sourceData) => {
    if (!sourceData?.restWorkItems) {
      return sourceData;
    }

    return produce(sourceData, (draftData) => {
      const { nodes } = draftData.restWorkItems;
      const index = nodes.findIndex((item) => item.id === workItemId);
      if (index !== -1) {
        nodes.splice(index, 1);
      }
    });
  });
};

// Inserts the card at `index`. `patchCard`, if given, runs on the inserted
// clone so its grouped attribute (e.g. status) already matches the target
// column while the mutation is still in flight.
export const addWorkItemToColumn = ({ cache, query, variables, workItem, index, patchCard }) => {
  cache.updateQuery({ query, variables }, (sourceData) => {
    if (!sourceData?.restWorkItems) {
      return sourceData;
    }

    return produce(sourceData, (draftData) => {
      const { nodes } = draftData.restWorkItems;
      if (nodes.some((item) => item.id === workItem.id)) {
        return;
      }

      const node = cloneDeep(workItem);
      if (patchCard) {
        patchCard(node);
      }

      nodes.splice(index, 0, node);
    });
  });
};

// The count-only query has its own cache entry, separate from the list query,
// so moving a card doesn't update the count for free — we have to do it here.
export const adjustWorkItemCountInColumn = ({ cache, query, variables, delta }) => {
  cache.updateQuery({ query, variables }, (sourceData) => {
    const connection = sourceData?.namespace?.workItems;
    if (typeof connection?.timeLimitedCount !== 'number') {
      return sourceData;
    }

    // A capped count (limit + 1) stays capped; the next refetch settles it.
    if (variables?.countLimit && connection.timeLimitedCount > variables.countLimit) {
      return sourceData;
    }

    return produce(sourceData, (draftData) => {
      const draft = draftData.namespace.workItems;
      draft.timeLimitedCount = Math.max(0, draft.timeLimitedCount + delta);
    });
  });
};
