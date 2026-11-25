export default {
  typePolicies: {
    Pipeline: {
      fields: {
        jobs: {
          keyArgs: ['jobKind', 'retried', 'securityReportTypes', 'statuses', 'whenExecuted'],
          merge(existing, incoming, { args, readField }) {
            if (!existing) return incoming;

            if (args?.after) {
              // Drop a page that no longer follows the loaded list, e.g. requested before a reset.
              if (args.after !== existing.pageInfo?.endCursor) return existing;

              return { ...incoming, nodes: [...existing.nodes, ...incoming.nodes] };
            }

            if (!incoming.pageInfo?.hasNextPage) return incoming;

            // Polling refetches only the first page, so keep the pages loaded after it.
            const lastIncomingId = readField('id', incoming.nodes.at(-1));
            const lastIncomingIndex = existing.nodes.findIndex(
              (node) => readField('id', node) === lastIncomingId,
            );
            const olderNodes = existing.nodes.slice(lastIncomingIndex + 1);

            if (lastIncomingIndex === -1 || !olderNodes.length) return incoming;

            return {
              ...incoming,
              nodes: [...incoming.nodes, ...olderNodes],
              pageInfo: {
                ...incoming.pageInfo,
                endCursor: existing.pageInfo.endCursor,
                hasNextPage: existing.pageInfo.hasNextPage,
              },
            };
          },
        },
      },
    },
  },
};
