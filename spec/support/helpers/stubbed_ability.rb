# frozen_string_literal: true

# Lets `Ability.allowed?` return stubbed permissions, falling back to the real policy.
module StubbedAbility
  class << self
    attr_accessor :stubs

    def reset
      @stubs = nil
    end
  end

  def allowed?(user, ability, subject = :global, **opts)
    # `Ability.allowed?(user, :ability, cache: false)` passes the options where the subject goes.
    if subject.is_a?(Hash)
      opts = subject
      subject = :global
    end

    stubbed = StubbedAbility.stubs&.dig([user, subject], ability.to_sym)
    stubbed.nil? ? super : stubbed
  end
end
