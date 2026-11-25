import { GlAvatar, GlPopover, GlSkeletonLoader, GlTruncate } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CommitPopoverContent from 'ee_component/commit/components/commit_popover_content.vue';
import CommitPopover from '~/issuable/popover/components/commit_popover.vue';
import commitQuery from '~/issuable/popover/queries/commit.query.graphql';

Vue.use(VueApollo);

const mockCommit = {
  id: 'gid://gitlab/Commit/abc123',
  title: 'Fix bug in feature',
  shortId: 'abc123de',
  authoredDate: '2024-01-15T10:00:00Z',
  authorName: 'Test Author',
  authorEmail: 'author@example.com',
  authorGravatar: 'https://example.com/gravatar.png',
  committerName: 'Test Committer',
  committerEmail: 'committer@example.com',
  committedDate: '2024-01-16T10:00:00Z',
  author: {
    id: 'gid://gitlab/User/1',
    name: 'Test Author',
    avatarUrl: 'https://example.com/avatar.png',
    webPath: '/test-author',
    bot: false,
  },
  webPath: '/gitlab-org/gitlab-test/-/commit/abc123de',
};

const mockQueryResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      repository: {
        commit: mockCommit,
      },
    },
  },
};

const mockNullResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      repository: {
        commit: null,
      },
    },
  },
};

describe('CommitPopover', () => {
  let wrapper;

  const createComponent = ({
    queryResponse = jest.fn().mockResolvedValue(mockQueryResponse),
    commitAgentSessions = false,
  } = {}) => {
    wrapper = shallowMountExtended(CommitPopover, {
      apolloProvider: createMockApollo([[commitQuery, queryResponse]]),
      propsData: {
        target: document.createElement('a'),
        commitSha: 'abc123de',
        projectPath: 'gitlab-org/gitlab-test',
      },
      provide: { glFeatures: { commitAgentSessions } },
      // Declares the props so the spec also passes in FOSS, where the EE component is empty.
      stubs: {
        CommitPopoverContent: stubComponent(CommitPopoverContent, {
          props: ['commit', 'projectPath', 'loading', 'trackingLabel'],
        }),
      },
    });
  };

  const findPopover = () => wrapper.findComponent(GlPopover);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findCommitLink = () => wrapper.findByTestId('commit-title-link');
  const findTruncate = () => wrapper.findComponent(GlTruncate);
  const findSha = () => wrapper.findByTestId('commit-sha-link');
  const findAuthor = () => wrapper.findByTestId('commit-author-name');
  const findErrorMessage = () => wrapper.findByTestId('commit-error-message');
  const findContent = () => wrapper.findComponent(CommitPopoverContent);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render commit content', () => {
      expect(findCommitLink().exists()).toBe(false);
    });

    it('does not render the error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
    });

    it('passes commitSha and projectPath as query variables', () => {
      const queryHandler = jest.fn().mockResolvedValue(mockQueryResponse);
      createComponent({ queryResponse: queryHandler });

      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          sha: 'abc123de',
          projectPath: 'gitlab-org/gitlab-test',
        }),
      );
    });
  });

  describe('when loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not render the skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('does not render the error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
    });

    it('renders the commit title', () => {
      expect(findTruncate().props('text')).toBe(mockCommit.title);
    });

    it('renders the author name', () => {
      expect(findAuthor().text()).toBe(mockCommit.author.name);
    });

    it('renders the author avatar', () => {
      expect(findAvatar().props('src')).toBe(mockCommit.author.avatarUrl);
    });

    it('renders the short SHA', () => {
      expect(findSha().text()).toBe(mockCommit.shortId);
    });
  });

  describe('when commit is not found (null response)', () => {
    beforeEach(async () => {
      createComponent({ queryResponse: jest.fn().mockResolvedValue(mockNullResponse) });
      await waitForPromises();
    });

    it('removes the popover so nothing shows for the reference', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('when the query errors', () => {
    beforeEach(async () => {
      createComponent({ queryResponse: jest.fn().mockRejectedValue(new Error('Network error')) });
      await waitForPromises();
    });

    it('does not render the skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('does not render commit content', () => {
      expect(findCommitLink().exists()).toBe(false);
    });

    it('shows the popover', () => {
      expect(findPopover().props('show')).toBe(true);
    });

    it('renders a user-friendly error message', () => {
      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessage().text()).toBe('Could not load commit. Please reload the page.');
    });
  });

  describe('with the commit_agent_sessions flag on', () => {
    it('renders the new content while loading', () => {
      createComponent({ commitAgentSessions: true });

      expect(findContent().props()).toEqual({
        commit: {},
        projectPath: 'gitlab-org/gitlab-test',
        loading: true,
        trackingLabel: 'commit_reference',
      });
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('renders the new content with the commit once loaded', async () => {
      createComponent({ commitAgentSessions: true });
      await waitForPromises();

      expect(findContent().props()).toEqual({
        commit: mockCommit,
        projectPath: 'gitlab-org/gitlab-test',
        loading: false,
        trackingLabel: 'commit_reference',
      });
      expect(findCommitLink().exists()).toBe(false);
    });

    it('keeps the error message and its width when the query errors', async () => {
      createComponent({
        commitAgentSessions: true,
        queryResponse: jest.fn().mockRejectedValue(new Error('Network error')),
      });
      await waitForPromises();

      expect(findContent().exists()).toBe(false);
      expect(findErrorMessage().exists()).toBe(true);
      expect(findPopover().props('cssClasses')).toEqual(['gl-min-w-30']);
    });

    it('removes the popover when the commit is not found', async () => {
      createComponent({
        commitAgentSessions: true,
        queryResponse: jest.fn().mockResolvedValue(mockNullResponse),
      });
      await waitForPromises();

      expect(findPopover().exists()).toBe(false);
    });
  });
});
