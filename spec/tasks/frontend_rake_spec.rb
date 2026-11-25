# frozen_string_literal: true

require 'fast_spec_helper'
require 'rspec/core/rake_task'
require_relative '../support/matchers/abort_matcher'

RSpec.describe 'frontend rake tasks', :silence_stdout, feature_category: :tooling do
  let(:install_command) { 'yarn install --immutable' }

  before do
    allow(Rails).to receive(:env).and_return(double(production?: false)) # rubocop:disable RSpec/VerifiedDoubles -- Rails.env is a StringInquirer
    Rake.application.rake_require 'tasks/yarn'
    Rake.application.rake_require 'tasks/frontend'
    allow(main_object).to receive(:system).with('yarn --version', out: File::NULL).and_return(true)
    allow(main_object).to receive(:system).with(install_command).and_return(true)
    # run_rake_task only re-enables the task itself, not its prerequisites.
    %w[yarn:available yarn:install].each { |task| Rake::Task[task].reenable }
  end

  describe 'frontend:tests' do
    subject(:run_task) { run_rake_task('frontend:tests') }

    it 'installs the Node dependencies, then runs the Jest tests' do
      expect(main_object).to receive(:system).with(install_command).ordered.and_return(true)
      expect(main_object).to receive(:sh).with('yarn test').ordered.and_yield(true, nil)

      expect { run_task }.not_to raise_error
    end

    it 'aborts when the tests fail' do
      allow(main_object).to receive(:sh).with('yarn test').and_yield(false, nil)

      expect { run_task }.to abort_execution.with_message('rake frontend:tests failed')
    end
  end
end
