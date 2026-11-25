import { defineStore } from 'pinia';
import { uniqBy, orderBy } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Api from '~/api';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';
import { ACTIVE_AND_BLOCKED_USER_STATES } from '~/users_select/constants';
import { autocompleteUsersPath } from '~/lib/utils/path_helpers/autocomplete';

const uniqAndSortByDate = (commits) =>
  orderBy(uniqBy(commits, 'short_id'), (c) => new Date(c.committed_date), ['desc']);

export const useAddContextCommits = defineStore('addContextCommits', {
  state() {
    return {
      projectId: null,
      mergeRequestIid: null,
      contextCommitsPath: '',
      tabIndex: 0,
      isLoadingCommits: false,
      commits: [],
      commitsLoadingError: false,
      selectedCommits: [],
      isLoadingContextCommits: false,
      contextCommits: [],
      contextCommitsLoadingError: false,
      toRemoveCommits: [],
    };
  },
  actions: {
    setBaseConfig(options) {
      this.$patch(options);
    },
    setTabIndex(tabIndex) {
      this.tabIndex = tabIndex;
    },
    searchCommits(search = {}) {
      this.isLoadingCommits = true;
      this.commitsLoadingError = false;

      let params = {};
      if (search) {
        params = { params: search };
      }

      return axios
        .get(this.contextCommitsPath, params)
        .then(({ data }) => {
          const selectedIds = new Set(
            this.selectedCommits.filter((c) => c.isSelected).map((c) => c.short_id),
          );
          const commits = data.map((o) => ({ ...o, isSelected: selectedIds.has(o.short_id) }));
          if (!search) {
            this.setCommits({ commits: [...commits, ...this.contextCommits] });
          } else {
            this.setCommits({ commits });
          }
        })
        .catch(() => {
          this.commitsLoadingError = true;
          this.isLoadingCommits = false;
        });
    },
    setCommits({ commits: data, silentAddition = false }) {
      this.commits = uniqAndSortByDate(data);
      if (!silentAddition) {
        this.isLoadingCommits = false;
        this.commitsLoadingError = false;
      }
    },
    createContextCommits({ commits, forceReload = false }) {
      return Api.createContextCommits(this.projectId, this.mergeRequestIid, {
        commits: commits.map((commit) => commit.short_id),
      })
        .then(() => {
          if (forceReload) {
            window.location.reload();
          }

          return true;
        })
        .catch(() => {
          if (forceReload) {
            createAlert({
              message: s__('ContextCommits|Failed to create context commits. Please try again.'),
            });
          }

          return false;
        });
    },
    fetchContextCommits() {
      this.isLoadingContextCommits = true;
      this.contextCommitsLoadingError = false;

      return Api.allContextCommits(this.projectId, this.mergeRequestIid)
        .then(({ data }) => {
          const contextCommits = data.map((o) => ({ ...o, isSelected: true }));
          this.setContextCommits(contextCommits);
          this.setCommits({
            commits: [...this.commits, ...contextCommits],
            silentAddition: true,
          });
          this.setSelectedCommits(contextCommits);
        })
        .catch(() => {
          this.contextCommitsLoadingError = true;
          this.isLoadingContextCommits = false;
        });
    },
    setContextCommits(data) {
      this.contextCommits = data;
      this.isLoadingContextCommits = false;
      this.contextCommitsLoadingError = false;
    },
    removeContextCommits(forceReload = false) {
      return Api.removeContextCommits(this.projectId, this.mergeRequestIid, {
        commits: this.toRemoveCommits,
      })
        .then(() => {
          if (forceReload) {
            window.location.reload();
          }

          return true;
        })
        .catch(() => {
          if (forceReload) {
            createAlert({
              message: s__('ContextCommits|Failed to delete context commits. Please try again.'),
            });
          }

          return false;
        });
    },
    setSelectedCommits(selected) {
      this.selectedCommits = uniqAndSortByDate(selected);
    },
    fetchAuthors(author = null) {
      return axios
        .get(autocompleteUsersPath({ format: 'json' }), {
          params: {
            project_id: this.projectId,
            states: ACTIVE_AND_BLOCKED_USER_STATES,
            search: author,
          },
        })
        .then(({ data }) => data)
        .catch((error) => {
          // Resolves with undefined; UserToken shows its own fetch-error alert.
          Sentry.captureException(error);
        });
    },
    setToRemoveCommits(data) {
      this.toRemoveCommits = data;
    },
    resetModalState() {
      this.tabIndex = 0;
      this.commits = [];
      this.contextCommits = [];
      this.selectedCommits = [];
      this.toRemoveCommits = [];
    },
  },
});
