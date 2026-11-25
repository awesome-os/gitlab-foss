import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { pinia } from '~/pinia/instance';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { commitDiffDiscussionsStore } from '~/rapid_diffs/stores/instances/commit_discussions';
import CommitTimeline from './discussions/timeline.vue';

export function initTimeline(appData) {
  const timelineContainer = document.querySelector('[data-commit-timeline]');

  initVueApp({
    el: timelineContainer,
    name: 'CommitTimelineRoot',
    pinia,
    apolloProvider,
    provide: {
      store: commitDiffDiscussionsStore,
      userPermissions: appData.userPermissions,
      endpoints: {
        discussions: appData.discussionsEndpoint,
        previewMarkdown: appData.previewMarkdownEndpoint,
        markdownDocs: appData.markdownDocsPath,
        register: appData.registerPath,
        signIn: appData.signInPath,
        reportAbuse: appData.reportAbusePath,
      },
      noteableType: appData.noteableType,
      newCommentTemplatePaths: appData.newCommentTemplatePaths || [],
    },
    component: CommitTimeline,
  });
}
