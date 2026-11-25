import { defineStore } from 'pinia';
import { normalizeHeaders } from '@gitlab/frontend-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import axios from '~/lib/utils/axios_utils';
import { joinPaths } from '~/lib/utils/url_utility';
import { isOtherToneOfSameEmoji } from '~/emoji/skin_tone';

/**
 * Creates an intermediary award, used for display
 * until the real award is loaded from the backend.
 */
const newOptimisticAward = (name, awards) => {
  const freeId = Math.min(...awards.map((a) => a.id), Number.MAX_SAFE_INTEGER) - 1;
  return {
    id: freeId,
    name,
    user: {
      id: window.gon.current_user_id,
      name: window.gon.current_user_fullname,
      username: window.gon.current_username,
    },
  };
};

export const useAwardsApp = defineStore('awardsApp', {
  state() {
    return {
      awards: [],
      path: '',
      currentUserId: null,
      canAwardEmoji: false,
    };
  },
  actions: {
    setInitialData({ path, currentUserId, canAwardEmoji }) {
      this.path = path;
      this.currentUserId = currentUserId;
      this.canAwardEmoji = canAwardEmoji;
    },
    async fetchAwards(page = '1') {
      try {
        // eslint-disable-next-line @gitlab/no-hardcoded-urls -- this.path is a REST API path passed from Rails. Not an ideal setup but acceptable.
        const url = joinPaths(gon.relative_url_root || '', this.path);
        const { data, headers } = await axios.get(url, { params: { per_page: 100, page } });
        const normalizedHeaders = normalizeHeaders(headers);
        const nextPage = normalizedHeaders['X-NEXT-PAGE'];

        this.awards.push(...data);

        if (nextPage) {
          this.fetchAwards(nextPage);
        }
      } catch (error) {
        Sentry.captureException(error);
      }
    },
    async toggleAward(name) {
      const award = this.awards.find((a) => a.name === name && a.user.id === this.currentUserId);

      try {
        if (award) {
          this.awards = this.awards.filter(({ id }) => id !== award.id);

          await axios
            // eslint-disable-next-line @gitlab/no-hardcoded-urls -- this.path is a REST API path passed from Rails. Not an ideal setup but acceptable.
            .delete(joinPaths(gon.relative_url_root || '', `${this.path}/${award.id}`))
            .catch((err) => {
              this.awards.push(award);

              throw err;
            });
        } else {
          const optimisticAward = newOptimisticAward(name, this.awards);

          // The server keeps one tone per user and emoji, so the other tones leave the list with the add.
          const otherTones = this.awards.filter(
            (a) => a.user.id === this.currentUserId && isOtherToneOfSameEmoji(name, a.name),
          );
          this.awards = this.awards.filter((a) => !otherTones.includes(a));
          this.awards.push(optimisticAward);

          const { data } = await axios
            // eslint-disable-next-line @gitlab/no-hardcoded-urls -- this.path is a REST API path passed from Rails. Not an ideal setup but acceptable.
            .post(joinPaths(gon.relative_url_root || '', this.path), {
              name,
            })
            .catch((err) => {
              this.awards.push(...otherTones);

              throw err;
            })
            .finally(() => {
              this.awards = this.awards.filter(({ id }) => id !== optimisticAward.id);
            });

          this.awards.push(data);
        }
      } catch (error) {
        Sentry.captureException(error);
      }
    },
  },
});
