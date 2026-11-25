import {
  CREATION_CONTEXT_LIST_ROUTE,
  STATE_CLOSED,
  STATE_OPEN,
  WIDGET_TYPE_LABELS,
  WIDGET_TYPE_LINKED_ITEMS,
  WIDGET_TYPE_HIERARCHY,
  WIDGET_TYPE_WEIGHT,
  WORK_ITEM_TYPE_ENUM_EPIC,
  WORK_ITEM_TYPE_ENUM_INCIDENT,
  WORK_ITEM_TYPE_ENUM_ISSUE,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_REQUIREMENTS,
  WORK_ITEM_TYPE_ENUM_TASK,
  WORK_ITEM_TYPE_ENUM_TEST_CASE,
  WORK_ITEM_TYPE_ENUM_TICKET,
  WORK_ITEM_TYPE_NAME_EPIC,
  WORK_ITEM_TYPE_NAME_INCIDENT,
  WORK_ITEM_TYPE_NAME_ISSUE,
  WORK_ITEM_TYPE_NAME_KEY_RESULT,
  WORK_ITEM_TYPE_NAME_OBJECTIVE,
  WORK_ITEM_TYPE_NAME_REQUIREMENTS,
  WORK_ITEM_TYPE_NAME_TASK,
  WORK_ITEM_TYPE_NAME_TEST_CASE,
  WORK_ITEM_TYPE_NAME_TICKET,
  WIDGET_TYPE_MILESTONE,
} from '~/work_items/constants';
import {
  autocompleteDataSources,
  convertTypeEnumToName,
  findAssigneesWidget,
  findAwardEmojiWidget,
  findBlockerLinkedItems,
  findDesignsWidget,
  findDevelopmentWidget,
  findErrorTrackingWidget,
  findHierarchyWidget,
  findMilestoneWidget,
  findNotificationsWidget,
  findNotesWidget,
  findOpenChildItemsCountsByType,
  findCrmContactsWidget,
  findCurrentUserTodosWidget,
  findCustomFieldsWidget,
  findColorWidget,
  findDescriptionWidget,
  findEmailParticipantsWidget,
  findHealthStatusWidget,
  findIterationWidget,
  findLabelsWidget,
  findParticipantsWidget,
  findProgressWidget,
  findRequesterWidget,
  findWeightWidget,
  findWidgetByType,
  findStatusWidget,
  findLinkedItemsWidget,
  findLinkedResourcesWidget,
  findStartAndDueDateWidget,
  findTimeTrackingWidget,
  findVulnerabilitiesWidget,
  getMetadataWidgetsFromWorkItem,
  formatLabelForListbox,
  formatUserForListbox,
  lowercaseWorkItemType,
  newWorkItemPath,
  getDisplayReference,
  isReference,
  workItemRoadmapPath,
  saveHiddenMetadataKeysToLocalStorage,
  getHiddenMetadataKeysFromLocalStorage,
  makeDetailPanelUrlParam,
  makeDetailPanelItemFullPath,
  findDetailPanelWorkItem,
  getItems,
  canRouterNav,
  formatSelectOptionForCustomField,
  preserveDetailsState,
  getParentGroupName,
  createBranchMRApiPathHelper,
  getNewWorkItemAutoSaveKey,
  getNewWorkItemWidgetsAutoSaveKey,
  updateDraftWorkItemType,
  getDraftWorkItemType,
  setLastUsedWorkItemTypeIdForNamespace,
  getLastUsedWorkItemTypeIdForNamespace,
  combineWorkItemLists,
  isCurrentViewWorkItem,
  getSortValue,
  getRequestedPanel,
} from '~/work_items/utils';
import setWindowLocation from 'helpers/set_window_location_helper';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import { TYPE_EPIC } from '~/issues/constants';
import {
  CLOSED_AT_ASC,
  CLOSED_AT_DESC,
  CREATED_ASC,
  CREATED_DESC,
  DUE_DATE_ASC,
  DUE_DATE_DESC,
  MILESTONE_DUE_ASC,
  MILESTONE_DUE_DESC,
  POPULARITY_ASC,
  POPULARITY_DESC,
  START_DATE_ASC,
  START_DATE_DESC,
  TITLE_ASC,
  TITLE_DESC,
  UPDATED_ASC,
  UPDATED_DESC,
} from '~/work_items/list/constants';

describe('formatLabelForListbox', () => {
  const label = {
    __typename: 'Label',
    id: 'gid://gitlab/Label/1',
    title: 'Label 1',
    description: '',
    color: '#f00',
    textColor: '#00f',
  };

  it('formats as expected', () => {
    expect(formatLabelForListbox(label)).toEqual({
      text: 'Label 1',
      value: 'gid://gitlab/Label/1',
      color: '#f00',
    });
  });
});

describe('formatUserForListbox', () => {
  const user = {
    __typename: 'UserCore',
    id: 'gid://gitlab/User/1',
    avatarUrl: '',
    webUrl: '',
    webPath: '/doe_I',
    name: 'John Doe',
    username: 'doe_I',
  };

  it('formats as expected', () => {
    expect(formatUserForListbox(user)).toEqual({
      __typename: 'UserCore',
      id: 'gid://gitlab/User/1',
      avatarUrl: '',
      webUrl: '',
      webPath: '/doe_I',
      name: 'John Doe',
      username: 'doe_I',
      text: 'John Doe',
      value: 'gid://gitlab/User/1',
    });
  });
});

describe('autocompleteDataSources', () => {
  const pathsWithSnakeCase = {
    members: '/flightjs/Flight/-/autocomplete_sources/members?type=WorkItem&work_item_type_id=1',
    issues: '/flightjs/Flight/-/autocomplete_sources/issues?type=WorkItem&work_item_type_id=1',
    mergeRequests:
      '/flightjs/Flight/-/autocomplete_sources/merge_requests?type=WorkItem&work_item_type_id=1',
    labels: '/flightjs/Flight/-/autocomplete_sources/labels?type=WorkItem&work_item_type_id=1',
    milestones:
      '/flightjs/Flight/-/autocomplete_sources/milestones?type=WorkItem&work_item_type_id=1',
    commands: '/flightjs/Flight/-/autocomplete_sources/commands?type=WorkItem&work_item_type_id=1',
    snippets: '/flightjs/Flight/-/autocomplete_sources/snippets?type=WorkItem&work_item_type_id=1',
    contacts: '/flightjs/Flight/-/autocomplete_sources/contacts?type=WorkItem&work_item_type_id=1',
    wikis: '/flightjs/Flight/-/autocomplete_sources/wikis?type=WorkItem&work_item_type_id=1',
    epics: '/flightjs/Flight/-/autocomplete_sources/epics?type=WorkItem&work_item_type_id=1',
    iterations:
      '/flightjs/Flight/-/autocomplete_sources/iterations?type=WorkItem&work_item_type_id=1',
    vulnerabilities:
      '/flightjs/Flight/-/autocomplete_sources/vulnerabilities?type=WorkItem&work_item_type_id=1',
  };

  const pathsWithCamelCase = {
    members: '/flightjs/Flight/-/autocomplete_sources/members?type=WorkItem&work_item_type_id=1',
    issues: '/flightjs/Flight/-/autocomplete_sources/issues?type=WorkItem&work_item_type_id=1',
    mergeRequests:
      '/flightjs/Flight/-/autocomplete_sources/merge_requests?type=WorkItem&work_item_type_id=1',
    labels: '/flightjs/Flight/-/autocomplete_sources/labels?type=WorkItem&work_item_type_id=1',
    milestones:
      '/flightjs/Flight/-/autocomplete_sources/milestones?type=WorkItem&work_item_type_id=1',
    commands: '/flightjs/Flight/-/autocomplete_sources/commands?type=WorkItem&work_item_type_id=1',
    snippets: '/flightjs/Flight/-/autocomplete_sources/snippets?type=WorkItem&work_item_type_id=1',
    contacts: '/flightjs/Flight/-/autocomplete_sources/contacts?type=WorkItem&work_item_type_id=1',
    wikis: '/flightjs/Flight/-/autocomplete_sources/wikis?type=WorkItem&work_item_type_id=1',
    epics: '/flightjs/Flight/-/autocomplete_sources/epics?type=WorkItem&work_item_type_id=1',
    iterations:
      '/flightjs/Flight/-/autocomplete_sources/iterations?type=WorkItem&work_item_type_id=1',
    vulnerabilities:
      '/flightjs/Flight/-/autocomplete_sources/vulnerabilities?type=WorkItem&work_item_type_id=1',
  };

  describe('default', () => {
    it('returns paths', () => {
      expect(autocompleteDataSources(pathsWithCamelCase)).toEqual({
        ...pathsWithCamelCase,
        statuses: true,
      });
    });
  });

  describe('when sources contains merge_requests property', () => {
    it('returns paths with merge_requests converted to mergeRequests', () => {
      expect(autocompleteDataSources(pathsWithSnakeCase)).toEqual({
        ...pathsWithCamelCase,
        statuses: true,
      });
    });
  });
});

