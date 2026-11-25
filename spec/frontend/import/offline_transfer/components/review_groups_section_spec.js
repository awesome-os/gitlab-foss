import { nextTick } from 'vue';
import { GlPagination } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ReviewGroupsSection from '~/import/offline_transfer/components/review_groups_section.vue';
import GroupRow from '~/import/offline_transfer/components/group_row.vue';

describe('ReviewGroupsSection', () => {
  let wrapper;

  const createGroups = (count) =>
    Array.from({ length: count }, (_, index) => ({
      id: `gid://glab/Group/${index + 1}`,
      fullName: `Group ${index + 1}`,
      description: `Description ${index + 1}`,
      avatarUrl: `/avatar/${index + 1}.png`,
    }));

  const createComponent = ({ groups, slots = {} } = {}) => {
    wrapper = shallowMountExtended(ReviewGroupsSection, {
      propsData: { groups },
      slots,
    });
  };

  const findGroupRows = () => wrapper.findAllComponents(GroupRow);
  const findPagination = () => wrapper.findComponent(GlPagination);

  describe('by default', () => {
    const groups = createGroups(1);

    beforeEach(() => {
      createComponent({ groups, slots: { default: '<p data-testid="slot-content">Summary</p>' } });
    });

    it('renders the default slot', () => {
      expect(wrapper.findByTestId('slot-content').text()).toBe('Summary');
    });

    it('renders a static row for every group', () => {
      expect(findGroupRows()).toHaveLength(1);
      expect(findGroupRows().at(0).props('selectable')).toBe(false);
    });

    it('passes the group details to each row', () => {
      expect(findGroupRows().at(0).props()).toMatchObject({
        name: groups[0].fullName,
        description: groups[0].description,
        avatarUrl: groups[0].avatarUrl,
      });
    });
  });

  describe('when the list of groups fit on one page', () => {
    const groups = createGroups(1);

    beforeEach(() => {
      createComponent({ groups });
    });

    it('does not render pagination', () => {
      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('when group count exceeds one page', () => {
    beforeEach(() => {
      createComponent({ groups: createGroups(23) });
    });

    it('shows only the first ten rows', () => {
      expect(findGroupRows()).toHaveLength(10);
      expect(findGroupRows().at(0).props('name')).toBe('Group 1');
      expect(findGroupRows().at(9).props('name')).toBe('Group 10');
    });

    it('passes pagination controls correctly', () => {
      expect(findPagination().props()).toMatchObject({
        value: 1,
        perPage: 10,
        totalItems: 23,
      });
    });

    it('shows the correct groups after the page changes', async () => {
      findPagination().vm.$emit('input', 2);
      await nextTick();

      expect(findGroupRows()).toHaveLength(10);
      expect(findGroupRows().at(0).props('name')).toBe('Group 11');
      expect(findPagination().props('value')).toBe(2);
    });

    it('shows the remaining rows on the last page', async () => {
      findPagination().vm.$emit('input', 3);
      await nextTick();

      expect(findGroupRows()).toHaveLength(3);
      expect(findGroupRows().at(0).props('name')).toBe('Group 21');
    });

    it('resets pagination to the first page when the groups prop changes', async () => {
      findPagination().vm.$emit('input', 3);
      await nextTick();
      expect(findPagination().props('value')).toBe(3);

      await wrapper.setProps({ groups: createGroups(15) });

      expect(findPagination().props('value')).toBe(1);
    });
  });
});
