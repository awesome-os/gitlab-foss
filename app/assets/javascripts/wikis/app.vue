<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import { draftMatchesPage, clearDraftsAt } from './utils';
import WikiHeader from './components/wiki_header.vue';
import WikiContent from './components/wiki_content.vue';
import WikiForm from './components/wiki_form.vue';
import WikiAlert from './components/wiki_alert.vue';
import WikiNotesApp from './wiki_notes/components/wiki_notes_app.vue';

export default {
  name: 'WikisApp',
  components: {
    GlAlert,
    WikiHeader,
    WikiContent,
    WikiForm,
    WikiAlert,
    WikiNotesApp,
  },
  inject: {
    isPageHistorical: { default: null },
    wikiUrl: { default: null },
    historyUrl: { default: null },
    error: { default: null },
    pagePersisted: { default: false },
    pageInfo: { default: null },
    pageChanged: { default: false },
  },
  i18n: {
    alertText: s__('WikiHistoricalPage|This is an old version of this page.'),
    alertPrimaryButton: s__('WikiHistoricalPage|Go to most recent version'),
    alertSecondaryButton: s__('WikiHistoricalPage|Browse history'),
  },
  data() {
    return {
      isEditing: false,
      // Only the form the failed save redirected to reports it, not one opened later.
      showPageChanged: this.pageChanged,
    };
  },
  computed: {
    showWikiNotes() {
      return !this.isCustomSidebar && (!this.isEditing || this.pagePersisted);
    },
    showWikiHeader() {
      return !this.isEditing;
    },
    isCustomSidebar() {
      return this.wikiUrl.endsWith('_sidebar');
    },
  },
  watch: {
    isEditing() {
      // sync the mode with the URL to ensure the state survives a page reload
      const url = new URL(window.location);

      if (this.isEditing) {
        url.searchParams.set('edit', 'true');
      } else {
        url.searchParams.delete('edit');
        url.searchParams.delete('view');
      }

      window.history.pushState({}, '', url);
    },
  },
  mounted() {
    this.checkEditingMode();
    this.clearSavedDrafts();
    this.checkOpenCloneModal();
    window.addEventListener('popstate', this.checkEditingMode);
  },
  beforeDestroy() {
    window.removeEventListener('popstate', this.checkEditingMode);
  },
  methods: {
    setEditingMode(value) {
      this.isEditing = value;
      if (!value) this.showPageChanged = false;
    },
    checkEditingMode() {
      const url = new URL(window.location);

      if (url.searchParams.has('edit') || url.searchParams.get('view') === 'create' || this.error) {
        this.setEditingMode(true);
      } else {
        this.setEditingMode(false);
      }
    },
    clearSavedDrafts() {
      if (this.isEditing || !this.pageInfo?.persisted) return;

      // A new page's draft is stored under createPath, so check that too.
      [this.pageInfo.path, this.pageInfo.createPath]
        .filter((path) => draftMatchesPage(path, this.pageInfo))
        .forEach((path) => clearDraftsAt(path));
    },
    checkOpenCloneModal() {
      const url = new URL(window.location);

      if (url.searchParams.has('open_clone_modal')) {
        url.searchParams.delete('open_clone_modal');
        window.history.replaceState({}, '', url);
        this.$root.$emit(BV_SHOW_MODAL, 'clone-wiki-modal');
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-if="isPageHistorical"
      :dismissible="false"
      variant="warning"
      class="gl-mt-5"
      :primary-button-text="$options.i18n.alertPrimaryButton"
      :primary-button-link="wikiUrl"
      :secondary-button-text="$options.i18n.alertSecondaryButton"
      :secondary-button-link="historyUrl"
    >
      {{ $options.i18n.alertText }}
    </gl-alert>
    <wiki-alert v-if="error" :error="error" class="gl-mt-5" />
    <wiki-header v-if="showWikiHeader" @is-editing="setEditingMode" />
    <wiki-form v-if="isEditing" :page-changed="showPageChanged" @is-editing="setEditingMode" />
    <wiki-content v-else :is-editing="isEditing" />
    <wiki-notes-app v-if="showWikiNotes" />
  </div>
</template>