describe('newWorkItemPath', () => {
  beforeEach(() => {
    gon.relative_url_root = '/foobar';
  });

  it('returns correct path', () => {
    expect(newWorkItemPath({ fullPath: 'group/project' })).toBe(
      '/foobar/group/project/-/work_items/new',
    );
  });

  it('returns correct data sources with group context', () => {
    expect(newWorkItemPath({ fullPath: 'group', isGroup: true })).toBe(
      '/foobar/groups/group/-/work_items/new',
    );
  });

  it('appends a query string to the path', () => {
    expect(newWorkItemPath({ fullPath: 'project', query: '?foo=bar' })).toBe(
      '/foobar/project/-/work_items/new?foo=bar',
    );
  });
});

describe('convertTypeEnumToName', () => {
  it.each`
    name                                | enumValue
    ${WORK_ITEM_TYPE_NAME_EPIC}         | ${WORK_ITEM_TYPE_ENUM_EPIC}
    ${WORK_ITEM_TYPE_NAME_INCIDENT}     | ${WORK_ITEM_TYPE_ENUM_INCIDENT}
    ${WORK_ITEM_TYPE_NAME_ISSUE}        | ${WORK_ITEM_TYPE_ENUM_ISSUE}
    ${WORK_ITEM_TYPE_NAME_KEY_RESULT}   | ${WORK_ITEM_TYPE_ENUM_KEY_RESULT}
    ${WORK_ITEM_TYPE_NAME_OBJECTIVE}    | ${WORK_ITEM_TYPE_ENUM_OBJECTIVE}
    ${WORK_ITEM_TYPE_NAME_REQUIREMENTS} | ${WORK_ITEM_TYPE_ENUM_REQUIREMENTS}
    ${WORK_ITEM_TYPE_NAME_TASK}         | ${WORK_ITEM_TYPE_ENUM_TASK}
    ${WORK_ITEM_TYPE_NAME_TEST_CASE}    | ${WORK_ITEM_TYPE_ENUM_TEST_CASE}
    ${WORK_ITEM_TYPE_NAME_TICKET}       | ${WORK_ITEM_TYPE_ENUM_TICKET}
  `('returns %name when given the enum %enumValue', ({ name, enumValue }) => {
    expect(convertTypeEnumToName(enumValue)).toBe(name);
  });
});

describe('lowercaseWorkItemType', () => {
  it.each`
    workItemType    | result
    ${'Key Result'} | ${'key result'}
    ${'Epic'}       | ${'epic'}
    ${undefined}    | ${''}
    ${null}         | ${''}
  `('returns "$result" when given $workItemType', ({ workItemType, result }) => {
    expect(lowercaseWorkItemType(workItemType)).toBe(result);
  });
});

describe('getDisplayReference', () => {
  it.each`
    workItemFullPath             | workItemReference                           | result
    ${'gitlab-org/project-path'} | ${'gitlab-org/project-path#101'}            | ${'#101'}
    ${'gitlab-org/project-path'} | ${'other-root/gitlab-org/project-path#101'} | ${'other-root/gitlab-org/project-path#101'}
    ${'gitlab-org'}              | ${'gitlab-org/project-path#101'}            | ${'gitlab-org/project-path#101'}
  `(
    'removes namespace from workItemReference if it matches workItemFullPath',
    ({ workItemFullPath, workItemReference, result }) => {
      expect(getDisplayReference(workItemFullPath, workItemReference)).toBe(result);
    },
  );
});

describe('isReference', () => {
  it.each`
    referenceId                                | result
    ${'#101'}                                  | ${true}
    ${'&101'}                                  | ${true}
    ${'101'}                                   | ${false}
    ${'#'}                                     | ${false}
    ${'&'}                                     | ${false}
    ${' &101'}                                 | ${false}
    ${'gitlab-org&101'}                        | ${true}
    ${'gitlab-org/project-path#101'}           | ${true}
    ${'gitlab-org/sub-group/project-path#101'} | ${true}
    ${'gitlab-org'}                            | ${false}
    ${'gitlab-org101#'}                        | ${false}
    ${'gitlab-org101&'}                        | ${false}
    ${'#gitlab-org101'}                        | ${false}
    ${'&gitlab-org101'}                        | ${false}
  `('returns $result for $referenceId', ({ referenceId, result }) => {
    expect(isReference(referenceId)).toBe(result);
  });
});

describe('workItemRoadmapPath', () => {
  it('constructs a path to the roadmap page', () => {
    const path = workItemRoadmapPath('project/group', '2');
    expect(path).toBe(
      '/groups/project/group/-/roadmap?epic_iid=2&layout=MONTHS&timeframe_range_type=CURRENT_YEAR',
    );
  });
});

describe('utils for remembering hidden metadata keys', () => {
  useLocalStorageSpy();

  afterEach(() => {
    localStorage.clear();
  });

  describe('saveHiddenMetadataKeysToLocalStorage', () => {
    it('saves the array value to localStorage as JSON', () => {
      const TEST_KEY = `test-key-${new Date().getTime}`;

      expect(localStorage.getItem(TEST_KEY)).toBe(null);

      saveHiddenMetadataKeysToLocalStorage(TEST_KEY, ['label1', 'label2']);
      expect(localStorage.setItem).toHaveBeenCalled();
      expect(localStorage.getItem(TEST_KEY)).toBe('["label1","label2"]');
    });
  });

  describe('getHiddenMetadataKeysFromLocalStorage', () => {
    it('returns default empty array when there is no value from localStorage and no default value is passed', () => {
      const TEST_KEY = `test-key-${new Date().getTime}`;

      expect(localStorage.getItem(TEST_KEY)).toBe(null);

      const result = getHiddenMetadataKeysFromLocalStorage(TEST_KEY);
      expect(localStorage.getItem).toHaveBeenCalled();
      expect(result).toEqual([]);
    });

    it('returns an empty array when there is no value from localStorage', () => {
      const TEST_KEY = `test-key-${new Date().getTime}`;

      expect(localStorage.getItem(TEST_KEY)).toBe(null);

      const result = getHiddenMetadataKeysFromLocalStorage(TEST_KEY);
      expect(localStorage.getItem).toHaveBeenCalled();
      expect(result).toEqual([]);
    });

    it('returns the parsed array value from localStorage if it exists', () => {
      const TEST_KEY = `test-key-${new Date().getTime}`;
      const TEST_ARRAY = ['labels', 'weight', 'milestone'];

      localStorage.setItem(TEST_KEY, JSON.stringify(TEST_ARRAY));

      const result = getHiddenMetadataKeysFromLocalStorage(TEST_KEY);
      expect(localStorage.getItem).toHaveBeenCalled();
      expect(result).toEqual(TEST_ARRAY);
    });

    it('returns an empty array when stored value is invalid JSON', () => {
      const TEST_KEY = `test-key-${new Date().getTime}`;

      localStorage.setItem(TEST_KEY, 'invalid-json');

      const result = getHiddenMetadataKeysFromLocalStorage(TEST_KEY);
      expect(localStorage.getItem).toHaveBeenCalled();
      expect(result).toEqual([]);
    });
  });
});

