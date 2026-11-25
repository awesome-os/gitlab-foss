const { spawnSync } = require('child_process');
const { join, resolve } = require('path');
const { existsSync, readdirSync } = require('fs');
const { env } = require('process');
const chalk = require('chalk');

const ROOT_PATH = resolve(__dirname, '../../');

// check that fsevents is available if we're on macOS
if (process.platform === 'darwin') {
  try {
    require.resolve('fsevents');
  } catch (e) {
    console.error(`${chalk.red('error')} Dependency postinstall check failed.`);
    console.error(
      chalk.red(
        `The fsevents driver is not installed properly.
        If you are running a new version of Node, please
        ensure that it is supported by the fsevents library.

        You can try installing again with \`${chalk.cyan('rm -rf node_modules && yarn install')}\`
      `,
      ),
    );
    process.exit(1);
  }
}

console.log(`${chalk.green('success')} Dependency postinstall check passed.`);

// skip patching when populating cache on CI to not change file metadata and allow install commands to re-apply patch
// if patch files are ever updated
if (env.GLCI_SKIP_NODE_MODULES_PATCHING !== 'true') {
  try {
    // Verify that the patches directory was copied, using its README.md as a sentinel file.
    // This catches cases where the directory was not copied (e.g. in Docker builds) without
    // requiring patches to exist, since shipping with no patches is possible.
    const patchesDir = join(ROOT_PATH, 'patches');
    if (!existsSync(join(patchesDir, 'README.md'))) {
      throw new Error(`The patches directory is missing or incomplete: ${patchesDir}`);
    }

    const patchFiles = readdirSync(patchesDir).filter((f) => f.endsWith('.patch'));
    if (patchFiles.length === 0) {
      console.warn(`${chalk.yellow('warning')} No .patch files found in ${patchesDir}`);
    }

    // Apply any patches to our packages
    // See https://gitlab.com/gitlab-org/gitlab/-/issues/336138
    process.exitCode =
      spawnSync('node_modules/.bin/patch-package', ['--error-on-fail', '--error-on-warn'], {
        stdio: ['ignore', 'inherit', 'inherit'],
      }).status ?? 1;
  } catch (e) {
    console.error(`${chalk.red('error')} Patch validation failed: ${e.message}`);
    console.error(
      chalk.red('Ensure the patches/ directory is present before running yarn install.'),
    );
    process.exitCode = 1;
  }
}
