import createMockApollo from 'helpers/mock_apollo_helper';
import searchNamespacesWhereUserCanCreateProjectsQuery from '../queries/search_namespaces_where_user_can_create_projects.query.graphql';
import NewProjectUrlSelect from './new_project_url_select.vue';

export default {
  component: NewProjectUrlSelect,
  title: 'projects/new/components/new_project_url_select',
};

const currentUser = {
  id: 'gid://gitlab/User/1',
  groups: {
    nodes: [
      {
        id: 'gid://gitlab/Group/10',
        fullPath: 'gitlab-org',
        name: 'GitLab.org',
        visibility: 'public',
        webUrl: 'http://gdk.test:3000/groups/gitlab-org',
        canPushInitialCommit: false,
      },
      {
        id: 'gid://gitlab/Group/11',
        fullPath: 'gitlab-org/frontend',
        name: 'Frontend',
        visibility: 'private',
        webUrl: 'http://gdk.test:3000/groups/gitlab-org/frontend',
        canPushInitialCommit: true,
      },
      {
        id: 'gid://gitlab/Group/12',
        fullPath: 'my-team',
        name: 'My Team',
        visibility: 'internal',
        webUrl: 'http://gdk.test:3000/groups/my-team',
        canPushInitialCommit: true,
      },
    ],
  },
  namespace: {
    id: 'gid://gitlab/Namespaces::UserNamespace/1',
    fullPath: 'root',
    name: 'Administrator',
    visibility: 'public',
    webUrl: 'http://gdk.test:3000/root',
    canPushInitialCommit: true,
  },
};

const mockApolloProvider = () =>
  createMockApollo([
    [searchNamespacesWhereUserCanCreateProjectsQuery, () => ({ data: { currentUser } })],
  ]);

const defaultProvide = {
  namespaceFullPath: undefined,
  namespaceId: undefined,
  rootUrl: 'http://gdk.test:3000/',
  trackLabel: 'blank_project',
  userNamespaceId: '1',
  inputId: 'project_namespace_id',
  inputName: 'project[namespace_id]',
};

const Template = (args) => ({
  components: { NewProjectUrlSelect },
  apolloProvider: mockApolloProvider(),
  provide: {
    namespaceFullPath: args.namespaceFullPath,
    namespaceId: args.namespaceId,
    rootUrl: args.rootUrl,
    trackLabel: args.trackLabel,
    userNamespaceId: args.userNamespaceId,
    inputId: args.inputId,
    inputName: args.inputName,
  },
  template: `
    <div style="min-height: 400px;" class="gl-py-3">
      <new-project-url-select />
    </div>`,
});

export const Default = Template.bind({});
Default.args = { ...defaultProvide };

export const PreselectedGroup = Template.bind({});
PreselectedGroup.args = {
  ...defaultProvide,
  namespaceId: '10',
  namespaceFullPath: 'gitlab-org',
};

// Documents current behavior: with an ID but no full path, the toggle text is blank.
export const NamespaceIdWithoutFullPath = Template.bind({});
NamespaceIdWithoutFullPath.args = {
  ...defaultProvide,
  namespaceId: '10',
  namespaceFullPath: undefined,
};

// This story intentionally reproduces the blank-toggle accessibility bug.
NamespaceIdWithoutFullPath.parameters = {
  a11y: {
    config: {
      rules: [{ id: 'button-name', enabled: false }],
    },
  },
};

// Wait for the mocked Apollo response to populate the dropdown options.
const waitUntil = async (condition, timeout = 5000) => {
  const deadline = Date.now() + timeout;
  while (!condition()) {
    if (Date.now() >= deadline) {
      throw new Error('Timed out waiting for the namespace options to render');
    }
    // eslint-disable-next-line no-await-in-loop
    await new Promise((resolve) => {
      setTimeout(resolve, 50);
    });
  }
};

export const DropdownOpen = Template.bind({});
DropdownOpen.args = { ...defaultProvide };

// Opening the dropdown triggers the debounced Apollo query. Wait for both
// group and personal namespace options before the accessibility check runs.
DropdownOpen.play = async ({ canvasElement }) => {
  const toggle = canvasElement.querySelector('[data-testid="select-namespace-dropdown"] button');
  toggle.click();

  await waitUntil(
    () =>
      canvasElement.textContent.includes('gitlab-org/frontend') &&
      canvasElement.textContent.includes('root'),
  );
};