describe('`makeDetailPanelItemFullPath`', () => {
  it('returns the items `fullPath` if present', () => {
    const result = makeDetailPanelItemFullPath(
      { fullPath: 'this/should/be/returned' },
      'this/should/not',
    );
    expect(result).toBe('this/should/be/returned');
  });
  it('returns the fallback `fullPath` if `activeItem` does not have a `referencePath`', () => {
    const result = makeDetailPanelItemFullPath({}, 'this/should/be/returned');
    expect(result).toBe('this/should/be/returned');
  });
  describe('when `activeItem` has a `referencePath`', () => {
    it('handles the default `issuableType` of `ISSUE`', () => {
      const result = makeDetailPanelItemFullPath(
        { referencePath: 'this/should/be/returned#100' },
        'this/should/not',
      );
      expect(result).toBe('this/should/be/returned');
    });
    it('handles case where `issuableType` is an `EPIC`', () => {
      const result = makeDetailPanelItemFullPath(
        { referencePath: 'this/should/be/returned&100' },
        'this/should/not',
        TYPE_EPIC,
      );
      expect(result).toBe('this/should/be/returned');
    });
  });
});

describe('`makeDetailPanelUrlParam`', () => {
  it('returns iid, full_path, and id', () => {
    const result = makeDetailPanelUrlParam(
      { id: 'gid://gitlab/Issue/1', iid: '123', fullPath: 'gitlab-org/gitlab' },
      'gitlab-org/gitlab',
    );
    expect(result).toEqual(
      btoa(JSON.stringify({ iid: '123', full_path: 'gitlab-org/gitlab', id: 1 })),
    );
  });
});

describe('`findDetailPanelWorkItem`', () => {
  const items = [
    { id: 'gid://gitlab/WorkItem/1', iid: '1' },
    { id: 'gid://gitlab/WorkItem/2', iid: '2' },
  ];
  const showParam = (id) => btoa(JSON.stringify({ iid: '1', full_path: 'group/project', id }));

  it('returns the matching item merged with fullPath from the param', () => {
    expect(findDetailPanelWorkItem(showParam(2), items, null)).toEqual({
      item: { ...items[1], fullPath: 'group/project' },
      notFound: false,
    });
  });

  it('flags notFound when the referenced item is not in the list', () => {
    expect(findDetailPanelWorkItem(showParam(999), items, null)).toEqual({
      item: null,
      notFound: true,
    });
  });

  it('returns no item and does not flag notFound when the item is already active', () => {
    expect(findDetailPanelWorkItem(showParam(1), items, items[0])).toEqual({
      item: null,
      notFound: false,
    });
  });

  it('returns no item and does not flag notFound when the param has no id', () => {
    const param = btoa(JSON.stringify({ iid: '1', full_path: 'group/project' }));

    expect(findDetailPanelWorkItem(param, items, null)).toEqual({
      item: null,
      notFound: false,
    });
  });

  describe('when the param is not a base64-encoded work item', () => {
    it('returns no item and does not flag notFound', () => {
      expect(findDetailPanelWorkItem('workplan', items, null)).toEqual({
        item: null,
        notFound: false,
      });
    });
  });
});

describe('getNewWorkItemAutoSaveKey', () => {
  let originalWindowLocation;

  beforeEach(() => {
    originalWindowLocation = window.location;
    delete window.location;
    window.location = new URL('https://gitlab.example.com');
  });

  afterEach(() => {
    window.location = originalWindowLocation;
  });

  it('returns autosave key for a new work item', () => {
    const autosaveKey = getNewWorkItemAutoSaveKey({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
      workItemType: 'issue',
    });
    expect(autosaveKey).toBe('new-gitlab-org/gitlab-list-route-issue-draft');
  });

  it.each`
    locationSearch                            | expectedAutosaveKey
    ${'vulnerability_id=1'}                   | ${'new-gitlab-org/gitlab-list-route-vulnerability_id=1-issue-draft'}
    ${'discussion_to_resolve=2'}              | ${'new-gitlab-org/gitlab-list-route-discussion_to_resolve=2-issue-draft'}
    ${'issue[issue_type]=Issue'}              | ${'new-gitlab-org/gitlab-list-route-issue%5Bissue_type%5D=Issue-issue-draft'}
    ${'issuable_template=FeatureIssue'}       | ${'new-gitlab-org/gitlab-list-route-issuable_template=FeatureIssue-issue-draft'}
    ${'discussion_to_resolve=2&state=opened'} | ${'new-gitlab-org/gitlab-list-route-discussion_to_resolve=2-issue-draft'}
  `(
    'returns autosave key with query params $locationSearch',
    ({ locationSearch, expectedAutosaveKey }) => {
      window.location.search = locationSearch;
      const autosaveKey = getNewWorkItemAutoSaveKey({
        fullPath: 'gitlab-org/gitlab',
        context: CREATION_CONTEXT_LIST_ROUTE,
        workItemType: 'issue',
      });

      expect(autosaveKey).toBe(expectedAutosaveKey);
    },
  );

  it('returns autosave key for new related item', () => {
    const autosaveKey = getNewWorkItemAutoSaveKey({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
      workItemType: 'issue',
      relatedItemId: 'gid://gitlab/WorkItem/22',
    });

    expect(autosaveKey).toBe('new-gitlab-org/gitlab-list-route-related-id-22-issue-draft');
  });
});

describe('getNewWorkItemWidgetsAutoSaveKey', () => {
  it('returns autosave key for a new work item', () => {
    const autosaveKey = getNewWorkItemWidgetsAutoSaveKey({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
    });
    expect(autosaveKey).toBe('new-gitlab-org/gitlab-list-route-widgets-draft');
  });

  it('returns autosave key for new related item', () => {
    const autosaveKey = getNewWorkItemWidgetsAutoSaveKey({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
      relatedItemId: 'gid://gitlab/WorkItem/22',
    });

    expect(autosaveKey).toBe('new-gitlab-org/gitlab-list-route-related-id-22-widgets-draft');
  });
});

describe('updateDraftWorkItemType', () => {
  useLocalStorageSpy();

  const workItemWidgetsAutosaveKey = 'autosave/new-gitlab-org/gitlab-list-route-widgets-draft';
  const workItemType = {
    id: 'gid://gitlab/WorkItemType/1',
    name: WORK_ITEM_TYPE_NAME_ISSUE,
    iconName: 'work-item-issue',
  };

  afterEach(() => {
    localStorage.clear();
  });

  it('sets `TYPE` with workItemType to localStorage widgets drafts key when it does not exist', () => {
    updateDraftWorkItemType({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
      workItemType,
    });

    expect(localStorage.setItem).toHaveBeenCalledWith(
      workItemWidgetsAutosaveKey,
      JSON.stringify({ TYPE: workItemType }),
    );
  });

  it('updates `TYPE` with workItemType to localStorage widgets drafts key when it already exists', () => {
    localStorage.setItem(workItemWidgetsAutosaveKey, JSON.stringify({ TITLE: 'Some work item' }));

    updateDraftWorkItemType({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
      workItemType,
    });

    expect(localStorage.setItem).toHaveBeenCalledWith(
      workItemWidgetsAutosaveKey,
      JSON.stringify({ TITLE: 'Some work item', TYPE: workItemType }),
    );
  });

  it('updates `TYPE` with workItemType to localStorage widgets for related item drafts key when it already exists', () => {
    const workItemWidgetsKey =
      'autosave/new-gitlab-org/gitlab-list-route-related-id-22-widgets-draft';
    localStorage.setItem(workItemWidgetsKey, JSON.stringify({ TITLE: 'Some work item' }));

    updateDraftWorkItemType({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
      relatedItemId: 'gid://gitlab/WorkItem/22',
      workItemType,
    });

    expect(localStorage.setItem).toHaveBeenCalledWith(
      workItemWidgetsKey,
      JSON.stringify({ TITLE: 'Some work item', TYPE: workItemType }),
    );
  });
});

