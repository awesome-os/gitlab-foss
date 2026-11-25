import Vue from 'vue';
import { mapActions, mapState } from 'pinia';
import { parseBoolean } from '@gitlab/frontend-utils';
import AwardsList from '~/vue_shared/components/awards_list.vue';
import { EMOJI_THUMBS_UP, EMOJI_THUMBS_DOWN } from '~/emoji/constants';
import { pinia } from '~/pinia/instance';
import { useAwardsApp } from './store';

export default (el) => {
  if (!el) return null;

  const {
    dataset: { path, newCustomEmojiPath },
  } = el;
  const canAwardEmoji = parseBoolean(el.dataset.canAwardEmoji);
  const showDefaultAwardEmojis = parseBoolean(el.dataset.showDefaultAwardEmojis);

  useAwardsApp(pinia).setInitialData({
    path,
    currentUserId: window.gon.current_user_id,
    canAwardEmoji,
  });

  return new Vue({
    el,
    name: 'AwardsListRoot',
    pinia,
    provide: {
      newCustomEmojiPath,
    },
    computed: {
      ...mapState(useAwardsApp, ['currentUserId', 'canAwardEmoji', 'awards']),
    },
    mounted() {
      this.fetchAwards();
    },
    methods: {
      ...mapActions(useAwardsApp, ['fetchAwards', 'toggleAward']),
    },
    render(createElement) {
      return createElement(AwardsList, {
        props: {
          awards: this.awards,
          canAwardEmoji: this.canAwardEmoji,
          currentUserId: this.currentUserId,
          defaultAwards: showDefaultAwardEmojis ? [EMOJI_THUMBS_UP, EMOJI_THUMBS_DOWN] : [],
          selectedClass: 'selected',
        },
        on: {
          award: this.toggleAward,
        },
      });
    },
  });
};
