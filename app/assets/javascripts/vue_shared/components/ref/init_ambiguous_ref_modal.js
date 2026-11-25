import { parseBoolean } from '@gitlab/frontend-utils';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import AmbiguousRefModal from './components/ambiguous_ref_modal.vue';
import { isRefTypeSet } from './is_ref_type_set';

export default (el = document.querySelector('#js-ambiguous-ref-modal')) => {
  if (!el || isRefTypeSet() || !parseBoolean(el.dataset.ambiguous)) return false;

  const { ref } = el.dataset;

  return initVueApp({
    el,
    name: 'AmbiguousRefModalRoot',
    component: AmbiguousRefModal,
    props: { refName: ref },
  });
};
