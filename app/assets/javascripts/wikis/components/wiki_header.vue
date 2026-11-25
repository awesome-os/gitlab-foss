<script>
import {
  GlButton,
  GlDisclosureDropdownItem,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
  GlAnimatedNotificationIcon,
  GlModalDirective,
  GlToastMixin,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { isLoggedIn } from '~/lib/utils/common_utils';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import PanelActionsPortal from '~/vue_shared/components/panel_actions_portal.vue';
import wikiPageQuery from '~/wikis/graphql/wiki_page.query.graphql';
import wikiPageSubscribeMutation from '~/wikis/graphql/wiki_page_subscribe.mutation.graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import WikiSidebarToggle from '~/wikis/components/wiki_sidebar_toggle.vue';
import WikiMoreDropdown from './wiki_more_dropdown.vue';
import RestoreVersionModal from './restore_version_modal.vue';

export default {
  name: 'WikiHeader',
  components: {
    WikiSidebarToggle,
    GlButton,
    GlDisclosureDropdownItem,
    GlAnimatedNotificationIcon,
    GlLink,
    GlSprintf,
    WikiMoreDropdown,
    TimeAgo,
    PageHeading,
    PanelActionsPortal,
    RestoreVersionModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModal: GlModalDirective,
  },
  mixins: [GlToastMixin],
  inject: {
    pageHeading: { default: null },
    showEditButton: { default: null },
    showRestoreVersionButton: { default: null },
    isPageTemplate: { default: null },
    lastVersion: { default: null },
    pageVersion: { default: null },
    authorUrl: { default: null },
    createFromTemplateUrl: { default: null },
    queryVariables: { default: null },
  },
  emits: ['is-editing'],
  apollo: {
    wikiPage: {
      query: wikiPageQuery,
      variables() {
        return { ...this.queryVariables, skipDiscussions: true };
      },
    },
  },
  data() {
    return {
      changingSubState: false,
      wikiPage: {},
    };
  },
  computed: {
    isLoggedIn() {
      return isLoggedIn();
    },
    showCreateFromTemplateButton() {
      return this.showEditButton && this.isPageTemplate && this.createFromTemplateUrl;
    },
    editTooltipText() {
      return this.isPageTemplate ? this.$options.i18n.editTemplate : this.$options.i18n.editPage;
    },
    editTooltip() {
      return `${this.editTooltipText} <kbd class='flat gl-ml-2' aria-hidden=true>e</kbd>`;
    },
    isSubscribed() {
      return Boolean(this.wikiPage?.subscribed);
    },
    createFromTemplateItem() {
      return {
        text: this.$options.i18n.createFromTemplate,
        href: this.createFromTemplateUrl,
        extraAttrs: { 'data-testid': 'wiki-create-from-template-item' },
      };
    },
    restoreVersionItem() {
      return {
        text: this.$options.i18n.restoreText,
        extraAttrs: { 'data-testid': 'wiki-restore-version-item' },
      };
    },
    subscribeTooltip() {
      return this.isSubscribed ? __('Notifications are on') : __('Notifications are off');
    },
  },
  mounted() {
    if (this.showEditButton) {
      document.addEventListener('keyup', this.onKeyUp);
    }
  },
  destroyed() {
    if (this.showEditButton) {
      document.removeEventListener('keyup', this.onKeyUp);
    }
  },
  methods: {
    onKeyUp(event) {
      const { tagName, isContentEditable } = event.currentTarget.activeElement;

      if (/input|textarea/i.test(tagName) || isContentEditable) return false;

      if (event.key === 'e') {
        this.setEditingMode();
      }

      return false;
    },
    setEditingMode() {
      this.$emit('is-editing', true);
    },
    async toggleSubscribe() {
      if (this.changingSubState) return;

      this.changingSubState = true;
      const newSubState = !this.wikiPage.subscribed;

      try {
        await this.$apollo.mutate({
          mutation: wikiPageSubscribeMutation,
          variables: {
            id: this.wikiPage.id,
            subscribed: newSubState,
          },
          optimisticResponse: {
            wikiPageSubscribe: {
              errors: [],
              wikiPage: {
                id: this.wikiPage.id,
                subscribed: newSubState,
              },
            },
          },
        });

        const message = newSubState
          ? __('Notifications turned on')
          : __('Notifications turned off');
        this.$toast.show(message);
      } catch (error) {
        this.handleSubscribeError(error, newSubState);
      }

      this.changingSubState = false;
    },
    handleSubscribeError(error, newSubState) {
      const message = newSubState
        ? __('An error occurred while subscribing to this page. Please try again later.')
        : __('An error occurred while unsubscribing from this page. Please try again later.');

      this.$toast.show(message);
      Sentry.captureException(error);
    },
  },
  i18n: {
    edit: __('Edit'),
    notifications: __('Notifications'),
    restoreText: __('Restore this version'),
    cancelText: __('Cancel'),
    newPage: s__('Wiki|New page'),
    editPage: s__('Wiki|Edit page'),
    newTemplate: s__('Wiki|New template'),
    editTemplate: s__('Wiki|Edit template'),
    newSidebar: s__('Wiki|New custom sidebar'),
    editSidebar: s__('Wiki|Edit custom sidebar'),
    lastEdited: s__('Wiki|Last edited by %{author} %{timeago}'),
    createFromTemplate: s__('Wiki|Create from template'),
    createFromTemplateTitle: s__('Wiki|Create a new wiki page using this template'),
  },
  modal: {
    restoreVersionModalId: 'wiki-restore-version-modal',
  },
};
</script>

<template>
  <div>
    <div
      class="js-wiki-page-header wiki-page-header has-sidebar-toggle detail-page-header gl-flex gl-flex-wrap gl-border-b-0 gl-px-5 !gl-pt-0"
    >
      <page-heading class="gl-wrap-break-word gl-w-full">
        <template #heading>
          <span class="gl-flex gl-items-center">
            <div class="toggle-with-hide-transition gl-mb-2">
              <wiki-sidebar-toggle action="open" />
            </div>
            <span>{{ pageHeading }}</span>
          </span>
        </template>

        <template v-if="lastVersion" #description>
          <div class="wiki-last-version gl-leading-20" data-testid="wiki-page-last-version">
            <gl-sprintf :message="$options.i18n.lastEdited">
              <template #author>
                <gl-link :href="authorUrl" class="gl-font-bold gl-text-default">{{
                  pageVersion.author_name
                }}</gl-link>
              </template>
              <template #timeago>
                <time-ago :time="pageVersion.authored_date" target="wiki-last-version" />
              </template>
            </gl-sprintf>
          </div>
        </template>
      </page-heading>
    </div>

    <panel-actions-portal>
      <gl-button
        v-if="showCreateFromTemplateButton"
        v-gl-tooltip.bottom.html
        :title="$options.i18n.createFromTemplateTitle"
        category="tertiary"
        size="small"
        class="gl-hidden @md/panel:gl-inline-flex"
        data-testid="wiki-create-from-template-button"
        :href="createFromTemplateUrl"
      >
        {{ $options.i18n.createFromTemplate }}
      </gl-button>

      <gl-button
        v-if="showRestoreVersionButton"
        v-gl-modal="$options.modal.restoreVersionModalId"
        category="tertiary"
        size="small"
        class="gl-hidden @md/panel:gl-inline-flex"
        data-testid="wiki-restore-version-button"
      >
        {{ $options.i18n.restoreText }}
      </gl-button>

      <gl-button
        v-if="showEditButton"
        v-gl-tooltip.bottom.html
        :title="editTooltip"
        category="tertiary"
        size="small"
        data-testid="wiki-edit-button"
        @click="setEditingMode"
      >
        {{ $options.i18n.edit }}
      </gl-button>

      <gl-button
        v-if="isLoggedIn"
        v-gl-tooltip.bottom="subscribeTooltip"
        :disabled="!wikiPage.id"
        :selected="isSubscribed"
        :aria-label="$options.i18n.notifications"
        :aria-pressed="String(isSubscribed)"
        category="tertiary"
        size="small"
        class="btn-icon"
        data-testid="wiki-subscribe-button"
        @click="toggleSubscribe"
      >
        <gl-animated-notification-icon :is-on="!isSubscribed" class="gl-button-icon" />
      </gl-button>

      <wiki-more-dropdown>
        <template v-if="showCreateFromTemplateButton || showRestoreVersionButton" #default>
          <gl-disclosure-dropdown-item
            v-if="showCreateFromTemplateButton"
            :item="createFromTemplateItem"
            icon="doc-new"
          />
          <gl-disclosure-dropdown-item
            v-if="showRestoreVersionButton"
            v-gl-modal="$options.modal.restoreVersionModalId"
            :item="restoreVersionItem"
            icon="retry"
          />
        </template>
      </wiki-more-dropdown>
    </panel-actions-portal>

    <restore-version-modal :modal-id="$options.modal.restoreVersionModalId" />
  </div>
</template>
