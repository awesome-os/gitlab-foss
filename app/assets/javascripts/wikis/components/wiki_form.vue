<script>
import { isEmpty } from 'lodash-es';
import { markRaw } from 'vue';
import { stringify } from 'yaml';
import {
  GlForm,
  GlButton,
  GlButtonGroup,
  GlCollapsibleListbox,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlDisclosureDropdown,
  GlModal,
  GlFormTextarea,
  GlToggle,
  GlToastMixin,
} from '@gitlab/ui';
import produce from 'immer';
import { getDraft, updateDraft, getLockVersion } from '~/lib/utils/autosave';
import csrf from '~/lib/utils/csrf';
import { __, s__, sprintf } from '~/locale';
import Tracking from '~/tracking';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import { trackSavedUsingEditor } from '~/vue_shared/components/markdown/tracking';
import { getInitialEditingMode } from '~/vue_shared/components/markdown/utils';
import { EDITING_MODE_CONTENT_EDITOR } from '~/vue_shared/constants';
import {
  ActionCableProvider,
  STALL_REASON_PAYLOAD_TOO_LARGE,
  STALL_REASON_SESSION_INVALIDATED,
  STALL_REASON_LOOKUP_FAILED,
  SAVE_REJECTION_BUSY,
} from '~/collaborative_editing';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import CollaboratorsIndicator from '~/collaborative_editing/components/collaborators_indicator.vue';
import WikiSidebarToggle from '~/wikis/components/wiki_sidebar_toggle.vue';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PanelActionsPortal from '~/vue_shared/components/panel_actions_portal.vue';
import {
  WIKI_CONTENT_EDITOR_TRACKING_LABEL,
  WIKI_FORMAT_LABEL,
  WIKI_FORMAT_UPDATED_ACTION,
  CONTENT_EDITOR_LOADED_ACTION,
  WIKI_TEMPLATES_DIR,
} from '../constants';
import {
  isTemplate as isTemplateUrl,
  getUpstreamTitle,
  draftMatchesPage,
  clearDraftsAt,
} from '../utils';
import getAutoCommitMessagePreference from '../graphql/auto_commit_message_preference.query.graphql';
import updateAutoCommitMessagePreference from '../graphql/update_auto_commit_message_preference.mutation.graphql';
import WikiTemplate from './wiki_template.vue';
import DeleteWikiModal from './delete_wiki_modal.vue';

const trackingMixin = Tracking.mixin({
  label: WIKI_CONTENT_EDITOR_TRACKING_LABEL,
});

const SAVE_MESSAGE = {
  AUTO: 'AUTO',
  CUSTOM: 'CUSTOM',
};

const CONFLICT = {
  NONE: 'none',
  // The save failed, but there is no stored draft (the restore version modal, or no localStorage).
  NOT_SAVED: 'notSaved',
  DRAFT: 'draft',
};

const AUTO_GENERATED_PATH_DATE_FORMAT = 'yyyymmddHHMMss';

// The backend reads front matter as YAML 1.1, where unquoted `on`, `yes` or `1:30` are not
// strings, and it refuses aliases.
const FRONT_MATTER_YAML_OPTIONS = {
  version: '1.1',
  singleQuote: true,
  aliasDuplicateObjects: false,
};

function getPagePath(pageInfo) {
  return pageInfo.persisted ? pageInfo.path : pageInfo.createPath;
}

const autosaveKey = (pageInfo, field) => {
  const path = pageInfo.persisted ? pageInfo.path : pageInfo.createPath;

  return `${path}/${field}`;
};

const titleAutosaveKey = (pageInfo) => autosaveKey(pageInfo, 'title');
const formatAutosaveKey = (pageInfo) => autosaveKey(pageInfo, 'format');
const contentAutosaveKey = (pageInfo) => autosaveKey(pageInfo, 'content');
const commitAutosaveKey = (pageInfo) => autosaveKey(pageInfo, 'commit');

const isDraftStale = (pageInfo) => {
  if (!pageInfo.persisted) return false;

  const storedLockVersion = getLockVersion(titleAutosaveKey(pageInfo));

  return Boolean(storedLockVersion) && storedLockVersion !== pageInfo.lastCommitSha;
};

const getTitle = (pageInfo, frontMatter) =>
  getDraft(titleAutosaveKey(pageInfo)) || getUpstreamTitle(pageInfo, frontMatter);

const getFormat = (pageInfo) =>
  getDraft(formatAutosaveKey(pageInfo)) || pageInfo.format || 'markdown';
const getContent = (pageInfo) => getDraft(contentAutosaveKey(pageInfo)) || pageInfo.content || '';
const getCommitMessage = (pageInfo) =>
  getDraft(commitAutosaveKey(pageInfo)) || pageInfo.commitMessage || '';
const getIsFormDirty = (pageInfo) => Boolean(getDraft(titleAutosaveKey(pageInfo)));

