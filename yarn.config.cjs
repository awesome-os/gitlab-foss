// Yarn constraints, checked on every `yarn install` (see `enableConstraintsChecks` in .yarnrc.yml).
// Run them on their own with `yarn constraints`.
// https://yarnpkg.com/features/constraints
const semver = require('semver');

module.exports = {
  async constraints({ Yarn }) {
    // @gitlab/duo-ui uses the @gitlab/ui installed for the app, so it must satisfy its peer range.
    for (const duoUi of Yarn.dependencies({ ident: '@gitlab/duo-ui' })) {
      const requiredUiVersion = duoUi.resolution?.peerDependencies.get('@gitlab/ui');
      const installedUiVersion = duoUi.resolution?.dependencies.get('@gitlab/ui')?.version;

      if (!requiredUiVersion) {
        duoUi.error('@gitlab/duo-ui does not specify a @gitlab/ui peer dependency');
      } else if (!installedUiVersion) {
        duoUi.error('@gitlab/ui is not installed');
      } else if (!semver.satisfies(installedUiVersion, requiredUiVersion)) {
        duoUi.error(
          `@gitlab/duo-ui requires @gitlab/ui@${requiredUiVersion} but ${installedUiVersion} is installed`,
        );
      }
    }
  },
};
