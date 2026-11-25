import path from 'node:path';
import autoprefixer from 'autoprefixer';
import { Features } from 'lightningcss';
import { Logger } from 'sass';
import tailwindcss from 'tailwindcss/lib/plugin.js';
import {
  resolveCompilationTargetsForVite,
  resolveLoadPaths,
} from '../../scripts/frontend/lib/compile_css.mjs';
import tailwindConfig from '../tailwind.config.js';
import { IS_EE, IS_JH, ROOT_PATH } from '../webpack.constants.js';
import { BROWSERSLIST_QUERIES, STYLESHEET_QUERY, STYLESHEET_QUERY_RE } from './loader_rules.js';

const LIGHTNINGCSS_OPTIONS = Object.freeze({
  // Queries: Rspack's own browser data lags caniuse-lite and fails on unknown versions.
  targets: BROWSERSLIST_QUERIES,
  // Recovery silently drops unparseable rules along with valid declarations next to them.
  errorRecovery: false,
  // Lowered light-dark() needs a color-scheme declaration, and GitLab has one only for dark mode.
  exclude: Features.LightDark,
});

const ENTRY_PREFIX = 'styles/';

const stylesheetsPath = path.join(ROOT_PATH, 'app/assets/stylesheets');

const imagesPaths = [
  IS_JH && path.join(ROOT_PATH, 'jh/app/assets/images'),
  IS_EE && path.join(ROOT_PATH, 'ee/app/assets/images'),
  path.join(ROOT_PATH, 'app/assets/images'),
].filter(Boolean);

function buildStylesheetEntries() {
  const sources = {
    'tailwind.css': path.join(stylesheetsPath, 'tailwind.css'),
    'lazy_bundles/cropper.css': path.join(stylesheetsPath, 'lazy_bundles/cropper.css'),
    ...resolveCompilationTargetsForVite(),
  };

  return Object.fromEntries(
    Object.entries(sources)
      .filter(([output]) => !output.startsWith('mailers/'))
      .map(([output, source]) => [
        `${ENTRY_PREFIX}${output.replace(/\.css$/, '')}`,
        `${source}?${STYLESHEET_QUERY}`,
      ]),
  );
}

function buildStylesheetRules({ sourceMap }) {
  const lightningcssLoader = {
    loader: 'builtin:lightningcss-loader',
    options: { ...LIGHTNINGCSS_OPTIONS },
  };
  const postcssLoader = {
    loader: 'postcss-loader',
    options: {
      sourceMap,
      postcssOptions: { plugins: [tailwindcss(tailwindConfig), autoprefixer()] },
    },
  };

  return [
    {
      test: /\.css$/,
      resourceQuery: STYLESHEET_QUERY_RE,
      type: 'css',
      use: [lightningcssLoader, postcssLoader],
    },
    {
      test: /\.scss$/,
      resourceQuery: STYLESHEET_QUERY_RE,
      type: 'css',
      use: [
        lightningcssLoader,
        postcssLoader,
        {
          loader: 'sass-loader',
          options: {
            api: 'modern-compiler',
            sourceMap,
            sassOptions: {
              loadPaths: resolveLoadPaths(),
              logger: Logger.silent,
            },
          },
        },
      ],
    },
    {
      dependency: 'url',
      oneOf: [
        { scheme: /^data$/, type: 'asset/inline' },
        {
          type: 'asset/resource',
          generator: {
            // Native CSS bakes the public path in at build time, relative URLs keep working
            // under a relative URL root or an asset host.
            publicPath: 'auto',
            filename: '[name].[contenthash:8][ext]',
          },
        },
      ],
    },
  ];
}

// Sprockets resolved bare `url()` references against its asset paths, so the stylesheets
// rely on lookups like `url('illustrations/foo.svg')` and `url('gitlab-sans/x.woff2')`.
const urlResolve = {
  preferRelative: true,
  modules: [
    ...imagesPaths,
    path.join(ROOT_PATH, 'node_modules/@gitlab/svgs/dist'),
    path.join(ROOT_PATH, 'node_modules/@gitlab/fonts'),
    path.join(ROOT_PATH, 'vendor/assets/fonts'),
    'node_modules',
  ],
};

export { buildStylesheetEntries, buildStylesheetRules, LIGHTNINGCSS_OPTIONS, urlResolve };
