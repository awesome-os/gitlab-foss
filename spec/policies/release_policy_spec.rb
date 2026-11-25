# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleasePolicy, :request_store, feature_category: :release_orchestration do
  let_it_be(:developer) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, developers: developer) }
  let_it_be_with_reload(:release) { create(:release, project: project) }

  let(:permissions) { %i[create_release update_release destroy_release publish_catalog_version] }

  subject(:policy) { described_class.new(developer, release) }

  specify { expect(described_class).to delegate_to(ProjectPolicy) }

  context 'when the user can create the release tag' do
    let_it_be(:protected_tag) { create(:protected_tag, :developers_can_create, name: release.tag, project: project) }

    it { expect_allowed(*permissions) }
  end

  context 'when the user cannot create the release tag' do
    let_it_be(:protected_tag) { create(:protected_tag, :maintainers_can_create, name: release.tag, project: project) }

    it { expect_disallowed(*permissions) }
  end
end
