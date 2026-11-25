import {
  hideGlTooltip as hideGitLabUiTooltip,
  showGlTooltip as showGitLabUiTooltip,
} from '@gitlab/ui';

// `vm` is unused: @gitlab/ui finds tooltips itself. It stays until a follow-up
// drops it from the call sites and removes this module.

/**
 * Shows the tooltip whose target element or tooltip has the given `id`,
 * or all tooltips when `id` is omitted.
 *
 * @param {Object} vm The calling component (`this`)
 * @param {string} [id] Id of the tooltip's target element, or of the tooltip itself
 */
export const showGlTooltip = (vm, id) => showGitLabUiTooltip(id);

/**
 * Hides the tooltip whose target element or tooltip has the given `id`,
 * or all tooltips when `id` is omitted.
 *
 * @param {Object} vm The calling component (`this`)
 * @param {string} [id] Id of the tooltip's target element, or of the tooltip itself
 */
export const hideGlTooltip = (vm, id) => hideGitLabUiTooltip(id);
