#!/usr/bin/env bash
set -euo pipefail
#
# Imports or removes yarn-plugin-licenses, which LicenseFinder needs to list
# Yarn 2+ packages. It isn't committed, so that only license runs load it.
# Used by scripts/license-check.sh and by Omnibus's package build.
#
# Usage: scripts/frontend/yarn_licenses_plugin.sh import|remove

PLUGIN_URL="https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.15.1/bundles/@yarnpkg/plugin-licenses.js"
PLUGIN_SHA256="825c8abba65ef53c878b486c69df5f6fdca5169b659fde23049d231235adf590"
PLUGIN_FILE="tmp/yarn-plugin-licenses.js"

case "${1:-}" in
  import)
    mkdir -p tmp
    curl --fail --silent --show-error --location --output "${PLUGIN_FILE}" "${PLUGIN_URL}"
    if ! ruby -rdigest -e 'exit Digest::SHA256.file(ARGV[0]).hexdigest == ARGV[1]' "${PLUGIN_FILE}" "${PLUGIN_SHA256}"; then
      echo "Checksum mismatch for ${PLUGIN_URL}"
      exit 1
    fi
    yarn plugin import "./${PLUGIN_FILE}"
    rm -f "${PLUGIN_FILE}"
    ;;
  remove)
    # Skip `yarn plugin remove` if the import didn't get that far, so cleanup works after a failed run.
    if grep -q '@yarnpkg/plugin-licenses' .yarnrc.yml; then
      yarn plugin remove @yarnpkg/plugin-licenses
    fi
    rm -rf .yarn/plugins "${PLUGIN_FILE}"
    ;;
  *)
    echo "Usage: $0 import|remove"
    exit 1
    ;;
esac
