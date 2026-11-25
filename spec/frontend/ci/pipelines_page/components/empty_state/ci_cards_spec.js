import { GlButton, GlCard } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import CiCards from '~/ci/pipelines_page/components/empty_state/ci_cards.vue';

describe('CI Cards', () => {
  let wrapper;
  let trackingSpy;

  const createComponent = ({ showJenkinsCiPrompt = true } = {}) => {
    wrapper = shallowMountExtended(CiCards, {
      provide: {
        pipelineEditorPath: '/-/ci/editor',
        showJenkinsCiPrompt,
      },
    });
  };

  const findCards = () => wrapper.findAllComponents(GlCard);
  const findButtons = () => wrapper.findAllComponents(GlButton);
  const findJenkinsCard = () => wrapper.findByTestId('jenkins-migration-card');

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
  });

  afterEach(() => {
    unmockTracking();
  });

  describe('when the Jenkins prompt is enabled', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the Jenkins card', () => {
      expect(findCards()).toHaveLength(4);
      expect(findJenkinsCard().exists()).toBe(true);
    });

    it('tracks the Jenkins prompt render', () => {
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'render', {
        label: 'migrate_from_jenkins_prompt',
      });
    });

    it('links the test template to the pipeline editor', () => {
      expect(findButtons().at(1).attributes('href')).toBe('/-/ci/editor?template=Getting-Started');
    });

    it.each`
      index | label
      ${0}  | ${'migrate_from_jenkins_prompt'}
      ${1}  | ${'Getting-Started'}
      ${2}  | ${'gitlab_university_prompt'}
      ${3}  | ${'ci_cd_catalog_prompt'}
    `('tracks a click on card $index with the $label label', ({ index, label }) => {
      findButtons().at(index).vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'template_clicked', { label });
    });
  });

  describe('when the Jenkins prompt is disabled', () => {
    beforeEach(() => {
      createComponent({ showJenkinsCiPrompt: false });
    });

    it('hides the Jenkins card', () => {
      expect(findCards()).toHaveLength(3);
      expect(findJenkinsCard().exists()).toBe(false);
    });

    it('does not track a render', () => {
      expect(trackingSpy).not.toHaveBeenCalled();
    });
  });
});
