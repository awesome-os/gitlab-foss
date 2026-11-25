<script>
import {
  GlAlert,
  GlModal,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadio,
  GlFormRadioGroup,
  GlForm,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';
import csrf from '~/lib/utils/csrf';
import { __ } from '~/locale';
import { truncateSha } from '~/lib/utils/text_utility';
import validation, { initFormField } from '~/vue_shared/directives/validation';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import { COMMIT_MESSAGE_SUBJECT_MAX_LENGTH, COMMIT_MESSAGE_BODY_MAX_LENGTH } from '../constants';
import { isCommitSha } from '../utils/ref_type';

export default {
  name: 'CommitChangesModal',
  csrf,
  components: {
    GlAlert,
    GlModal,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormTextarea,
    GlForm,
    GlSprintf,
    GlLink,
  },
  i18n: {
    BRANCH: __('Branch'),
    COMMIT_CHANGES: __('Commit changes'),
    CREATE_MR_LABEL: __('Create a merge request for this change'),
  },
  directives: {
    validation: validation(),
  },
  mixins: [InternalEvents.mixin()],
  inheritAttrs: false,
  props: {
    modalId: {
      type: String,
      required: true,
    },
    commitMessage: {
      type: String,
      required: true,
    },
    targetBranch: {
      type: String,
      required: true,
    },
    originalBranch: {
      type: String,
      required: true,
    },
    canPushCode: {
      type: Boolean,
      required: true,
    },
    canPushToBranch: {
      type: Boolean,
      required: true,
    },
    emptyRepo: {
      type: Boolean,
      required: false,
      default: false,
    },
    isUsingLfs: {
      type: Boolean,
      required: false,
      default: false,
    },
    branchAllowsCollaboration: {
      type: Boolean,
      required: false,
      default: false,
    },
    valid: {
      type: Boolean,
      required: false,
      default: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    error: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['submit-form', 'close-commit-changes-modal'],
  data() {
    const form = {
      state: false,
      showValidation: false,
      fields: {
        // fields key must match case of form name for validation directive to work
        commit_message: initFormField({ value: this.commitMessage }),
        branch_name: initFormField({
          value: this.targetBranch,
          // Branch name is pre-filled with the current branch name in two scenarios and therefore doesn't need validation:
          // 1. When the user doesn't have permission to push to the repo (e.g. guest user)
          // 2. When the user can push directly to the current branch
          skipValidation: !this.canPushCode || this.canPushToBranch,
        }),
      },
    };
    return {
      lfsWarningDismissed: false,
      createNewBranch: false,
      createNewMr: true,
      form,
    };
  },
  computed: {
    primaryOptions() {
      const defaultOptions = {
        text: this.$options.i18n.COMMIT_CHANGES,
        attributes: {
          variant: 'confirm',
          loading: this.loading,
          disabled: this.loading || !this.form.state || !this.valid,
          'data-testid': 'commit-change-modal-commit-button',
        },
      };

      const lfsWarningOptions = {
        text: __('Continue…'),
        attributes: { variant: 'confirm' },
      };

      return this.showLfsWarning ? lfsWarningOptions : defaultOptions;
    },
    cancelOptions() {
      return {
        text: __('Cancel'),
        attributes: {
          disabled: this.loading,
        },
      };
    },
    showHint() {
      const splitCommitMessageByLineBreak = this.form.fields.commit_message.value
        .trim()
        .split('\n');
      const [firstLine, ...otherLines] = splitCommitMessageByLineBreak;

      const hasFirstLineExceedMaxLength = firstLine.length > COMMIT_MESSAGE_SUBJECT_MAX_LENGTH;

      const hasOtherLineExceedMaxLength =
        Boolean(otherLines.length) &&
        otherLines.some((text) => text.length > COMMIT_MESSAGE_BODY_MAX_LENGTH);

      return (
        !this.form.fields.commit_message.feedback &&
        (hasFirstLineExceedMaxLength || hasOtherLineExceedMaxLength)
      );
    },
    showLfsWarning() {
      return this.isUsingLfs && !this.lfsWarningDismissed;
    },
    title() {
      return this.showLfsWarning
        ? __("The file you're about to delete is tracked by LFS")
        : this.$options.i18n.COMMIT_CHANGES;
    },
    isOnCommit() {
      return isCommitSha(this.originalBranch);
    },
    shortOriginalSha() {
      return truncateSha(this.originalBranch);
    },
    showForm() {
      return !this.isUsingLfs || (this.isUsingLfs && this.lfsWarningDismissed);
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- called via $refs by parent components
    show() {
      this.$refs[this.modalId].show();
      this.lfsWarningDismissed = false;
    },
    async handleContinueLfsWarning() {
      this.lfsWarningDismissed = true;
      await this.$nextTick();
      this.$refs.message?.$el.focus();
    },
    async handlePrimaryAction(e) {
      window.onbeforeunload = null;
      e.preventDefault(); // Prevent modal from closing

      this.trackEvent('click_commit_changes_in_commit_changes_modal');

      if (this.showLfsWarning) {
        await this.handleContinueLfsWarning();
        return;
      }

      this.form.showValidation = true;

      if (!this.form.state) {
        return;
      }

      this.form.showValidation = false;

      const form = this.$refs.form.$el;
      const formData = new FormData(form);

      this.$emit('submit-form', formData);
    },
    handleModalClose() {
      this.$emit('close-commit-changes-modal');
    },
  },
  deleteLfsHelpPath: helpPagePath('topics/git/lfs/_index', {
    anchor: 'delete-a-git-lfs-file-from-repository-history',
  }),
  protectedBranchHelpPath: helpPagePath('user/project/repository/branches/protected'),
};
</script>

<template>
  <gl-modal
    :ref="modalId"
    v-bind="$attrs"
    :modal-id="modalId"
    :title="title"
    data-testid="commit-change-modal"
    :action-primary="primaryOptions"
    :action-cancel="cancelOptions"
    @primary="handlePrimaryAction"
    @cancel="handleModalClose"
    @close="handleModalClose"
  >
    <slot name="body"></slot>
    <div v-if="showLfsWarning">
      <p>
        <gl-sprintf
          :message="
            s__('BlobViewer|If you delete the file, it will be removed from the branch %{branch}.')
          "
        >
          <template #branch>
            <code>{{ targetBranch }}</code>
          </template>
        </gl-sprintf>
      </p>
      <p>
        <gl-sprintf
          :message="
            s__(
              'BlobViewer|This file will still take up space in your LFS storage. %{linkStart}How do I remove tracked objects from Git LFS?%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.deleteLfsHelpPath">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </div>
    <div v-if="showForm">
      <gl-form ref="form" novalidate>
        <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
        <slot name="form-fields"></slot>
        <gl-form-group
          :label="__('Commit message')"
          label-for="commit_message"
          :invalid-feedback="form.fields['commit_message'].feedback"
        >
          <gl-form-textarea
            id="commit_message"
            ref="message"
            v-model="form.fields['commit_message'].value"
            v-validation:[form.showValidation]
            name="commit_message"
            no-resize
            data-testid="commit-message-field"
            :state="form.fields['commit_message'].state"
            :disabled="loading"
            required
          />
          <p
            v-if="error"
            class="gl-mt-3 gl-whitespace-pre-line gl-text-danger"
            data-testid="error"
            v-text="error"
          ></p>
          <p v-if="showHint" class="form-text gl-text-subtle" data-testid="hint">
            {{ __('Try to keep the first line under 52 characters and the others under 72.') }}
          </p>
        </gl-form-group>
        <template v-if="emptyRepo">
          <input type="hidden" name="branch_name" :value="originalBranch" class="js-branch-name" />
          <gl-alert v-if="emptyRepo" :dismissible="false" class="gl-my-3">
            <gl-sprintf
              :message="
                __('GitLab will create a default branch, %{branchName}, and commit your changes.')
              "
            >
              <template #branchName
                ><strong>{{ originalBranch }}</strong>
              </template>
            </gl-sprintf>
          </gl-alert>
        </template>
        <template v-else>
          <input type="hidden" name="original_branch" :value="originalBranch" />
          <input v-if="createNewMr" type="hidden" name="create_merge_request" value="1" />
          <template v-if="canPushCode">
            <gl-form-group
              v-if="canPushToBranch"
              :label="$options.i18n.BRANCH"
              label-for="branch_selection"
            >
              <gl-form-radio-group
                v-model="createNewBranch"
                name="branch_selection"
                :label="$options.i18n.BRANCH"
              >
                <gl-form-radio :value="false" :disabled="loading">
                  <gl-sprintf :message="__('Commit to the current %{branchName} branch')">
                    <template #branchName
                      ><code>{{ originalBranch }}</code>
                    </template>
                  </gl-sprintf>
                </gl-form-radio>
                <gl-form-radio :value="true" :disabled="loading">
                  {{ __('Commit to a new branch') }}
                </gl-form-radio>
              </gl-form-radio-group>
              <div v-if="createNewBranch" class="gl-ml-6">
                <gl-form-group :invalid-feedback="form.fields['branch_name'].feedback">
                  <gl-form-input
                    v-model="form.fields['branch_name'].value"
                    v-validation:[form.showValidation]
                    :state="form.fields['branch_name'].state"
                    :disabled="loading"
                    name="branch_name"
                    :placeholder="__('example-branch-name')"
                    required
                    class="gl-mt-2"
                  />
                </gl-form-group>
                <gl-form-checkbox v-if="createNewBranch" v-model="createNewMr" class="gl-mt-4">
                  <span>
                    {{ $options.i18n.CREATE_MR_LABEL }}
                  </span>
                </gl-form-checkbox>
              </div>
            </gl-form-group>
            <template v-else>
              <gl-form-group
                :label="__('New branch')"
                label-for="branch_selection"
                :invalid-feedback="form.fields['branch_name'].feedback"
              >
                <label for="branchNameInput" class="gl-font-normal gl-text-subtle">
                  <gl-sprintf
                    v-if="isOnCommit"
                    :message="
                      __(
                        'You\'re viewing commit %{commitSha}, which isn\'t a branch. Commit your changes to a new branch.',
                      )
                    "
                    data-testid="commit-sha-new-branch-message"
                  >
                    <template #commitSha
                      ><code class="gl-text-subtle">{{ shortOriginalSha }}</code>
                    </template>
                  </gl-sprintf>
                  <gl-sprintf
                    v-else
                    :message="
                      __(
                        'You can\'t commit directly to %{branchName}, so your changes go to a new branch. %{linkStart}Learn more about protected branches%{linkEnd}.',
                      )
                    "
                  >
                    <template #branchName
                      ><code class="gl-text-subtle">{{ originalBranch }}</code>
                    </template>
                    <template #link="{ content }">
                      <gl-link :href="$options.protectedBranchHelpPath">{{ content }}</gl-link>
                    </template>
                  </gl-sprintf>
                </label>
                <gl-form-input
                  id="branchNameInput"
                  v-model="form.fields['branch_name'].value"
                  v-validation:[form.showValidation]
                  :state="form.fields['branch_name'].state"
                  :disabled="loading"
                  name="branch_name"
                  required
                  :placeholder="__('example-branch-name')"
                />
              </gl-form-group>

              <gl-form-checkbox v-model="createNewMr" class="gl-mt-4">
                <span>
                  {{ $options.i18n.CREATE_MR_LABEL }}
                </span>
              </gl-form-checkbox>
            </template>
          </template>
          <template v-else>
            <gl-alert v-if="branchAllowsCollaboration" :dismissible="false" class="gl-my-3">
              <gl-sprintf
                :message="
                  __(
                    'Your changes can be committed to %{branchName} because a merge request is open.',
                  )
                "
              >
                <template #branchName
                  ><strong>{{ originalBranch }}</strong>
                </template>
              </gl-sprintf></gl-alert
            >
            <gl-alert v-else :dismissible="false" class="gl-my-3">{{
              __('GitLab will create a branch in your fork and start a merge request.')
            }}</gl-alert>
          </template>
        </template>
      </gl-form>
    </div>
  </gl-modal>
</template>
