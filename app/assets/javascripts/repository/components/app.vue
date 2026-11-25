<script>
// Static, not async: an async chunk would insert the row late and shift <router-view>.
// EE entries already bundle CodeOwners; CE resolves this to the empty component.
import CodeOwnersWrapper from 'ee_component/repository/components/code_owners_wrapper.vue';
import FileTreeBrowser from '~/repository/file_tree_browser/file_tree_browser.vue';
import repositoryPathMixin from '~/repository/mixins/repository_path';
import { generateHistoryUrl } from '~/repository/utils/url_utility';
import AmbiguousRefModal from '~/vue_shared/components/ref/components/ambiguous_ref_modal.vue';
import BlobAuxiliaryViewer from './blob_auxiliary_viewer.vue';
import HeaderArea from './header_area.vue';
import ForkInfo from './fork_info.vue';
import LastCommit from './last_commit.vue';

export default {
  name: 'RepositoryApp',
  components: {
    FileTreeBrowser,
    HeaderArea,
    ForkInfo,
    LastCommit,
    BlobAuxiliaryViewer,
    CodeOwnersWrapper,
    AmbiguousRefModal,
  },
  mixins: [repositoryPathMixin],
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    projectId: {
      type: String,
      required: true,
    },
    currentRef: {
      type: String,
      required: true,
    },
    refType: {
      type: String,
      required: false,
      default: null,
    },
    ambiguousRef: {
      type: Boolean,
      required: false,
      default: false,
    },
    historyLink: {
      type: String,
      required: true,
    },
    forkInfo: {
      type: Object,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      // Decided once: client-side navigation keeps this root mounted, so the modal never re-opens.
      // The backend already reports `ambiguousRef: false` when the URL sets a valid `ref_type`.
      showAmbiguousRefModal: this.ambiguousRef,
    };
  },
  computed: {
    isBlobRoute() {
      return Boolean(this.$route.name?.startsWith('blobPath'));
    },
    showFileTreeBrowser() {
      return this.$route.name !== 'projectRoot';
    },
    routeRefType() {
      return this.$route.meta.refType || this.$route.query.ref_type;
    },
    historyUrl() {
      return generateHistoryUrl(this.historyLink, this.computedPath, this.routeRefType).href;
    },
  },
};
</script>

<template>
  <!-- Mirrors the legacy .navigation-root flex layout. -->
  <div class="repository-app gl-flex">
    <file-tree-browser
      v-if="showFileTreeBrowser"
      :project-path="projectPath"
      :current-ref="currentRef"
      :ref-type="refType"
    />
    <!-- Gap spacing and the last commit container classes match the legacy `#tree-holder` markup. -->
    <div class="gl-flex gl-w-full gl-min-w-0 gl-flex-col gl-gap-5">
      <header-area
        :project-path="projectPath"
        :project-id="projectId"
        :current-ref="currentRef"
        :ref-type="refType"
      />
      <fork-info v-if="forkInfo" v-bind="forkInfo" />
      <div class="project-last-commit gl-border gl-overflow-clip gl-rounded-lg gl-bg-subtle">
        <last-commit
          :current-path="computedPath"
          :ref-type="routeRefType"
          :history-url="historyUrl"
        />
        <code-owners-wrapper
          :project-path="projectPath"
          :file-path="computedPath"
          :branch="currentRef"
        />
        <!-- Keyed so a blob without a notice does not keep showing the previous blob's notice. -->
        <blob-auxiliary-viewer
          v-if="isBlobRoute"
          :key="computedPath"
          :path="computedPath"
          :project-path="projectPath"
          :current-ref="currentRef"
          :ref-type="routeRefType"
        />
      </div>
      <router-view :key="$route.path" />
    </div>
    <ambiguous-ref-modal v-if="showAmbiguousRefModal" :ref-name="currentRef" />
  </div>
</template>
