import { parseBoolean } from '@gitlab/frontend-utils';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { pinia } from '~/pinia/instance';
import AddContextCommitsModalTrigger from './components/add_context_commits_modal_trigger.vue';
import AddContextCommitsModalWrapper from './components/add_context_commits_modal_wrapper.vue';

export default function initAddContextCommitsTriggers() {
  const addContextCommitsModalTriggerEl = document.querySelector('.add-review-item-modal-trigger');
  const addContextCommitsModalWrapperEl = document.querySelector('.add-review-item-modal-wrapper');

  if (addContextCommitsModalTriggerEl) {
    const { commitsEmpty, contextCommitsEmpty } = addContextCommitsModalTriggerEl.dataset;

    initVueApp({
      el: addContextCommitsModalTriggerEl,
      name: 'AddContextCommitsModalTriggerRoot',
      component: AddContextCommitsModalTrigger,
      props: {
        commitsEmpty: parseBoolean(commitsEmpty),
        contextCommitsEmpty: parseBoolean(contextCommitsEmpty),
      },
    });
  }

  if (addContextCommitsModalWrapperEl) {
    const { contextCommitsPath, targetBranch, mergeRequestIid, projectId } =
      addContextCommitsModalWrapperEl.dataset;

    initVueApp({
      el: addContextCommitsModalWrapperEl,
      name: 'AddContextCommitsModalWrapperRoot',
      pinia,
      component: AddContextCommitsModalWrapper,
      props: {
        contextCommitsPath,
        targetBranch,
        mergeRequestIid: Number(mergeRequestIid),
        projectId: Number(projectId),
      },
    });
  }
}
