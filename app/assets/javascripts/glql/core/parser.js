import { isPlainObject } from 'lodash-es';
import { parse as parseYaml } from 'yaml';
import { glql } from '@gitlab/query-language-rust';
import { DEFAULT_DISPLAY_TYPE, MODE_ANALYTICS, MODE_STANDARD } from '../constants';
import { extractGroupOrProject } from '../utils/common';
import { glqlFeatureFlags } from '../utils/feature_flags';

// Like the GLQL API's Psych, merge `<<` keys into the block.
const YAML_OPTIONS = { merge: true };

// Like the GLQL API, read anything that is not a map as the query.
// A bare query with colons can make yaml.parse throw; return null instead.
export const parseMap = (text) => {
  try {
    const parsed = parseYaml(text, YAML_OPTIONS);
    return isPlainObject(parsed) ? parsed : null;
  } catch {
    return null;
  }
};

export const parseYAMLConfig = (frontmatter) => {
  const config = parseYaml(frontmatter, YAML_OPTIONS) || {};

  config.display = config.display || DEFAULT_DISPLAY_TYPE;

  return config;
};

export const parseQueryTextWithFrontmatter = (text) => {
  const frontmatter = text.match(/---\n([\s\S]*?)\n---/);
  const remaining = text.replace(frontmatter ? frontmatter[0] : '', '');
  return {
    frontmatter: frontmatter ? frontmatter[1].trim() : '',
    query: remaining.trim(),
  };
};

export const parseQuery = async (query, config, scope = null) => {
  const { output, success, variables, fields, mode, source } = await glql.compile(query, {
    ...config,
    // An explicit scope replaces the URL-derived one rather than merging with it: the compiler
    // prefers `project` over `group` unconditionally, so merging would let a stale URL-derived
    // `project` win and compile successfully against the wrong namespace.
    ...(scope ?? extractGroupOrProject()),
    username: gon.current_username,
    featureFlags: glqlFeatureFlags(),
  });

  if (!success) throw new Error(output);

  return {
    query: output,
    variables,
    config,
    fields,
    mode: mode || MODE_STANDARD,
    source,
  };
};

export const parseYAML = (yaml) => {
  let { frontmatter: config, query } = parseQueryTextWithFrontmatter(yaml);
  // Anything but a map with a string `query` is read as the query itself.
  const block = config ? null : parseMap(yaml);

  if (typeof block?.query === 'string') {
    ({ query, ...config } = block);
    config.display = config.display || DEFAULT_DISPLAY_TYPE;
  } else {
    config = parseYAMLConfig(config);
  }

  return { query, config };
};

export const parse = (yaml, scope = null, { bindings = [] } = {}) => {
  const { query, config } = parseYAML(yaml);

  // Only analytics sources accept lists of groups and projects; the compiler rejects them
  // elsewhere, so other queries keep the regular scope.
  if (bindings.length && config.mode === MODE_ANALYTICS) config.bindings = bindings;

  return parseQuery(query, config, scope);
};
