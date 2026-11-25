<script>
import { n__, sprintf } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import TodoItem from './todo_item.vue';
import TodoItemTitle from './todo_item_title.vue';
import TodoItemTitleHiddenBySaml from './todo_item_title_hidden_by_saml.vue';

export default {
  name: 'TodosGroup',
  components: {
    CrudComponent,
    TodoItem,
    TodoItemTitle,
    TodoItemTitleHiddenBySaml,
  },
  props: {
    todos: {
      type: Array,
      required: true,
    },
    selectedIds: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['change', 'select-change'],
  computed: {
    firstTodo() {
      return this.todos[0];
    },
    isHiddenBySaml() {
      return !this.firstTodo.targetEntity;
    },
    countLabel() {
      return sprintf(n__('Todos|%{count} to-do', 'Todos|%{count} to-dos', this.todos.length), {
        count: this.todos.length,
      });
    },
  },
};
</script>

<template>
  <crud-component
    container-tag="li"
    is-collapsible
    class="!gl-mt-0"
    header-class="!gl-flex-nowrap"
    title-container-class="gl-min-w-0"
    title-class="gl-min-w-0 gl-max-w-full"
    body-class="!gl-p-0 gl-overflow-hidden"
    data-testid="todos-group"
  >
    <template #title>
      <todo-item-title-hidden-by-saml
        v-if="isHiddenBySaml"
        class="gl-flex gl-min-w-0 gl-items-center gl-gap-2"
      />
      <todo-item-title
        v-else
        :todo="firstTodo"
        target-name-only
        class="gl-flex gl-min-w-0 gl-items-center gl-gap-2 gl-whitespace-nowrap"
      />
    </template>
    <template #count>
      <span aria-hidden="true" data-testid="todos-group-count-number">{{ todos.length }}</span>
      <span class="gl-sr-only" data-testid="todos-group-count-label">{{ countLabel }}</span>
    </template>
    <ol class="gl-m-0 gl-list-none gl-p-0">
      <todo-item
        v-for="todo in todos"
        :key="todo.id"
        :todo="todo"
        class="last:gl-border-b-0"
        selectable
        hide-target-name
        :selected="selectedIds.includes(todo.id)"
        @change="$emit('change')"
        @select-change="(id, checked) => $emit('select-change', id, checked)"
      />
    </ol>
  </crud-component>
</template>
