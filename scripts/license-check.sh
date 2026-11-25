#!/usr/bin/env bash
set -euo pipefail
#
# This script runs the LicenseFinder gem to verify that all licenses are
# compliant. However, bundler v2.2+ and LicenseFinder do not play well
# together when:
#
# 1. There are native gems installed (e.g. nokogiri, grpc, and google-protobuf).
# 2. `Gemfile.lock` doesn't list the platform-specific gems that were installed.
#
# A full explanation is here:
# https://github.com/pivotal/LicenseFinder/issues/828#issuecomment-953359134
#
# To work around the issue, we configure bundler to install gems for the
# current Ruby platform, which causes Gemfile and Gemfile.lock to be
# updated with the platform-specific gems. This allows LicenseFinder to
# run properly. After it finishes, we clean up the mess.
#
# LicenseFinder lists Yarn 2+ packages with yarn-plugin-licenses, which GitLab
# doesn't load by default. The script imports it for the run and removes it again.

PROJECT_PATH=${1:-`pwd`}

function restore_git_state() {
  git checkout -q Gemfile Gemfile.lock
  scripts/frontend/yarn_licenses_plugin.sh remove
}

echo "Using project path ${PROJECT_PATH}"

GEMFILE_DIFF=`git diff Gemfile Gemfile.lock .yarnrc.yml`

if [ ! -z "$GEMFILE_DIFF" ]; then
  echo "LicenseFinder needs to lock the Gemfile to the current platform and add a Yarn plugin, but Gemfile, Gemfile.lock or .yarnrc.yml has changes."
  exit 1
fi

trap restore_git_state EXIT

scripts/frontend/yarn_licenses_plugin.sh import

BUNDLE_DEPLOYMENT=false BUNDLE_FROZEN=false bundle lock --add-platform `ruby -e "puts RUBY_PLATFORM"`
bundle exec license_finder --decisions-file config/dependency_decisions.yml --project-path ${PROJECT_PATH}
