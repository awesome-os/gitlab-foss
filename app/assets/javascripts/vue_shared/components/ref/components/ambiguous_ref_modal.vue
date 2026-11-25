<script>
import { GlModal, GlButton, GlSprintf } from '@gitlab/ui';
import { visitUrl } from '~/lib/utils/url_utility';
import { REF_TYPE_PARAM_NAME, TAG_REF_TYPE, BRANCH_REF_TYPE } from '../constants';

export default {
  name: 'AmbiguousRefModal',
  tagRefType: TAG_REF_TYPE,
  branchRefType: BRANCH_REF_TYPE,
  components: {
    GlModal,
    GlButton,
    GlSprintf,
  },

  props: {
    refName: {
      type: String,
      required: true,
    },
  },
  mounted() {
    this.$refs.ambiguousRefModal.show();
  },
  methods: {
    navigate(refType) {
      const url = new URL(window.location.href);
      url.searchParams.set(REF_TYPE_PARAM_NAME, refType);

      visitUrl(url.toString());
    },
  },
};
</script>

<template>
  <gl-modal
    ref="ambiguousRefModal"
    modal-id="ambiguous-ref"
    :title="s__('AmbiguousRef|Which reference do you want to view?')"
    @primary="navigate"
  >
    <p class="gl-mb-0">
      <gl-sprintf
        :message="s__('AmbiguousRef|There is a branch and a tag with the same name of %{ref}.')"
      >
        <template #ref
          ><code>{{ refName }}</code></template
        >
      </gl-sprintf>
    </p>

    <p>
      {{ s__('AmbiguousRef|Which reference would you like to view?') }}
    </p>

    <template #modal-footer>
      <gl-button
        category="secondary"
        variant="confirm"
        data-testid="view-tag-btn"
        @click="() => navigate($options.tagRefType)"
        >{{ s__('AmbiguousRef|View tag') }}</gl-button
      >
      <gl-button
        category="secondary"
        variant="confirm"
        data-testid="view-branch-btn"
        @click="() => navigate($options.branchRefType)"
        >{{ s__('AmbiguousRef|View branch') }}</gl-button
      >
    </template>
  </gl-modal>
</template>
