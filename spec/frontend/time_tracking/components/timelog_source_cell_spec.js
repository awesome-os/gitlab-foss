import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TimelogSourceCell from '~/time_tracking/components/timelog_source_cell.vue';
import {
  issuableStatusText,
  STATUS_CLOSED,
  STATUS_MERGED,
  STATUS_OPEN,
  STATUS_LOCKED,
  STATUS_REOPENED,
} from '~/issues/constants';

const createIssuableTimelogMock = (
  type,
  { title, state, webPath, reference } = {
    title: 'Issuable title',
    state: STATUS_OPEN,
    webPath: '/group/project/-/issues/111',
    reference: 'group/project#111',
  },
) => {
  return {
    timelog: {
      project: {
        fullPath: 'group/project',
      },
      [type]: {
        title,
        state,
        webPath,
        reference,
      },
    },
  };
};

describe('TimelogSourceCell component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const findTitleContainer = () => wrapper.findByTestId('title-container');
  const findReferenceContainer = () => wrapper.findByTestId('reference-container');
  const findStateContainer = () => wrapper.findByTestId('state-container');

  const mountComponent = ({ timelog } = {}) => {
    wrapper = shallowMountExtended(TimelogSourceCell, {
      propsData: {
        timelog,
      },
    });
  };

  describe('when the timelog is associated to an issue', () => {
    it('shows the issue title as link to the issue', () => {
      mountComponent(
        createIssuableTimelogMock('issue', {
          title: 'Issue title',
          webPath: '/group/project/-/issues/1',
        }),
      );

      const titleContainer = findTitleContainer();

      expect(titleContainer.text()).toBe('Issue title');
      expect(titleContainer.attributes('href')).toBe('/group/project/-/issues/1');
    });

    it('shows the issue full reference as link to the issue', () => {
      mountComponent(
        createIssuableTimelogMock('issue', {
          reference: 'group/project#111',
          webPath: '/group/project/-/issues/1',
        }),
      );

      const referenceContainer = findReferenceContainer();

      expect(referenceContainer.text()).toBe('group/project#111');
      expect(referenceContainer.attributes('href')).toBe('/group/project/-/issues/1');
    });

    it('shows the group full reference when the timelog has no project', () => {
      const { timelog } = createIssuableTimelogMock('issue', {
        reference: 'group#111',
        webPath: '/group/project/-/issues/1',
      });

      mountComponent({ timelog: { ...timelog, project: null } });

      expect(findReferenceContainer().text()).toBe('group#111');
    });

    it.each`
      state              | stateDescription
      ${STATUS_OPEN}     | ${issuableStatusText[STATUS_OPEN]}
      ${STATUS_REOPENED} | ${issuableStatusText[STATUS_REOPENED]}
      ${STATUS_LOCKED}   | ${issuableStatusText[STATUS_LOCKED]}
      ${STATUS_CLOSED}   | ${issuableStatusText[STATUS_CLOSED]}
    `('shows $stateDescription when the state is $state', ({ state, stateDescription }) => {
      mountComponent(createIssuableTimelogMock('issue', { state }));

      expect(findStateContainer().text()).toBe(stateDescription);
    });
  });

  describe('when the timelog is associated to a merge request', () => {
    it('shows the merge request title as link to the merge request', () => {
      mountComponent(
        createIssuableTimelogMock('mergeRequest', {
          title: 'MR title',
          webPath: '/group/project/-/merge_requests/1',
        }),
      );

      const titleContainer = findTitleContainer();

      expect(titleContainer.text()).toBe('MR title');
      expect(titleContainer.attributes('href')).toBe('/group/project/-/merge_requests/1');
    });

    it('shows the merge request full reference as link to the merge request', () => {
      mountComponent(
        createIssuableTimelogMock('mergeRequest', {
          reference: 'group/project!111',
          webPath: '/group/project/-/merge_requests/1',
        }),
      );

      const referenceContainer = findReferenceContainer();

      expect(referenceContainer.text()).toBe('group/project!111');
      expect(referenceContainer.attributes('href')).toBe('/group/project/-/merge_requests/1');
    });
    it.each`
      state            | stateDescription
      ${STATUS_OPEN}   | ${issuableStatusText[STATUS_OPEN]}
      ${STATUS_CLOSED} | ${issuableStatusText[STATUS_CLOSED]}
      ${STATUS_MERGED} | ${issuableStatusText[STATUS_MERGED]}
    `('shows $stateDescription when the state is $state', ({ state, stateDescription }) => {
      mountComponent(createIssuableTimelogMock('mergeRequest', { state }));

      expect(findStateContainer().text()).toBe(stateDescription);
    });
  });
});
