import { __, s__ } from '~/locale';

export const i18n = {
  slackErrorMessage: __('Unable to build Slack link.'),
  gitlabLogoAlt: __('GitLab logo'),
  slackLogoAlt: __('Slack logo'),
  title: s__('SlackIntegration|GitLab for Slack'),
  dropdownLabel: s__('SlackIntegration|Select a GitLab project to link with your Slack workspace.'),
  dropdownLabelWithGroups: s__(
    'SlackIntegration|Select where to install the GitLab for Slack app. Install it in a top-level group to use GitLab Duo in Slack.',
  ),
  dropdownLabelInstance: s__('SlackIntegration|Select where to install the GitLab for Slack app.'),
  searchPlaceholder: s__('SlackIntegration|Search groups and projects'),
  noResults: s__('SlackIntegration|No groups or projects found'),
  groupsHeader: s__('SlackIntegration|Groups · for GitLab Duo'),
  projectsHeader: s__('SlackIntegration|Projects · notifications only'),
  groupHint: s__(
    'SlackIntegration|If this Slack workspace has no GitLab Duo group yet, GitLab Duo will run in %{name} and use its GitLab Duo settings and credits.',
  ),
  instanceNotice: s__(
    'SlackIntegration|%{workspace} is connected for the whole instance. Your administrator chooses where GitLab Duo runs for it.',
  ),
  instanceNoticeLink: s__('SlackIntegration|Choose in the Admin area'),
  instanceOtherWorkspace: s__(
    "SlackIntegration|To connect a group or project to another Slack workspace, install the app from the group's or project's settings instead.",
  ),
  targetNotListed: s__(
    "SlackIntegration|Don't see your group or project? Install the app from its settings.",
  ),
  projectNotListed: s__(
    "SlackIntegration|Don't see your project? Install the app from the project's settings.",
  ),
  projectHint: s__(
    "SlackIntegration|GitLab Duo isn't turned on by a project install. An Owner of the top-level group can turn it on later.",
  ),
  selectTarget: s__('SlackIntegration|Select a group or project'),
  dropdownButtonText: __('Continue'),
  noProjects: __('No projects available.'),
  noProjectsDescription: __('Make sure you have the correct permissions to link your project.'),
  learnMore: __('Learn more'),
  signInLabel: s__('JiraService|Sign in to GitLab to get started.'),
  signInButtonText: __('Sign in to GitLab'),
};
