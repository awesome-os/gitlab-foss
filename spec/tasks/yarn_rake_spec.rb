# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../support/matchers/abort_matcher'

RSpec.describe 'yarn rake tasks', :silence_stdout, feature_category: :tooling do
  before do
    Rake.application.rake_require 'tasks/yarn'
    allow(main_object).to receive(:system).with('yarn --version', out: File::NULL).and_return(true)
    stub_env('NODE_ENV', nil)
  end

  describe 'yarn:install' do
    subject(:run_task) { run_rake_task('yarn:install') }

    it 'runs an immutable install' do
      expect(main_object).to receive(:system).with('yarn install --immutable').and_return(true)

      expect { run_task }.not_to raise_error
    end

    it 'aborts when the install fails' do
      allow(main_object).to receive(:system).with('yarn install --immutable').and_return(false)

      expect { run_task }.to abort_execution.with_message(/Unable to install node modules/)
    end

    context 'when NODE_ENV is production' do
      before do
        stub_env('NODE_ENV', 'production')
      end

      it 'installs only the production dependencies' do
        expect(main_object).to receive(:system).with('yarn workspaces focus --production').and_return(true)

        expect { run_task }.not_to raise_error
      end
    end
  end
end