export default {
  name: 'WikiForm',
  i18n: {
    title: {
      label: s__('WikiPage|Title'),
      placeholder: s__('WikiPage|Page title'),
      templatePlaceholder: s__('WikiPage|Template title'),
      newPagePlaceholder: s__('WikiPage|{Give this page a title}'),
      defaultTitle: __('Untitled'),
    },
    path: {
      label: s__('WikiPage|Path'),
      placeholder: s__('WikiPage|Page path'),
      description: s__(
        'WikiPage|The path where your page is located. Use "/" to create nested pages.',
      ),
      generateFromTitle: s__('WikiPage|Generate path from title'),
      generateFromTitleHelp: s__(
        'WikiPage|Automatically updates the path when you change the title.',
      ),
      templateTitleHelp: s__(
        'WikiPage|For templates, the path is generated from the title and cannot be edited.',
      ),
      restorePagePath: s__('WikiPage|Convert back to page'),
    },
    format: {
      label: s__('WikiPage|Format'),
    },
    template: {
      label: __('Template'),
      collaborating: s__(
        'WikiPage|Templates cannot be applied while others are editing this page.',
      ),
    },
    content: {
      label: s__('WikiPage|Content'),
      placeholder: s__('WikiPage|Write your content or drag files here…'),
    },
    commitMessage: {
      label: s__('WikiPage|Commit message'),
      value: {
        existingPage: s__('WikiPage|Update %{pageTitle}'),
        newPage: s__('WikiPage|Create %{pageTitle}'),
        existingTemplate: s__('WikiPage|Update template %{pageTitle}'),
        newTemplatePage: s__('WikiPage|Create template %{pageTitle}'),
      },
    },
    submitButton: {
      existingPage: s__('WikiPage|Save changes'),
      newPage: s__('WikiPage|Create page'),
      newSidebar: s__('WikiPage|Create sidebar'),
      newTemplate: s__('WikiPage|Create template'),
      existingTemplate: s__('WikiPage|Save template'),
    },
    cancel: s__('WikiPage|Cancel'),
    messageModalTitle: s__('WikiPage|Add a commit message'),
    autoCommitMessageToggle: s__('WikiPage|Use the default commit message for future saves'),
    autoCommitMessageToggleHelp: s__('WikiPage|Wiki pages save without opening this dialog.'),
    deleteSidebar: s__('WikiPage|Delete sidebar'),
    pageChanged: s__(
      'WikiPage|Someone edited the page the same time you did. Please make sure your changes will not unintentionally remove theirs.',
    ),
    pageChangedNotSaved: s__(
      'WikiPage|Your changes were not saved because someone else edited this page. Review their changes in the page history before you try again.',
    ),
    viewPageHistory: s__('WikiPage|View page history'),
  },
  components: {
    WikiSidebarToggle,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlButton,
    MarkdownEditor,
    WikiTemplate,
    DeleteWikiModal,
    PanelActionsPortal,
    GlButtonGroup,
    GlCollapsibleListbox,
    GlModal,
    GlFormTextarea,
    GlDisclosureDropdown,
    GlToggle,
    CollaboratorsIndicator,
  },
  mixins: [trackingMixin, glFeatureFlagsMixin(), GlToastMixin],
  inject: ['formatOptions', 'pageInfo', 'drawioUrl', 'templates', 'wikiUrl', 'historyUrl'],
  props: {
    // The last save failed because someone else edited the page.
    pageChanged: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['is-editing'],
  saveOptions: [
    {
      text: s__('WikiPage|Save changes directly'),
      description: s__('WikiPage|Uses the default commit message'),
      value: SAVE_MESSAGE.AUTO,
    },
    {
      text: s__('WikiPage|Save changes with message'),
      description: s__('WikiPage|Review and write a commit message'),
      value: SAVE_MESSAGE.CUSTOM,
    },
  ],
  data() {
    const title = window.location.href.includes('random_title=true')
      ? ''
      : getTitle(this.pageInfo, this.pageInfo.frontMatter);
    const path = window.location.href.includes('random_title=true') ? '' : this.pageInfo.slug;
    const hasStaleDraft =
      isDraftStale(this.pageInfo) && !draftMatchesPage(getPagePath(this.pageInfo), this.pageInfo);
    let conflict = CONFLICT.NONE;
    if (hasStaleDraft) conflict = CONFLICT.DRAFT;
    else if (this.pageChanged) conflict = CONFLICT.NOT_SAVED;
    return {
      title,
      pageTitle: title.replace('templates/', ''),
      format: getFormat(this.pageInfo),
      path,
      frontMatter: { ...this.pageInfo.frontMatter },
      content: getContent(this.pageInfo),
      commitMessage: getCommitMessage(this.pageInfo),
      isContentEditorActive: false,
      isFormDirty: getIsFormDirty(this.pageInfo),
      formFieldProps: {
        placeholder: this.$options.i18n.content.placeholder,
        'aria-label': this.$options.i18n.content.label,
        id: 'wiki_content',
        class: 'note-textarea',
      },
      shouldGeneratePathFromTitle:
        (!this.pageInfo.persisted &&
          (!path.startsWith(`${WIKI_TEMPLATES_DIR}/`) || path.endsWith('{new_page_title}'))) ||
        this.isAutoGeneratedPath(path),
      initialPath: path,
      placeholderActive: false,
      placeholderText: this.$options.i18n.title.newPagePlaceholder,
      parentPath: '',
      useAutoCommitMessage: false,
      savingPreference: false,
      commitMessageModalOpen: false,
      isTemplateUrl: isTemplateUrl(),
      isSubmitting: false,
      submission: null,
      collaborationVersion: this.pageInfo.lastCommitSha,
      collaborationProvider: null,
      collaborationStallReason: null,
      plainTextStartContent: this.pageInfo.content || '',
      conflict,
      // The user's version while their version is on screen, otherwise null.
      shelf: null,
      plainTextHoldsUnsynchronizedEdits: false,
    };
  },
  apollo: {
    useAutoCommitMessage: {
      query: getAutoCommitMessagePreference,
      update: (data) => {
        return data.currentUser?.userPreferences?.wikiUseAutoCommitMessage ?? false;
      },
    },
  },
  computed: {
    isCollaborating() {
      return Boolean(this.collaborationProvider);
    },
    isCollaborationStalled() {
      return Boolean(this.collaborationStallReason);
    },
    isCollaborationInvalidated() {
      return [STALL_REASON_SESSION_INVALIDATED, STALL_REASON_LOOKUP_FAILED].includes(
        this.collaborationStallReason,
      );
    },
    collaborationAlert() {
      if (!this.isCollaborationStalled) return null;

      const messages = {
        [STALL_REASON_PAYLOAD_TOO_LARGE]: s__(
          'WikiPage|Your changes are too large to synchronize with other editors, so you cannot save them. Copy the page content to keep your work, then switch to the plain text editor to save it.',
        ),
        [STALL_REASON_SESSION_INVALIDATED]: s__(
          'WikiPage|This collaborative session has ended because the page changed or the session expired, so you cannot save in rich text or plain text. Copy the page content, reload the page, and reconcile your changes with the latest version.',
        ),
        [STALL_REASON_LOOKUP_FAILED]: s__(
          'WikiPage|GitLab temporarily cannot verify the latest page version, so this collaborative session cannot continue. Copy the page content, reload the page, and reconcile your changes with the latest version.',
        ),
      };
      const tooLarge = this.collaborationStallReason === STALL_REASON_PAYLOAD_TOO_LARGE;

      return {
        variant: tooLarge || this.isCollaborationInvalidated ? 'danger' : 'warning',
        message:
          messages[this.collaborationStallReason] ??
          s__(
            'WikiPage|Your recent changes are not synchronized with other editors, so you cannot save them. GitLab keeps trying to synchronize them. Copy the page content to keep your work.',
          ),
        primaryButtonText: s__('WikiPage|Copy page content'),
        primaryAction: this.copyContent,
      };
    },
    templateDescription() {
      return this.isCollaborating ? this.$options.i18n.template.collaborating : null;
    },
    isTemplatePath() {
      return this.path.startsWith(`${WIKI_TEMPLATES_DIR}/`);
    },
    isTemplateByPathOnly() {
      return this.isTemplatePath && !this.isTemplateUrl;
    },
    isTemplate() {
      return this.isTemplateUrl || this.isTemplatePath;
    },
    titlePlaceholder() {
      return this.isTemplate
        ? this.$options.i18n.title.templatePlaceholder
        : this.$options.i18n.title.placeholder;
    },
    autocompleteDataSources() {
      return gl.GfmAutoComplete?.dataSources;
    },
    csrfToken() {
      return csrf.token;
    },
    formAction() {
      return getPagePath(this.pageInfo);
    },
    commitMessageI18n() {
      if (this.pageInfo.persisted) {
        if (this.isTemplate) return this.$options.i18n.commitMessage.value.existingTemplate;
        return this.$options.i18n.commitMessage.value.existingPage;
      }
      if (this.isTemplate) return this.$options.i18n.commitMessage.value.newTemplatePage;
      return this.$options.i18n.commitMessage.value.newPage;
    },
    submitButtonText() {
      if (this.isTemplate) {
        return this.pageInfo.persisted
          ? this.$options.i18n.submitButton.existingTemplate
          : this.$options.i18n.submitButton.newTemplate;
      }

      let buttonText = this.pageInfo.persisted
        ? this.$options.i18n.submitButton.existingPage
        : this.$options.i18n.submitButton.newPage;

      buttonText =
        this.isCustomSidebar && !this.pageInfo.persisted
          ? this.$options.i18n.submitButton.newSidebar
          : buttonText;

      return buttonText;
    },
    isMarkdownFormat() {
      return this.format === 'markdown';
    },
    drawioEnabled() {
      return typeof this.drawioUrl === 'string' && this.drawioUrl.length > 0;
    },
    isCustomSidebar() {
      return this.wikiUrl.endsWith('_sidebar');
    },
    rawContent() {
      return this.serializeContent(this.content);
    },
    messageModalAction() {
      return {
        primary: {
          text: this.submitButtonText,
          attributes: {
            variant: 'confirm',
            'data-testid': 'wiki-confirm-message',
            disabled: this.isCollaborationStalled,
          },
        },
        cancel: { text: this.$options.i18n.cancel },
      };
    },
    saveMessageMode() {
      return this.useAutoCommitMessage ? SAVE_MESSAGE.AUTO : SAVE_MESSAGE.CUSTOM;
    },
    collaborativeEditingEnabled() {
      return Boolean(
        this.glFeatures.wikiCollaborativeEditing &&
        this.isMarkdownFormat &&
        this.pageInfo.persisted,
      );
    },
    viewingTheirVersion() {
      return this.shelf !== null;
    },
    staleAlert() {
      if (this.conflict === CONFLICT.NONE) return null;
      if (this.conflict === CONFLICT.NOT_SAVED) {
        // Nothing was saved, so point to the history to review their edit (or restore again).
        return {
          message: this.$options.i18n.pageChangedNotSaved,
          variant: 'danger',
          ...(this.historyUrl && {
            primaryButtonText: this.$options.i18n.viewPageHistory,
            primaryButtonLink: this.historyUrl,
          }),
        };
      }
      if (this.viewingTheirVersion) {
        return {
          message: s__(
            'WikiPage|You are viewing the page as saved by someone else (read-only). You have shelved changes.',
          ),
          variant: 'danger',
          primaryButtonText: s__('WikiPage|Edit my version'),
          secondaryButtonText: s__('WikiPage|Discard my changes'),
          primaryAction: this.unshelveChanges,
          secondaryAction: this.discardDraft,
        };
      }
      return {
        message: this.$options.i18n.pageChanged,
        variant: 'danger',
        primaryButtonText: s__('WikiPage|View their version'),
        secondaryButtonText: s__('WikiPage|Discard my changes'),
        primaryAction: this.shelveChanges,
        secondaryAction: this.discardDraft,
      };
    },
  },
  watch: {
    title() {
      this.updateCommitMessage();
    },
    pageTitle() {
      this.title =
        this.isTemplate && !this.pageInfo.persisted
          ? `templates/${this.pageTitle}`
          : this.pageTitle;
      this.onTitleUpdate();
    },
    shouldGeneratePathFromTitle(newValue) {
      if (newValue) {
        this.generatePathFromTitle();
      }
    },
  },
  created() {
    if (getInitialEditingMode() === EDITING_MODE_CONTENT_EDITOR) {
      this.startCollaborativeEditing();
    }
  },
  mounted() {
    this.initializeTitlePlaceholder();

    if (isDraftStale(this.pageInfo) && this.conflict !== CONFLICT.DRAFT) this.clearDrafts();

    if (!this.commitMessage) this.updateCommitMessage();
    window.addEventListener('beforeunload', this.onPageUnload);
  },
  destroyed() {
    window.removeEventListener('beforeunload', this.onPageUnload);
    this.stopCollaborativeEditing();
  },
  methods: {
    serializeContent(markdown) {
      const frontMatter =
        this.isTemplate || isEmpty(this.frontMatter)
          ? ''
          : `---\n${stringify(this.frontMatter, FRONT_MATTER_YAML_OPTIONS)}---\n`;
      return `${frontMatter}${markdown}`;
    },
    startCollaborativeEditing() {
      if (
        !this.collaborativeEditingEnabled ||
        this.collaborationProvider ||
        this.isCollaborationInvalidated
      )
        return;

      const provider = markRaw(
        new ActionCableProvider({
          channel: 'CollaborativeEditing::WikiPageChannel',
          channelParams: {
            container_full_path: this.pageInfo.containerFullPath,
            slug: this.pageInfo.slug,
          },
          version: this.collaborationVersion,
          onVersionChange: (version) => {
            this.collaborationVersion = version;
          },
          onStallChange: (reason) => {
            if (this.isCollaborationInvalidated) return;
            this.collaborationStallReason = reason;
            if (reason) this.commitMessageModalOpen = false;
          },
        }),
      );

      provider.connect();
      this.collaborationProvider = provider;
    },

    stopCollaborativeEditing() {
      this.collaborationProvider?.destroy();
      this.collaborationProvider = null;
      if (!this.isCollaborationInvalidated) this.collaborationStallReason = null;
    },

    async copyContent() {
      try {
        await copyToClipboard(this.$refs.markdownEditor.getMarkdown());
        this.$toast.show(s__('WikiPage|Page content copied to clipboard.'));
      } catch {
        this.$toast.show(
          s__('WikiPage|Could not copy the page content. Select and copy it manually.'),
        );
      }
    },

    async submitForm() {
      if (this.isCollaborationStalled || this.isSubmitting) return;
      this.setMissingFields();
      this.isSubmitting = true;
      if (this.collaborationProvider) await this.$nextTick();
      const version = this.collaborationVersion;
      const markdown = this.collaborationProvider
        ? this.$refs.markdownEditor.getMarkdown()
        : this.content;
      const rawContent = this.serializeContent(markdown);
      try {
        const continuation = this.collaborationProvider
          ? await this.collaborationProvider.startSave()
          : null;
        this.submission = continuation ? { content: rawContent, version, ...continuation } : null;
      } catch (error) {
        this.isSubmitting = false;
        this.submission = null;
        if (!this.isCollaborationStalled) {
          this.$toast.show(
            error.message === SAVE_REJECTION_BUSY
              ? s__('WikiPage|Another editor is saving this page. Try again.')
              : s__('WikiPage|Your changes could not be synchronized. Try saving again.'),
          );
        }
        return;
      }

      this.updateDrafts(version, markdown);
      this.isFormDirty = false;

      this.trackFormSubmit();
      this.trackWikiFormat();

      // Wait until form field values are refreshed
      await this.$nextTick();

      if (this.isCollaborationStalled) {
        this.isSubmitting = false;
        this.isFormDirty = true;
        return;
      }
      this.$refs.form.$el.submit();
    },

    generatePathFromTitle() {
      const prefix = this.isTemplate ? `${WIKI_TEMPLATES_DIR}/` : '';
      this.path = prefix + this.parentPath + this.pageTitle.replace(/ +/g, '-');
    },

    restorePagePath() {
      this.path = this.initialPath.startsWith(`${WIKI_TEMPLATES_DIR}/`)
        ? this.path.replace(new RegExp(`^${WIKI_TEMPLATES_DIR}/`), '')
        : this.initialPath;
    },

    onTitleUpdate() {
      if (!this.placeholderActive) {
        this.frontMatter.title = this.pageTitle;
        this.frontMatter = { ...this.frontMatter };
      }

      if (
        (this.shouldGeneratePathFromTitle || this.isTemplate) &&
        !this.placeholderActive &&
        this.pageTitle !== this.$options.i18n.title.defaultTitle &&
        this.pageTitle.trim().length
      ) {
        this.generatePathFromTitle();
      }
    },

    updateDrafts(lockVersion = this.collaborationVersion, content = this.content) {
      updateDraft(titleAutosaveKey(this.pageInfo), this.title, lockVersion);
      updateDraft(formatAutosaveKey(this.pageInfo), this.format, lockVersion);
      updateDraft(contentAutosaveKey(this.pageInfo), content, lockVersion);
      updateDraft(commitAutosaveKey(this.pageInfo), this.commitMessage, lockVersion);
    },

    clearDrafts() {
      clearDraftsAt(getPagePath(this.pageInfo));
    },

    shelveChanges() {
      // Their version is read-only, so the draft stored here is what survives leaving the page.
      if (this.isFormDirty) this.updateDrafts(getLockVersion(titleAutosaveKey(this.pageInfo)));
      this.shelf = this.currentVersion();
      return this.applyVersion(this.upstreamVersion());
    },

    unshelveChanges() {
      const { shelf } = this;
      this.shelf = null;
      return this.applyVersion(shelf);
    },

    async discardDraft() {
      const confirmed = await confirmAction(
        s__('WikiPage|Your changes to this page will be permanently deleted.'),
        {
          title: s__('WikiPage|Discard your changes?'),
          primaryBtnText: s__('WikiPage|Discard changes'),
          primaryBtnVariant: 'danger',
          cancelBtnText: s__('WikiPage|Keep my changes'),
        },
      );
      if (!confirmed) return;

      this.clearDrafts();
      this.conflict = CONFLICT.NONE;
      this.shelf = null;
      this.isFormDirty = false;
      await this.applyVersion(this.upstreamVersion());
      // The path is the page's name on save, so a leftover edit would rename the page.
      this.path = this.pageInfo.slug;
    },

    currentVersion() {
      const { pageTitle, format, content, commitMessage } = this;
      return { pageTitle, format, content, commitMessage };
    },

    upstreamVersion() {
      return {
        pageTitle: getUpstreamTitle(this.pageInfo, this.pageInfo.frontMatter).replace(
          'templates/',
          '',
        ),
        format: this.pageInfo.format || 'markdown',
        content: this.pageInfo.content || '',
        commitMessage: this.pageInfo.commitMessage || '',
      };
    },

    async applyVersion({ pageTitle, format, content, commitMessage }) {
      this.pageTitle = pageTitle;
      this.format = format;
      this.content = content;

      // The title watcher regenerates the commit message, so set it once that has run.
      await this.$nextTick();
      this.commitMessage = commitMessage;
      if (!this.commitMessage) this.updateCommitMessage();
    },

    onPageUnload() {
      // Their version is on screen; the draft was stored when it was shelved.
      if (this.isSubmitting || this.viewingTheirVersion) return;

      if (this.isFormDirty) {
        // Keep a conflicting draft's old lock version, so the warning survives a reload.
        const lockVersion =
          this.conflict === CONFLICT.DRAFT
            ? getLockVersion(titleAutosaveKey(this.pageInfo))
            : this.collaborationVersion;
        this.updateDrafts(lockVersion);
      } else {
        this.clearDrafts();
      }
    },

    updateCommitMessage() {
      if (!this.title) return;

      // Replace hyphens with spaces
      let newTitle = this.title.replace(/-+/g, ' ').replace('templates/', '');

      // Replace _sidebar with sidebar
      if (this.isCustomSidebar) {
        newTitle = this.title.replace('_sidebar', 'sidebar');
      }

      const newCommitMessage = sprintf(this.commitMessageI18n, { pageTitle: newTitle }, false);
      this.commitMessage = newCommitMessage;
    },

    notifyContentEditorActive() {
      this.isContentEditorActive = true;
      this.trackContentEditorLoaded();
      this.startCollaborativeEditing();
    },

    notifyContentEditorInactive() {
      const wasContentEditorActive = this.isContentEditorActive;
      const wasStalled = this.isCollaborationStalled;
      this.isContentEditorActive = false;
      this.stopCollaborativeEditing();
      if (!wasContentEditorActive || !this.collaborativeEditingEnabled) return;

      this.plainTextHoldsUnsynchronizedEdits = wasStalled;
      if (!wasStalled) this.plainTextStartContent = this.content;
    },
    async beforeContentEditor(markdown) {
      if (this.isCollaborationInvalidated) return false;
      if (!this.collaborativeEditingEnabled || markdown === this.plainTextStartContent) return true;

      const discard = await confirmAction(
        this.plainTextHoldsUnsynchronizedEdits
          ? s__(
              "WikiPage|Switching to rich text will discard your changes that didn't synchronize and any changes made in plain text. Continue?",
            )
          : s__(
              'WikiPage|Switching to rich text will discard changes made in plain text. Continue?',
            ),
        {
          title: this.plainTextHoldsUnsynchronizedEdits
            ? s__('WikiPage|Discard unsynchronized changes?')
            : s__('WikiPage|Discard plain text changes?'),
          primaryBtnText: s__('WikiPage|Discard changes and switch'),
          cancelBtnText: s__('WikiPage|Keep editing in plain text'),
        },
      );

      if (discard) {
        this.plainTextHoldsUnsynchronizedEdits = false;
        this.content = this.plainTextStartContent;
        // Let MarkdownEditor receive the restored content before it mounts rich text.
        await this.$nextTick();
      }

      return discard;
    },

    trackFormSubmit() {
      // eslint-disable-next-line @gitlab/require-i18n-strings
      trackSavedUsingEditor(this.isContentEditorActive, 'Wiki');
    },

    trackWikiFormat() {
      this.track(WIKI_FORMAT_UPDATED_ACTION, {
        label: WIKI_FORMAT_LABEL,
        extra: {
          project_path: this.pageInfo.path,
          old_format: this.pageInfo.format,
          value: this.format,
        },
      });
    },

    trackContentEditorLoaded() {
      this.track(CONTENT_EDITOR_LOADED_ACTION);
    },

    submitFormWithShortcut() {
      if (this.viewingTheirVersion || this.isCollaborationStalled) return;

      this.submitForm();
    },

    setTemplate(template) {
      this.$refs.markdownEditor.setTemplate(template);
    },
    cancelFormAction() {
      this.isFormDirty = false;
      this.$emit('is-editing', false);
    },

    isPrintableKey(event) {
      // More robust check for printable characters
      // Excludes control keys, function keys, etc.
      if (event.ctrlKey || event.metaKey || event.altKey) {
        return false;
      }

      // Check if it's a single printable character
      // This includes letters, numbers, symbols, space, etc.
      const { key } = event;
      return key.length === 1;
    },

    async initializeTitlePlaceholder() {
      if (this.pageInfo.persisted) return;

      if (!this.pageTitle.endsWith('{new_page_title}')) return;

      this.parentPath = this.pageTitle.replace(/\{new_page_title\}$/, '');

      this.pageTitle = this.placeholderText;
      if (this.shouldGeneratePathFromTitle) {
        this.path = this.parentPath;
      }

      this.placeholderActive = true;

      await this.$nextTick();
      this.positionCursorForPlaceholder();
    },

    positionCursorForPlaceholder() {
      const input = this.$refs.titleInput?.$el || this.$refs.titleInput;
      if (input) {
        input.setSelectionRange(0, 0);
        input.focus();
      }
    },

    handleTitleInput(event) {
      const newValue = (event.target ? event.target.value : event).replace(
        /[\r\n\u2028\u2029]/g,
        ' ',
      );

      if (this.placeholderActive) {
        // Check if user has modified the placeholder area
        if (!newValue.includes(this.placeholderText)) {
          this.placeholderActive = false;
        }
      }

      this.pageTitle = newValue;
    },

    async handleTitleKeydown(event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        if (event.ctrlKey || event.metaKey) this.submitFormWithShortcut();
        return;
      }

      if (this.placeholderActive && this.isPrintableKey(event)) {
        this.placeholderActive = false;
        this.pageTitle = '';
        await this.$nextTick();
        const input = this.$refs.titleInput?.$el || this.$refs.titleInput;
        if (input) {
          input.setSelectionRange(0, 0);
        }
      }
    },

    handleTitleFocus() {
      if (this.placeholderActive) {
        this.positionCursorForPlaceholder();
      }
    },

    setAutoGeneratedTitle() {
      this.pageTitle = this.$options.i18n.title.defaultTitle;
    },

    setAutoGeneratedPath() {
      const dateSegment = formatDate(Date.now(), AUTO_GENERATED_PATH_DATE_FORMAT);
      const prefix = this.isTemplate ? `${WIKI_TEMPLATES_DIR}/` : '';
      this.path = `${prefix}untitled-${dateSegment}`;
    },

    isAutoGeneratedPath(path) {
      const regex = new RegExp(`^(${WIKI_TEMPLATES_DIR}/)?untitled-\\d{14}$`);
      return regex.test(path);
    },

    setMissingFields() {
      // Ensure empty string with spaces don't prevent the placeholder from being shown
      this.pageTitle = this.pageTitle.trim();

      if (!this.pageTitle.trim().length) {
        this.setAutoGeneratedTitle();
      }
      if (!this.path.trim().length || (this.isTemplate && this.isAutoGeneratedPath(this.path))) {
        this.setAutoGeneratedPath();
      }
    },

    handleSave() {
      if (this.viewingTheirVersion || this.isCollaborationStalled) return;

      if (this.useAutoCommitMessage) {
        this.submitForm();
      } else {
        this.commitMessageModalOpen = true;
      }
    },

    async handleSaveMessageModeSelect(value) {
      const useAutoCommitMessage = value === SAVE_MESSAGE.AUTO;
      if (this.useAutoCommitMessage !== useAutoCommitMessage) {
        this.useAutoCommitMessage = useAutoCommitMessage;
        await this.updateCommitMessageModePreference(useAutoCommitMessage);
      }
      this.handleSave();
    },

    async updateCommitMessageModePreference(useAutoCommitMessage) {
      try {
        this.savingPreference = true;
        await this.$apollo.mutate({
          mutation: updateAutoCommitMessagePreference,
          variables: {
            input: {
              wikiUseAutoCommitMessage: useAutoCommitMessage,
            },
          },
          optimisticResponse: {
            userPreferencesUpdate: {
              __typename: 'UserPreferencesUpdatePayload',
              userPreferences: {
                __typename: 'UserPreferences',
                wikiUseAutoCommitMessage: useAutoCommitMessage,
              },
            },
          },
          update(cache, { data: { userPreferencesUpdate } }) {
            cache.updateQuery({ query: getAutoCommitMessagePreference }, (existingData) =>
              produce(existingData, (draft) => {
                if (draft?.currentUser?.userPreferences) {
                  draft.currentUser.userPreferences.wikiUseAutoCommitMessage =
                    userPreferencesUpdate.userPreferences.wikiUseAutoCommitMessage;
                }
              }),
            );
          },
        });
      } catch (e) {
        Sentry.captureException();
      } finally {
        this.savingPreference = false;
      }
    },
  },
};
</script>

