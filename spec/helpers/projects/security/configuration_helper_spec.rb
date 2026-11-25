# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::ConfigurationHelper, feature_category: :security_testing_configuration do
  describe 'vulnerability_training_docs_path' do
    subject { helper.vulnerability_training_docs_path }

    it { is_expected.to eq(help_page_path('user/application_security/vulnerabilities/_index.md', anchor: 'enable-security-training-for-vulnerabilities')) }
  end

  describe 'group_owners_path' do
    let(:group) { build_stubbed(:group) }
    let(:project) { build_stubbed(:project, group: group) }
    let(:user) { build_stubbed(:user) }

    subject { helper.group_owners_path(project) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:can?).with(user, :read_group_member, group).and_return(can_read_group_member)
    end

    context 'when the user can read the root group members' do
      let(:can_read_group_member) { true }

      it { is_expected.to eq(group_group_members_path(group, max_role: "static-#{Gitlab::Access::OWNER}")) }
    end

    context 'when the user cannot read the root group members' do
      let(:can_read_group_member) { false }

      it { is_expected.to eq(project_project_members_path(project)) }
    end
  end
end
