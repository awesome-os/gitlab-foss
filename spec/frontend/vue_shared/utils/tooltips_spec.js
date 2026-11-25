import {
  hideGlTooltip as hideGitLabUiTooltip,
  showGlTooltip as showGitLabUiTooltip,
} from '@gitlab/ui';
import { hideGlTooltip, showGlTooltip } from '~/vue_shared/utils/tooltips';

describe('tooltips utils', () => {
  const vm = {};

  describe.each`
    helper           | gitLabUiHelper
    ${showGlTooltip} | ${showGitLabUiTooltip}
    ${hideGlTooltip} | ${hideGitLabUiTooltip}
  `('$helper.name', ({ helper, gitLabUiHelper }) => {
    it('passes the id to @gitlab/ui', () => {
      helper(vm, 'my-id');

      expect(gitLabUiHelper).toHaveBeenCalledWith('my-id');
    });

    it('passes no id to @gitlab/ui when none is given', () => {
      helper(vm);

      expect(gitLabUiHelper).toHaveBeenCalledWith(undefined);
    });
  });
});
