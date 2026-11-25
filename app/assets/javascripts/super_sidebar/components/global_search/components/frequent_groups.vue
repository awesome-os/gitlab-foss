<script>
import { dashboardGroupsPath } from '~/lib/utils/path_helpers/dashboard';
import { groupPath } from '~/lib/utils/path_helpers/group';
import currentUserFrecentGroupsQuery from '~/super_sidebar/graphql/queries/current_user_frecent_groups.query.graphql';
import { FREQUENTLY_VISITED_GROUPS_HANDLE } from '~/super_sidebar/components/global_search/command_palette/constants';
import FrequentItems from './frequent_items.vue';

export default {
  name: 'FrequentlyVisitedGroups',
  components: {
    FrequentItems,
  },
  emits: ['action', 'nothing-to-render'],
  data() {
    return {
      frecentGroups: undefined,
    };
  },
  apollo: {
    frecentGroups: {
      query: currentUserFrecentGroupsQuery,
      skip() {
        return !this.isLoggedIn;
      },
    },
  },
  computed: {
    isLoggedIn() {
      return Boolean(gon.current_username);
    },
    items() {
      return (this.frecentGroups || []).map((group) => ({
        ...group,
        webPath: groupPath(group.fullPath),
      }));
    },
    viewAllItemsPath() {
      return dashboardGroupsPath({ organizationPath: null });
    },
  },
  created() {
    if (!this.isLoggedIn) {
      this.$emit('nothing-to-render');
    }
  },
  FREQUENTLY_VISITED_GROUPS_HANDLE,
};
</script>

<template>
  <frequent-items
    v-if="isLoggedIn"
    :loading="$apollo.queries.frecentGroups.loading"
    :empty-state-text="s__('Navigation|Groups you visit often will appear here.')"
    :group-name="s__('Navigation|Frequently visited groups')"
    :items="items"
    view-all-items-icon="group"
    :view-all-items-text="s__('Navigation|View all my groups')"
    :view-all-items-path="viewAllItemsPath"
    v-bind="$attrs"
    @action="$emit('action', $options.FREQUENTLY_VISITED_GROUPS_HANDLE)"
  />
</template>
