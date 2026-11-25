# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Git::TagPolicy, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:tag) { project.repository.tags.first }

  subject(:policy) { described_class.new(developer, tag) }

  it { is_expected.to delegate_to(ProjectPolicy) }

  it { expect_allowed(:delete_repository_tag) }

  context 'when the tag is protected' do
    before_all do
      create(:protected_tag, project: project, name: tag.name)
    end

    before do
      stub_permissions(delete_protected_tag: can_delete_protected_tag)
    end

    context 'when the user can delete protected tags' do
      let(:can_delete_protected_tag) { true }

      it { expect_allowed(:delete_repository_tag) }
    end

    context 'when the user cannot delete protected tags' do
      let(:can_delete_protected_tag) { false }

      it { expect_disallowed(:delete_repository_tag) }
    end
  end
end
