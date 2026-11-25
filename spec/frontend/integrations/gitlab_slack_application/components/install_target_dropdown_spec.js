import { GlCollapsibleListbox } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import InstallTargetDropdown from '~/integrations/gitlab_slack_application/components/install_target_dropdown.vue';
import { mockGroups, mockProjects } from '../mock_data';

describe('InstallTargetDropdown', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(InstallTargetDropdown, {
      propsData: { groups: mockGroups, projects: mockProjects, ...props },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  it('lists groups before projects, each under its own header', () => {
    createComponent();

    expect(findListbox().props('items')).toEqual([
      {
        text: 'Groups · for GitLab Duo',
        options: expect.arrayContaining([expect.objectContaining({ value: 'group-10' })]),
      },
      {
        text: 'Projects · notifications only',
        options: expect.arrayContaining([expect.objectContaining({ value: 'project-1' })]),
      },
    ]);
  });

  it('omits the groups header when there are no groups', () => {
    createComponent({ groups: [] });

    expect(
      findListbox()
        .props('items')
        .map((section) => section.text),
    ).toEqual(['Projects · notifications only']);
  });

  describe('search', () => {
    beforeEach(() => {
      createComponent();
    });

    it('is searchable', () => {
      expect(findListbox().props('searchable')).toBe(true);
    });

    it('filters groups and projects by name, ignoring case', async () => {
      findListbox().vm.$emit('search', 'acme');
      await nextTick();

      expect(findListbox().props('items')).toEqual([
        {
          text: 'Groups · for GitLab Duo',
          options: [expect.objectContaining({ value: 'group-10' })],
        },
      ]);
    });

    it('keeps a section only when it has matches', async () => {
      findListbox().vm.$emit('search', 'shell');
      await nextTick();

      expect(
        findListbox()
          .props('items')
          .map((section) => section.text),
      ).toEqual(['Projects · notifications only']);
    });

    it('shows everything again when the search is cleared', async () => {
      findListbox().vm.$emit('search', 'acme');
      findListbox().vm.$emit('search', '');
      await nextTick();

      expect(findListbox().props('items')).toHaveLength(2);
    });

    it('still selects the right target after searching', async () => {
      findListbox().vm.$emit('search', 'shell');
      await nextTick();
      findListbox().vm.$emit('select', 'project-2');

      expect(wrapper.emitted('target-selected')[0][0]).toMatchObject({ type: 'project', id: 2 });
    });
  });

  it('emits the selected target with its type', () => {
    createComponent();

    findListbox().vm.$emit('select', 'project-2');

    expect(wrapper.emitted('target-selected')[0][0]).toMatchObject({
      type: 'project',
      id: 2,
      name: 'Test org / Shell',
    });
  });

  it('shows the selected name in the toggle', () => {
    createComponent({ selectedTarget: { value: 'group-10', name: 'Acme' } });

    expect(findListbox().props('toggleText')).toBe('Acme');
  });
});
