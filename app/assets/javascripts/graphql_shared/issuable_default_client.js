import produce from 'immer';
import { isPlainObject } from 'lodash-es';
import { concatPagination } from '@apollo/client/utilities';
import errorQuery from '~/boards/graphql/client/error.query.graphql';
import isShowingLabelsQuery from '~/graphql_shared/client/is_showing_labels.query.graphql';
import getIssueStateQuery from '~/issues/show/queries/get_issue_state.query.graphql';
import createDefaultClient from '~/lib/graphql';
import { pageSingleton } from '~/lib/utils/page_singleton';
import typeDefs from '~/work_items/graphql/typedefs.graphql';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';

import isExpandedHierarchyTreeChildQuery from '~/work_items/graphql/client/is_expanded_hierarchy_tree_child.query.graphql';
import { getRealtimeRequestTagLink } from '~/work_items/list/graphql/realtime_request_tag';
import activeBoardItemQuery from 'ee_else_ce/boards/graphql/client/active_board_item.query.graphql';
import activeDiscussionQuery from '~/work_items/components/design_management/graphql/client/active_design_discussion.query.graphql';
import { updateNewWorkItemCache, workItemBulkEdit } from '~/work_items/graphql/resolvers';
import { restWorkItemsResolver } from 'ee_else_ce/work_items/list/graphql/rest/work_items_rest_resolver';
import { preserveDetailsState } from '~/work_items/utils';
import {
  linkedItems,
  currentAssignees,
  appliedLabels,
  availableStatuses,
  supportedConversionTypes,
} from './issuable_client_state';

// Populates the `currentAssignees` reactive var from `features.assignees`.
const updateCurrentAssignees = (assigneesWidget, context) => {
  if (!assigneesWidget || !context.variables.id) {
    return;
  }

  const workItemAssignees = assigneesWidget.assignees?.nodes || [];
  const users = workItemAssignees
    .map((user) => {
      // eslint-disable-next-line no-underscore-dangle
      const userRef = context.cache.extract()[user.__ref];

      // The ref may be absent when a user node hasn't been written to the cache yet
      // (e.g. an optimistic response or a partial write); skip it to avoid throwing.
      if (!userRef) return null;

      // We're copying `avatarUrl` into `avatar_url` because both
      // Quick action autocompletion setups;
      // 1. `gfm_auto_complete.js` - Plain Text Editor
      // 2. `content_editor/components/suggestions_dropdown.vue` - RTE
      // expect user avatars to be present in `avatar_url` and
      // adding `avatar_url || avatarUrl` there requires unnecessary
      // repetition.
      return { ...userRef, avatar_url: userRef.avatarUrl };
    })
    .filter(Boolean);

  currentAssignees({
    ...currentAssignees(),
    [`${context.variables.id}`]: users,
  });
};

// Populates the `appliedLabels` reactive var from `features.labels`.
const updateAppliedLabels = (labelsWidget, context) => {
  if (!labelsWidget || !context.variables.id) {
    return;
  }

  const workItemLabels = labelsWidget.labels?.nodes || [];
  const labels = workItemLabels.map(
    // eslint-disable-next-line no-underscore-dangle
    (label) => context.cache.extract()[label.__ref],
  );

  appliedLabels({
    ...appliedLabels(),
    [`${context.variables.id}`]: labels,
  });
};

// Populates the `linkedItems` reactive var from `features.linkedItems`.
const updateLinkedItems = (linkedItemsWidget, context) => {
  if (!linkedItemsWidget?.linkedItems || !context.variables.iid) {
    return;
  }

  // We only set up linked items when the widget is present and has `workItem` property
  //
  // The added null checks and .filter call is to address a situation where a work item
  // that's still hasn't loaded remains undefined during extraction, causing the linked
  // items widget to fail, see https://gitlab.com/gitlab-org/gitlab/-/work_items/595004
  const items = (linkedItemsWidget.linkedItems.nodes || [])
    .filter((node) => node.workItem)
    // normally we would only get a `__ref` for nested properties but we need to extract the full work item
    .map((node) => {
      /* eslint-disable no-underscore-dangle */
      const itemRef = context.cache.extract()[node.workItem.__ref];
      if (!itemRef?.workItemType?.__ref) return null;
      const { __typename, id, name, iconName } =
        context.cache.extract()[itemRef.workItemType.__ref];
      /* eslint-enable no-underscore-dangle */
      if (!__typename) return null;

      return {
        ...itemRef,
        workItemType: {
          __typename,
          id,
          name,
          iconName,
        },
      };
    })
    .filter(Boolean);

  linkedItems({
    ...linkedItems(),
    [`${context.variables.fullPath}:${context.variables.iid}`]: items,
  });
};

