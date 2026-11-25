import {
  FILTERED_SEARCH_TERM,
  OPERATORS_IS,
  TOKEN_TITLE_ASSIGNEE,
  TOKEN_TITLE_AUTHOR,
  TOKEN_TITLE_LABEL,
  TOKEN_TITLE_MILESTONE,
  TOKEN_TITLE_SOURCE_BRANCH,
  TOKEN_TITLE_TARGET_BRANCH,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_SOURCE_BRANCH,
  TOKEN_TYPE_TARGET_BRANCH,
} from '~/vue_shared/components/filtered_search_bar/constants';
import BranchToken from '~/vue_shared/components/filtered_search_bar/tokens/branch_token.vue';
import LabelToken from '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue';
import MilestoneToken from '~/vue_shared/components/filtered_search_bar/tokens/milestone_token.vue';
import UserToken from '~/vue_shared/components/filtered_search_bar/tokens/user_token.vue';
import { FILTERED_SEARCH_MAX_LABELS } from '~/explore/analytics_dashboards/components/constants';

export const mockEmptyDashboardsListResponse = {
  customDashboards: {
    nodes: [],
  },
};

// Shape returned when the query is unauthorized, e.g. the `custom_dashboard_storage`
// feature flag is disabled: the field resolves to null rather than an empty list.
export const mockNullDashboardsListResponse = {
  customDashboards: null,
};

export const mockCustomDashboard = {
  id: 'gid://gitlab/Analytics::CustomDashboards::Dashboard/3',
  name: 'Fake trends',
  description: 'Visualize fake trend data that is definitly fake',
  config: {
    title: 'Fake trend dashboard',
    panels: [
      {
        title: 'Total fake users',
        visualization: 'fake_users_count_over_time',
        gridAttributes: {
          xPos: 0,
          yPos: 0,
          width: 3,
          height: 1,
        },
      },
      {
        title: 'Some arbritrary attribute',
        options: {},
        visualization: 'fake_attribute_count_over_time',
        gridAttributes: {
          xPos: 3,
          yPos: 0,
          width: 3,
          height: 1,
        },
      },
    ],
    version: '2',
    description: 'A very much more specific description',
  },
  organization: {
    id: 'gid://gitlab/Organizations::Organization/1',
    name: 'Fake organization',
    __typename: 'Organization',
  },
  namespace: null,
  createdBy: {
    id: 'gid://gitlab/User/1',
    name: 'Administrator',
    username: 'root',
    webUrl: 'http://gdk.test:3001/root',
    webPath: '/root',
    avatarUrl: 'https://www.gravatar.com/avatar/fake',
    __typename: 'UserCore',
  },
  createdAt: '2026-03-25T04:38:01Z',
  updatedAt: '2026-03-25T04:38:01Z',
  system: false,
  slug: null,
  __typename: 'CustomDashboard',
};

const mockSystemDashboard = {
  id: 'gitlab:dashboard:merge_requests',
  name: 'Merge request analytics',
  description: 'Get insights into your merge request lifecycle and view trends over time.',
  config: {
    title: 'Merge request analytics',
    panels: [],
    version: '2',
  },
  createdAt: null,
  system: true,
  slug: 'merge_requests',
  errors: null,
  __typename: 'CustomSystemDashboard',
};

export const mockDashboardsListResponse = {
  customDashboards: {
    nodes: [mockCustomDashboard, mockSystemDashboard],
  },
};

export const mockDashboardResponse = {
  customDashboard: mockCustomDashboard,
};

export const mockSystemDashboardResponse = {
  customSystemDashboard: mockSystemDashboard,
};

// A dashboard with a `null` entry in panels and in views, as an unfinished YAML list item parses.
export const mockSystemDashboardWithNullEntriesResponse = {
  customSystemDashboard: {
    id: 'gitlab:dashboard:null_entries',
    name: 'null_entries',
    description: null,
    config: {
      panels: [
        null,
        { id: 'panel-original-1', title: 'Fine', gridAttributes: { width: 4, height: 2 } },
      ],
      views: [null, { title: 'Good', panels: [null] }],
    },
    system: true,
    slug: 'null_entries',
    errors: ["property '/panels/0' is not of type: object", 'root is missing required keys: title'],
  },
};

