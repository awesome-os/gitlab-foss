import { GlFormGroup, GlFormInput, GlFormTextarea, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DynamicValueRenderer from '~/ci/common/pipeline_inputs/pipeline_inputs_table/value_column/dynamic_value_renderer.vue';
import BooleanCell from '~/ci/common/pipeline_inputs/pipeline_inputs_table/value_column/boolean_cell.vue';
import DropdownCell from '~/ci/common/pipeline_inputs/pipeline_inputs_table/value_column/dropdown_cell.vue';

describe('DynamicValueRenderer', () => {
  let wrapper;

  const defaultProps = {
    item: { name: 'input1', description: '', type: 'STRING', value: 'value1' },
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(DynamicValueRenderer, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlFormInput,
        GlFormTextarea,
        GlSprintf,
      },
    });
  };

  const findBooleanCellComponent = () => wrapper.findComponent(BooleanCell);
  const findDropdownCell = () => wrapper.findComponent(DropdownCell);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findValidationFeedback = () => wrapper.findByTestId('validation-feedback');
  const findPattern = () => wrapper.findByTestId('input-pattern');

  const getInputType = (type) => (type === 'ARRAY' ? 'textarea' : 'input');

  const setInputValue = async (value) => {
    await findInput().setValue(value);

    await nextTick();
  };

  describe('rendering', () => {
    describe('basic input types', () => {
      it('renders text input for string type', () => {
        createComponent();
        expect(findInput().exists()).toBe(true);
        expect(findInput().attributes('type')).toBe('text');
      });

      it('renders number input for number type', () => {
        createComponent({ props: { item: { ...defaultProps.item, type: 'NUMBER' } } });
        expect(findInput().exists()).toBe(true);
        expect(findInput().attributes('type')).toBe('number');
        expect(findInput().attributes('min')).toBe(String(Number.MIN_SAFE_INTEGER));
        expect(findInput().attributes('max')).toBe(String(Number.MAX_SAFE_INTEGER));
      });

      it('renders boolean cell component for boolean type', () => {
        createComponent({ props: { item: { ...defaultProps.item, type: 'BOOLEAN' } } });
        expect(findBooleanCellComponent().exists()).toBe(true);
        expect(findInput().exists()).toBe(false);
      });

      it.each(['STRING', 'ARRAY'])('renders dropdown cell for %s type with options', (type) => {
        const item = { ...defaultProps.item, type, options: ['option1', 'option2'] };
        createComponent({ props: { item } });

        expect(findDropdownCell().props('input')).toEqual(item);
        expect(findInput().exists()).toBe(false);
        expect(findTextarea().exists()).toBe(false);
      });
    });

    describe('array type handling', () => {
      it('renders a textarea for array inputs', () => {
        createComponent({
          props: {
            item: {
              ...defaultProps.item,
              type: 'ARRAY',
            },
          },
        });

        expect(findTextarea().exists()).toBe(true);
        expect(findInput().exists()).toBe(false);
      });
    });
  });

  describe('event handling', () => {
    describe('basic input events', () => {
      it('emits update event when input value changes', async () => {
        createComponent();
        await findInput().vm.$emit('input', 'new value');

        expect(wrapper.emitted().update).toHaveLength(1);
        expect(wrapper.emitted('update')[0][0]).toEqual({
          item: defaultProps.item,
          value: 'new value',
        });
      });

      describe('when the input has options', () => {
        const item = { ...defaultProps.item, options: ['option1', 'option2', 'hi'] };

        beforeEach(() => {
          createComponent({ props: { item } });
        });

        it('emits update event when dropdown cell value changes', async () => {
          await findDropdownCell().vm.$emit('update', { input: item, value: 'option2' });

          expect(wrapper.emitted().update).toHaveLength(1);
          expect(wrapper.emitted('update')[0][0]).toEqual({
            item,
            value: 'option2',
          });
        });
      });

      it('emits update event when boolean value changes', async () => {
        const item = {
          ...defaultProps.item,
          type: 'BOOLEAN',
        };

        createComponent({
          props: { item },
        });

        await findBooleanCellComponent().vm.$emit('update', {
          input: item,
          value: true,
        });

        expect(wrapper.emitted().update).toHaveLength(1);
        expect(wrapper.emitted('update')[0][0]).toEqual({
          item,
          value: true,
        });
      });
    });
  });

  describe('type conversion', () => {
    describe('convertToDisplayValue', () => {
      it.each`
        type        | value              | expectedDisplayValue
        ${'STRING'} | ${'test'}          | ${'test'}
        ${'NUMBER'} | ${0}               | ${0}
        ${'ARRAY'}  | ${['a', 'b', 'c']} | ${'["a","b","c"]'}
      `(
        'converts $type value "$value" to display value "$expectedDisplayValue"',
        ({ type, value, expectedDisplayValue }) => {
          createComponent({
            props: { item: { ...defaultProps.item, type, value } },
          });

          const input = getInputType(type) === 'textarea' ? findTextarea() : findInput();
          expect(input.props('value')).toBe(expectedDisplayValue);
        },
      );
    });

    describe('convertToType', () => {
      it.each`
        type        | inputValue | expectedTypedValue
        ${'STRING'} | ${'test'}  | ${'test'}
        ${'NUMBER'} | ${'42'}    | ${42}
        ${'ARRAY'}  | ${'a,b,c'} | ${'a,b,c'}
      `(
        'handles input value "$inputValue" for $type type appropriately',
        async ({ type, inputValue, expectedTypedValue }) => {
          createComponent({
            props: { item: { ...defaultProps.item, type } },
          });

          const input = getInputType(type) === 'textarea' ? findTextarea() : findInput();
          await input.vm.$emit('input', inputValue);

          expect(wrapper.emitted('update')[0][0].value).toEqual(expectedTypedValue);
        },
      );
    });
  });

  describe('pattern', () => {
    describe('when the input defines a regex', () => {
      beforeEach(() => {
        createComponent({ props: { item: { ...defaultProps.item, regex: '^[a-z]+$' } } });
      });

      it('renders the pattern', () => {
        expect(findPattern().exists()).toBe(true);
        expect(findPattern().text()).toBe('Pattern: ^[a-z]+$');
      });

      it('accepts a value the regex rejects', async () => {
        await setInputValue('123');

        expect(findInput().element.checkValidity()).toBe(true);
        expect(findValidationFeedback().exists()).toBe(false);
      });
    });

    describe('when the input defines no regex', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render the pattern', () => {
        expect(findPattern().exists()).toBe(false);
      });
    });

    describe('when the input has options and regex', () => {
      beforeEach(() => {
        createComponent({
          props: { item: { ...defaultProps.item, regex: '^[a-z]+$', options: ['a', 'b'] } },
        });
      });

      it('renders the pattern', () => {
        expect(findPattern().exists()).toBe(true);
      });
    });
  });

  describe('form group association', () => {
    it.each([
      ['text input', {}, () => findInput().attributes('id')],
      ['number input', { type: 'NUMBER' }, () => findInput().attributes('id')],
      ['textarea', { type: 'ARRAY' }, () => findTextarea().attributes('id')],
      ['dropdown toggle', { options: ['a', 'b'] }, () => findDropdownCell().props('toggleId')],
    ])('sets labelFor to the %s id', (_, itemProps, controlId) => {
      createComponent({ props: { item: { ...defaultProps.item, ...itemProps } } });

      expect(findFormGroup().attributes('labelfor')).toBe(controlId());
    });
  });

  describe('validation', () => {
    describe('attributes', () => {
      it.each`
        description                     | itemProps             | attribute            | expectedValue
        ${'number type data attribute'} | ${{ type: 'NUMBER' }} | ${'data-field-type'} | ${'NUMBER'}
        ${'json array data attribute'}  | ${{ type: 'ARRAY' }}  | ${'data-json-array'} | ${'true'}
      `('applies $description to input', ({ itemProps, attribute, expectedValue }) => {
        createComponent({
          props: {
            item: {
              ...defaultProps.item,
              ...itemProps,
            },
          },
        });

        const inputComponent = itemProps.type === 'ARRAY' ? findTextarea() : findInput();
        expect(inputComponent.attributes(attribute)).toBe(expectedValue);
      });

      // Separate test for required attribute because vue 2 and vue 3 handle required differently
      it('applies required attribute to input', () => {
        createComponent({
          props: {
            item: {
              ...defaultProps.item,
              required: true,
            },
          },
        });
        expect(findInput().element.hasAttribute('required')).toBe(true);
      });
    });

    describe('invalid text feedback', () => {
      it('displays validation feedback when required field is empty', async () => {
        createComponent({
          props: {
            item: {
              ...defaultProps.item,
              required: true,
            },
          },
        });

        await setInputValue('');

        expect(findValidationFeedback().exists()).toBe(true);
        expect(findValidationFeedback().text()).toContain('This is required and must be defined.');
      });
    });
  });
});
