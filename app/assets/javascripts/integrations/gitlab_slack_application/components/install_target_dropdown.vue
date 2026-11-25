<script>
import { GlCollapsibleListbox, GlAvatarLabeled } from '@gitlab/ui';
import { i18n } from '../constants';

const GROUP = 'group';
const PROJECT = 'project';

const toItem = (type, entity) => ({
  value: `${type}-${entity.id}`,
  type,
  id: entity.id,
  name: type === GROUP ? entity.full_name : entity.name_with_namespace,
  avatarUrl: entity.avatar_url,
});

export default {
  name: 'InstallTargetDropdown',
  components: {
    GlCollapsibleListbox,
    GlAvatarLabeled,
  },
  props: {
    groups: {
      type: Array,
      required: false,
      default: () => [],
    },
    projects: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedTarget: {
      type: Object,
      required: false,
      default: null,
    },
    labelledBy: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['target-selected'],
  i18n,
  data() {
    return {
      selected: this.selectedTarget?.value ?? null,
      searchTerm: '',
    };
  },
  computed: {
    groupItems() {
      return this.groups.map((group) => toItem(GROUP, group));
    },
    projectItems() {
      return this.projects.map((project) => toItem(PROJECT, project));
    },
    items() {
      const term = this.searchTerm.trim().toLowerCase();
      const matching = (options) =>
        term ? options.filter((item) => item.name.toLowerCase().includes(term)) : options;

      return [
        { text: i18n.groupsHeader, options: matching(this.groupItems) },
        { text: i18n.projectsHeader, options: matching(this.projectItems) },
      ].filter((section) => section.options.length);
    },
    dropdownText() {
      return this.selectedTarget ? this.selectedTarget.name : i18n.selectTarget;
    },
  },
  methods: {
    onSearch(term) {
      this.searchTerm = term;
    },
    onSelect(value) {
      const target = [...this.groupItems, ...this.projectItems].find(
        (item) => item.value === value,
      );
      this.$emit('target-selected', target);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    v-model="selected"
    block
    fluid-width
    is-check-centered
    :toggle-text="dropdownText"
    :toggle-aria-labelled-by="labelledBy"
    :list-aria-labelled-by="labelledBy"
    :items="items"
    :searchable="true"
    :search-placeholder="$options.i18n.searchPlaceholder"
    :no-results-text="$options.i18n.noResults"
    @search="onSearch"
    @select="onSelect"
  >
    <template #list-item="{ item }">
      <span class="gl-flex gl-items-center gl-justify-between gl-gap-3">
        <gl-avatar-labeled
          :label="item.name"
          :entity-name="item.name"
          :entity-id="item.id"
          shape="rect"
          :size="32"
          :src="item.avatarUrl"
        />
      </span>
    </template>
  </gl-collapsible-listbox>
</template>
