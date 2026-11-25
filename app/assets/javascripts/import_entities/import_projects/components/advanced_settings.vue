<script>
import {
  GlButton,
  GlCollapse,
  GlForm,
  GlFormCheckbox,
  GlLink,
  GlPopover,
  GlSprintf,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';
import { CONTINUOUS_SYNC_STAGE } from '../../constants';

const SYNC_POPOVER_ID = 'import-settings-sync-full-list';

export default {
  name: 'AdvancedSettings',
  components: {
    GlButton,
    GlCollapse,
    GlForm,
    GlFormCheckbox,
    GlLink,
    GlPopover,
    GlSprintf,
  },
  props: {
    stages: {
      required: true,
      type: Array,
    },
    value: {
      required: true,
      type: Object,
    },
    expanded: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['input', 'update:expanded'],
  computed: {
    syncStage() {
      return this.stages.find(({ name }) => name === CONTINUOUS_SYNC_STAGE);
    },
    otherStages() {
      return this.stages.filter(({ name }) => name !== CONTINUOUS_SYNC_STAGE);
    },
  },
  methods: {
    toggle() {
      this.$emit('update:expanded', !this.expanded);
    },
  },
  syncPopoverId: SYNC_POPOVER_ID,
  syncedItems: [
    s__('GithubUpdatesImport|Repository'),
    s__('GithubUpdatesImport|Git LFS objects'),
    s__('GithubUpdatesImport|Issues and merge requests'),
    s__('GithubUpdatesImport|Comments, reviews and review comments'),
    s__('GithubUpdatesImport|Releases'),
    s__('GithubUpdatesImport|Markdown attachments (if selected)'),
  ],
  oneTimeItems: [
    s__('GithubUpdatesImport|Labels and milestones (new ones are added)'),
    s__('GithubUpdatesImport|Wiki'),
    s__('GithubUpdatesImport|Protected branches'),
    s__('GithubUpdatesImport|Collaborators (if selected)'),
  ],
  docsLink: helpPagePath('user/project/import/github', {
    anchor: 'use-a-github-personal-access-token',
  }),
};
</script>
<template>
  <section class="gl-mb-5">
    <gl-button
      variant="link"
      :icon="expanded ? 'chevron-lg-down' : 'chevron-lg-right'"
      :aria-expanded="expanded ? 'true' : 'false'"
      aria-controls="import-settings-panel"
      data-testid="import-settings-toggle"
      @click="toggle"
    >
      {{ s__('ImportProjects|Import settings') }}
    </gl-button>
    <gl-collapse id="import-settings-panel" :visible="expanded">
      <div class="gl-mt-3">
        <p class="gl-text-subtle">
          {{
            s__(
              'ImportProjects|The more information you select, the longer it will take to import.',
            )
          }}
          <gl-sprintf
            :message="
              s__(
                'ImportProjects|To import collaborators, or if your project has Git LFS files, you must use a classic personal access token with %{codeStart}read:org%{codeEnd} scope. %{linkStart}Learn more%{linkEnd}.',
              )
            "
          >
            <template #code="{ content }">
              <code class="gl-ml-2">{{ content }}</code>
            </template>
            <template #link="{ content }">
              <gl-link :href="$options.docsLink" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
        <gl-form>
          <div
            v-if="syncStage"
            class="gl-border gl-mb-5 gl-rounded-lg gl-bg-subtle gl-p-5"
            data-testid="sync-settings-card"
          >
            <p class="gl-mb-3 gl-mt-0">
              {{
                s__(
                  'ImportProjects|GitLab syncs later GitHub changes instead of importing once. Code, issues, merge requests, reviews, and releases stay updated, while wikis and protected branches are imported once. The project is read-only in GitLab while updates are on, so changes are made in GitHub.',
                )
              }}
              <gl-button
                :id="$options.syncPopoverId"
                variant="link"
                class="!gl-align-baseline"
                data-testid="sync-full-list-trigger"
                >{{ s__('ImportProjects|See the full list') }}</gl-button
              >
            </p>
            <gl-popover
              :target="$options.syncPopoverId"
              triggers="click blur"
              placement="bottom"
              data-testid="sync-full-list-popover"
            >
              <p class="gl-mb-2 gl-font-bold">{{ s__('ImportProjects|Kept up to date') }}</p>
              <ul class="gl-mb-3 gl-pl-5">
                <li v-for="item in $options.syncedItems" :key="item">{{ item }}</li>
              </ul>
              <p class="gl-mb-2 gl-font-bold">{{ s__('ImportProjects|Imported once') }}</p>
              <ul class="gl-mb-0 gl-pl-5">
                <li v-for="item in $options.oneTimeItems" :key="item">{{ item }}</li>
              </ul>
            </gl-popover>
            <gl-form-checkbox
              :checked="value[syncStage.name]"
              :data-qa-option-name="syncStage.name"
              data-testid="advanced-settings-checkbox"
              @change="$emit('input', { ...value, [syncStage.name]: $event })"
            >
              {{ s__('ImportProjects|Sync the repositories you import') }}
              <template #help>{{
                s__('ImportProjects|Only groups on Premium or Ultimate can keep updates on.')
              }}</template>
            </gl-form-checkbox>
          </div>
          <div
            v-if="otherStages.length"
            class="gl-border gl-rounded-lg gl-bg-subtle gl-p-5"
            data-testid="additional-settings-card"
          >
            <h3 class="gl-heading-5 gl-mb-3 gl-mt-0">
              {{ s__('ImportProjects|Additional settings') }}
            </h3>
            <gl-form-checkbox
              v-for="{ name, label, details } in otherStages"
              :key="name"
              :checked="value[name]"
              :data-qa-option-name="name"
              data-testid="advanced-settings-checkbox"
              @change="$emit('input', { ...value, [name]: $event })"
            >
              {{ label }}
              <template v-if="details" #help>{{ details }} </template>
            </gl-form-checkbox>
          </div>
        </gl-form>
      </div>
    </gl-collapse>
  </section>
</template>
