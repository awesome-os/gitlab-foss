import { shallowMount } from '@vue/test-utils';
import UserStatusBubble from '~/vue_shared/components/user_status_bubble.vue';

describe('UserStatusBubble', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(UserStatusBubble, {
      slots: { default: '<span>On vacation</span>' },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the slot content', () => {
    expect(wrapper.text()).toBe('On vacation');
  });

  it('renders a decorative tail', () => {
    expect(wrapper.find('svg').attributes('aria-hidden')).toBe('true');
  });
});
