import { h, nextTick, ref } from 'vue';
import { mount } from '@vue/test-utils';
import { Portal, PortalTarget } from '~/lib/utils/vue3compat/portal_vue_vue3';
import PortaledButtons from './components/portaled_buttons.vue';

(process.env.VUE_VERSION === '3' ? describe : describe.skip)('portal_vue_vue3', () => {
  let wrapper;
  let targetClass;

  const createComponent = (rootCount) => {
    targetClass = ref('initial');

    // The target sits in its own component so it can re-render without the portal.
    const TargetHost = {
      render: () => h(PortalTarget, { name: 'footer', class: targetClass.value }),
    };

    wrapper = mount({
      render: () =>
        h('div', [
          h(TargetHost),
          h(
            Portal,
            { to: 'footer' },
            {
              default: () =>
                Array.from({ length: rootCount }, (_, i) =>
                  h('span', { 'data-testid': 'portaled-node' }, `Node ${i}`),
                ),
            },
          ),
        ]),
    });
  };

  const findPortaledText = () =>
    wrapper.findAll('[data-testid="portaled-node"]').wrappers.map((node) => node.text());

  it.each([
    [1, ['Node 0']],
    [2, ['Node 0', 'Node 1']],
  ])('keeps %i root node(s) when the target re-renders', async (rootCount, expected) => {
    createComponent(rootCount);
    await nextTick();

    targetClass.value = 'updated';
    await nextTick();

    expect(findPortaledText()).toEqual(expected);
  });

  describe('when dynamic portal content moves to another component instance', () => {
    const onPrev = jest.fn();
    const onNext = jest.fn();

    const createSwappingComponent = () => {
      const step = ref(1);

      wrapper = mount({
        render: () =>
          h('div', [
            h(PortalTarget, { name: 'footer' }),
            h(PortaledButtons, {
              key: step.value,
              step: step.value,
              onPrev: () => {
                onPrev(step.value);
                step.value -= 1;
              },
              onNext: () => {
                onNext(step.value);
                step.value += 1;
              },
            }),
          ]),
      });
    };

    const findPrevButton = () => wrapper.find('[data-testid="prev-button"]');
    const findNextButton = () => wrapper.find('[data-testid="next-button"]');

    it('binds each click handler to the current instance', async () => {
      createSwappingComponent();
      await nextTick();

      await findNextButton().trigger('click');
      await findNextButton().trigger('click');
      await findPrevButton().trigger('click');

      expect(onNext.mock.calls).toEqual([[1], [2]]);
      expect(onPrev.mock.calls).toEqual([[3]]);
    });
  });
});