// A system dashboard whose schema errors point at individual panels, including a null entry
// before them so the pointer indexes do not match the filtered list.
export const mockSystemDashboardWithPanelErrorsResponse = {
  customSystemDashboard: {
    id: 'gitlab:dashboard:panel_errors',
    name: 'panel_errors',
    description: null,
    config: {
      title: 'Panel errors',
      panels: [
        null,
        {
          id: 'fine',
          title: 'Fine',
          gridAttributes: { width: 4, height: 2 },
          visualization: { type: 'LineChart' },
        },
        {
          id: 'bad',
          title: 'Bad',
          gridAttributes: { width: 4, height: 2 },
          visualization: { type: 'Nope' },
        },
        { id: 'missing', title: 'Missing', gridAttributes: { width: 4, height: 2 } },
        {
          id: 'scalar',
          title: 'Scalar',
          gridAttributes: { width: 4, height: 2 },
          visualization: 'oops',
        },
        {
          id: 'scalar-errors',
          title: 'Scalar errors',
          gridAttributes: { width: 4, height: 2 },
          visualization: { type: 'Nope', errors: 'oops' },
        },
        {
          id: 'with-views',
          title: 'With views',
          gridAttributes: { width: 4, height: 2 },
          visualization: { type: 'LineChart' },
          views: [
            { text: 'First', visualization: { type: 'LineChart' } },
            { text: 'Second', visualization: { type: 'Nope' } },
          ],
        },
        {
          id: 'section',
          section: { title: 'Section', description: 7 },
          gridAttributes: { height: 1 },
        },
      ],
      views: [
        {
          title: 'View',
          panels: [
            {
              id: 'view-bad',
              title: 'View bad',
              gridAttributes: { width: 4, height: 2 },
              visualization: { type: 'Nope' },
            },
          ],
        },
      ],
    },
    system: true,
    slug: 'panel_errors',
    errors: [
      "property '/panels/0' is not of type: object",
      'property \'/panels/2/visualization/type\' is not one of: ["LineChart"]',
      "property '/panels/2/gridAttributes/width' is not of type: integer",
      "property '/panels/3' is missing required keys: visualization",
      "property '/panels/4/visualization' is not of type: object",
      'property \'/panels/5/visualization/type\' is not one of: ["LineChart"]',
      'property \'/panels/6/views/1/visualization/type\' is not one of: ["LineChart"]',
      "property '/panels/6/title' is not of type: string",
      "property '/panels/7/section/description' is not of type: string",
      'property \'/views/0/panels/0/visualization/type\' is not one of: ["LineChart"]',
      'root is missing required keys: version',
    ],
  },
};

// The same, for a dashboard with views: one view's panels are broken, the other's are fine.
export const mockInvalidSystemDashboardWithViewsResponse = {
  customSystemDashboard: {
    id: 'gitlab:dashboard:broken_views',
    name: 'Broken views',
    description: null,
    config: {
      title: 'Broken views',
      views: [
        { title: 'Bad', panels: 'oops' },
        {
          title: 'Good',
          panels: [
            { id: 'panel-original-1', title: 'Fine', gridAttributes: { width: 4, height: 2 } },
          ],
        },
      ],
    },
    system: true,
    slug: 'broken_views',
    errors: ["property '/views/0/panels' is not of type: array"],
  },
};

// A system dashboard whose YAML failed schema validation: the loader keeps it, and
// `panels` is not even an array.
export const mockInvalidSystemDashboardResponse = {
  customSystemDashboard: {
    id: 'gitlab:dashboard:broken',
    name: 'Broken',
    description: null,
    config: { title: 'Broken', panels: 'oops' },
    system: true,
    slug: 'broken',
    errors: ["property '/panels' is not of type: array", 'root is missing required keys: version'],
  },
};

export const mockDashboardCompactGridResponse = (gridHeight) => ({
  customDashboard: {
    ...mockCustomDashboard,
    config: {
      ...mockCustomDashboard.config,
      gridHeight,
    },
  },
});

const mockDashboardWithViews = {
  ...mockCustomDashboard,
  config: {
    ...mockCustomDashboard.config,
    views: [
      {
        title: 'Overview',
        panels: [
          {
            title: 'Overview panel',
            visualization: 'overview_over_time',
            gridAttributes: { xPos: 0, yPos: 0, width: 3, height: 1 },
          },
        ],
      },
      {
        title: 'Details',
        panels: [
          {
            title: 'Details panel one',
            visualization: 'details_one_over_time',
            gridAttributes: { xPos: 0, yPos: 0, width: 3, height: 1 },
          },
          {
            title: 'Details panel two',
            visualization: 'details_two_over_time',
            gridAttributes: { xPos: 3, yPos: 0, width: 3, height: 1 },
          },
        ],
      },
    ],
  },
};

export const mockDashboardWithViewsResponse = {
  customDashboard: mockDashboardWithViews,
};

export const mockPanelWithViews = {
  ...mockCustomDashboard.config.panels[0],
  titleIcon: 'information-o',
  tooltip: { description: 'Fake tooltip' },
  queryOverrides: { limit: 10 },
  // The explore app expects an inline visualization object, not a slug.
  visualization: { type: 'SingleStat' },
  views: [
    { text: 'Chart', visualization: { type: 'LineChart' } },
    { text: 'Table', visualization: { type: 'DataTable' } },
  ],
};

