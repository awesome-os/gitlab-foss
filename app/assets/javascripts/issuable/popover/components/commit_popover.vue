<script>
import { GlAvatar, GlIcon, GlLink, GlPopover, GlSkeletonLoader, GlTruncate } from '@gitlab/ui';
import CommitPopoverContent from 'ee_component/commit/components/commit_popover_content.vue';
import { __, s__, sprintf } from '~/locale';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { newDate } from '~/lib/utils/datetime/date_calculation_utility';
import defaultAvatarUrl from 'images/no_avatar.png';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import query from '../queries/commit.query.graphql';

export default {
  name: 'CommitPopover',

  i18n: {
    errorMessage: s__('CommitPopover|Could not load commit. Please reload the page.'),
  },

  components: {
    CommitPopoverContent,
    GlAvatar,
    GlIcon,
    GlLink,
    GlPopover,
    GlSkeletonLoader,
    GlTruncate,
  },

  mixins: [glFeatureFlagsMixin()],

  props: {
    target: {
      type: HTMLAnchorElement,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    commitSha: {
      type: String,
      required: true,
    },
  },

  data() {
    return {
      commit: {},
      hasError: false,
      notFound: false,
    };
  },

  apollo: {
    commit: {
      query,
      variables() {
        return {
          projectPath: this.projectPath,
          sha: this.commitSha,
        };
      },
      update: (data) => data.project?.repository?.commit ?? {},
      result({ data, loading }) {
        // No record means it does not exist or the viewer cannot read it: show nothing.
        if (!loading && data) this.notFound = !data.project?.repository?.commit;
      },
      error() {
        this.hasError = true;
      },
    },
  },

  computed: {
    authorName() {
      return this.commit.author?.name ?? this.commit.authorName ?? '';
    },
    avatarUrl() {
      return this.commit.author?.avatarUrl ?? defaultAvatarUrl;
    },
    authoredText() {
      if (!this.commit.authoredDate) return '';
      const timeago = getTimeago().format(newDate(this.commit.authoredDate));
      return sprintf(__('Authored %{timeago}'), { timeago });
    },
    isLoading() {
      return this.$apollo.queries.commit.loading;
    },
    showsAgentSessions() {
      return this.glFeatures.commitAgentSessions && !this.hasError;
    },
    popoverClasses() {
      // Leaves room for the popover's 5px boundary padding on each side of narrow windows.
      return this.showsAgentSessions ? ['gl-w-48', 'gl-max-w-[calc(100vw-10px)]'] : ['gl-min-w-30'];
    },
  },
};
</script>

<template>
  <gl-popover
    v-if="!notFound"
    :target="target"
    boundary="viewport"
    placement="top"
    :css-classes="popoverClasses"
    :show="isLoading || Boolean(commit.shortId) || hasError"
  >
    <commit-popover-content
      v-if="showsAgentSessions"
      :commit="commit"
      :project-path="projectPath"
      :loading="isLoading"
      tracking-label="commit_reference"
    />

    <gl-skeleton-loader v-else-if="isLoading" :height="15">
      <rect width="100%" height="15" rx="4" />
    </gl-skeleton-loader>

    <template v-else-if="hasError">
      <p class="gl-m-0 gl-text-subtle" data-testid="commit-error-message">
        {{ $options.i18n.errorMessage }}
      </p>
    </template>

    <template v-else-if="commit.shortId">
      <div class="gl-flex gl-flex-col gl-gap-3">
        <div class="gl-text-subtle" data-testid="commit-authored-text">
          {{ authoredText }}
        </div>

        <gl-link
          :href="commit.webPath"
          class="gl-text-default hover:gl-text-default"
          data-testid="commit-title-link"
        >
          <gl-truncate :text="commit.title" :lines="2" class="gl-heading-5 !gl-my-0" />
        </gl-link>

        <div class="gl-flex gl-items-center gl-gap-2 gl-text-subtle">
          <gl-avatar :src="avatarUrl" :size="16" :alt="authorName" />
          <span data-testid="commit-author-name">{{ authorName }}</span>
        </div>

        <div class="gl-flex gl-items-center gl-gap-2">
          <gl-icon name="commit" :size="14" class="gl-text-subtle" />
          <gl-link
            :href="commit.webPath"
            class="gl-font-monospace gl-text-subtle hover:gl-text-default"
            data-testid="commit-sha-link"
          >
            {{ commit.shortId }}
          </gl-link>
        </div>
      </div>
    </template>
  </gl-popover>
</template>
