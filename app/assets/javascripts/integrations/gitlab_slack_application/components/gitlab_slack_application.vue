<script>
import { GlButton, GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';
import { helpPagePath } from '~/helpers/help_page_helper';

import { i18n } from '../constants';

import { addProjectToSlack, addToSlack } from '../api';
import ProjectsDropdown from './projects_dropdown.vue';
import InstallTargetDropdown from './install_target_dropdown.vue';

export default {
  name: 'GitlabSlackApplication',
  components: {
    GlButton,
    GlIcon,
    GlLink,
    GlSprintf,
    ProjectsDropdown,
    InstallTargetDropdown,
  },
  props: {
    projects: {
      type: Array,
      required: false,
      default: () => [],
    },
    groups: {
      type: Array,
      required: false,
      default: () => [],
    },
    instanceWorkspace: {
      type: Object,
      required: false,
      default: null,
    },
    isSignedIn: {
      type: Boolean,
      required: true,
    },
    signInPath: {
      type: String,
      required: true,
    },
    slackLinkPath: {
      type: String,
      required: true,
    },
    gitlabLogoPath: {
      type: String,
      required: true,
    },
    slackLogoPath: {
      type: String,
      required: true,
    },
  },
  i18n,
  learnMoreLink: helpPagePath('user/project/integrations/gitlab_slack_application', {
    anchor: 'install-the-gitlab-for-slack-app',
  }),
  data() {
    return {
      selectedProject: null,
      selectedTarget: null,
    };
  },
  computed: {
    hasProjects() {
      return this.projects.length > 0;
    },
    isGroupSelected() {
      return this.selectedTarget?.type === 'group';
    },
    // The administrator chooses where GitLab Duo runs for an instance-wide workspace, so no promise either way.
    showHint() {
      return Boolean(this.selectedTarget) && !this.instanceWorkspace;
    },
    hasGroups() {
      return this.groups.length > 0;
    },
  },
  methods: {
    selectProject(project) {
      this.selectedProject = project;
    },
    selectTarget(target) {
      this.selectedTarget = target;
    },
    addTargetToSlack() {
      const params =
        this.selectedTarget.type === 'group'
          ? { group_id: this.selectedTarget.id }
          : { project_id: this.selectedTarget.id };

      addToSlack(this.slackLinkPath, params)
        .then((response) => visitUrl(response.data.add_to_slack_link))
        .catch(() =>
          createAlert({
            message: i18n.slackErrorMessage,
          }),
        );
    },
    addSelectedProject() {
      addProjectToSlack(this.slackLinkPath, this.selectedProject.id)
        .then((response) => visitUrl(response.data.add_to_slack_link))
        .catch(() =>
          createAlert({
            message: i18n.slackErrorMessage,
          }),
        );
    },
  },
};
</script>

<template>
  <div class="gl-mx-auto gl-mt-11 gl-max-w-max gl-text-center">
    <div v-once class="gl-my-5 gl-flex gl-items-center gl-justify-center">
      <img :src="gitlabLogoPath" :alt="$options.i18n.gitlabLogoAlt" class="gl-h-11 gl-w-11" />
      <gl-icon name="arrow-right" :size="32" class="gl-mx-5" variant="disabled" />
      <img
        :src="slackLogoPath"
        :alt="$options.i18n.slackLogoAlt"
        class="gitlab-slack-slack-logo gl-h-11 gl-w-11"
      />
    </div>

    <h2>{{ $options.i18n.title }}</h2>

    <div data-testid="gitlab-slack-content">
      <template v-if="isSignedIn">
        <p v-if="instanceWorkspace" data-testid="instance-workspace-notice">
          <gl-sprintf :message="$options.i18n.instanceNotice">
            <template #workspace>
              <strong>{{ instanceWorkspace.name }}</strong>
            </template>
          </gl-sprintf>
          <gl-link v-if="instanceWorkspace.adminPath" :href="instanceWorkspace.adminPath">{{
            $options.i18n.instanceNoticeLink
          }}</gl-link>
        </p>
        <p v-if="instanceWorkspace" data-testid="instance-workspace-other-workspace">
          {{ $options.i18n.instanceOtherWorkspace }}
        </p>
        <div v-if="hasGroups" class="gl-mt-6">
          <p id="slack-install-target-label">
            {{
              instanceWorkspace
                ? $options.i18n.dropdownLabelInstance
                : $options.i18n.dropdownLabelWithGroups
            }}
          </p>

          <install-target-dropdown
            :groups="groups"
            :projects="projects"
            :selected-target="selectedTarget"
            labelled-by="slack-install-target-label"
            @target-selected="selectTarget"
          />

          <!-- Keeps room for a two-line hint, so picking a target doesn't move the button. -->
          <div
            v-if="!instanceWorkspace"
            class="gl-mt-3 gl-min-h-9 gl-w-0 gl-min-w-full gl-text-left gl-text-subtle"
          >
            <p v-if="showHint" class="gl-mb-0" data-testid="install-target-hint">
              <gl-sprintf v-if="isGroupSelected" :message="$options.i18n.groupHint">
                <template #name>
                  <strong>{{ selectedTarget.name }}</strong>
                </template>
              </gl-sprintf>
              <template v-else>{{ $options.i18n.projectHint }}</template>
            </p>
          </div>

          <p
            v-if="!instanceWorkspace"
            class="gl-mb-0 gl-mt-3 gl-text-left gl-text-subtle"
            data-testid="target-not-listed"
          >
            {{ $options.i18n.targetNotListed }}
          </p>

          <div class="gl-mt-3 gl-flex gl-justify-end">
            <gl-button
              category="primary"
              variant="confirm"
              :disabled="!selectedTarget"
              @click="addTargetToSlack"
            >
              {{ $options.i18n.dropdownButtonText }}
            </gl-button>
          </div>
        </div>
        <div v-else-if="hasProjects" class="gl-mt-6">
          <p>
            {{ $options.i18n.dropdownLabel }}
          </p>

          <projects-dropdown
            :projects="projects"
            :selected-project="selectedProject"
            @project-selected="selectProject"
          />

          <p
            v-if="!instanceWorkspace"
            class="gl-mb-0 gl-mt-3 gl-text-left gl-text-subtle"
            data-testid="project-not-listed"
          >
            {{ $options.i18n.projectNotListed }}
          </p>

          <div class="gl-mt-3 gl-flex gl-justify-end">
            <gl-button
              category="primary"
              variant="confirm"
              :disabled="!selectedProject"
              @click="addSelectedProject"
            >
              {{ $options.i18n.dropdownButtonText }}
            </gl-button>
          </div>
        </div>
        <div v-else>
          <p class="gl-mb-0">{{ $options.i18n.noProjects }}</p>
          <p>
            <span>{{ $options.i18n.noProjectsDescription }}</span>
            <gl-link :href="$options.learnMoreLink" target="_blank">{{
              $options.i18n.learnMore
            }}</gl-link
            >.
          </p>
        </div>
      </template>

      <template v-else>
        <p>{{ $options.i18n.signInLabel }}</p>
        <gl-button category="primary" variant="confirm" :href="signInPath">
          {{ $options.i18n.signInButtonText }}
        </gl-button>
      </template>
    </div>
  </div>
</template>
<style>
.gitlab-slack-slack-logo {
  transform: scale(200%); /* Slack logo SVG is scaled down 50% and has empty space around it */
}
</style>
