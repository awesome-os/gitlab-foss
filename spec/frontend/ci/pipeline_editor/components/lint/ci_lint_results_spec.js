import { GlTableLite, GlLink } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import CiLintResults from '~/ci/pipeline_editor/components/lint/ci_lint_results.vue';
import { mockJobs, mockErrors, mockWarnings } from '../../mock_data';

describe('CI Lint Results', () => {
  let wrapper;
  const defaultProps = {
    isValid: true,
    jobs: mockJobs,
    errors: [],
    warnings: [],
    dryRun: false,
    lintHelpPagePath: '/help',
  };

  const createComponent = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(CiLintResults, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findLinkToDoc = () => wrapper.findComponent(GlLink);
  const findErrors = () => wrapper.findByTestId('ci-lint-errors');
  const findWarnings = () => wrapper.findByTestId('ci-lint-warnings');
  const findStatus = () => wrapper.findByTestId('ci-lint-status');
  const findStatusComponent = () => wrapper.findComponent('[data-testid="ci-lint-status"]');
  const findOnlyExcept = () => wrapper.findByTestId('ci-lint-only-except');
  const findLintParameters = () => wrapper.findAllByTestId('ci-lint-parameter');
  const findLintValues = () => wrapper.findAllByTestId('ci-lint-value');
  const findBeforeScripts = () => wrapper.findAllByTestId('ci-lint-before-script');
  const findScripts = () => wrapper.findAllByTestId('ci-lint-script');
  const findAfterScripts = () => wrapper.findAllByTestId('ci-lint-after-script');
  const filterEmptyScripts = (property) => mockJobs.filter((job) => job[property].length !== 0);

  describe('Empty results', () => {
    it('renders with no jobs, errors or warnings defined', () => {
      createComponent({ jobs: undefined, errors: undefined, warnings: undefined }, mountExtended);
      expect(findTable().exists()).toBe(true);
    });

    it('renders when job has no properties defined', () => {
      // job with no attributes such as `tagList` or `environment`
      const job = {
        stage: 'Stage Name',
        name: 'test job',
      };
      createComponent({ jobs: [job] }, mountExtended);

      const param = findLintParameters().at(0);
      const value = findLintValues().at(0);

      expect(param.text()).toBe(`${job.stage} Job - ${job.name}`);

      // This test should be updated once properties of each job are shown
      // See https://gitlab.com/gitlab-org/gitlab/-/issues/291031
      expect(value.text()).toBe('');
    });
  });

  describe('Invalid results', () => {
    beforeEach(() => {
      createComponent(
        { isValid: false, errors: mockErrors, warnings: mockWarnings },
        mountExtended,
      );
    });

    it('does not display the table', () => {
      expect(findTable().exists()).toBe(false);
    });

    it('displays the invalid status', () => {
      expect(findStatus().text()).toContain(`Status: ${wrapper.vm.$options.incorrect.text}`);
      expect(findStatusComponent().props('variant')).toBe(wrapper.vm.$options.incorrect.variant);
    });

    it('contains the link to documentation', () => {
      expect(findLinkToDoc().text()).toBe('More information');
      expect(findLinkToDoc().attributes('href')).toBe(defaultProps.lintHelpPagePath);
    });

    it('displays the error message', () => {
      const [expectedError] = mockErrors;

      expect(findErrors().text()).toBe(expectedError);
    });

    it('displays the warning message', () => {
      const [expectedWarning] = mockWarnings;

      expect(findWarnings().exists()).toBe(true);
      expect(findWarnings().text()).toContain(expectedWarning);
    });
  });

  describe('Valid results with dry run', () => {
    beforeEach(() => {
      createComponent({ dryRun: true }, mountExtended);
    });

    it('displays table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('displays the valid status', () => {
      expect(findStatus().text()).toContain(wrapper.vm.$options.correct.text);
      expect(findStatusComponent().props('variant')).toBe(wrapper.vm.$options.correct.variant);
    });

    it('does not display only/expect values with dry run', () => {
      expect(findOnlyExcept().exists()).toBe(false);
    });

    it('contains the link to documentation', () => {
      expect(findLinkToDoc().text()).toBe('More information');
      expect(findLinkToDoc().attributes('href')).toBe(defaultProps.lintHelpPagePath);
    });
  });

  describe('Lint results', () => {
    beforeEach(() => {
      createComponent({}, mountExtended);
    });

    it('formats parameter value', () => {
      findLintParameters().wrappers.forEach((job, index) => {
        const { stage } = mockJobs[index];
        const { name } = mockJobs[index];

        expect(job.text()).toBe(`${capitalizeFirstCharacter(stage)} Job - ${name}`);
      });
    });

    it('only shows before scripts when data is present', () => {
      expect(findBeforeScripts()).toHaveLength(filterEmptyScripts('beforeScript').length);
    });

    it('only shows script when data is present', () => {
      expect(findScripts()).toHaveLength(filterEmptyScripts('script').length);
    });

    it('only shows after script when data is present', () => {
      expect(findAfterScripts()).toHaveLength(filterEmptyScripts('afterScript').length);
    });
  });

  describe('Hide Alert', () => {
    it('hides alert on success if hide-alert prop is true', async () => {
      await createComponent({ dryRun: true, hideAlert: true }, mountExtended);

      expect(findStatus().exists()).toBe(false);
    });

    it('hides alert on error if hide-alert prop is true', async () => {
      await createComponent(
        {
          hideAlert: true,
          isValid: false,
          errors: mockErrors,
          warnings: mockWarnings,
        },
        mountExtended,
      );

      expect(findStatus().exists()).toBe(false);
    });
  });
});
