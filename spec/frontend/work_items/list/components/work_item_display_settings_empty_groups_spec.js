import { GlDisclosureDropdownItem, GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import WorkItemDisplaySettingsEmptyGroups from '~/work_items/list/components/work_item_display_settings_empty_groups.vue';

describe('WorkItemDisplaySettingsEmptyGroups', () => {
  let wrapper;

  const findToggleItem = () => wrapper.findComponent(GlDisclosureDropdownItem);
  const findToggle = () => wrapper.findComponent(GlToggle);

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(WorkItemDisplaySettingsEmptyGroups, {
      propsData: props,
    });
  };

  it('defaults the toggle to true when namespacePreferences is empty', () => {
    createComponent();

    expect(findToggle().props('value')).toBe(true);
  });

  it('renders the toggle with the value from namespacePreferences', () => {
    createComponent({ props: { namespacePreferences: { showEmptyGroups: false } } });

    expect(findToggle().props('value')).toBe(false);
  });

  it('emits the toggled value, preserving other settings', async () => {
    createComponent({
      props: { namespacePreferences: { showEmptyGroups: true, hiddenMetadataKeys: ['labels'] } },
    });

    findToggleItem().vm.$emit('action');
    await waitForPromises();

    expect(wrapper.emitted('update-settings')).toEqual([
      [{ showEmptyGroups: false, hiddenMetadataKeys: ['labels'] }],
    ]);
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks hiding empty groups', async () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findToggleItem().vm.$emit('action');
      await waitForPromises();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'configure_columns_on_work_item_board',
        { label: 'hide_empty_groups' },
        undefined,
      );
    });

    it('tracks showing empty groups', async () => {
      createComponent({ props: { namespacePreferences: { showEmptyGroups: false } } });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findToggleItem().vm.$emit('action');
      await waitForPromises();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'configure_columns_on_work_item_board',
        { label: 'show_empty_groups' },
        undefined,
      );
    });
  });
});
