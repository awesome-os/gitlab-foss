import { GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import WikiAlert from '~/wikis/components/wiki_alert.vue';

describe('WikiAlert', () => {
  let wrapper;
  const ERROR = 'There is already a page with the same title in that path.';

  function createWrapper(propsData = {}) {
    wrapper = shallowMount(WikiAlert, {
      propsData,
      stubs: { GlAlert },
    });
  }

  const findGlAlert = () => wrapper.findComponent(GlAlert);

  it('shows the error in a non-dismissible danger alert', () => {
    createWrapper({ error: ERROR });

    expect(findGlAlert().props()).toMatchObject({ variant: 'danger', dismissible: false });
    expect(findGlAlert().text()).toBe(ERROR);
  });
});
