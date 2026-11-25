# frozen_string_literal: true

# Every Labkit::RateLimit::Limiter reads its contract defaults and overrides
# from this document. A rejected contract logs and leaves the document empty.
Labkit::RateLimit.configure do |config|
  config.rule_document = Gitlab::RateLimit::RuleDocument.load
end
