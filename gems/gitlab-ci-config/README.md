# gitlab-ci-config

GitLab CI configuration code extracted from the GitLab Rails monolith. Constants keep
their `Gitlab::Ci` names and `lib/` paths, so no call site changes.

The gem holds the pipeline expression lexer (`Gitlab::Ci::Pipeline::Expression::Lexer`,
its lexemes and `Token`). It depends on `gitlab-utils` for `Gitlab::UntrustedRegexp`
and on `gitlab-safe_request_store`, and needs nothing from the Rails application.

The monolith loads it from `config/application.rb` with `require 'gitlab_ci_config'`.
The `Gemfile` entry uses `require: false`, because Bundler would otherwise require
`gitlab/ci/config` and load the monolith's `Gitlab::Ci::Config` before Zeitwerk.

## Development

```shell
bundle install
bundle exec rspec
bundle exec rubocop
```
