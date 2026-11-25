import getStateKey from '~/vue_merge_request_widget/stores/get_state_key';

describe('getStateKey', () => {
  it('should return proper state name', () => {
    const context = {
      mergeStatus: 'checked',
      autoMergeEnabled: false,
      canMerge: true,
      onlyAllowMergeIfPipelineSucceeds: false,
      isPipelineFailed: false,
      hasMergeableDiscussionsState: false,
      isPipelineBlocked: false,
      canBeMerged: false,
      projectArchived: false,
      branchMissing: false,
      commitsCount: 2,
      hasConflicts: false,
      draft: false,
      mergeabilityChecks: [],
    };
    const bound = getStateKey.bind(context);

    expect(bound()).toEqual('readyToMerge');

    context.canMerge = true;
    context.isSHAMismatch = true;

    expect(bound()).toEqual('shaMismatch');

    context.commitsCount = 0;

    expect(bound()).toEqual('nothingToMerge');

    context.commitsCount = 1;
    context.branchMissing = true;

    expect(bound()).toEqual('missingBranch');

    context.projectArchived = true;

    expect(bound()).toEqual('archived');
  });

  const createContext = (context) => ({
    commitsCount: 2,
    canMerge: true,
    autoMergeEnabled: false,
    preferredAutoMergeStrategy: null,
    mergeabilityChecks: [],
    ...context,
  });

  it.each`
    preparing | commitsCount | expected
    ${true}   | ${0}         | ${'preparing'}
    ${true}   | ${2}         | ${'preparing'}
    ${false}  | ${0}         | ${'nothingToMerge'}
  `(
    'returns $expected when preparing is $preparing and there are $commitsCount commits',
    ({ preparing, commitsCount, expected }) => {
      expect(getStateKey.call(createContext({ preparing, commitsCount }))).toBe(expected);
    },
  );

  describe('mergeability checks', () => {
    it.each`
      description             | mergeabilityChecks                                      | expected
      ${'are not loaded'}     | ${null}                                                 | ${null}
      ${'are still checking'} | ${[{ identifier: 'CI_MUST_PASS', status: 'CHECKING' }]} | ${null}
      ${'have a failure'}     | ${[{ identifier: 'DRAFT_STATUS', status: 'FAILED' }]}   | ${'mergeChecksFailed'}
    `('returns $expected when the checks $description', ({ mergeabilityChecks, expected }) => {
      expect(getStateKey.call(createContext({ mergeabilityChecks }))).toBe(expected);
    });

    it('returns readyToMerge when a check fails but an auto-merge strategy is available', () => {
      const context = createContext({
        preferredAutoMergeStrategy: 'merge_when_checks_pass',
        mergeabilityChecks: [{ identifier: 'CI_MUST_PASS', status: 'FAILED' }],
      });

      expect(getStateKey.call(context)).toBe('readyToMerge');
    });

    it('returns mergeChecksFailed when a check fails and auto-merge is already enabled', () => {
      const context = createContext({
        autoMergeEnabled: true,
        preferredAutoMergeStrategy: 'merge_when_checks_pass',
        mergeabilityChecks: [{ identifier: 'CI_MUST_PASS', status: 'FAILED' }],
      });

      expect(getStateKey.call(context)).toBe('mergeChecksFailed');
    });
  });
});