describe('getDraftWorkItemType', () => {
  afterEach(() => {
    localStorage.clear();
  });

  it('gets `TYPE` from localStorage widgets draft when it exists', () => {
    localStorage.setItem(
      'autosave/new-gitlab-org/gitlab-list-route-widgets-draft',
      JSON.stringify({ TYPE: 'Issue' }),
    );
    const workItemType = getDraftWorkItemType({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
    });

    expect(workItemType).toBe('Issue');
  });

  it('gets `TYPE` from localStorage widgets for related item draft when it exists', () => {
    localStorage.setItem(
      'autosave/new-gitlab-org/gitlab-list-route-related-id-22-widgets-draft',
      JSON.stringify({ TYPE: 'Issue' }),
    );
    const workItemType = getDraftWorkItemType({
      fullPath: 'gitlab-org/gitlab',
      context: CREATION_CONTEXT_LIST_ROUTE,
      relatedItemId: 'gid://gitlab/WorkItem/22',
    });

    expect(workItemType).toBe('Issue');
  });
});

describe('`getItems`', () => {
  it('returns all children when showClosed flag is on', () => {
    const children = [
      { id: 1, state: STATE_OPEN },
      { id: 2, state: STATE_CLOSED },
    ];
    const result = getItems(true)(children);
    expect(result).toEqual(children);
  });

  it('returns only open children when showClosed flag is off', () => {
    const openChildren = [
      { id: 1, state: STATE_OPEN },
      { id: 2, state: STATE_OPEN },
    ];
    const closedChildren = [{ id: 3, state: STATE_CLOSED }];
    const children = openChildren.concat(closedChildren);
    const result = getItems(false)(children);
    expect(result).toEqual(openChildren);
  });
});

describe('canRouterNav', () => {
  const projectFullPath = 'gitlab-org/gitlab';
  const groupFullPath = 'gitlab-org';
  const projectWebUrl = (fullPath = projectFullPath) => `/${fullPath}/-/issues/1`;
  const groupWebUrl = (fullPath = groupFullPath) => `/groups/${fullPath}/-/epics/1`;
  it.each`
    contextFullPath    | targetWebUrl                                | contextIsGroup | issueAsWorkItem | shouldRouterNav
    ${projectFullPath} | ${projectWebUrl()}                          | ${false}       | ${false}        | ${false}
    ${projectFullPath} | ${projectWebUrl()}                          | ${false}       | ${true}         | ${true}
    ${projectFullPath} | ${projectWebUrl('gitlab-org/gitlab-other')} | ${false}       | ${false}        | ${false}
    ${projectFullPath} | ${projectWebUrl('gitlab-org/gitlab-other')} | ${false}       | ${true}         | ${false}
    ${groupFullPath}   | ${groupWebUrl()}                            | ${true}        | ${false}        | ${true}
    ${groupFullPath}   | ${groupWebUrl()}                            | ${true}        | ${true}         | ${true}
    ${groupFullPath}   | ${groupWebUrl('gitlab-other')}              | ${true}        | ${false}        | ${false}
    ${groupFullPath}   | ${groupWebUrl('gitlab-other')}              | ${true}        | ${true}         | ${false}
  `(
    `returns $shouldRouterNav when fullPath is $contextFullPath, webUrl is $targetWebUrl, isGroup is $contextIsGroup, and issueAsWorkItem is $issueAsWorkItem`,
    ({ contextFullPath, targetWebUrl, contextIsGroup, issueAsWorkItem, shouldRouterNav }) => {
      expect(
        canRouterNav({
          fullPath: contextFullPath,
          webUrl: targetWebUrl,
          isGroup: contextIsGroup,
          issueAsWorkItem,
        }),
      ).toBe(shouldRouterNav);
    },
  );
});

describe('formatSelectOptionForCustomField', () => {
  it('returns object with text and value properties', () => {
    const data = {
      id: 1,
      value: 'test',
    };
    const result = {
      text: 'test',
      value: 1,
    };

    expect(formatSelectOptionForCustomField(data)).toEqual(result);
  });
});

describe('getParentGroupName', () => {
  it('returns parent group name from namespace', () => {
    const namespaceFullName = 'Flightjs / Flight';
    expect(getParentGroupName(namespaceFullName)).toEqual('Flightjs');
  });
});

describe('preserveDetailsState', () => {
  const descriptionHtml = '<details><summary>Test</summary><p>Content</p></details>';
  let element;

  beforeEach(() => {
    element = document.createElement('div');
  });

  it('returns null when there are no open details elements', () => {
    element.innerHTML = '<details><summary>Test</summary><p>Content</p></details>';

    expect(preserveDetailsState(element, descriptionHtml)).toBe(null);
  });

  it('returns null when number of details elements does not match', () => {
    element.innerHTML = '<details open><summary>Test</summary><p>Content</p></details>';
    const newDescriptionHtml =
      '<details><summary>Test</summary><p>Content</p></details><details><summary>Test 2</summary><p>Content 2</p></details>';

    expect(preserveDetailsState(element, newDescriptionHtml)).toBe(null);
  });

  it('preserves open state of details elements', () => {
    element.innerHTML = '<details open><summary>Test</summary><p>Content</p></details>';

    expect(preserveDetailsState(element, descriptionHtml)).toBe(
      '<details open="true"><summary>Test</summary><p>Content</p></details>',
    );
  });

  it('handles multiple details elements', () => {
    element.innerHTML = `
      <details open><summary>Test 1</summary><p>Content 1</p></details>
      <details><summary>Test 2</summary><p>Content 2</p></details>
    `;
    const newDescriptionHtml = `
      <details><summary>Test 1</summary><p>Content 1</p></details>
      <details><summary>Test 2</summary><p>Content 2</p></details>
    `;

    expect(preserveDetailsState(element, newDescriptionHtml)).toBe(`
      <details open="true"><summary>Test 1</summary><p>Content 1</p></details>
      <details><summary>Test 2</summary><p>Content 2</p></details>
    `);
  });
});

describe('createBranch', () => {
  it('returns a "create branch" path when given fullPath', () => {
    expect(createBranchMRApiPathHelper.createBranch('myGroup/myProject')).toBe(
      '/myGroup/myProject/-/branches',
    );
  });
});

describe('createMR', () => {
  const fullPath = 'gitlab-org/gitlab';
  const workItemIID = '12';
  const sourceBranch = '12-fix';
  const targetBranch = 'main';

  it('returns MR url with target branch', () => {
    const path = createBranchMRApiPathHelper.createMR({
      fullPath,
      workItemIid: workItemIID,
      sourceBranch,
      targetBranch,
    });
    expect(path).toBe(
      '/gitlab-org/gitlab/-/merge_requests/new?merge_request%5Bissue_iid%5D=12&merge_request%5Bsource_branch%5D=12-fix&merge_request%5Btarget_branch%5D=main',
    );
  });

  it('returns MR url without target branch', () => {
    const path = createBranchMRApiPathHelper.createMR({
      fullPath,
      workItemIid: workItemIID,
      sourceBranch,
    });
    expect(path).toBe(
      '/gitlab-org/gitlab/-/merge_requests/new?merge_request%5Bissue_iid%5D=12&merge_request%5Bsource_branch%5D=12-fix',
    );
  });

  it('returns MR url with relative url', () => {
    gon.relative_url_root = '/foobar';

    const path = createBranchMRApiPathHelper.createMR({
      fullPath,
      workItemIid: workItemIID,
      sourceBranch,
    });
    expect(path).toBe(
      '/foobar/gitlab-org/gitlab/-/merge_requests/new?merge_request%5Bissue_iid%5D=12&merge_request%5Bsource_branch%5D=12-fix',
    );
  });

  it('returns url with encoded branch names', () => {
    const path = createBranchMRApiPathHelper.createMR({
      fullPath,
      workItemIid: workItemIID,
      sourceBranch: 'source-branch#1',
      targetBranch: 'target-branch#1',
    });

    expect(path).toBe(
      '/gitlab-org/gitlab/-/merge_requests/new?merge_request%5Bissue_iid%5D=12&merge_request%5Bsource_branch%5D=source-branch%231&merge_request%5Btarget_branch%5D=target-branch%231',
    );
  });
});

