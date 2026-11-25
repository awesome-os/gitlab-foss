import { GlButton, GlLink, GlSprintf } from '@gitlab/ui';

import { nextTick } from 'vue';
import GitlabSlackApplication from '~/integrations/gitlab_slack_application/components/gitlab_slack_application.vue';
import { addProjectToSlack, addToSlack } from '~/integrations/gitlab_slack_application/api';
import { i18n } from '~/integrations/gitlab_slack_application/constants';
import ProjectsDropdown from '~/integrations/gitlab_slack_application/components/projects_dropdown.vue';
import InstallTargetDropdown from '~/integrations/gitlab_slack_application/components/install_target_dropdown.vue';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';
import { mockGroups, mockProjects } from '../mock_data';

jest.mock('~/integrations/gitlab_slack_application/api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

describe('GitlabSlackApplication', () => {
  let wrapper;

  const defaultProps = {
    projects: [],
    gitlabForSlackGifPath: '//gitlabForSlackGifPath',
    signInPath: '//signInPath',
    slackLinkPath: '//slackLinkPath',
    docsPath: '//docsPath',
    gitlabLogoPath: '//gitlabLogoPath',
    slackLogoPath: '//slackLogoPath',
    isSignedIn: true,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(GitlabSlackApplication, {
      propsData: { ...defaultProps, ...props },
      stubs: { GlSprintf },
    });
  };

  const findGlButton = () => wrapper.findComponent(GlButton);
  const findGlLink = () => wrapper.findComponent(GlLink);
  const findProjectsDropdown = () => wrapper.findComponent(ProjectsDropdown);
  const findInstallTargetDropdown = () => wrapper.findComponent(InstallTargetDropdown);
  const findHint = () => wrapper.findByTestId('install-target-hint');
  const findAppContent = () => wrapper.findByTestId('gitlab-slack-content');
  const findInstallTargetLabel = () => wrapper.find('#slack-install-target-label');

  describe('template', () => {
    describe('when user is not signed in', () => {
      it('renders "Sign in" button', () => {
        createComponent({
          props: { isSignedIn: false },
        });

        expect(findGlButton().attributes('href')).toBe(defaultProps.signInPath);
      });
    });

    describe('when user is signed in', () => {
      describe('user does not have any projects', () => {
        it('renders empty text', () => {
          createComponent();

          expect(findAppContent().text()).toContain(i18n.noProjects);
          expect(findAppContent().text()).toContain(i18n.noProjectsDescription);
        });

        it('renders "Learn more" link', () => {
          createComponent();

          expect(findGlLink().text()).toBe(i18n.learnMore);
        });
      });

      describe('user has groups', () => {
        beforeEach(() => {
          createComponent({ props: { projects: mockProjects, groups: mockGroups } });
        });

        it('offers groups and projects in one dropdown instead of the projects dropdown', () => {
          expect(findProjectsDropdown().exists()).toBe(false);
          expect(findInstallTargetDropdown().props()).toMatchObject({
            groups: mockGroups,
            projects: mockProjects,
          });
        });

        it('keeps Continue disabled until something is selected', () => {
          expect(findGlButton().props('disabled')).toBe(true);
        });

        it('installs on the selected group', async () => {
          addToSlack.mockResolvedValue({ data: { add_to_slack_link: '//groupLink' } });

          findInstallTargetDropdown().vm.$emit('target-selected', {
            type: 'group',
            id: 10,
            name: 'Acme',
          });
          await nextTick();
          findGlButton().vm.$emit('click');
          await waitForPromises();

          expect(addToSlack).toHaveBeenCalledWith('//slackLinkPath', { group_id: 10 });
          expect(visitUrl).toHaveBeenCalledWith('//groupLink');
        });

        it('installs on the selected project', async () => {
          addToSlack.mockResolvedValue({ data: { add_to_slack_link: '//projectLink' } });

          findInstallTargetDropdown().vm.$emit('target-selected', {
            type: 'project',
            id: 2,
            name: 'Shell',
          });
          await nextTick();
          findGlButton().vm.$emit('click');
          await waitForPromises();

          expect(addToSlack).toHaveBeenCalledWith('//slackLinkPath', { project_id: 2 });
        });

        it('shows an error when the install link fails, for example for a group archived after the page loaded', async () => {
          addToSlack.mockRejectedValue(new Error('Not found'));

          findInstallTargetDropdown().vm.$emit('target-selected', {
            type: 'group',
            id: 10,
            name: 'Acme',
          });
          await nextTick();
          findGlButton().vm.$emit('click');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith({ message: 'Unable to build Slack link.' });
          expect(visitUrl).not.toHaveBeenCalled();
        });

        it('says a top-level group install is for GitLab Duo', () => {
          expect(findInstallTargetLabel().text()).toBe(
            'Select where to install the GitLab for Slack app. Install it in a top-level group to use GitLab Duo in Slack.',
          );
        });

        it('tells what a group install does for GitLab Duo', async () => {
          findInstallTargetDropdown().vm.$emit('target-selected', {
            type: 'group',
            id: 10,
            name: 'Acme',
          });
          await nextTick();

          expect(findHint().text()).toBe(
            'If this Slack workspace has no GitLab Duo group yet, GitLab Duo will run in Acme and use its GitLab Duo settings and credits.',
          );
        });

        it('says where to install on a group or project that is not listed', () => {
          expect(wrapper.findByTestId('target-not-listed').text()).toBe(
            "Don't see your group or project? Install the app from its settings.",
          );
        });

        it('shows no Duo notice without an instance-wide workspace', () => {
          expect(wrapper.findByTestId('instance-workspace-notice').exists()).toBe(false);
          expect(wrapper.findByTestId('instance-workspace-other-workspace').exists()).toBe(false);
        });

        it('says that a project install does not turn GitLab Duo on', async () => {
          findInstallTargetDropdown().vm.$emit('target-selected', {
            type: 'project',
            id: 2,
            name: 'Shell',
          });
          await nextTick();

          expect(findHint().text()).toBe(
            "GitLab Duo isn't turned on by a project install. An Owner of the top-level group can turn it on later.",
          );
        });
      });

      describe('with a workspace installed for the whole instance', () => {
        const createWithInstanceWorkspace = (adminPath = null) =>
          createComponent({
            props: {
              projects: mockProjects,
              groups: mockGroups,
              instanceWorkspace: { name: 'Everyone', adminPath },
            },
          });

        it('says the administrator chooses where GitLab Duo runs, with a link for administrators', () => {
          createWithInstanceWorkspace('/admin/slack');

          const notice = wrapper.findByTestId('instance-workspace-notice');

          expect(notice.text()).toContain(
            'Everyone is connected for the whole instance. Your administrator chooses where GitLab Duo runs for it.',
          );
          expect(notice.findComponent(GlLink).text()).toBe('Choose in the Admin area');
          expect(notice.findComponent(GlLink).attributes('href')).toBe('/admin/slack');
        });

        it('also tells people who can only install on projects', () => {
          createComponent({
            props: { projects: mockProjects, groups: [], instanceWorkspace: { name: 'Everyone' } },
          });

          expect(wrapper.findByTestId('instance-workspace-notice').exists()).toBe(true);
        });

        it('says where to connect another Slack workspace', () => {
          createComponent({
            props: { projects: [], groups: [], instanceWorkspace: { name: 'Everyone' } },
          });

          expect(wrapper.findByTestId('instance-workspace-other-workspace').text()).toBe(
            "To connect a group or project to another Slack workspace, install the app from the group's or project's settings instead.",
          );
        });

        it('has no link for people who are not administrators', () => {
          createWithInstanceWorkspace();

          expect(
            wrapper.findByTestId('instance-workspace-notice').findComponent(GlLink).exists(),
          ).toBe(false);
        });

        it.each([
          ['group', { type: 'group', id: 10, name: 'Acme' }],
          ['project', { type: 'project', id: 2, name: 'Shell' }],
        ])('makes no promise about GitLab Duo for a %s install', async (_, target) => {
          createWithInstanceWorkspace();

          findInstallTargetDropdown().vm.$emit('target-selected', target);
          await nextTick();

          expect(findHint().exists()).toBe(false);
        });

        it('leaves out the note about unlisted groups and projects, which the instance notice covers', () => {
          createWithInstanceWorkspace();

          expect(wrapper.findByTestId('target-not-listed').exists()).toBe(false);
        });

        it('leaves out the note about unlisted projects with only projects to offer', () => {
          createComponent({
            props: { projects: mockProjects, groups: [], instanceWorkspace: { name: 'Everyone' } },
          });

          expect(wrapper.findByTestId('project-not-listed').exists()).toBe(false);
        });

        it('leaves GitLab Duo out of the dropdown label', () => {
          createWithInstanceWorkspace();

          expect(findInstallTargetLabel().text()).toBe(
            'Select where to install the GitLab for Slack app.',
          );
        });
      });

      describe('user has projects', () => {
        beforeEach(() => {
          createComponent({
            props: {
              projects: mockProjects,
            },
          });
        });

        it('renders ProjectsDropdown', () => {
          expect(findProjectsDropdown().props('projects')).toBe(mockProjects);
        });

        it('says where to install on a project that is not listed', () => {
          expect(wrapper.findByTestId('project-not-listed').text()).toBe(
            "Don't see your project? Install the app from the project's settings.",
          );
        });

        it('redirects to slackLinkPath when submitted', async () => {
          const redirectLink = '//redirectLink';
          const mockProject = mockProjects[1];
          const addToSlackData = { data: { add_to_slack_link: redirectLink } };

          addProjectToSlack.mockResolvedValue(addToSlackData);

          findProjectsDropdown().vm.$emit('project-selected', mockProject);
          await nextTick();

          expect(findProjectsDropdown().props('selectedProject')).toBe(mockProject);
          expect(findGlButton().props('disabled')).toBe(false);

          findGlButton().vm.$emit('click');

          await waitForPromises();

          expect(visitUrl).toHaveBeenCalledWith(redirectLink);
        });

        it('shows an error when the install link fails', async () => {
          addProjectToSlack.mockRejectedValue(new Error('Not found'));

          findProjectsDropdown().vm.$emit('project-selected', mockProjects[1]);
          await nextTick();
          findGlButton().vm.$emit('click');
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith({ message: 'Unable to build Slack link.' });
          expect(visitUrl).not.toHaveBeenCalled();
        });
      });
    });
  });
});
