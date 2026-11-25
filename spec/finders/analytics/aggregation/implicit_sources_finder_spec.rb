# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::Aggregation::ImplicitSourcesFinder, feature_category: :value_stream_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }

  let_it_be(:member_group) { create(:group, organization: organization, reporters: user) }
  let_it_be(:member_subgroup) { create(:group, parent: member_group, organization: organization, reporters: user) }
  let_it_be(:shared_group) { create(:group, organization: organization) }
  let_it_be(:subgroup_member_parent) { create(:group, organization: organization) }
  let_it_be(:subgroup_member_group) do
    create(:group, parent: subgroup_member_parent, organization: organization, reporters: user)
  end

  let_it_be(:project_member_group) { create(:group, organization: organization) }
  let_it_be(:project_member_project) { create(:project, group: project_member_group, reporters: user) }
  let_it_be(:other_group) { create(:group, organization: organization) }
  let_it_be(:foreign_group) { create(:group, organization: create(:organization), reporters: user) }

  let(:current_user) { user }
  let(:params) { { organization: organization } }

  subject(:execute) { described_class.new(current_user, params).execute }

  before_all do
    create(:group_group_link, shared_group: shared_group, shared_with_group: member_group)
  end

  it 'returns the top-level groups the user is a member of or that are shared with them' do
    expect(execute).to match_array([shared_group, member_group])
  end

  context 'when a top-level group deletion is in progress' do
    let_it_be(:deleting_group) do
      create(:group, organization: organization, reporters: user).tap do |group|
        group.update!(state: :deletion_in_progress)
      end
    end

    it 'skips the group' do
      expect(execute).to match_array([shared_group, member_group])
    end
  end

  context 'without a current user' do
    let(:current_user) { nil }

    it { is_expected.to be_empty }
  end
end
