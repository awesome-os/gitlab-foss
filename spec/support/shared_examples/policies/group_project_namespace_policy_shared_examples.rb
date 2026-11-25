# frozen_string_literal: true

RSpec.shared_examples 'checks timelog categories permissions' do
  context 'with no user' do
    let_it_be(:current_user, freeze: false) { nil }

    it { expect_disallowed(:read_timelog_category) }
  end

  context 'with a regular user' do
    let_it_be(:current_user, freeze: false) { create(:user) }

    it { expect_disallowed(:read_timelog_category) }
  end

  context 'with a reporter user' do
    let_it_be(:current_user, freeze: false) { create(:user) }

    before do
      users_container.add_reporter(current_user)
    end

    context 'when timelog_categories is enabled' do
      it { expect_allowed(:read_timelog_category) }
    end

    context 'when timelog_categories is disabled' do
      before do
        stub_feature_flags(timelog_categories: false)
      end

      it { expect_disallowed(:read_timelog_category) }
    end
  end
end
