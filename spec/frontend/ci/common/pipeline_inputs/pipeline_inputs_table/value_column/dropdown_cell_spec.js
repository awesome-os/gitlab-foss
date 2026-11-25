import { GlCollapsibleListbox } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DropdownCell from '~/ci/common/pipeline_inputs/pipeline_inputs_table/value_column/dropdown_cell.vue';

describe('DropdownCell', () => {
  let wrapper;

  const defaultInput = {
    name: 'input1',
    type: 'STRING',
    value: 'option1',
    options: ['option1', 'option2', 'option3'],
  };

  const createComponent = (input = {}) => {
    wrapper = shallowMountExtended(DropdownCell, {
      propsData: {
        input: { ...defaultInput, ...input },
        toggleId: 'pipeline-input-1',
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const search = async (term) => {
    findDropdown().vm.$emit('search', term);
    await nextTick();
  };

  it('renders a single select dropdown', () => {
    createComponent();

    expect(findDropdown().props()).toMatchObject({
      multiple: false,
      selected: 'option1',
      toggleId: 'pipeline-input-1',
    });
  });

  it('renders a multi select dropdown for array type', () => {
    createComponent({ type: 'ARRAY', value: ['option1'] });

    expect(findDropdown().props('multiple')).toBe(true);
    expect(findDropdown().props('selected')).toEqual(['option1']);
  });

  it('converts numeric options to string text', () => {
    createComponent({ type: 'NUMBER', value: 1, options: [1, 50] });

    expect(findDropdown().props('items')).toEqual([
      { value: 1, text: '1' },
      { value: 50, text: '50' },
    ]);
  });

  it.each([
    ['NUMBER', 2, '2'],
    ['NUMBER', 0, '0'],
    ['STRING', 'option2', 'option2'],
    ['ARRAY', ['option1'], 'option1'],
    ['ARRAY', [1], '1'],
    ['ARRAY', [1, 2], '2 options selected'],
    ['ARRAY', [true], 'true'],
    ['ARRAY', ['option1', 'option2'], '2 options selected'],
    ['STRING', '', 'Select option'],
    ['STRING', null, 'Select option'],
    ['ARRAY', '', 'Select option'],
    ['ARRAY', [], 'Select option'],
  ])('%s input set to %p shows %p', (type, value, expected) => {
    createComponent({ type, value });

    expect(findDropdown().props('toggleText')).toBe(expected);
  });

  describe('when an option is selected', () => {
    beforeEach(() => {
      createComponent();
      findDropdown().vm.$emit('select', 'option2');
    });

    it('emits update with the value', () => {
      expect(wrapper.emitted('update')).toEqual([
        [{ input: { ...defaultInput }, value: 'option2' }],
      ]);
    });
  });

  describe('when a number option is selected', () => {
    beforeEach(() => {
      createComponent({ type: 'NUMBER', value: 1, options: [1, 50] });
      findDropdown().vm.$emit('select', 50);
    });

    it('emits update with a number', () => {
      expect(wrapper.emitted('update')[0][0].value).toBe(50);
    });
  });

  describe('when searching', () => {
    beforeEach(() => {
      createComponent({ options: ['production', 'staging', 'development', 'preview'] });
    });

    it('filters options case-insensitively', async () => {
      await search('PROD');

      expect(findDropdown().props('items')).toEqual([{ value: 'production', text: 'production' }]);
    });

    it('renders no options without a match', async () => {
      await search('xyz');

      expect(findDropdown().props('items')).toHaveLength(0);
    });

    it('restores all options when cleared', async () => {
      await search('prod');
      await search('');

      expect(findDropdown().props('items')).toHaveLength(4);
    });
  });
});
