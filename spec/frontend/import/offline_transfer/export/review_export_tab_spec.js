import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ReviewExportTab from '~/import/offline_transfer/export/review_export_tab.vue';
import ReviewGroupsSection from '~/import/offline_transfer/components/review_groups_section.vue';

describe('ReviewExportTab', () => {
  let wrapper;

  const bucketName = 'my<bucket';

  const createGroups = (count) =>
    Array.from({ length: count }, (_, index) => ({
      id: `gid://glab/Group/${index + 1}`,
      fullName: `Group ${index + 1}`,
      description: `Description ${index + 1}`,
      avatarUrl: `/avatar/${index + 1}.png`,
    }));

  const createComponent = (selectedGroups, props = {}) => {
    wrapper = shallowMountExtended(ReviewExportTab, {
      propsData: { selectedGroups, bucketName, ...props },
      stubs: { GlSprintf },
    });
  };

  const findReviewGroupsSection = () => wrapper.findComponent(ReviewGroupsSection);
  const findReviewExportText = () => wrapper.findByTestId('review-text');
  const findSubmitError = () => wrapper.findComponentByTestId('submit-error');
  const findSuccessPanel = () => wrapper.findByTestId('submit-success');
  const findViewExportStatusButton = () => wrapper.findByTestId('view-export-status-button');

  describe('when reviewing a single group', () => {
    const groups = createGroups(1);

    beforeEach(() => {
      createComponent(groups);
    });

    it('passes the selected groups to the review section', () => {
      expect(findReviewGroupsSection().props('groups')).toEqual(groups);
    });

    it('shows the correct group count and bucket name', () => {
      expect(findReviewExportText().text()).toBe(
        `1 group will be exported to bucket ${bucketName}. Select Start export to confirm.`,
      );
    });
  });

  describe('when reviewing multiple groups', () => {
    beforeEach(() => {
      createComponent(createGroups(23));
    });

    it('shows the correct group count and bucket name', () => {
      expect(findReviewExportText().text()).toBe(
        `23 groups will be exported to bucket ${bucketName}. Select Start export to confirm.`,
      );
    });
  });

  describe('when Offline Export submission fails', () => {
    const submissionError = 'Unable to access object storage bucket.';
    const groups = createGroups(2);

    beforeEach(() => {
      createComponent(groups, { submissionError });
    });

    it('renders a non-dismissible danger alert with the error message', () => {
      const alert = findSubmitError();

      expect(findSuccessPanel().exists()).toBe(false);
      expect(alert.props()).toMatchObject({
        title: 'Export failed',
        variant: 'danger',
        dismissible: false,
      });
      expect(alert.text()).toBe(submissionError);
    });

    it('hides the review subheader text', () => {
      expect(findReviewExportText().exists()).toBe(false);
    });

    it('keeps the selected groups list visible', () => {
      expect(findReviewGroupsSection().props('groups')).toEqual(groups);
    });
  });

  describe('when Offline Export submission succeeds', () => {
    beforeEach(() => {
      createComponent(createGroups(2), { hasSubmitSucceeded: true });
    });

    it('renders the success panel', () => {
      expect(findSuccessPanel().text()).toContain('Export started');
      expect(findSuccessPanel().text()).toContain(
        `You can leave this page. We'll email you when the export of 2 groups is finished and the package is ready in bucket ${bucketName}.`,
      );
      expect(findReviewExportText().exists()).toBe(false);
      expect(findReviewGroupsSection().exists()).toBe(false);
      expect(findSubmitError().exists()).toBe(false);
    });

    it('links the view export status button to the export history page', () => {
      expect(findViewExportStatusButton().attributes('href')).toBe(
        '/import/offline/export/history',
      );
      expect(findViewExportStatusButton().text()).toBe('View export status');
    });
  });
});
