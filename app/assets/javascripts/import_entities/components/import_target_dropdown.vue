<script>
import { GlCollapsibleListbox, GlTooltipDirective } from '@gitlab/ui';
import { debounce, isNull } from 'lodash-es';

import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import { truncate } from '~/lib/utils/text_utility';
import searchNamespacesWhereUserCanImportProjectsQuery from '~/import_entities/import_projects/graphql/queries/search_namespaces_where_user_can_import_projects.query.graphql';
import importTargetSyncAvailabilityQuery from '~/import_entities/import_projects/graphql/queries/import_target_sync_availability.query.graphql';
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import { MINIMUM_SEARCH_LENGTH } from '~/graphql_shared/constants';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

// This is added outside the component as each dropdown on the page triggers a query,
// so if multiple queries fail, we only show 1 error.
const reportNamespaceLoadError = debounce(
  () =>
    createAlert({
      message: s__('ImportProjects|Requesting namespaces failed'),
    }),
  DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
);

export default {
  name: 'ImportTargetDropdown',
  components: {
    GlCollapsibleListbox,
  },

  directives: {
    GlTooltip: GlTooltipDirective,
  },

  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    selected: {
      type: String,
      required: false,
      default: null,
    },
    continuousSyncRequired: {
      type: Boolean,
      required: false,
      default: false,
    },
    continuousSyncOffered: {
      type: Boolean,
      required: false,
      default: false,
    },
    toggleText: {
      type: String,
      required: false,
      default: null,
    },
    userNamespace: {
      type: String,
      required: false,
      default: undefined,
    },
  },

  emits: ['select', 'sync-blocked-change'],

  MAX_IMPORT_TARGET_LENGTH: 24,

  data() {
    return {
      namespaces: undefined,
      searchTerm: '',
      // Kept across searches so the selected namespace stays known when it is filtered out
      syncAvailability: {},
    };
  },

  apollo: {
    namespaces: {
      query: searchNamespacesWhereUserCanImportProjectsQuery,
      variables() {
        return {
          search: this.searchTerm,
          includeContinuousSync: this.continuousSyncOffered,
        };
      },
      skip() {
        const hasNotEnoughSearchCharacters =
          this.searchTerm.length > 0 && this.searchTerm.length < MINIMUM_SEARCH_LENGTH;
        return hasNotEnoughSearchCharacters;
      },
      update(data) {
        return data.currentUser.groups.nodes;
      },
      result({ data }) {
        const { namespace, groups } = data.currentUser;
        const availability = [namespace, ...groups.nodes]
          .filter((ns) => ns?.licensedFeatureAvailability)
          .map((ns) => [ns.fullPath, ns.licensedFeatureAvailability.available]);

        this.syncAvailability = { ...this.syncAvailability, ...Object.fromEntries(availability) };
      },
      error: reportNamespaceLoadError,
      debounce: DEBOUNCE_DELAY,
    },
    // The search page can miss the selected group, so look it up directly
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    selectedGroup: {
      query: importTargetSyncAvailabilityQuery,
      variables() {
        return { fullPath: this.selected, includeContinuousSync: true };
      },
      // Wait for the search page: its debounced result may already cover the selected group
      skip() {
        return (
          !this.continuousSyncRequired ||
          !this.selected ||
          this.selected === this.userNamespace ||
          this.namespaces === undefined ||
          this.selected in this.syncAvailability
        );
      },
      // Without update, vue-apollo never calls result for this key (it looks for selectedGroup in the data)
      update(data) {
        return data.group;
      },
      // A miss or an error leaves availability unknown, and the backend 422 still applies.
      // No alert: the lookup is a fallback, so the search error message would mislead.
      result({ data }) {
        const group = data?.group;
        if (!group?.licensedFeatureAvailability) return;

        this.syncAvailability = {
          ...this.syncAvailability,
          [group.fullPath]: group.licensedFeatureAvailability.available,
        };
      },
    },
  },

  computed: {
    isProject() {
      return Boolean(this.userNamespace);
    },

    syncBlockedMessage() {
      return s__('GithubImport|Not available with updates on. Choose a Premium or Ultimate group.');
    },

    selectedSyncBlocked() {
      return this.isSyncBlocked(this.selected);
    },

    filteredNamespaces() {
      return (this.namespaces ?? []).filter((ns) =>
        ns.fullPath.toLowerCase().includes(this.searchTerm.toLowerCase()),
      );
    },

    listboxToggleText() {
      if (isNull(this.selected)) {
        return this.toggleText;
      }

      return truncate(this.selected, this.$options.MAX_IMPORT_TARGET_LENGTH);
    },

    items() {
      const groups = {
        text: __('Groups'),
        options: this.filteredNamespaces.map((namespace) => {
          return {
            text: namespace.fullPath,
            value: namespace.fullPath,
            ...(this.isSyncBlocked(namespace.fullPath) && { disabled: true }),
          };
        }),
      };

      const users = this.isProject
        ? {
            text: __('Users'),
            options: [
              {
                text: this.userNamespace,
                value: this.userNamespace,
                ...(this.isSyncBlocked(this.userNamespace) && { disabled: true }),
              },
            ],
          }
        : {
            text: __('Parent'),
            textSrOnly: true,
            options: [
              {
                text: s__('BulkImport|No parent'),
                value: '',
              },
            ],
          };

      return this.isProject ? [groups, users] : [users, groups];
    },
  },

  watch: {
    selectedSyncBlocked: {
      immediate: true,
      handler(blocked) {
        this.$emit('sync-blocked-change', blocked);
      },
    },
  },

  beforeDestroy() {
    this.$emit('sync-blocked-change', false);
  },

  methods: {
    isSyncBlocked(fullPath) {
      // Unknown availability is not blocked: the backend 422 is the real gate
      return this.continuousSyncRequired && this.syncAvailability[fullPath] === false;
    },

    onSelect(value) {
      if (this.isProject) {
        this.$emit('select', value);
      } else if (value === '') {
        this.$emit('select', { fullPath: '', id: null });
      } else {
        const { fullPath, id } = this.filteredNamespaces.find((ns) => ns.fullPath === value);

        this.$emit('select', { fullPath, id });
      }
    },

    onSearch(value) {
      this.searchTerm = value.trim();
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="items"
    :disabled="disabled"
    :selected="selected"
    :toggle-text="listboxToggleText"
    searchable
    fluid-width
    :toggle-class="[
      '!gl-rounded-tr-none !gl-rounded-br-none',
      { '!gl-border-feedback-danger': selectedSyncBlocked },
    ]"
    data-testid="target-namespace-dropdown"
    @select="onSelect"
    @search="onSearch"
  >
    <template #list-item="{ item }">
      <!-- Disabled list items set pointer-events: none, so the tooltip needs it back -->
      <span
        v-if="item.disabled"
        v-gl-tooltip="syncBlockedMessage"
        class="gl-pointer-events-auto gl-block"
        >{{ item.text }}<span class="gl-sr-only">{{ syncBlockedMessage }}</span></span
      >
      <template v-else>{{ item.text }}</template>
    </template>
  </gl-collapsible-listbox>
</template>
