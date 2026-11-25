import { mount } from '@vue/test-utils';
import { GlFormCheckbox, GlButton } from '@gitlab/ui';
import AdvancedSettings from '~/import_entities/import_projects/components/advanced_settings.vue';
import { CONTINUOUS_SYNC_STAGE } from '~/import_entities/constants';

describe('Import Advanced Settings', () => {
  let wrapper;

  const OPTIONAL_STAGES = [
    { name: 'stage1', label: 'Stage 1', selected: false },
    { name: 'stage2', label: 'Stage 2', details: 'Extra details', selected: false },
  ];

  const SYNC_STAGE = {
    name: CONTINUOUS_SYNC_STAGE,
    label: 'Keep this project updated from GitHub',
    selected: false,
  };

  const createComponent = ({ stages = OPTIONAL_STAGES, propsData = {} } = {}) => {
    wrapper = mount(AdvancedSettings, {
      propsData: {
        stages,
        value: Object.fromEntries(stages.map(({ name }) => [name, false])),
        ...propsData,
      },
    });
  };

  const findToggle = () => wrapper.findComponent(GlButton);
  const findSyncCard = () => wrapper.find('[data-testid="sync-settings-card"]');
  const findAdditionalCard = () => wrapper.find('[data-testid="additional-settings-card"]');
  const findAllCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findBodyCopy = () =>
    wrapper.findAll('p').wrappers.find((w) => w.text().startsWith('The more information'));

  describe('without the sync stage', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the body copy about import time and the read:org scope', () => {
      expect(findBodyCopy().text()).toMatchInterpolatedText(
        'The more information you select, the longer it will take to import. To import collaborators, or if your project has Git LFS files, you must use a classic personal access token with read:org scope. Learn more.',
      );
    });

    it('does not render the sync card', () => {
      expect(findSyncCard().exists()).toBe(false);
    });

    it('renders all stages in the additional settings card', () => {
      expect(findAdditionalCard().exists()).toBe(true);
      expect(findAllCheckboxes()).toHaveLength(OPTIONAL_STAGES.length);
    });

    it('renders label for each optional stage', () => {
      findAllCheckboxes().wrappers.forEach((w, idx) => {
        expect(w.text()).toContain(OPTIONAL_STAGES[idx].label);
      });
    });

    it('renders details for stage with details', () => {
      expect(findAllCheckboxes().at(1).text()).toContain(OPTIONAL_STAGES[1].details);
    });

    it('emits new stages selection state when checkbox is changed', () => {
      findAllCheckboxes().at(0).vm.$emit('change', true);

      expect(wrapper.emitted('input')[0]).toStrictEqual([{ stage1: true, stage2: false }]);
    });
  });

  describe('with the sync stage', () => {
    beforeEach(() => {
      createComponent({ stages: [...OPTIONAL_STAGES, SYNC_STAGE] });
    });

    it('renders the sync card with the sync checkbox and help text', () => {
      const card = findSyncCard();

      expect(card.text()).toContain('Sync the repositories you import');
      expect(card.text()).toContain('Only groups on Premium or Ultimate can keep updates on.');
    });

    it('keeps the sync checkbox outside the additional settings card', () => {
      expect(findAdditionalCard().text()).not.toContain('Sync the repositories you import');
      expect(findAdditionalCard().findAllComponents(GlFormCheckbox)).toHaveLength(
        OPTIONAL_STAGES.length,
      );
    });

    it('emits the sync stage key when the sync checkbox is changed', () => {
      findSyncCard().findComponent(GlFormCheckbox).vm.$emit('change', true);

      expect(wrapper.emitted('input')[0]).toStrictEqual([
        { stage1: false, stage2: false, continuous_sync: true },
      ]);
    });

    it('lists synced and one-time data in the popover', () => {
      const popover = wrapper.find('[data-testid="sync-full-list-popover"]');

      const [synced, oneTime] = popover
        .findAll('ul')
        .wrappers.map((ul) => ul.findAll('li').wrappers.map((li) => li.text()));

      expect(synced).toStrictEqual([
        'Repository',
        'Git LFS objects',
        'Issues and merge requests',
        'Comments, reviews and review comments',
        'Releases',
        'Markdown attachments (if selected)',
      ]);
      expect(oneTime).toStrictEqual([
        'Labels and milestones (new ones are added)',
        'Wiki',
        'Protected branches',
        'Collaborators (if selected)',
      ]);
    });
  });

  describe('expansion', () => {
    it('emits update:expanded when the toggle is clicked', async () => {
      createComponent({ propsData: { expanded: true } });

      await findToggle().trigger('click');

      expect(wrapper.emitted('update:expanded')).toStrictEqual([[false]]);
    });

    it('shows the settings content when expanded', () => {
      createComponent({ propsData: { expanded: true } });

      expect(findToggle().attributes('aria-expanded')).toBe('true');
      expect(findAllCheckboxes().at(0).isVisible()).toBe(true);
    });

    it('hides the settings content when collapsed', () => {
      createComponent({ propsData: { expanded: false } });

      expect(findToggle().attributes('aria-expanded')).toBe('false');
      expect(findAllCheckboxes().at(0).isVisible()).toBe(false);
    });
  });
});