const mockDashboardWithPanelViews = {
  ...mockCustomDashboard,
  config: {
    ...mockCustomDashboard.config,
    panels: [mockPanelWithViews],
  },
};

export const mockDashboardWithPanelViewsResponse = {
  customDashboard: mockDashboardWithPanelViews,
};

export const mockMilestoneToken = {
  icon: 'milestone',
  title: TOKEN_TITLE_MILESTONE,
  type: TOKEN_TYPE_MILESTONE,
  token: MilestoneToken,
  unique: true,
  symbol: '%',
};

export const mockLabelToken = {
  icon: 'labels',
  title: TOKEN_TITLE_LABEL,
  type: TOKEN_TYPE_LABEL,
  token: LabelToken,
  unique: false,
  symbol: '~',
  maxSuggestions: FILTERED_SEARCH_MAX_LABELS,
};

export const mockAuthorToken = {
  icon: 'pencil',
  title: TOKEN_TITLE_AUTHOR,
  type: TOKEN_TYPE_AUTHOR,
  token: UserToken,
  dataType: 'user',
  unique: true,
};

export const mockAssigneeToken = {
  icon: 'user',
  title: TOKEN_TITLE_ASSIGNEE,
  type: TOKEN_TYPE_ASSIGNEE,
  token: UserToken,
  dataType: 'user',
  unique: false,
};

export const mockSourceBranchToken = {
  icon: 'branch',
  title: TOKEN_TITLE_SOURCE_BRANCH,
  type: TOKEN_TYPE_SOURCE_BRANCH,
  token: BranchToken,
  unique: true,
  operators: OPERATORS_IS,
};

export const mockTargetBranchToken = {
  icon: 'branch',
  title: TOKEN_TITLE_TARGET_BRANCH,
  type: TOKEN_TYPE_TARGET_BRANCH,
  token: BranchToken,
  unique: true,
  operators: OPERATORS_IS,
};

export const mockFilteredSearchFilters = [
  {
    type: TOKEN_TYPE_AUTHOR,
    value: {
      data: 'root',
      operator: '=',
    },
    id: 'token-14',
  },
  {
    type: TOKEN_TYPE_MILESTONE,
    value: {
      data: 'Any',
      operator: '=',
    },
    id: 'token-16',
  },
  {
    type: TOKEN_TYPE_LABEL,
    value: {
      data: 'Afterpod',
      operator: '=',
    },
    id: 'token-18',
  },
  {
    type: TOKEN_TYPE_ASSIGNEE,
    value: {
      data: 'root',
      operator: '=',
    },
    id: 'token-20',
  },
  {
    type: TOKEN_TYPE_ASSIGNEE,
    value: {
      data: 'vsm-user-1-1737989060',
      operator: '!=',
    },
    id: 'token-24',
  },
  {
    id: 'token-25',
    type: FILTERED_SEARCH_TERM,
    value: {
      data: '',
    },
  },
];

export const mockFilteredSearchChangePayload = {
  [TOKEN_TYPE_ASSIGNEE]: [
    {
      operator: '=',
      value: 'root',
    },
    {
      operator: '!=',
      value: 'vsm-user-1-1737989060',
    },
  ],
  [TOKEN_TYPE_AUTHOR]: [
    {
      operator: '=',
      value: 'root',
    },
  ],
  [TOKEN_TYPE_LABEL]: [
    {
      operator: '=',
      value: 'Afterpod',
    },
  ],
  [TOKEN_TYPE_MILESTONE]: [
    {
      operator: '=',
      value: 'Any',
    },
  ],
};

export const mockLabel1 = {
  id: 'gid://gitlab/GroupLabel/121',
  title: 'UX',
  color: '#F0AD4E',
  textColor: '#FFFFFF',
  description: null,
};

export const mockLabel2 = {
  id: 'gid://gitlab/GroupLabel/122',
  title: 'frontend',
  color: '#F0AD4E',
  textColor: '#FFFFFF',
  description: null,
};

export const mockProjectLabelsResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/1',
      labels: {
        nodes: [mockLabel1, mockLabel2],
      },
      __typename: 'Project',
    },
  },
};

export const mockGroupLabelsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      labels: {
        nodes: [mockLabel1, mockLabel2],
      },
      __typename: 'Group',
    },
  },
};

export const mockRepositoryBranchNamesResponse = {
  data: {
    project: {
      id: 'gid://gitlab/Project/34',
      repository: {
        branchNames: [
          'master',
          "'test'",
          '2-mb-file',
          'Amfunc-Trynt-320',
          'Aquafunc-Panapod-382',
          'NDC-Sosync-649',
          'Onesync-DNF-249',
          'Phant-Techbalt-941',
          'Phest-Phieck-278',
          'Phiestwood-Phyckwood-340',
        ],
        __typename: 'Repository',
      },
    },
  },
};