<template>
  <gl-form
    ref="form"
    :action="formAction"
    method="post"
    class="wiki-form common-note-form"
    @submit.prevent="handleSave"
    @input="isFormDirty = true"
  >
    <input :value="csrfToken" type="hidden" name="authenticity_token" />
    <input v-if="pageInfo.persisted" type="hidden" name="_method" value="put" />
    <input
      :v-if="pageInfo.persisted"
      type="hidden"
      name="wiki[last_commit_sha]"
      :value="submission ? submission.version : collaborationVersion"
    />
    <template v-if="submission && submission.sessionId">
      <input name="collaboration_session_id" type="hidden" :value="submission.sessionId" />
      <input name="collaboration_save_id" type="hidden" :value="submission.saveId" />
    </template>
    <input :value="commitMessage" name="wiki[message]" type="hidden" />
    <input v-if="isCustomSidebar" value="_sidebar" name="wiki[title]" type="hidden" />

    <panel-actions-portal>
      <collaborators-indicator v-if="isCollaborating" :provider="collaborationProvider" />
      <gl-button-group>
        <gl-button
          variant="confirm"
          size="small"
          :loading="savingPreference || (isCollaborating && isSubmitting)"
          :disabled="viewingTheirVersion || isCollaborationStalled"
          data-testid="wiki-submit-button"
          @click="handleSave"
          >{{ submitButtonText }}</gl-button
        >
        <gl-collapsible-listbox
          :selected="saveMessageMode"
          :disabled="viewingTheirVersion || isCollaborationStalled"
          :items="$options.saveOptions"
          :toggle-text="s__('Wiki|Save and choose commit message')"
          variant="confirm"
          size="small"
          data-testid="wiki-submit-message-mode"
          text-sr-only
          @select="handleSaveMessageModeSelect"
        >
          <template #list-item="{ item }">
            <div class="gl-whitespace-nowrap gl-font-bold">{{ item.text }}</div>
            <div class="gl-text-subtle">{{ item.description }}</div>
          </template>
        </gl-collapsible-listbox>
      </gl-button-group>
      <gl-button
        category="tertiary"
        size="small"
        data-testid="wiki-cancel-button"
        @click="cancelFormAction"
      >
        {{ $options.i18n.cancel }}</gl-button
      >
      <delete-wiki-modal v-if="isCustomSidebar || isTemplate" />
    </panel-actions-portal>

    <div class="row">
      <div class="gl-col-sm-12 row-sm-5">
        <gl-form-group :label="$options.i18n.content.label" label-for="wiki_content" label-sr-only>
          <markdown-editor
            ref="markdownEditor"
            v-model="content"
            :form-field-props="formFieldProps"
            :render-markdown-path="pageInfo.markdownPreviewPath"
            :markdown-docs-path="pageInfo.markdownHelpPath"
            :uploads-path="pageInfo.uploadsPath"
            :enable-content-editor="isMarkdownFormat"
            :enable-preview="isMarkdownFormat"
            :autofocus="pageInfo.persisted"
            :enable-autocomplete="true"
            :autocomplete-data-sources="autocompleteDataSources"
            :drawio-enabled="drawioEnabled"
            supports-table-of-contents
            :disable-attachments="isTemplate"
            :collaboration-provider="collaborationProvider"
            :before-content-editor="beforeContentEditor"
            :custom-alert="staleAlert || collaborationAlert"
            :disabled="viewingTheirVersion"
            immersive
            @content-editor="notifyContentEditorActive"
            @markdown-field="notifyContentEditorInactive"
            @keydown.ctrl.enter="submitFormWithShortcut"
            @keydown.meta.enter="submitFormWithShortcut"
          >
            <template #header>
              <div
                class="gl-flex gl-items-start gl-bg-default gl-px-5 gl-pt-3"
                data-testid="wiki-form-actions"
              >
                <div class="toggle-with-hide-transition gl-my-2 gl-shrink-0 gl-p-2">
                  <wiki-sidebar-toggle action="open" />
                </div>
                <div
                  class="flexible-input-container gl-my-2 gl-flex gl-items-start gl-gap-2 gl-overflow-hidden gl-p-2"
                >
                  <h1 v-if="isCustomSidebar" class="gl-heading-1 !gl-mb-0">
                    {{
                      pageInfo.persisted
                        ? s__('Wiki|Edit Sidebar')
                        : s__('Wiki|Create custom sidebar')
                    }}
                  </h1>
                  <textarea
                    v-else
                    id="wiki_title"
                    ref="titleInput"
                    v-model="pageTitle"
                    class="flexible-input gl-heading-1 !gl-mb-0 gl-max-h-[4lh] gl-flex-1 gl-resize-none gl-overflow-x-hidden gl-overflow-y-scroll gl-rounded-md gl-border-none gl-bg-transparent gl-shadow-none"
                    data-testid="wiki-title-textbox"
                    required
                    :readonly="viewingTheirVersion"
                    :autofocus="!pageInfo.persisted"
                    :placeholder="titlePlaceholder"
                    :aria-label="titlePlaceholder"
                    @input="handleTitleInput"
                    @keydown="handleTitleKeydown"
                    @focus="handleTitleFocus"
                  ></textarea>
                  <gl-disclosure-dropdown
                    icon="chevron-down"
                    :toggle-text="s__('Wiki|Edit page options')"
                    text-sr-only
                    toggle-id="wiki-page-options"
                    :disabled="viewingTheirVersion"
                    category="tertiary"
                    no-caret
                    fluid-width
                  >
                    <div class="gl-min-w-md gl-w-md gl-flex gl-flex-col !gl-p-5">
                      <gl-form-group
                        v-if="!isCustomSidebar"
                        :label="$options.i18n.path.label"
                        label-for="wiki_path"
                        :description="isTemplate ? null : $options.i18n.path.description"
                      >
                        <gl-form-input
                          id="wiki_path"
                          v-model="path"
                          name="wiki[title]"
                          data-testid="wiki-path-textbox"
                          class="form-control !gl-font-monospace"
                          :required="true"
                          :readonly="isTemplate"
                          :placeholder="$options.i18n.path.placeholder"
                        />
                        <template v-if="isTemplate" #description>
                          {{ $options.i18n.path.templateTitleHelp }}
                          <gl-button
                            v-if="isTemplateByPathOnly"
                            variant="link"
                            class="gl-align-baseline"
                            data-testid="convert-to-page-button"
                            @click="restorePagePath"
                            >{{ $options.i18n.path.restorePagePath }}</gl-button
                          >
                        </template>
                      </gl-form-group>
                      <gl-toggle
                        v-if="!isCustomSidebar && !isTemplate"
                        v-model="shouldGeneratePathFromTitle"
                        :label="$options.i18n.path.generateFromTitle"
                        :help="$options.i18n.path.generateFromTitleHelp"
                        label-position="top"
                        label-id="lock-path"
                        class="gl-mb-5"
                        data-testid="path-generation-toggle"
                      />
                      <gl-form-group :label="$options.i18n.format.label" label-for="wiki_format">
                        <gl-form-select
                          id="wiki_format"
                          v-model="format"
                          name="wiki[format]"
                          :disabled="isContentEditorActive"
                          :value="formatOptions.Markdown"
                        >
                          <option v-for="(key, label) of formatOptions" :key="key" :value="key">
                            {{ label }}
                          </option>
                        </gl-form-select>
                      </gl-form-group>
                      <gl-form-group
                        v-if="!isTemplate"
                        :label="$options.i18n.template.label"
                        :description="templateDescription"
                        label-for="wiki_template"
                        class="gl-mb-0"
                      >
                        <wiki-template
                          :format="format"
                          :templates="templates"
                          :disabled="isCollaborating"
                          @input="setTemplate"
                        />
                      </gl-form-group>
                    </div>
                  </gl-disclosure-dropdown>
                </div>
              </div>
            </template>
          </markdown-editor>
          <input
            name="wiki[content]"
            type="hidden"
            :value="submission ? submission.content : rawContent"
          />
        </gl-form-group>
      </div>
    </div>

    <gl-modal
      v-model="commitMessageModalOpen"
      modal-id="commit-message-modal"
      data-testid="commit-message-modal"
      :title="$options.i18n.messageModalTitle"
      :action-primary="messageModalAction.primary"
      :action-cancel="messageModalAction.cancel"
      @primary="submitForm"
    >
      <gl-form-group
        :label="$options.i18n.commitMessage.label"
        label-for="wiki_message"
        label-sr-only
      >
        <gl-form-textarea
          id="wiki_message"
          v-model.trim="commitMessage"
          class="form-control"
          data-testid="wiki-message-textbox"
          :placeholder="$options.i18n.commitMessage.label"
        />
      </gl-form-group>
      <gl-toggle
        :value="useAutoCommitMessage"
        :label="$options.i18n.autoCommitMessageToggle"
        :help="$options.i18n.autoCommitMessageToggleHelp"
        :disabled="savingPreference"
        label-position="left"
        data-testid="auto-commit-message-toggle"
        @change="updateCommitMessageModePreference"
      />
    </gl-modal>
  </gl-form>
</template>
