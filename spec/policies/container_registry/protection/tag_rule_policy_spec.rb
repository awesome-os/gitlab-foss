# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Protection::TagRulePolicy, feature_category: :container_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, creator: user) }

  subject { described_class.new(user, rule) }

  it 'delegates to the project policy' do
    expect(described_class.new(user, build_stubbed(:container_registry_protection_tag_rule)))
      .to delegate_to(ProjectPolicy)
  end

  context 'for anonymous users' do
    let(:user) { nil }
    let_it_be(:rule) { build(:container_registry_protection_tag_rule) }

    it { expect_disallowed(:destroy_container_registry_protection_tag_rule) }
  end

  context 'for admin', :enable_admin_mode do
    let(:user) { build_stubbed(:admin) }
    let_it_be(:rule) { build(:container_registry_protection_tag_rule) }

    it { expect_allowed(:destroy_container_registry_protection_tag_rule) }
  end

  context 'for a tag rule' do
    let_it_be(:rule) { build(:container_registry_protection_tag_rule, project:) }
    let(:permission) { :destroy_container_registry_protection_tag_rule }

    where(:user_role, :allowed) do
      :developer   | false
      :maintainer  | true
      :owner       | true
    end

    with_them do
      before do
        project.send(:"add_#{user_role}", user)
      end

      it { allowed ? expect_allowed(permission) : expect_disallowed(permission) }
    end
  end
end
