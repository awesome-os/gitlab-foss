# frozen_string_literal: true

namespace :gitlab do
  namespace :rate_limits do
    desc 'GitLab | Rate limits | Validate the rate limit contract files in strict mode'
    task validate: :environment do
      document = Gitlab::RateLimit::RuleDocument.load!(strict: true)

      document.warnings.each do |warning|
        puts "warning: #{warning[:step]} #{warning[:limiter]}/#{warning[:rule]}: #{warning[:message]}"
      end

      files = Gitlab::RateLimit::RuleDocument.contract_files
      puts "rate limit contract: #{document.limiters.size} limiters in #{files.size} files"
    rescue Labkit::RateLimit::Config::Error => e
      # The message already starts with the step, as "<step>: <detail>".
      abort(e.message)
    end
  end
end
