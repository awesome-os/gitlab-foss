# frozen_string_literal: true

require_relative "lib/gitlab_ci_config/version"

Gem::Specification.new do |spec|
  spec.name = "gitlab-ci-config"
  spec.version = GitlabCiConfig::VERSION
  spec.authors = ["group::pipeline authoring"]
  spec.email = ["engineering@gitlab.com"]

  spec.summary = "GitLab CI configuration parsing"
  spec.description = "GitLab CI configuration code extracted from the GitLab Rails monolith, starting with " \
    "the pipeline expression lexer. Constants keep their original Gitlab::Ci names and lib/ paths."
  spec.homepage = "https://gitlab.com/gitlab-org/gitlab/-/tree/master/gems/gitlab-ci-config"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.2"
  spec.add_dependency "gitlab-safe_request_store", "~> 0.1"
  spec.add_dependency "gitlab-utils", "~> 0.1"

  spec.add_development_dependency "gitlab-styles", "~> 14.1"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rspec-parameterized", "~> 1.0"
end