describe('getLastUsedWorkItemTypeIdForNamespace', () => {
  useLocalStorageSpy();

  afterEach(() => {
    localStorage.clear();
  });

  it('calls getItem on localStorage with the correct key', () => {
    getLastUsedWorkItemTypeIdForNamespace('gitlab-org/gitlab');
    expect(localStorage.getItem).toHaveBeenCalledWith('freq-wi-type:gitlab-org/gitlab');
  });
});

describe('setLastUsedWorkItemTypeIdForNamespace', () => {
  useLocalStorageSpy();

  afterEach(() => {
    localStorage.clear();
  });

  it('calls setItem on localStorage with the correct key and value', () => {
    setLastUsedWorkItemTypeIdForNamespace('gid://gitlab/WorkItems::Type/1', 'gitlab-org/gitlab');
    expect(localStorage.setItem).toHaveBeenCalledWith(
      'freq-wi-type:gitlab-org/gitlab',
      'gid://gitlab/WorkItems::Type/1',
    );
  });
});

describe('combineWorkItemLists', () => {
  describe('with the features data', () => {
    const baseSlimList = [
      { id: 1, features: { description: { description: 'This work item description' } } },
      { id: 2, features: { assignees: { assignees: { nodes: [{ name: 'John' }] } } } },
    ];
    const baseFullList = [
      {
        id: 1,
        features: { description: { description: 'This work item description full version' } },
      },
      { id: 2, features: { assignees: { assignees: [{ name: 'John Jack' }] } } },
      { id: 3, features: { labels: { labels: { title: 'workflow' } } } },
    ];

    describe('when slim list is empty', () => {
      describe('and full list is empty', () => {
        it('returns empty array', () => {
          expect(combineWorkItemLists([], [])).toEqual([]);
        });
      });

      describe('and full list has items', () => {
        it('returns the full list', () => {
          expect(combineWorkItemLists([], baseFullList)).toEqual(baseFullList);
        });
      });

      describe('when both lists have items', () => {
        describe('and slim list features have fewer keys than full list features', () => {
          it('prioritizes full list features', () => {
            const fullList = [
              { ...baseFullList[0], features: { ...baseFullList[0].features, otherProp: true } },
              baseFullList[1],
              baseFullList[2],
            ];
            const result = combineWorkItemLists(baseSlimList, fullList);
            expect(result).toEqual(fullList);
          });
        });

        describe('and slim list has items not in full list', () => {
          it('includes items from both lists', () => {
            const slimList = [
              ...baseSlimList,
              { id: 4, features: { labels: { labels: { title: 'slim workflow' } } } },
            ];
            const fullList = [
              baseFullList[0],
              baseFullList[1],
              { id: 3, features: { milestone: { title: 'full milestone' } } },
            ];
            const result = combineWorkItemLists(slimList, fullList);
            expect(result).toEqual(fullList);
          });
        });
      });
    });

    describe('when the full list omits scalars the slim list provides', () => {
      it('keeps the slim list scalars on the merged item', () => {
        const slimList = [{ id: 1, title: 'Slim title', webUrl: '/slim', features: {} }];
        const fullList = [{ id: 1, userDiscussionsCount: 3, features: {} }];

        expect(combineWorkItemLists(slimList, fullList)).toEqual([
          { id: 1, title: 'Slim title', webUrl: '/slim', userDiscussionsCount: 3, features: {} },
        ]);
      });
    });

    describe('when a feature is null in full list', () => {
      it('preserves null instead of converting to empty object', () => {
        const slimList = [
          { id: 1, title: 'Incident', features: { labels: { labels: { nodes: [] } } } },
        ];
        const fullList = [
          {
            id: 1,
            features: {
              labels: { labels: { nodes: [] } },
              weight: null,
              healthStatus: null,
            },
          },
        ];

        const result = combineWorkItemLists(slimList, fullList);

        expect(result).toEqual([
          {
            id: 1,
            title: 'Incident',
            features: {
              labels: { labels: { nodes: [] } },
              weight: null,
              healthStatus: null,
            },
          },
        ]);
        expect(result[0].features.weight).toBeNull();
        expect(result[0].features.healthStatus).toBeNull();
      });
    });
  });
});

describe('isCurrentViewWorkItem', () => {
  const createDescriptionWrapper = (issuableType) => {
    const wrapper = document.createElement('div');
    wrapper.classList.add('js-issuable-description-wrapper');
    if (issuableType) {
      wrapper.dataset.issuableType = issuableType;
    }
    document.body.appendChild(wrapper);
    return wrapper;
  };

  afterEach(() => {
    document.body.dataset.page = '';
    document.querySelector('.js-issuable-description-wrapper')?.remove();
  });

  it.each`
    issuableType  | description
    ${'incident'} | ${'Incident'}
    ${'ticket'}   | ${'Ticket'}
  `('returns false for $description pages', ({ issuableType }) => {
    document.body.dataset.page = 'projects:issues:show';
    createDescriptionWrapper(issuableType);

    expect(isCurrentViewWorkItem()).toBe(false);
  });

  it.each`
    page                           | description
    ${'groups:work_items:index'}   | ${'Group Work Items list'}
    ${'groups:epics:index'}        | ${'Group Epics list'}
    ${'groups:issues'}             | ${'Group Issues'}
    ${'groups:boards:index'}       | ${'Group Issues Board'}
    ${'groups:epic_boards:index'}  | ${'Group Epics Board'}
    ${'projects:work_items:index'} | ${'Project Work Items list'}
    ${'projects:issues:index'}     | ${'Project Issues list'}
    ${'projects:boards:index'}     | ${'Project Issues Board'}
    ${'groups:work_items:show'}    | ${'Group Work Item detail'}
    ${'groups:epics:show'}         | ${'Group Epic detail'}
    ${'projects:work_items:show'}  | ${'Project Work Item detail'}
    ${'projects:issues:show'}      | ${'Project Issue detail'}
  `('returns true for $description view ($page)', ({ page }) => {
    document.body.dataset.page = page;

    expect(isCurrentViewWorkItem()).toBe(true);
  });

  it.each`
    page                              | description
    ${'projects:merge_requests:show'} | ${'Merge Request detail'}
    ${'projects:pipelines:show'}      | ${'Pipeline detail'}
    ${''}                             | ${'empty page'}
  `('returns false for $description view ($page)', ({ page }) => {
    document.body.dataset.page = page;

    expect(isCurrentViewWorkItem()).toBe(false);
  });
});

describe('findAssigneesWidget', () => {
  const featuresAssignees = { allowsMultipleAssignees: true, assignees: { nodes: [] } };

  it('returns features.assignees when present', () => {
    const workItem = {
      features: { assignees: featuresAssignees },
    };

    expect(findAssigneesWidget(workItem)).toBe(featuresAssignees);
  });

  it('returns undefined when neither exists', () => {
    expect(findAssigneesWidget({})).toBeUndefined();
  });
});

