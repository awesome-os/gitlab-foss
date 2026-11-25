import { GlLink, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ForkPipelineWarningModal from '~/ci/merge_requests/components/fork_pipeline_warning_modal.vue';

describe('ForkPipelineWarningModal', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ForkPipelineWarningModal, {
      propsData: props,
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findLink = () => wrapper.findComponent(GlLink);

  it('renders the title and actions', () => {
    createComponent();

    expect(findModal().props()).toMatchObject({
      modalId: 'create-pipeline-for-fork-merge-request-modal',
      title: 'Are you sure you want to run this pipeline?',
      actionPrimary: { text: 'Run pipeline', attributes: { variant: 'danger' } },
      actionCancel: { text: 'Cancel', attributes: { variant: 'default' } },
    });
  });

  it('renders the fork security warning', () => {
    createComponent();

    expect(findModal().text()).toContain(
      'This pipeline will run code originating from a forked project merge request.',
    );
  });

  it('renders the parent project pipelines docs link', () => {
    createComponent();

    expect(findLink().attributes()).toMatchObject({
      href: '/help/ci/pipelines/merge_request_pipelines.html#run-pipelines-in-the-parent-project',
      target: '_blank',
    });
  });

  describe.each`
    state        | props                | visible
    ${'hidden'}  | ${{}}                | ${false}
    ${'visible'} | ${{ visible: true }} | ${true}
  `('when $state', ({ state, props, visible }) => {
    beforeEach(() => {
      createComponent({ props });
    });

    it(`renders the modal as ${state}`, () => {
      expect(findModal().props('visible')).toBe(visible);
    });
  });

  describe('when the primary action is clicked', () => {
    beforeEach(() => {
      createComponent();
      findModal().vm.$emit('primary');
    });

    it('emits confirm', () => {
      expect(wrapper.emitted('confirm')).toHaveLength(1);
    });
  });

  describe('when the modal is closed', () => {
    beforeEach(() => {
      createComponent();
      findModal().vm.$emit('change', false);
    });

    it('emits change with false', () => {
      expect(wrapper.emitted('change')).toEqual([[false]]);
    });
  });
});
