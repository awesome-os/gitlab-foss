# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Achievements::UserAchievementPolicy, feature_category: :user_profile do
  let(:maintainer) { create(:user) }

  let(:group) { create(:group, :public) }

  let(:current_user) { create(:user) }
  let(:achievement) { create(:achievement, namespace: group) }
  let(:achievement_owner) { create(:user) }
  let(:user_achievement) { create(:user_achievement, achievement: achievement, user: achievement_owner) }

  before do
    group.add_maintainer(maintainer)
  end

  subject { described_class.new(current_user, user_achievement) }

  it { is_expected.to delegate_to(Achievements::AchievementPolicy) }
  it { is_expected.to delegate_to(GroupPolicy) }
  it { is_expected.to delegate_to(UserPolicy) }

  it 'is readable to everyone when user has public profile' do
    expect_allowed(:read_user_achievement)
  end

  context 'when user has private profile' do
    before do
      achievement_owner.update!(private_profile: true)
    end

    context 'for achievement owner' do
      let(:current_user) { achievement_owner }

      it 'is visible' do
        expect_allowed(:read_user_achievement)
      end
    end

    context 'for group maintainer' do
      let(:current_user) { maintainer }

      it 'is visible' do
        expect_allowed(:read_user_achievement)
      end
    end

    context 'for others' do
      it 'is hidden' do
        expect_disallowed(:read_user_achievement)
      end
    end
  end

  context 'when group is private' do
    let(:group) { create(:group, :private) }

    context 'for achievement owner' do
      let(:current_user) { achievement_owner }

      it 'is visible' do
        expect_allowed(:read_user_achievement)
      end
    end

    context 'for group maintainer' do
      let(:current_user) { maintainer }

      it 'is visible' do
        expect_allowed(:read_user_achievement)
      end
    end

    context 'for others' do
      it 'is not visible' do
        expect_disallowed(:read_user_achievement)
      end
    end
  end

  context 'when current_user and achievement owner are different' do
    it 'disallows updating the user achievement' do
      expect_disallowed(:update_owned_user_achievement, :update_user_achievement_show_on_profile,
        :update_user_achievement_award_message, :update_user_achievement)
    end
  end

  context 'when current_user and achievement owner are the same' do
    let(:current_user) { achievement_owner }

    it 'allows updating the user achievement' do
      expect_allowed(:update_owned_user_achievement, :update_user_achievement_show_on_profile,
        :update_user_achievement)
    end

    it { expect_disallowed(:update_user_achievement_award_message) }

    context 'when the user cannot read the achievement' do
      before do
        stub_permissions(read_achievement: false)
      end

      it { expect_disallowed(:read_user_achievement, :update_user_achievement) }
    end
  end

  context 'when current_user is a maintainer' do
    let(:current_user) { maintainer }

    it { expect_allowed(:update_user_achievement_award_message, :update_user_achievement) }
    it { expect_disallowed(:update_owned_user_achievement, :update_user_achievement_show_on_profile) }
  end
end