describe('getMetadataWidgetsFromWorkItem', () => {
  const labelsWidget = { type: WIDGET_TYPE_LABELS, labels: { nodes: [{ id: 'widgets-label' }] } };
  const weightWidget = { type: WIDGET_TYPE_WEIGHT, weight: 1 };
  const milestoneWidget = { type: WIDGET_TYPE_MILESTONE, milestone: { id: 'milestone-1' } };

  describe('when a widget is only available on `widgets`', () => {
    it('builds the map from `widgets`', () => {
      const workItem = { widgets: [labelsWidget, milestoneWidget] };

      expect(getMetadataWidgetsFromWorkItem(workItem)).toEqual({
        [WIDGET_TYPE_LABELS]: labelsWidget,
        [WIDGET_TYPE_MILESTONE]: milestoneWidget,
      });
    });
  });

  describe('when a widget is available on `features`', () => {
    it('reads the widget from `features` instead of `widgets`', () => {
      const featuresLabels = { labels: { nodes: [{ id: 'features-label' }] } };
      const featuresWeight = { weight: 5 };
      const workItem = {
        widgets: [labelsWidget, weightWidget, milestoneWidget],
        features: { labels: featuresLabels, weight: featuresWeight },
      };

      expect(getMetadataWidgetsFromWorkItem(workItem)).toEqual({
        [WIDGET_TYPE_LABELS]: { type: WIDGET_TYPE_LABELS, ...featuresLabels },
        [WIDGET_TYPE_WEIGHT]: { type: WIDGET_TYPE_WEIGHT, ...featuresWeight },
        [WIDGET_TYPE_MILESTONE]: milestoneWidget,
      });
    });

    it('reads the hierarchy widget from `features`', () => {
      const featuresHierarchy = { parent: { id: 'parent-1' }, rolledUpCountsByType: [] };
      const workItem = { features: { hierarchy: featuresHierarchy } };

      expect(getMetadataWidgetsFromWorkItem(workItem)).toEqual({
        [WIDGET_TYPE_HIERARCHY]: { type: WIDGET_TYPE_HIERARCHY, ...featuresHierarchy },
      });
    });

    it('ignores feature values that are absent or empty', () => {
      const workItem = {
        widgets: [weightWidget, labelsWidget],
        features: { weight: null, healthStatus: undefined, labels: {} },
      };

      expect(getMetadataWidgetsFromWorkItem(workItem)).toEqual({
        [WIDGET_TYPE_WEIGHT]: weightWidget,
        // an empty `features.labels` must not clobber the widgets value
        [WIDGET_TYPE_LABELS]: labelsWidget,
      });
    });
  });

  describe('when the work item has no widgets or features', () => {
    it('returns an empty map', () => {
      expect(getMetadataWidgetsFromWorkItem(undefined)).toEqual({});
      expect(getMetadataWidgetsFromWorkItem({})).toEqual({});
    });
  });
});

describe('getSortValue', () => {
  const mockItem = {
    createdAt: '2024-01-15T10:00:00Z',
    updatedAt: '2024-02-20T14:30:00Z',
    closedAt: '2024-03-10T16:45:00Z',
    title: 'Test Work Item',
    features: {
      awardEmoji: { upvotes: 5 },
      startAndDueDate: { dueDate: '2024-05-15', startDate: '2024-05-01' },
      milestone: { milestone: { dueDate: '2024-04-30', startDate: '2024-04-01' } },
    },
  };
  const withFeature = (key, value) => (item) => ({
    ...item,
    features: { ...item.features, [key]: value },
  });

  it.each`
    sortKey               | itemModifier                                          | expectedResult
    ${CREATED_ASC}        | ${(item) => item}                                     | ${new Date('2024-01-15T10:00:00Z')}
    ${CREATED_DESC}       | ${(item) => item}                                     | ${new Date('2024-01-15T10:00:00Z')}
    ${UPDATED_ASC}        | ${(item) => item}                                     | ${new Date('2024-02-20T14:30:00Z')}
    ${UPDATED_DESC}       | ${(item) => item}                                     | ${new Date('2024-02-20T14:30:00Z')}
    ${CLOSED_AT_ASC}      | ${(item) => item}                                     | ${new Date('2024-03-10T16:45:00Z')}
    ${CLOSED_AT_DESC}     | ${(item) => item}                                     | ${new Date('2024-03-10T16:45:00Z')}
    ${MILESTONE_DUE_ASC}  | ${(item) => item}                                     | ${new Date('2024-04-30')}
    ${MILESTONE_DUE_DESC} | ${(item) => item}                                     | ${new Date('2024-04-30')}
    ${DUE_DATE_ASC}       | ${(item) => item}                                     | ${new Date('2024-05-15')}
    ${DUE_DATE_DESC}      | ${(item) => item}                                     | ${new Date('2024-05-15')}
    ${START_DATE_ASC}     | ${(item) => item}                                     | ${new Date('2024-05-01')}
    ${START_DATE_DESC}    | ${(item) => item}                                     | ${new Date('2024-05-01')}
    ${TITLE_ASC}          | ${(item) => item}                                     | ${'test work item'}
    ${TITLE_DESC}         | ${(item) => item}                                     | ${'test work item'}
    ${TITLE_ASC}          | ${(item) => ({ ...item, title: 'MiXeD CaSe TiTlE' })} | ${'mixed case title'}
    ${POPULARITY_ASC}     | ${(item) => item}                                     | ${5}
    ${POPULARITY_DESC}    | ${(item) => item}                                     | ${5}
  `('returns $expectedResult for $sortKey', ({ sortKey, itemModifier, expectedResult }) => {
    const item = itemModifier(mockItem);
    const result = getSortValue(item, sortKey);
    expect(result).toEqual(expectedResult);
  });

  it.each`
    sortKey               | itemModifier                                           | expectedResult
    ${CLOSED_AT_ASC}      | ${(item) => ({ ...item, closedAt: null })}             | ${null}
    ${CLOSED_AT_DESC}     | ${(item) => ({ ...item, closedAt: null })}             | ${null}
    ${TITLE_ASC}          | ${(item) => ({ ...item, title: null })}                | ${''}
    ${TITLE_DESC}         | ${(item) => ({ ...item, title: null })}                | ${''}
    ${POPULARITY_DESC}    | ${withFeature('awardEmoji', { upvotes: undefined })}   | ${null}
    ${MILESTONE_DUE_ASC}  | ${withFeature('milestone', null)}                      | ${null}
    ${MILESTONE_DUE_DESC} | ${withFeature('milestone', null)}                      | ${null}
    ${MILESTONE_DUE_ASC}  | ${withFeature('milestone', { milestone: {} })}         | ${null}
    ${MILESTONE_DUE_DESC} | ${withFeature('milestone', { milestone: {} })}         | ${null}
    ${DUE_DATE_ASC}       | ${withFeature('startAndDueDate', null)}                | ${null}
    ${DUE_DATE_DESC}      | ${withFeature('startAndDueDate', { dueDate: null })}   | ${null}
    ${START_DATE_ASC}     | ${withFeature('startAndDueDate', null)}                | ${null}
    ${START_DATE_DESC}    | ${withFeature('startAndDueDate', { startDate: null })} | ${null}
    ${'UNKNOWN_SORT_KEY'} | ${(item) => item}                                      | ${null}
    ${''}                 | ${(item) => item}                                      | ${null}
  `('returns null for $sortKey', ({ sortKey, itemModifier, expectedResult }) => {
    const item = itemModifier(mockItem);
    const result = getSortValue(item, sortKey);
    expect(result).toEqual(expectedResult);
  });
});

describe('findMilestoneWidget', () => {
  const featuresMilestone = { milestone: { id: 'gid://m/2' } };

  it('returns features.milestone when present', () => {
    const workItem = {
      features: { milestone: featuresMilestone },
    };

    expect(findMilestoneWidget(workItem)).toBe(featuresMilestone);
  });

  it('returns undefined when neither exists', () => {
    expect(findMilestoneWidget({})).toBeUndefined();
  });
});

describe('findHierarchyWidget', () => {
  const featuresHierarchy = { hasChildren: false };

  it('returns features.hierarchy when present', () => {
    const workItem = {
      features: { hierarchy: featuresHierarchy },
    };

    expect(findHierarchyWidget(workItem)).toBe(featuresHierarchy);
  });

  it('returns undefined when neither exists', () => {
    expect(findHierarchyWidget({})).toBeUndefined();
  });
});

describe('findAwardEmojiWidget', () => {
  const featuresAwardEmoji = { upvotes: 0, downvotes: 0, awardEmoji: { nodes: [] } };

  it('returns features.awardEmoji when present', () => {
    const workItem = {
      features: { awardEmoji: featuresAwardEmoji },
    };

    expect(findAwardEmojiWidget(workItem)).toBe(featuresAwardEmoji);
  });

  it('returns undefined when neither exists', () => {
    expect(findAwardEmojiWidget({})).toBeUndefined();
  });
});

