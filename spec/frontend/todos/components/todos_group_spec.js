import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import TodosGroup from '~/todos/components/todos_group.vue';
import TodoItem from '~/todos/components/todo_item.vue';
import TodoItemTitle from '~/todos/components/todo_item_title.vue';
import TodoItemTitleHiddenBySaml from '~/todos/components/todo_item_title_hidden_by_saml.vue';
import { MR_REVIEW_REQUEST_TODO, SAML_HIDDEN_TODO } from '../mock_data';

describe('TodosGroup', () => {
  let wrapper;

  const firstTodo = MR_REVIEW_REQUEST_TODO;
  const secondTodo = { ...MR_REVIEW_REQUEST_TODO, id: 'gid://gitlab/Todo/30' };

  const createComponent = ({ todos = [firstTodo, secondTodo], selectedIds = [] } = {}) => {
    wrapper = shallowMountExtended(TodosGroup, {
      propsData: { todos, selectedIds },
      stubs: { CrudComponent },
    });
  };

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findTodoItems = () => wrapper.findAllComponents(TodoItem);
  const findHeaderTitle = () => wrapper.findComponent(TodoItemTitle);
  const findCountNumber = () => wrapper.findByTestId('todos-group-count-number');
  const findCountLabel = () => wrapper.findByTestId('todos-group-count-label');

  describe('header', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a collapsible list item card', () => {
      expect(findCrudComponent().props()).toMatchObject({
        containerTag: 'li',
        isCollapsible: true,
      });
    });

    it('shows the target name of the first to-do', () => {
      expect(findHeaderTitle().props()).toMatchObject({
        todo: firstTodo,
        targetNameOnly: true,
      });
    });

    it('shows the number of to-dos with a label for screen readers', () => {
      expect(wrapper.findByTestId('crud-count').element.contains(findCountNumber().element)).toBe(
        true,
      );
      expect(findCountNumber().text()).toBe('2');
      expect(findCountNumber().attributes('aria-hidden')).toBe('true');
      expect(findCountLabel().text()).toBe('2 to-dos');
    });
  });

  describe('when the target is hidden by SAML', () => {
    beforeEach(() => {
      createComponent({ todos: [SAML_HIDDEN_TODO] });
    });

    it('shows the hidden title instead of the target name', () => {
      expect(wrapper.findComponent(TodoItemTitleHiddenBySaml).exists()).toBe(true);
      expect(findHeaderTitle().exists()).toBe(false);
    });
  });

  describe('to-do items', () => {
    beforeEach(() => {
      createComponent({ selectedIds: [secondTodo.id] });
    });

    it('renders a selectable item without the target name for each to-do', () => {
      expect(findTodoItems()).toHaveLength(2);
      expect(findTodoItems().at(0).props()).toMatchObject({
        todo: firstTodo,
        selectable: true,
        hideTargetName: true,
        selected: false,
      });
      expect(findTodoItems().at(1).props('selected')).toBe(true);
    });

    it('re-emits the change event', () => {
      findTodoItems().at(0).vm.$emit('change');

      expect(wrapper.emitted('change')).toHaveLength(1);
    });

    it('re-emits the select-change event', () => {
      findTodoItems().at(1).vm.$emit('select-change', secondTodo.id, false);

      expect(wrapper.emitted('select-change')).toEqual([[secondTodo.id, false]]);
    });
  });
});
