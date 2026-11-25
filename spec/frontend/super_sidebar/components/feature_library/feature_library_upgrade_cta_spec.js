import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { TEST_HOST } from 'helpers/test_constants';
import FeatureLibraryUpgradeCta from '~/super_sidebar/components/feature_library/feature_library_upgrade_cta.vue';

describe('FeatureLibraryUpgradeCta', () => {
  let wrapper;

  const createWrapper = (cta) => {
    wrapper = shallowMountExtended(FeatureLibraryUpgradeCta, {
      propsData: { cta },
      stubs: { GlButton },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  describe('with an external URL', () => {
    const cta = { type: 'upgrade', text: 'Upgrade to Premium', url: 'https://example.com/upgrade' };

    beforeEach(() => createWrapper(cta));

    it('renders a confirm button that opens the CTA URL in a new tab', () => {
      expect(findButton().props('variant')).toBe('confirm');
      expect(findButton().attributes('href')).toBe(cta.url);
      expect(findButton().attributes('target')).toBe('_blank');
      expect(findButton().text()).toBe(cta.text);
    });

    it('emits click with the CTA type', () => {
      findButton().vm.$emit('click');

      expect(wrapper.emitted('click')).toEqual([[cta.type]]);
    });
  });

  describe('with a URL in GitLab', () => {
    const cta = {
      type: 'upgrade',
      text: 'Upgrade to Ultimate',
      url: `${TEST_HOST}/groups/my-group/-/billings`,
    };

    beforeEach(() => createWrapper(cta));

    it('opens the CTA URL in the same tab', () => {
      expect(findButton().attributes('href')).toBe(cta.url);
      expect(findButton().attributes('target')).toBeUndefined();
      expect(findButton().text()).toBe(cta.text);
    });
  });

  describe('with a URL in GitLab that asks for a new tab', () => {
    const cta = {
      type: 'migrate',
      text: 'Migrate to Enterprise Edition',
      url: '/help/update/convert_to_ee/_index.md#convert-to-enterprise-edition',
      new_tab: true,
    };

    beforeEach(() => createWrapper(cta));

    it('opens the CTA URL in a new tab', () => {
      expect(findButton().attributes('href')).toBe(cta.url);
      expect(findButton().attributes('target')).toBe('_blank');
    });
  });
});
