import { parseBoolean } from '@gitlab/frontend-utils';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import GitlabSlackApplication from './components/gitlab_slack_application.vue';

export default () => {
  const el = document.querySelector('.js-gitlab-slack-application');

  if (!el) return null;

  const {
    projects,
    groups,
    instanceWorkspace,
    isSignedIn,
    signInPath,
    slackLinkPath,
    gitlabLogoPath,
    slackLogoPath,
  } = el.dataset;

  return initVueApp({
    el,
    name: 'GitlabSlackApplicationRoot',
    component: GitlabSlackApplication,
    props: {
      projects: JSON.parse(projects),
      groups: groups ? JSON.parse(groups) : [],
      instanceWorkspace: instanceWorkspace
        ? convertObjectPropsToCamelCase(JSON.parse(instanceWorkspace))
        : null,
      isSignedIn: parseBoolean(isSignedIn),
      signInPath,
      slackLinkPath,
      gitlabLogoPath,
      slackLogoPath,
    },
  });
};
