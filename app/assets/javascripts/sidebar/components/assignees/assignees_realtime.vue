<script>
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import { assigneesQueries } from '../../queries/constants';

export default normalizeRender({
  subscription: null,
  name: 'AssigneesRealtime',
  props: {
    mediator: {
      type: Object,
      required: false,
      default: null,
    },
    issuableType: {
      type: String,
      required: true,
    },
    queryVariables: {
      type: Object,
      required: true,
    },
  },
  emits: ['assignees-updated'],
  computed: {
    issuableId() {
      return this.issuable?.id;
    },
  },
  apollo: {
    issuable: {
      query() {
        return assigneesQueries[this.issuableType].query;
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.namespace?.issuable;
      },
      subscribeToMore: {
        document() {
          return assigneesQueries[this.issuableType].subscription;
        },
        variables() {
          return {
            issuableId: this.issuableId,
          };
        },
        skip() {
          return !this.issuableId;
        },
        updateQuery(
          _,
          {
            subscriptionData: {
              data: { issuableAssigneesUpdated },
            },
          },
        ) {
          // TODO: Remove this null check. Subscriptions no longer start with a null payload.
          // https://gitlab.com/gitlab-org/gitlab/-/work_items/629373
          if (issuableAssigneesUpdated) {
            const {
              id,
              assignees: { nodes },
            } = issuableAssigneesUpdated;
            if (this.mediator) {
              this.handleFetchResult(nodes);
            }
            this.$emit('assignees-updated', { id, assignees: nodes });
          }
        },
      },
    },
  },
  methods: {
    handleFetchResult(nodes) {
      const assignees = nodes.map((n) => ({
        ...n,
        avatar_url: n.avatarUrl,
        id: getIdFromGraphQLId(n.id),
      }));

      this.mediator.store.setAssigneesFromRealtime(assignees);
    },
  },
  render() {
    return null;
  },
});
</script>
