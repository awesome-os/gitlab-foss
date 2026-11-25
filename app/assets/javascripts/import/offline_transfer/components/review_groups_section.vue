<script>
import { GlPagination } from '@gitlab/ui';
import GroupRow from './group_row.vue';

export default {
  name: 'ReviewGroupsSection',
  components: {
    GlPagination,
    GroupRow,
  },
  props: {
    groups: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      currentPage: 1,
    };
  },
  computed: {
    pageGroups() {
      const start = (this.currentPage - 1) * this.$options.PAGE_SIZE;
      return this.groups.slice(start, start + this.$options.PAGE_SIZE);
    },
    showPagination() {
      return this.groups.length > this.$options.PAGE_SIZE;
    },
  },
  watch: {
    groups() {
      this.currentPage = 1;
    },
  },
  PAGE_SIZE: 10,
};
</script>

<template>
  <section class="gl-p-5 gl-pb-0">
    <slot />
    <ul class="gl-mb-0 gl-list-none gl-p-0">
      <group-row
        v-for="group in pageGroups"
        :key="group.id"
        :name="group.fullName"
        :description="group.description"
        :avatar-url="group.avatarUrl"
      />
    </ul>
    <gl-pagination
      v-if="showPagination"
      v-model="currentPage"
      :per-page="$options.PAGE_SIZE"
      :total-items="groups.length"
      align="center"
    />
  </section>
</template>
