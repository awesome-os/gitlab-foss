import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ReviewImportTab from '~/import/offline_transfer/import/review_import_tab.vue';
import { mockGroups } from '../mock_data';

describe('ReviewImportTab', () => {
  let wrapper;

  const [parentGroup] = mockGroups;
  const topLevelDestination = { type: 'top_level', parentGroup: null };
  const existingGroupDestination = { type: 'existing_group', parentGroup };
  const storageConfig = {
    accessKeyId: 'TESTACCESSKEYID12345',
    secretAccessKey: 'test-secret-access-key-value',
    region: 'eu-west-1',
    bucketName: 'my<bucket',
    pathStyle: false,
    exportPrefix: 'offline-export-2026-11-18',
  };

  const createComponent = ({ destinationConfig = topLevelDestination, ...props } = {}) => {
    wrapper = shallowMountExtended(ReviewImportTab, {
      propsData: { destinationConfig, storageConfig, ...props },
      stubs: { GlSprintf },
    });
  };

  const findSummary = () => wrapper.findByTestId('review-summary');
  const findRow = (id) => wrapper.findByTestId(`review-row-${id}`);
  const findRowValue = (id) => findRow(id).find('dd').text();
  const findReviewText = () => wrapper.findByTestId('review-text');
  const findSubmitError = () => wrapper.findComponentByTestId('submit-error');
  const findSuccessPanel = () => wrapper.findByTestId('submit-success');
  const findViewImportStatusButton = () => wrapper.findByTestId('view-import-status-button');

  describe('by default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the bucket, region and export prefix as entered', () => {
      expect(findRowValue('bucket')).toBe('my<bucket');
      expect(findRowValue('region')).toBe('eu-west-1');
      expect(findRowValue('export-prefix')).toBe('offline-export-2026-11-18');
    });

    it('shows path-style URLs as No when unchecked', () => {
      expect(findRowValue('path-style')).toBe('No');
    });

    it('masks the access key ID after the first four characters', () => {
      expect(findRowValue('access-key-id')).toBe('TEST••••••••••••');
    });

    it('shows the secret access key row fully masked', () => {
      expect(findRowValue('secret-access-key')).toBe('••••••••••••');
      expect(wrapper.text()).not.toContain(storageConfig.secretAccessKey);
    });

    describe('when path-style URLs are enabled', () => {
      beforeEach(() => {
        createComponent({ storageConfig: { ...storageConfig, pathStyle: true } });
      });

      it('shows path-style URLs as Yes', () => {
        expect(findRowValue('path-style')).toBe('Yes');
      });
    });
  });

  describe('when importing all as top-level groups', () => {
    it('shows the import as top level', () => {
      createComponent();
      expect(findRowValue('import-as')).toBe('Top-level groups');
      expect(findRow('parent-group').exists()).toBe(false);
      expect(findReviewText().text()).toBe(
        'All groups in the package will be imported as top-level groups on this instance. Select Start import to confirm.',
      );
    });
  });

  describe('when importing under an existing group', () => {
    it('shows the import structure and the parent group info', () => {
      createComponent({ destinationConfig: existingGroupDestination });
      expect(findRowValue('import-as')).toBe('Subgroups of an existing group');
      expect(findRowValue('parent-group')).toBe(parentGroup.fullName);
      expect(findReviewText().text()).toBe(
        `All groups in the package will be imported as subgroups under ${parentGroup.fullName}. Select Start import to confirm.`,
      );
    });
  });

  describe('when submission fails', () => {
    const submissionError = 'Unable to access object storage bucket.';

    beforeEach(() => {
      createComponent({ submissionError });
    });

    it('renders a non-dismissible danger alert with the error message', () => {
      const alert = findSubmitError();

      expect(findSuccessPanel().exists()).toBe(false);
      expect(alert.props()).toMatchObject({
        title: 'Import failed',
        variant: 'danger',
        dismissible: false,
      });
      expect(alert.text()).toBe(submissionError);
    });

    it('hides the confirmation text', () => {
      expect(findReviewText().exists()).toBe(false);
    });

    it('keeps the summary visible', () => {
      expect(findSummary().exists()).toBe(true);
    });
  });

  describe('when submission succeeds', () => {
    describe('for a top-level import', () => {
      beforeEach(() => {
        createComponent({ hasSubmitSucceeded: true });
      });

      it('renders the success panel in place of the summary', () => {
        expect(findSuccessPanel().text()).toContain('Import started');
        expect(findSuccessPanel().text()).toContain(
          "You can leave this page. We'll email you when the import of all groups from bucket my<bucket is finished.",
        );
        expect(findSummary().exists()).toBe(false);
        expect(findReviewText().exists()).toBe(false);
        expect(findSubmitError().exists()).toBe(false);
      });

      it('links the status button to the bulk import history page', () => {
        expect(findViewImportStatusButton().attributes('href')).toBe(
          '/import/bulk_imports/history',
        );
        expect(findViewImportStatusButton().text()).toBe('View import status');
      });
    });

    describe('for an import under an existing group', () => {
      beforeEach(() => {
        createComponent({ destinationConfig: existingGroupDestination, hasSubmitSucceeded: true });
      });

      it('names the parent group in the success text', () => {
        expect(findSuccessPanel().text()).toContain(
          `You can leave this page. We'll email you when the import of all groups from bucket my<bucket under ${parentGroup.fullName} is finished.`,
        );
      });
    });
  });
});
