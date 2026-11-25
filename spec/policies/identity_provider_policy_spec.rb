# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IdentityProviderPolicy, feature_category: :system_access do
  subject(:policy) { described_class.new(user, provider) }

  let(:user) { build_stubbed(:user) }
  let(:provider) { :a_provider }

  it { expect_allowed(:link, :unlink) }

  context 'when the user is anonymous' do
    let(:user) { nil }

    it { expect_disallowed(:link, :unlink) }
  end

  context 'when the provider is SAML' do
    let(:provider) { 'saml' }

    it { expect_allowed(:link) }
    it { expect_disallowed(:unlink) }
  end
end
