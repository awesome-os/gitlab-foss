---
stage: none
group: unassigned
info: Any user with at least the Maintainer role can merge updates to this content. For details, see <https://docs.gitlab.com/development/development_processes/#development-guidelines-review>.
title: Frontend dependencies
---

We use [Yarn 4](https://yarnpkg.com/) to manage frontend dependencies.
[mise](https://mise.jdx.dev/) 2026.11.6 or later installs the Yarn version set in the
`packageManager` field of `package.json`, and checks its SHA-512 hash.
We don't use Corepack.
Upgrading Yarn also needs changes in the CI images, the Cloud Native GitLab images, and the Linux package,
which install Yarn separately.
For details, see [issue 638441](https://gitlab.com/gitlab-org/gitlab/-/work_items/638441).
Yarn only installs a release one day after it's published.
The `@gitlab/*` packages that GitLab publishes skip this wait (`npmPreapprovedPackages` in `.yarnrc.yml`).

There are a few exceptions in the GitLab repository, stored in `vendor/assets/`.

## What are production and development dependencies?

These dependencies are defined in two groups within `package.json`, `dependencies` and `devDependencies`.
For our purposes, we consider anything that is required to compile our production assets a "production" dependency.
That is, anything required to run the `webpack` script with `NODE_ENV=production`.
Tools like `eslint`, `jest`, and various plugins and tools used in development are considered `devDependencies`.
This distinction is used by omnibus to determine which dependencies it requires when building GitLab.
To install only the production dependencies, run `NODE_ENV=production yarn workspaces focus --production`.

Exceptions are made for some tools that we require in the
`compile-production-assets` CI job such as `webpack-bundle-analyzer` to analyze our
production assets post-compile.

## Updating dependencies

See the main [Dependencies](../dependencies.md) page for general information about dependency updates.

## Dependency build scripts

Yarn doesn't run the install scripts of dependencies.
It runs only the scripts in our own `package.json`.
If a dependency needs its install script to work, add it to `dependenciesMeta` in `package.json`:

```json
"dependenciesMeta": {
  "vue-demi": {
    "built": true
  }
}
```

To check whether a dependency needs its script, compare its files after an install with and without
`YARN_ENABLE_SCRIPTS=true`.
Many install scripts only print messages or download binaries that are already installed.

## Patching dependencies

Patches can be applied to dependencies with [`patch-package`](https://github.com/ds300/patch-package). Patches are stored under the [`patches/`](https://gitlab.com/gitlab-org/gitlab/-/tree/master/patches) directory.

### What warrants a patch

Dependencies should only be patched as a last resort, as they are technical
debt. Here are some acceptable reasons for patching a dependency:

- it is unmaintained, so there isn't an upstream version which includes the change;
- there is a vulnerability identified that we cannot wait for upstream to fix;
- to change aspects that are specific to GitLab and would or could not be changed upstream.

### Patching a dependency

1. If possible, add tests that ensure the patch achieves the desired behavior.
1. Edit the relevant file directly in `node_modules`. Ensure to include a comment in your edit which details:
   - why the patch is needed,
   - when it can be removed,
   - a link to an issue or merge request which describes the problem that the patch solves.
1. Generate the patch from your edit by running `yarn patch-package <package-name>`.
1. Add the patch with `git add patches/`.
1. Commit as usual.

### Updating a patch

> [!note]
> `@vue/compat` patches require special treatment. Run `scripts/frontend/update_vue_compat_patches.mjs` to guide you through it.

Patches are specific to the particular version of the dependency. When that dependency is updated, any patches for it must also be updated.

If the patch applies cleanly:

1. Run `yarn patch-package <package-name>` to rename the patch to apply to the new version.
1. Run `git add patches/`.
1. Commit as usual.

If the patch does not apply cleanly, determine whether the patch is still needed.

- If so, [create](#patching-a-dependency) a new patch from scratch.
- If not, delete the patch file, and commit.

> [!warning]
> Do not delete patches or parts of patches without confirming that they are no longer needed. If in doubt, ask the person who introduced the patch.