describe('findNotificationsWidget', () => {
  const featuresNotifications = { subscribed: true };

  it('returns features.notifications when present', () => {
    const workItem = {
      features: { notifications: featuresNotifications },
    };

    expect(findNotificationsWidget(workItem)).toBe(featuresNotifications);
  });

  it('returns undefined when neither exists', () => {
    expect(findNotificationsWidget({})).toBeUndefined();
  });
});

describe('findNotesWidget', () => {
  describe('when features.notes is present', () => {
    const featuresNotes = { discussionLocked: true };
    let workItem;

    beforeEach(() => {
      workItem = {
        features: { notes: featuresNotes },
      };
    });

    it('returns features.notes', () => {
      expect(findNotesWidget(workItem)).toBe(featuresNotes);
    });
  });

  describe('when neither exists', () => {
    it('returns undefined', () => {
      expect(findNotesWidget({})).toBeUndefined();
    });
  });
});

describe('findParticipantsWidget', () => {
  const featuresParticipants = {
    participants: { count: 2, nodes: [{ id: 'gid://gitlab/User/2' }] },
  };

  describe('when features.participants is present', () => {
    let workItem;

    beforeEach(() => {
      workItem = {
        features: { participants: featuresParticipants },
      };
    });

    it('returns features.participants', () => {
      expect(findParticipantsWidget(workItem)).toBe(featuresParticipants);
    });
  });

  describe('when neither features nor widget is present', () => {
    it('returns undefined', () => {
      expect(findParticipantsWidget({})).toBeUndefined();
    });
  });
});

describe('findErrorTrackingWidget', () => {
  const featuresErrorTracking = { identifier: '1', stackTrace: { nodes: [] }, status: 'SUCCESS' };

  it('returns features.errorTracking when present', () => {
    const workItem = {
      features: { errorTracking: featuresErrorTracking },
    };

    expect(findErrorTrackingWidget(workItem)).toBe(featuresErrorTracking);
  });

  it('returns undefined when neither exists', () => {
    expect(findErrorTrackingWidget({})).toBeUndefined();
  });
});

describe('findCrmContactsWidget', () => {
  const featuresCrmContacts = { contactsAvailable: true, contacts: { nodes: [] } };

  it('returns features.crmContacts when present', () => {
    const workItem = {
      features: { crmContacts: featuresCrmContacts },
    };

    expect(findCrmContactsWidget(workItem)).toBe(featuresCrmContacts);
  });

  it('returns undefined when neither exists', () => {
    expect(findCrmContactsWidget({})).toBeUndefined();
  });
});

describe('findCurrentUserTodosWidget', () => {
  const featuresCurrentUserTodos = {
    currentUserTodos: { nodes: [{ id: 'gid://gitlab/Todo/2', state: 'pending' }] },
  };

  describe('when features.currentUserTodos is present', () => {
    let workItem;

    beforeEach(() => {
      workItem = {
        features: { currentUserTodos: featuresCurrentUserTodos },
      };
    });

    it('returns features.currentUserTodos', () => {
      expect(findCurrentUserTodosWidget(workItem)).toBe(featuresCurrentUserTodos);
    });
  });

  describe('when neither features nor widget is present', () => {
    it('returns undefined', () => {
      expect(findCurrentUserTodosWidget({})).toBeUndefined();
    });
  });
});

describe('findLinkedResourcesWidget', () => {
  const featuresLinkedResources = { linkedResources: { nodes: [] } };

  it('returns features.linkedResources when present', () => {
    const workItem = {
      features: { linkedResources: featuresLinkedResources },
    };

    expect(findLinkedResourcesWidget(workItem)).toBe(featuresLinkedResources);
  });

  it('returns undefined when neither exists', () => {
    expect(findLinkedResourcesWidget({})).toBeUndefined();
  });
});

describe('findLinkedItemsWidget', () => {
  const featuresLinkedItems = {
    linkedItems: { nodes: [{ linkId: 'gid://gitlab/IssueLink/2', linkType: 'relates_to' }] },
  };

  it('returns features.linkedItems when present', () => {
    const workItem = {
      features: { linkedItems: featuresLinkedItems },
    };

    expect(findLinkedItemsWidget(workItem)).toBe(featuresLinkedItems);
  });

  it('falls back to the linked items widget that carries the blocked counts', () => {
    const linkedItemsWidget = {
      type: WIDGET_TYPE_LINKED_ITEMS,
      blockedByCount: 1,
      blockingCount: 0,
    };

    expect(findLinkedItemsWidget({ widgets: [linkedItemsWidget] })).toBe(linkedItemsWidget);
  });

  it('returns undefined when neither exists', () => {
    expect(findLinkedItemsWidget({})).toBeUndefined();
  });
});

describe('findStartAndDueDateWidget', () => {
  const featuresStartAndDueDate = { startDate: '2024-02-01', dueDate: '2024-02-28' };

  it('returns features.startAndDueDate when present', () => {
    const workItem = {
      features: { startAndDueDate: featuresStartAndDueDate },
    };

    expect(findStartAndDueDateWidget(workItem)).toBe(featuresStartAndDueDate);
  });

  it('returns undefined when neither exists', () => {
    expect(findStartAndDueDateWidget({})).toBeUndefined();
  });
});

describe('findLabelsWidget', () => {
  const featuresLabels = {
    allowsScopedLabels: true,
    labels: { nodes: [{ id: 'gid://gitlab/Label/2', title: 'feature' }] },
  };

  it('returns features.labels when present', () => {
    const workItem = {
      features: { labels: featuresLabels },
    };

    expect(findLabelsWidget(workItem)).toBe(featuresLabels);
  });

  it('returns undefined when neither exists', () => {
    expect(findLabelsWidget({})).toBeUndefined();
  });
});

describe('findHealthStatusWidget', () => {
  const featuresHealthStatus = {
    healthStatus: 'atRisk',
    rolledUpHealthStatus: [],
  };

  it('returns features.healthStatus when present', () => {
    const workItem = {
      features: { healthStatus: featuresHealthStatus },
    };

    expect(findHealthStatusWidget(workItem)).toBe(featuresHealthStatus);
  });

  it('returns undefined when neither exists', () => {
    expect(findHealthStatusWidget({})).toBeUndefined();
  });
});

describe('findWeightWidget', () => {
  const featuresWeight = {
    weight: 8,
    rolledUpWeight: 10,
    rolledUpCompletedWeight: 4,
  };

  it('returns features.weight when present', () => {
    const workItem = {
      features: { weight: featuresWeight },
    };

    expect(findWeightWidget(workItem)).toBe(featuresWeight);
  });

  it('returns undefined when neither exists', () => {
    expect(findWeightWidget({})).toBeUndefined();
  });
});

describe('findEmailParticipantsWidget', () => {
  const featuresEmailParticipants = {
    type: 'EMAIL_PARTICIPANTS',
    emailParticipants: { nodes: [{ email: 'feature@example.com' }] },
  };

  describe('when both features and widgets are present', () => {
    let workItem;

    beforeEach(() => {
      workItem = {
        features: { emailParticipants: featuresEmailParticipants },
      };
    });

    it('returns features.emailParticipants', () => {
      expect(findEmailParticipantsWidget(workItem)).toBe(featuresEmailParticipants);
    });
  });

  describe('when neither features nor widgets has the widget', () => {
    let workItem;

    beforeEach(() => {
      workItem = { widgets: [] };
    });

    it('returns undefined', () => {
      expect(findEmailParticipantsWidget(workItem)).toBeUndefined();
    });
  });
});

