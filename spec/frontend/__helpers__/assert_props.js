import { mount } from '@vue/test-utils';
import { ErrorWithStack } from 'jest-util';

function installConsoleHandler(method, errors) {
  const originalHandler = global.console[method];

  global.console[method] = function collectPropErrors(...args) {
    if (args[0]?.includes('Invalid prop') || args[0]?.includes('Missing required prop')) {
      // Let Vue finish warning cleanup before assertProps throws.
      errors.push(
        new ErrorWithStack(
          `Unexpected call of console.${method}() with:\n\n${args.join(', ')}`,
          this[method],
        ),
      );
      return;
    }

    originalHandler.apply(this, args);
  };

  return function restore() {
    global.console[method] = originalHandler;
  };
}

export function assertProps(Component, props, extraMountArgs = {}) {
  const errors = [];
  const [restoreError, restoreWarn] = [
    installConsoleHandler('error', errors),
    installConsoleHandler('warn', errors),
  ];
  const ComponentWithoutRenderFn = {
    ...Component,
    inheritAttrs: false,
    render() {
      return '';
    },
  };

  try {
    mount(ComponentWithoutRenderFn, { propsData: props, ...extraMountArgs });
  } finally {
    restoreError();
    restoreWarn();
  }

  if (errors.length) {
    throw errors[0];
  }
}
