# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StubAbility, feature_category: :permissions do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:other_project) { create(:project, :public) }
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }

  describe '#stub_ability' do
    it 'returns the stubbed result for the user, subject and permission' do
      stub_ability(user, project, read_code: false)

      expect(Ability.allowed?(user, :read_code, project)).to be(false)
    end

    it 'runs the real policy for permissions it does not stub' do
      stub_ability(user, project, admin_project: true)

      expect(Ability.allowed?(user, :admin_project, project)).to be(true)
      expect(Ability.allowed?(user, :read_project, project)).to be(true)
      expect(Ability.allowed?(user, :push_code, project)).to be(false)
    end

    it 'runs the real policy for another user or subject' do
      stub_ability(user, project, read_code: false)

      expect(Ability.allowed?(other_user, :read_code, project)).to be(true)
      expect(Ability.allowed?(user, :read_code, other_project)).to be(true)
    end

    it 'keeps permissions stubbed by an earlier call' do
      stub_ability(user, project, read_code: false)
      stub_ability(user, project, admin_project: true)

      expect(Ability.allowed?(user, :read_code, project)).to be(false)
      expect(Ability.allowed?(user, :admin_project, project)).to be(true)
    end

    it 'lets a later call override an earlier one' do
      stub_ability(user, project, read_code: false)
      stub_ability(user, project, read_code: true)

      expect(Ability.allowed?(user, :read_code, project)).to be(true)
    end

    it 'keeps a hand stub on Ability.allowed? working' do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :push_code, project).and_return(true)
      stub_ability(user, project, read_code: false)

      expect(Ability.allowed?(user, :push_code, project)).to be(true)
      expect(Ability.allowed?(user, :read_code, project)).to be(false)
    end

    it 'covers can? from Gitlab::Allowable' do
      stub_ability(user, project, read_code: false)

      allowable = Class.new { include Gitlab::Allowable }.new

      expect(allowable.can?(user, :read_code, project)).to be(false)
    end

    it 'stubs global permissions' do
      stub_ability(user, :global, create_group: false)

      expect(Ability.allowed?(user, :create_group)).to be(false)
      expect(Ability.allowed?(user, :create_group, cache: false)).to be(false)
    end

    it 'raises for a permission the policy does not define' do
      expect { stub_ability(user, project, read_cdoe: false) }
        .to raise_error(ArgumentError, 'ProjectPolicy does not define :read_cdoe')
    end
  end
end