export const config = {
  typeDefs,
  links: [getRealtimeRequestTagLink()],
  cacheConfig: {
    typePolicies: {
      Query: {
        fields: {
          isShowingLabels: {
            read(currentState) {
              return currentState ?? true;
            },
          },
          boardList: {
            keyArgs: ['id'],
          },
          epicBoardList: {
            keyArgs: ['id'],
          },
          isExpandedHierarchyTreeChild: (_, { variables, toReference }) =>
            toReference({ __typename: 'LocalWorkItemChildIsExpanded', id: variables.id }),
          namespace: {
            keyArgs: ['fullPath'],
          },
        },
      },
      MergeRequestConnection: {
        merge: true,
      },
      DesignManagement: {
        merge(existing = {}, incoming) {
          return { ...existing, ...incoming };
        },
      },
      Project: {
        fields: {
          projectMembers: {
            keyArgs: ['fullPath', 'search', 'relations', 'first'],
          },
        },
      },
      Namespace: {
        merge: true,
        fields: {
          workItems: {
            merge(existing = {}, incoming = {}) {
              return { ...existing, ...incoming };
            },
          },
          savedViews: {
            keyArgs: ['subscribedOnly', 'sort', 'search', 'id'],
            merge(existing, incoming, context) {
              if (!context.variables.after || context.variables.id) {
                return incoming;
              }

              return {
                ...incoming,
                nodes: [...existing.nodes, ...incoming.nodes],
              };
            },
          },
        },
      },
      WorkItemPermissions: {
        merge: true,
      },
      NamespacePermissions: {
        merge: true,
      },
      NamespaceAvailableFeatures: {
        merge: true,
      },
      ProjectPermissions: {
        merge: true,
      },
      ProjectNamespaceMarkdownPaths: {
        merge: true,
      },
      GroupNamespaceMarkdownPaths: {
        merge: true,
      },
      Discussion: {
        fields: {
          userPermissions: {
            merge: true,
          },
        },
      },
      WorkItemWidgetDescription: {
        fields: {
          descriptionHtml: {
            merge(_, incoming) {
              const el = document.querySelector('.work-item-description');
              if (!el) {
                return incoming;
              }

              const descriptionHtml = preserveDetailsState(el, incoming);
              return descriptionHtml || incoming;
            },
          },
        },
      },
      WorkItemWidgetNotes: {
        fields: {
          // If we add any key args, the discussions field becomes discussions({"filter":"ONLY_ACTIVITY","first":10}) and
          // kills any possibility to handle it on the widget level without hardcoding a string.
          discussions: {
            keyArgs: false,
            // we want to concat next page of discussions to the existing ones
            // handled here so it applies `features.notes.discussions`
            merge(existing, incoming, { variables }) {
              if (existing && incoming && variables.after) {
                return {
                  ...incoming,
                  nodes: [...existing.nodes, ...incoming.nodes],
                };
              }
              return incoming;
            },
          },
        },
      },
      WorkItemWidgetAwardEmoji: {
        fields: {
          // If we add any key args, the awardEmoji field becomes awardEmoji({"first":10}) and
          // kills any possibility to handle it on the widget level without hardcoding a string.
          awardEmoji: {
            keyArgs: false,
            // we want to concat next page of awardEmoji to the existing ones
            merge(existing, incoming, { variables }) {
              if (existing && incoming && variables.after) {
                return {
                  ...incoming,
                  nodes: [...existing.nodes, ...incoming.nodes],
                };
              }
              return incoming;
            },
          },
        },
      },
      WorkItemWidgetProgress: {
        fields: {
          progress: {
            // We want to show null progress as 0 as per https://gitlab.com/gitlab-org/gitlab/-/issues/386117
            read(existing) {
              return existing === null ? 0 : existing;
            },
          },
        },
      },
      DescriptionVersion: {
        fields: {
          startVersionId: {
            read() {
              // we need to set this when fetching the diff in the last 10 mins , the starting diff will be the very first one , so need to save it
              return '';
            },
          },
        },
      },
      WorkItemWidgetHierarchy: {
        merge: true,
        fields: {
          // If we add any key args, the children field becomes children({"first":10}) and
          // kills any possibility to handle it on the widget level without hardcoding a string.
          children: {
            keyArgs: false,
            // Handles paginated `features.hierarchy.children`.
            merge(existing, incoming, { variables }) {
              if (existing && incoming && variables.endCursor) {
                return {
                  ...incoming,
                  nodes: [...existing.nodes, ...incoming.nodes],
                };
              }
              return incoming;
            },
          },
        },
      },
      WorkItemWidgetLinkedItems: {
        merge: true,
      },
      WorkItemWidgetNotifications: {
        merge: true,
      },
      WorkItemWidgetVulnerabilities: {
        fields: {
          // If we add any key args, the relatedVulnerabilities field becomes relatedVulnerabilities({"first":50,"after":"xyz"}) and
          // kills any possibility to handle it on the widget level without hardcoding a string.
          relatedVulnerabilities: {
            keyArgs: false,
            // we want to concat next page of related vulnerabilities to the existing ones
            // handled here so it applies to `features.vulnerabilities.relatedVulnerabilities`.
            merge(existing, incoming, { variables }) {
              if (existing && incoming && variables.after) {
                return {
                  ...incoming,
                  nodes: [...existing.nodes, ...incoming.nodes],
                };
              }
              return incoming;
            },
          },
        },
      },
      WorkItem: {
        fields: {
          // Prevent `reference` from being transformed into `reference({"fullPath":true})`
          reference: {
            keyArgs: false,
          },
          features: {
            keyArgs: false,
            merge(existing = {}, incoming = {}, context) {
              // A widget can arrive from more than one document, so merge wrapper by wrapper:
              // a partial write would otherwise drop fields another query supplied.
              const merged = { ...existing };
              Object.keys(incoming).forEach((key) => {
                const existingWidget = existing[key];
                const incomingWidget = incoming[key];

                merged[key] =
                  isPlainObject(existingWidget) && isPlainObject(incomingWidget)
                    ? { ...existingWidget, ...incomingWidget }
                    : incomingWidget;
              });

              // Extract data into reactive vars for consumers that read them.
              updateCurrentAssignees(merged.assignees, context);
              updateAppliedLabels(merged.labels, context);
              updateLinkedItems(merged.linkedItems, context);

              return merged;
            },
          },
          // Linked items still select `widgets(onlyTypes: [LINKED_ITEMS])` for blocked counts.
          widgets: {
            keyArgs: false,
            merge: (_, incoming) => incoming,
          },
        },
      },
      MemberInterfaceConnection: {
        fields: {
          nodes: concatPagination(),
        },
      },
      Group: {
        fields: {
          projects: {
            keyArgs: ['includeSubgroups', 'search'],
          },
          descendantGroups: {
            keyArgs: ['includeSubgroups', 'search'],
          },
        },
      },
      ProjectConnection: {
        fields: {
          nodes: concatPagination(),
        },
      },
      GroupConnection: {
        fields: {
          nodes: concatPagination(),
        },
      },
      MergeRequestApprovalState: {
        merge: true,
      },
      WorkItemType: {
        // this prevents child and parent work item types from overriding each other
        fields: {
          supportedConversionTypes: {
            merge(existing, incoming, context) {
              if (context.variables.fullPath) {
                const existingSupportedConversionTypes = supportedConversionTypes();
                const cacheNodes = context.cache.extract();

                // Get available work item types for the namespace
                const workItemTypes = Object.keys(cacheNodes).filter((cacheKey) =>
                  cacheKey.includes('WorkItemType:'),
                );

                // Collect available supportedConversionTypes per work item type
                const conversionTypes = workItemTypes.reduce((acc, currentType) => {
                  const supportedConversionTypesForThisType =
                    cacheNodes[currentType].supportedConversionTypes;
                  if (supportedConversionTypesForThisType) {
                    // Normalize type ID key name
                    acc[currentType.split('WorkItemType:').pop()] =
                      supportedConversionTypesForThisType.map(
                        // eslint-disable-next-line no-underscore-dangle
                        (type) => cacheNodes[type.__ref],
                      );
                  }
                  return acc;
                }, {});

                // Set type-to-supportedConversionTypes map for this namespace in reactive prop
                supportedConversionTypes({
                  ...existingSupportedConversionTypes,
                  [context.variables.fullPath]: conversionTypes,
                });
              }

              return incoming;
            },
          },
          widgetDefinitions: {
            merge(existing = [], incoming, context) {
              if (existing.length === 0) {
                return incoming;
              }

              if (context.variables.fullPath) {
                const existingAvailableStatuses = availableStatuses();
                const cacheNodes = context.cache.extract();

                // Get available work item types for the namespace
                const workItemTypes = Object.keys(cacheNodes).filter((cacheKey) =>
                  cacheKey.includes('WorkItemType:'),
                );

                // Collect available statuses per work item type
                const statusesForTypes = workItemTypes.reduce((acc, currentType) => {
                  const typeWidgetDefs = cacheNodes[currentType].widgetDefinitions;
                  if (typeWidgetDefs) {
                    const { allowedStatuses } =
                      typeWidgetDefs.find((widget) => widget.type === WIDGET_TYPE_STATUS) || {};

                    // Only capture once statuses are available in cache
                    if (allowedStatuses) {
                      // Normalize type ID key name
                      acc[currentType.split('WorkItemType:').pop()] = allowedStatuses.map(
                        // eslint-disable-next-line no-underscore-dangle
                        (status) => cacheNodes[status.__ref],
                      );
                    }
                  }
                  return acc;
                }, {});

                // Set type-to-status map in reactive prop
                availableStatuses({
                  ...existingAvailableStatuses,
                  [context.variables.fullPath]: statusesForTypes,
                });
              }

              return existing.map((existingWidget) => {
                const incomingWidget = incoming.find(
                  (w) => w.type && w.type === existingWidget.type,
                );

                return { ...existingWidget, ...incomingWidget };
              });
            },
          },
        },
      },
    },
  },
};

