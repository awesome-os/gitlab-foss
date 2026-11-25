# frozen_string_literal: true

require 'fast_spec_helper'
require 'danger'
require 'danger/plugins/internal/helper'
require 'gitlab/dangerfiles/spec_helper'

require_relative '../../../tooling/danger/changelog'

RSpec.describe Tooling::Danger::Changelog, feature_category: :tooling do
  include_context "with dangerfile"

  let(:fake_danger) { DangerSpecHelper.fake_danger.include(described_class) }
  let(:fake_helper) { Danger::Helper.new(changelog) }

  subject(:changelog) { fake_danger.new(git: fake_git) }

  before do
    allow(changelog).to receive(:helper).and_return(fake_helper)
  end

  describe '#ee_changes' do
    it 'returns the changed files in ee/ and domains/<name>/ee/' do
      allow(fake_helper).to receive(:all_changed_files).and_return(%w[
        ee/app/models/foo.rb
        domains/cd/ee/app/models/foo.rb
        app/models/foo.rb
        domains/cd/app/models/foo.rb
        domains/ee/app/models/foo.rb
        app/ee/foo.rb
      ])

      expect(changelog.ee_changes).to eq(%w[ee/app/models/foo.rb domains/cd/ee/app/models/foo.rb])
    end
  end

  describe 'plugin wiring' do
    it 'is prepended to the gem Changelog plugin' do
      require 'danger/plugins/changelog'
      load File.expand_path('../../../danger/plugins/project_helper.rb', __dir__)

      expect(Danger::Changelog.ancestors.first).to eq(described_class)
    end
  end
end
