# frozen_string_literal: true

module StubAbility
  def self.included(_base)
    Ability.singleton_class.prepend(StubbedAbility)
  end

  def reset_stubbed_abilities
    StubbedAbility.reset
  end

  # @note Only the given user, subject, and permissions are stubbed. Other
  #   `Ability.allowed?` checks run the real policy.
  # @param user [User]
  # @param subject [ApplicationRecord, Symbol] a record, or `:global`
  # @param permissions [Hash{Symbol => Boolean}] for example `read_code: false`
  def stub_ability(user, subject, **permissions)
    policy = DeclarativePolicy.policy_for(user, subject)

    permissions.each_key do |permission|
      next if Support::AbilityCheck::Checker.ok?(policy, permission)

      raise ArgumentError, "#{policy.class.name} does not define :#{permission}"
    end

    StubbedAbility.stubs ||= {}
    (StubbedAbility.stubs[[user, subject]] ||= {}).merge!(permissions)
  end
end
