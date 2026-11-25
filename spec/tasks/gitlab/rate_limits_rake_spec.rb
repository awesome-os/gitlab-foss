# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:rate_limits rake tasks', :silence_stdout, feature_category: :rate_limiting do
  before(:all) do
    Rake.application.rake_require 'tasks/gitlab/rate_limits'
  end

  describe 'validate' do
    subject(:validate) { run_rake_task('gitlab:rate_limits:validate') }

    it 'loads the contract files in strict mode and reports the count' do
      expect(Gitlab::RateLimit::RuleDocument).to receive(:load!).with(strict: true).and_call_original

      expect { validate }.to output(/\Arate limit contract: \d+ limiters in \d+ files\n\z/).to_stdout
    end

    it 'prints every warning the loader recorded' do
      document = Labkit::RateLimit::Config::Document.new(
        {}, [{ step: :contract, limiter: 'rack_request', rule: 'api', message: 'dropped match keys: plan' }]
      )
      allow(Gitlab::RateLimit::RuleDocument).to receive(:load!).and_return(document)

      expect { validate }
        .to output(a_string_including("warning: contract rack_request/api: dropped match keys: plan\n")).to_stdout
    end

    it 'aborts with the step and the detail when a file is rejected' do
      allow(Gitlab::RateLimit::RuleDocument).to receive(:load!)
        .and_raise(Labkit::RateLimit::Config::Error.new(:schema, 'rack_request.yaml:3: unknown field "limt"'))

      expect { validate }
        .to raise_error(SystemExit).and output("schema: rack_request.yaml:3: unknown field \"limt\"\n").to_stderr
    end
  end
end
