# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::TriggerPolicy, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:admin) { create(:admin) }
  let_it_be_with_refind(:trigger) { create(:ci_trigger, project: project, owner: create(:user)) }

  subject(:policy) { described_class.new(current_user, trigger) }

  specify { expect(described_class.new(nil, trigger)).to delegate_to(ProjectPolicy) }

  context 'when the owner and another Maintainer are checked against the same trigger', :request_store do
    let_it_be(:other_maintainer) { create(:user, maintainer_of: project) }

    before do
      trigger.update!(owner: maintainer)
    end

    it 'answers for each user' do
      expect(Ability.allowed?(maintainer, :update_trigger, trigger)).to be(true)
      expect(Ability.allowed?(other_maintainer, :update_trigger, trigger)).to be(false)
    end
  end

  describe 'update_trigger' do
    context 'when the user owns the trigger' do
      let(:current_user) { maintainer }

      before do
        trigger.update!(owner: maintainer)
      end

      it { expect_allowed(:update_trigger) }

      context 'when the project is archived' do
        let_it_be(:archived_project) { create(:project, :archived, maintainers: maintainer) }
        let_it_be_with_refind(:archived_trigger) do
          create(:ci_trigger, project: archived_project, owner: maintainer)
        end

        subject(:policy) { described_class.new(current_user, archived_trigger) }

        it { expect_disallowed(:update_trigger) }
      end
    end

    context 'when the user does not own the trigger' do
      let(:current_user) { maintainer }

      it { expect_disallowed(:update_trigger) }
    end

    context 'when the user is an admin who does not own the trigger' do
      let(:current_user) { admin }

      context 'with admin mode enabled', :enable_admin_mode do
        it { expect_allowed(:update_trigger) }
      end

      context 'without admin mode enabled' do
        it { expect_disallowed(:update_trigger) }
      end
    end
  end
end
