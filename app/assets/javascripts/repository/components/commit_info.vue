<script>
import { GlTooltipDirective, GlLink, GlButton, GlSprintf } from '@gitlab/ui';
import CommitAttribution from 'ee_component/commit/components/commit_attribution.vue';
import CommitSessionRow from 'ee_component/commit/components/commit_session_row.vue';
import { commitAuthor, commitCommitter } from '~/commit/utils/attribution';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { __, sprintf } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';
import defaultAvatarUrl from 'images/no_avatar.png';
import TimeagoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import UserAvatarImage from '~/vue_shared/components/user_avatar/user_avatar_image.vue';
import getRefMixin from '../mixins/get_ref';

export default {
  name: 'CommitInfo',
  components: {
    CommitAttribution,
    CommitSessionRow,
    UserAvatarLink,
    TimeagoTooltip,
    GlButton,
    GlLink,
    UserAvatarImage,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  mixins: [getRefMixin, glFeatureFlagsMixin()],
  props: {
    commit: {
      type: Object,
      required: true,
    },
    span: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data() {
    return { showDescription: false };
  },
  computed: {
    commitDescription() {
      // Strip the newline at the beginning
      return this.commit?.descriptionHtml?.replace(/^&#x000A;/, '');
    },
    avatarLinkAltText() {
      return sprintf(__(`%{username}'s avatar`), { username: this.commit.authorName });
    },
    truncateAuthorName() {
      return typeof this.span === 'number' && this.span < 3;
    },
    isCommitterDifferentFromAuthor() {
      return (
        this.commit.authorName !== this.commit.committerName ||
        this.commit.authorEmail !== this.commit.committerEmail
      );
    },
    author() {
      return commitAuthor(this.commit);
    },
    committer() {
      return commitCommitter(this.commit);
    },
  },
  methods: {
    toggleShowDescription() {
      this.showDescription = !this.showDescription;
    },
  },
  defaultAvatarUrl,
  safeHtmlConfig: {
    ADD_TAGS: ['gl-emoji'],
  },
  i18n: {
    toggleCommitDescription: __('Toggle commit description'),
  },
};
</script>

<template>
  <div class="commit gl-flex gl-w-full gl-px-4 gl-py-3">
    <user-avatar-link
      v-if="commit.author"
      :link-href="commit.author.webPath"
      :img-src="commit.author.avatarUrl"
      :img-alt="avatarLinkAltText"
      :img-size="32"
      class="gl-my-2 gl-mr-3"
    />
    <user-avatar-image
      v-else
      class="gl-my-2 gl-mr-3"
      :img-src="commit.authorGravatar || $options.defaultAvatarUrl"
      :size="32"
    />
    <div class="commit-detail flex-list gl-flex gl-min-w-0 gl-grow">
      <div
        class="commit-content gl-inline-flex gl-w-full gl-flex-wrap gl-items-baseline"
        data-testid="commit-content"
      >
        <div class="gl-inline-flex gl-basis-full gl-items-center gl-gap-x-3">
          <gl-link
            v-safe-html:[$options.safeHtmlConfig]="commit.titleHtml"
            :href="commit.webPath"
            :class="{ 'gl-italic': !commit.message }"
            class="commit-row-message item-title gl-line-clamp-1 gl-whitespace-normal !gl-break-all"
            aria-describedby="recent-commit-description"
          />
          <p id="recent-commit-description" class="gl-sr-only">
            {{ __('Most recent commit.') }}
          </p>
          <gl-button
            v-if="commit.descriptionHtml"
            v-gl-tooltip
            :class="{ open: showDescription }"
            :title="$options.i18n.toggleCommitDescription"
            :aria-label="$options.i18n.toggleCommitDescription"
            :selected="showDescription"
            class="!gl-ml-0"
            icon="ellipsis_h"
            @click="toggleShowDescription"
          />
        </div>
        <div
          class="committer gl-basis-full gl-text-sm"
          :class="{
            'gl-truncate': !glFeatures.commitAgentSessions,
            'gl-inline-flex': truncateAuthorName,
          }"
          data-testid="committer"
        >
          <template v-if="glFeatures.commitAgentSessions">
            <commit-attribution :author="author" :committer="committer" />
            <commit-session-row :sessions="commit.agentSessions" separated />
          </template>
          <gl-sprintf
            v-else-if="commit.committerName && isCommitterDifferentFromAuthor"
            :message="
              __('%{author} authored %{authoredDate} and %{committer} committed %{committedDate}')
            "
          >
            <template #author>
              <gl-link
                v-if="commit.author"
                :href="commit.author.webPath"
                class="commit-author-link js-user-link"
                :class="{ 'gl-inline-block gl-truncate': truncateAuthorName }"
              >
                {{ commit.author.name }}</gl-link
              >
              <template v-else>
                {{ commit.authorName }}
              </template>
            </template>

            <template #authoredDate>
              <timeago-tooltip :time="commit.authoredDate" tooltip-placement="bottom" />
            </template>

            <template #committer>
              <user-avatar-image
                v-if="commit.committerAvatarUrl"
                class="gl-mx-1 gl-my-2"
                :img-src="commit.committerAvatarUrl"
                :size="16"
              />
              {{ commit.committerName }}
            </template>

            <template #committedDate>
              <timeago-tooltip :time="commit.committedDate" tooltip-placement="bottom" />
            </template>
          </gl-sprintf>

          <gl-sprintf v-else :message="__('%{author} authored %{authoredDate}')">
            <template #author>
              <gl-link
                v-if="commit.author"
                :href="commit.author.webPath"
                class="commit-author-link js-user-link"
                :class="{ 'gl-inline-block gl-truncate': truncateAuthorName }"
              >
                {{ commit.author.name }}</gl-link
              >
              <template v-else>{{ commit.authorName }}</template>
            </template>

            <template #authoredDate>
              <timeago-tooltip :time="commit.authoredDate" tooltip-placement="bottom" />
            </template>
          </gl-sprintf>
        </div>
        <pre
          v-if="commitDescription"
          v-safe-html:[$options.safeHtmlConfig]="commitDescription"
          :class="{ '!gl-block': showDescription }"
          class="commit-row-description gl-mb-3 gl-whitespace-pre-wrap"
        ></pre>
      </div>
      <div class="gl-grow"></div>
      <slot></slot>
    </div>
  </div>
</template>
