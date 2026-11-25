# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Helpers::Packages::Npm, feature_category: :package_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:namespace) { group }
  let_it_be(:project) { create(:project, :public, namespace: namespace) }
  let_it_be(:package) { create(:npm_package, project: project) }

  let(:package_name) { package.name }
  let(:object) { klass.new({}) }
  let(:klass) do
    Struct.new(:params) do
      include ::API::Helpers
      include ::API::Helpers::Packages::Npm
    end
  end

  describe '#enqueue_sync_npm_metadata_cache_worker' do
    it_behaves_like 'enqueue a worker to sync a npm metadata cache' do
      subject { object.enqueue_sync_npm_metadata_cache_worker(project, package_name) }
    end
  end

  describe '#npm_metadata_time_enabled?' do
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:subgroup_project) { create(:project, namespace: subgroup) }

    it 'checks the flag on the root ancestor' do
      stub_feature_flags(npm_metadata_time: group)

      expect(object.npm_metadata_time_enabled?(subgroup_project)).to be(true)
      expect(object.npm_metadata_time_enabled?(subgroup)).to be(true)
    end

    it 'is false when the flag is off for the root ancestor' do
      stub_feature_flags(npm_metadata_time: false)

      expect(object.npm_metadata_time_enabled?(project)).to be(false)
    end
  end
end
