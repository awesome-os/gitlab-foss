# frozen_string_literal: true

module Tooling
  # Files in domains/<name>/ mirror the top-level app/, lib/, spec/ and ee/ trees.
  # Plain Ruby with no requires, so Danger, RuboCop, scripts and specs can all load it.
  module Domains
    # Glob for the root of every domain.
    GLOB_PREFIX = 'domains/*/'
    # The root of one domain, for example domains/foo/.
    ROOT = %r{domains/[^/]+/}
    # Optional domain root, so a pattern matches the top-level tree and every domain tree.
    PATH_PREFIX = %r{(?:#{ROOT})?}
  end
end
