# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../support/matchers/abort_matcher'

RSpec.describe 'eslint rake task', :silence_stdout, feature_category: :tooling do
  subject(:run_task) { run_rake_task('eslint') }

  let(:install_command) { 'yarn install --immutable' }

  before do
    allow(Rails).to receive(:env).and_return(double(production?: false)) # rubocop:disable RSpec/VerifiedDoubles -- Rails.env is a StringInquirer
    Rake.application.rake_require 'tasks/yarn'
    Rake.application.rake_require 'tasks/eslint'
    allow(main_object).to receive(:system).with('yarn --version', out: File::NULL).and_return(true)
    allow(main_object).to receive(:system).with(install_command).and_return(true)
    # run_rake_task only re-enables the task itself, not its prerequisites.
    %w[yarn:available yarn:install].each { |task| Rake::Task[task].reenable }
  end

  it 'installs the Node dependencies, then runs ESLint' do
    expect(main_object).to receive(:system).with(install_command).ordered.and_return(true)
    expect(main_object).to receive(:system).with('yarn run lint:eslint:all').ordered.and_return(true)

    expect { run_task }.not_to raise_error
  end

  it 'aborts when ESLint fails' do
    allow(main_object).to receive(:system).with('yarn run lint:eslint:all').and_return(false)

    expect { run_task }.to abort_execution.with_message('rake eslint failed')
  end
end
