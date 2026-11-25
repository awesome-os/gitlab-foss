<script>
import { GlButton } from '@gitlab/ui';
import { mapActions } from 'pinia';
import axios from '~/lib/utils/axios_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import { useWhatsNew } from '../store';
import Feature from './feature.vue';
import SkeletonLoader from './skeleton_loader.vue';

export default {
  name: 'OtherUpdates',
  components: {
    GlButton,
    Feature,
    SkeletonLoader,
  },
  props: {
    features: {
      type: Array,
      required: true,
    },
    fetching: {
      type: Boolean,
      required: true,
    },
    readArticles: {
      type: Array,
      required: false,
      default: () => [],
    },
    totalArticlesToRead: {
      type: Number,
      required: true,
    },
    markAsReadPath: {
      type: String,
      required: false,
      default: null,
    },
    pageInfo: {
      type: Object,
      required: true,
    },
  },
  emits: ['load-more', 'close-drawer'],
  data() {
    return {
      previousButtonCount: 0,
      markingAllAsRead: false,
    };
  },
  computed: {
    unreadArticleIds() {
      return Array.from({ length: this.totalArticlesToRead }, (_, i) => i + 1).filter(
        (id) => !this.readArticles.includes(id),
      );
    },
    canMarkAllAsRead() {
      return isLoggedIn() && Boolean(this.markAsReadPath) && this.unreadArticleIds.length > 0;
    },
  },
  watch: {
    fetching(newVal, oldVal) {
      if (oldVal && !newVal && this.previousButtonCount > 0) {
        this.focusFirstNewItem();
      }
    },
  },
  methods: {
    ...mapActions(useWhatsNew, ['setReadArticles']),
    loadMore() {
      this.previousButtonCount = this.getArticleToggleButtons().length;
      this.$emit('load-more');
    },
    getArticleToggleButtons() {
      return (
        this.$refs.featureList?.querySelectorAll('[data-testid="whats-new-article-toggle"]') || []
      );
    },
    focusFirstNewItem() {
      this.$nextTick(() => {
        const buttons = this.getArticleToggleButtons();
        const firstNewButton = buttons[this.previousButtonCount];
        if (firstNewButton) {
          firstNewButton.focus();
        }
      });
    },
    showUnread(index) {
      return index <= this.totalArticlesToRead && !this.readArticles.includes(index);
    },
    markAsRead(index) {
      if (isLoggedIn() && this.markAsReadPath) {
        axios
          .post(this.markAsReadPath, { article_id: index })
          .then(() => {
            this.setReadArticles([...this.readArticles, index]);
          })
          .catch((error) => Sentry.captureException(error));
      }
    },
    async markAllAsRead() {
      const ids = this.unreadArticleIds;
      this.markingAllAsRead = true;

      // There is no bulk endpoint, so mark each unread article and record all successes at once.
      const results = await Promise.allSettled(
        ids.map((id) => axios.post(this.markAsReadPath, { article_id: id })),
      );

      // A 400 means the article was already read, for example in another tab.
      const isRead = ({ status, reason }) =>
        status === 'fulfilled' || reason?.response?.status === HTTP_STATUS_BAD_REQUEST;

      const readIds = ids.filter((_, i) => isRead(results[i]));
      results
        .filter((result) => !isRead(result))
        .forEach(({ reason }) => Sentry.captureException(reason));

      if (readIds.length) {
        this.setReadArticles([...this.readArticles, ...readIds]);
      }
      this.markingAllAsRead = false;

      if (readIds.length === ids.length) {
        // The button disappears once everything is read, so keep keyboard focus inside the list.
        await this.$nextTick();
        this.getArticleToggleButtons()[0]?.focus();
      }
    },
    closeDrawer() {
      this.$emit('close-drawer');
    },
  },
};
</script>

<template>
  <div>
    <template v-if="features.length || !fetching">
      <div ref="featureList" class="gl-p-0">
        <feature
          v-for="(feature, index) in features"
          :key="feature.name"
          :feature="feature"
          :show-unread="showUnread(index)"
          :show-mark-all-as-read="index === 0 && canMarkAllAsRead"
          :marking-all-as-read="markingAllAsRead"
          @mark-article-as-read="markAsRead(index)"
          @mark-all-as-read="markAllAsRead"
          @close-drawer="closeDrawer"
        />
      </div>

      <div v-if="pageInfo.nextPage" class="gl-mb-6 gl-mt-5 gl-flex gl-justify-center">
        <gl-button
          data-testid="load-more-button"
          size="small"
          category="tertiary"
          variant="confirm"
          :loading="fetching"
          @click="loadMore"
        >
          {{ __('Load more') }}
        </gl-button>
      </div>
    </template>
    <div v-else class="gl-mt-5">
      <skeleton-loader />
    </div>
  </div>
</template>