describe('findWidgetByType', () => {
  const featuresDates = { dueDate: '2026-11-01', startDate: null };

  it.each`
    type                    | featureKey
    ${'MILESTONE'}          | ${'milestone'}
    ${'START_AND_DUE_DATE'} | ${'startAndDueDate'}
    ${'AGENT_PLAN'}         | ${'agentPlan'}
  `('reads $type from features.$featureKey', ({ type, featureKey }) => {
    const feature = { __typename: 'WorkItemWidget' };

    expect(findWidgetByType({ features: { [featureKey]: feature }, widgets: [] }, type)).toBe(
      feature,
    );
  });

  describe('when both features and widgets are present', () => {
    let workItem;

    beforeEach(() => {
      workItem = {
        features: { startAndDueDate: featuresDates },
      };
    });

    it('returns the widget from features', () => {
      expect(findWidgetByType(workItem, 'START_AND_DUE_DATE')).toBe(featuresDates);
    });
  });

  describe('when neither features nor widgets has the widget', () => {
    let workItem;

    beforeEach(() => {
      workItem = { features: {}, widgets: [] };
    });

    it('returns undefined', () => {
      expect(findWidgetByType(workItem, 'MILESTONE')).toBeUndefined();
    });
  });
});

describe('findStatusWidget', () => {
  const featuresStatus = {
    status: {
      id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/2',
      name: 'In progress',
    },
  };

  describe('when features.status is present', () => {
    let workItem;

    beforeEach(() => {
      workItem = {
        features: { status: featuresStatus },
      };
    });

    it('returns features.status', () => {
      expect(findStatusWidget(workItem)).toBe(featuresStatus);
    });
  });

  describe('when neither features nor widget is present', () => {
    it('returns undefined', () => {
      expect(findStatusWidget({})).toBeUndefined();
    });
  });
});

describe('findCustomFieldsWidget', () => {
  const featuresCustomFields = {
    customFieldValues: [{ customField: { id: '1-number' }, value: 5 }],
  };

  describe('when features.customFields is present', () => {
    let workItem;

    beforeEach(() => {
      workItem = {
        features: { customFields: featuresCustomFields },
      };
    });

    it('returns features.customFields', () => {
      expect(findCustomFieldsWidget(workItem)).toBe(featuresCustomFields);
    });
  });

  describe('when neither features nor widget is present', () => {
    it('returns undefined', () => {
      expect(findCustomFieldsWidget({})).toBeUndefined();
    });
  });
});

describe('findIterationWidget', () => {
  const featuresIteration = {
    iteration: { id: 'gid://gitlab/Iteration/2' },
  };

  it('returns features.iteration when present', () => {
    const workItem = {
      features: { iteration: featuresIteration },
    };

    expect(findIterationWidget(workItem)).toBe(featuresIteration);
  });

  it('returns undefined when neither exists', () => {
    expect(findIterationWidget({})).toBeUndefined();
  });
});

describe('findColorWidget', () => {
  const featuresColor = {
    color: '#e24329',
    textColor: '#FFFFFF',
  };

  it('returns features.color when present', () => {
    const workItem = {
      features: { color: featuresColor },
    };

    expect(findColorWidget(workItem)).toBe(featuresColor);
  });

  it('returns undefined when neither exists', () => {
    expect(findColorWidget({})).toBeUndefined();
  });
});

describe('findProgressWidget', () => {
  const featuresProgress = {
    progress: 70,
    updatedAt: '2024-02-01T00:00:00Z',
  };

  it('returns features.progress when present', () => {
    const workItem = {
      features: { progress: featuresProgress },
    };

    expect(findProgressWidget(workItem)).toBe(featuresProgress);
  });

  it('returns undefined when neither exists', () => {
    expect(findProgressWidget({})).toBeUndefined();
  });
});

describe('findRequesterWidget', () => {
  const featuresRequester = {
    email: 'features-requester@example.com',
  };

  it('returns features.requester when present', () => {
    const workItem = { features: { requester: featuresRequester } };

    expect(findRequesterWidget(workItem)).toBe(featuresRequester);
  });

  it('returns undefined when it does not exist', () => {
    expect(findRequesterWidget({})).toBeUndefined();
  });
});

describe('findDescriptionWidget', () => {
  const featuresDescription = {
    description: 'From features',
  };

  describe('when both features and widgets are present', () => {
    let workItem;

    beforeEach(() => {
      workItem = {
        features: { description: featuresDescription },
      };
    });

    it('returns features.description', () => {
      expect(findDescriptionWidget(workItem)).toBe(featuresDescription);
    });
  });

  describe('when neither features nor widgets has the widget', () => {
    let workItem;

    beforeEach(() => {
      workItem = { widgets: [] };
    });

    it('returns undefined', () => {
      expect(findDescriptionWidget(workItem)).toBeUndefined();
    });
  });
});

describe('findDesignsWidget', () => {
  const featuresDesigns = {
    designCollection: { copyState: 'IN_PROGRESS' },
  };

  it('returns features.designs when present', () => {
    const workItem = {
      features: { designs: featuresDesigns },
    };

    expect(findDesignsWidget(workItem)).toBe(featuresDesigns);
  });

  it('returns undefined when neither exists', () => {
    expect(findDesignsWidget({})).toBeUndefined();
  });
});

describe('findDevelopmentWidget', () => {
  const featuresDevelopment = {
    willAutoCloseByMergeRequest: true,
    closingMergeRequests: { count: 1, nodes: [] },
  };

  it('returns features.development when present', () => {
    const workItem = {
      features: { development: featuresDevelopment },
    };

    expect(findDevelopmentWidget(workItem)).toBe(featuresDevelopment);
  });

  it('returns undefined when neither exists', () => {
    expect(findDevelopmentWidget({})).toBeUndefined();
  });
});

describe('findTimeTrackingWidget', () => {
  const featuresTimeTracking = {
    timeEstimate: 3600,
    humanReadableAttributes: { timeEstimate: '1h' },
    timelogs: { nodes: [] },
    totalTimeSpent: 1800,
  };

  it('returns features.timeTracking when present', () => {
    const workItem = {
      features: { timeTracking: featuresTimeTracking },
    };

    expect(findTimeTrackingWidget(workItem)).toBe(featuresTimeTracking);
  });

  it('returns undefined when neither exists', () => {
    expect(findTimeTrackingWidget({})).toBeUndefined();
  });
});

describe('findVulnerabilitiesWidget', () => {
  const featuresVulnerabilities = {
    relatedVulnerabilities: { nodes: [], count: 3 },
  };

  it('returns features.vulnerabilities when present', () => {
    const workItem = {
      features: { vulnerabilities: featuresVulnerabilities },
    };

    expect(findVulnerabilitiesWidget(workItem)).toBe(featuresVulnerabilities);
  });

  it('returns undefined when neither exists', () => {
    expect(findVulnerabilitiesWidget({})).toBeUndefined();
  });
});

describe('findBlockerLinkedItems', () => {
  const featuresNodes = [{ linkId: 'gid://gitlab/IssueLink/2', linkType: 'is_blocked_by' }];
  it('returns features.linkedItems.linkedItems.nodes when present', () => {
    const workItem = {
      features: { linkedItems: { linkedItems: { nodes: featuresNodes } } },
    };

    expect(findBlockerLinkedItems(workItem)).toBe(featuresNodes);
  });

  it('returns undefined when neither exists', () => {
    expect(findBlockerLinkedItems({})).toBeUndefined();
  });
});

describe('findOpenChildItemsCountsByType', () => {
  const featuresCounts = [
    { countsByState: { opened: 2, all: 2, closed: 0 }, workItemType: { name: 'Issue' } },
  ];
  it('returns features.hierarchy.rolledUpCountsByType when present', () => {
    const workItem = {
      features: { hierarchy: { rolledUpCountsByType: featuresCounts } },
    };

    expect(findOpenChildItemsCountsByType(workItem)).toBe(featuresCounts);
  });

  it('returns undefined when neither exists', () => {
    expect(findOpenChildItemsCountsByType({})).toBeUndefined();
  });
});

describe('getRequestedPanel', () => {
  describe('when the show param names a panel', () => {
    it('returns the panel key', () => {
      setWindowLocation('?show=decision-log');

      expect(getRequestedPanel()).toBe('decision-log');
    });
  });

  describe('when the show param is absent', () => {
    it('returns undefined', () => {
      setWindowLocation('/');

      expect(getRequestedPanel()).toBeUndefined();
    });
  });
});