export const resolvers = {
  Query: {
    restWorkItems: restWorkItemsResolver,
  },
  Mutation: {
    updateIssueState: (_, { issueType = undefined, isDirty = false }, { cache }) => {
      const sourceData = cache.readQuery({ query: getIssueStateQuery });
      const data = produce(sourceData, (draftData) => {
        draftData.issueState = { issueType, isDirty };
      });
      cache.writeQuery({ query: getIssueStateQuery, data });
    },
    setActiveBoardItem(_, { boardItem, listId }, { cache }) {
      // activeBoardItem is queried with the full Issue fragment, so writing a boardItem-less
      // (e.g. { listId }) object here would leave those fields missing rather than null.
      const activeBoardItem = boardItem ? { ...boardItem, listId } : null;

      cache.writeQuery({
        query: activeBoardItemQuery,
        data: { activeBoardItem },
      });
      return activeBoardItem;
    },
    setError(_, { error }, { cache }) {
      cache.writeQuery({
        query: errorQuery,
        data: { boardsAppError: error },
      });
      return error;
    },
    clientToggleListCollapsed(_, { list = {}, collapsed = false }) {
      return {
        list: {
          ...list,
          collapsed,
        },
      };
    },
    clientToggleEpicListCollapsed(_, { list = {}, collapsed = false }) {
      return {
        list: {
          ...list,
          collapsed,
        },
      };
    },
    setIsShowingLabels(_, { isShowingLabels }, { cache }) {
      cache.writeQuery({
        query: isShowingLabelsQuery,
        data: { isShowingLabels },
      });
      return isShowingLabels;
    },
    updateNewWorkItem(_, { input }, { cache }) {
      updateNewWorkItemCache(input, cache);
    },
    localWorkItemBulkUpdate(_, { input }) {
      return workItemBulkEdit(input);
    },
    toggleHierarchyTreeChild(_, { id, isExpanded = false }, { cache }) {
      cache.writeQuery({
        query: isExpandedHierarchyTreeChildQuery,
        variables: { id },
        data: {
          isExpandedHierarchyTreeChild: {
            id,
            isExpanded,
            __typename: 'LocalWorkItemChildIsExpanded',
          },
        },
      });
    },
    updateActiveDesignDiscussion: (_, { id = null, source }, { cache }) => {
      const data = {
        activeDesignDiscussion: {
          __typename: 'ActiveDesignDiscussion',
          id,
          source,
        },
      };

      cache.writeQuery({ query: activeDiscussionQuery, data });
    },
  },
};

// The Vue 3 loader can build this module twice. Both copies must use one cache.
export const defaultClient = pageSingleton('issuable_default_client', () =>
  createDefaultClient(resolvers, config),
);
